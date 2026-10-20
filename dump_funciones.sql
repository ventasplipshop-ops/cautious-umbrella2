CREATE FUNCTION public.trial_feedback_submit(p_meta jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin

  insert into public.trial_feedback(meta)
  values (p_meta);

end;
$$;


ALTER FUNCTION public.trial_feedback_submit(p_meta jsonb) OWNER TO postgres;

--
-- Name: adjust_stock(uuid, uuid, integer, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.adjust_stock(p_company_id uuid, p_product_id uuid, p_quantity integer, p_reason text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_user uuid;
BEGIN
  v_user := current_setting('app.user_id', true)::uuid;

  INSERT INTO tenant.stock_movements (
    company_id,
    product_id,
    movement_type,
    quantity,
    reason,
    created_by
  )
  VALUES (
    p_company_id,
    p_product_id,
    'adjustment',
    p_quantity,
    p_reason,
    v_user
  );

  UPDATE tenant.products
  SET stock = stock + p_quantity
  WHERE id = p_product_id
    AND company_id = p_company_id;
END;
$$;


ALTER FUNCTION tenant.adjust_stock(p_company_id uuid, p_product_id uuid, p_quantity integer, p_reason text) OWNER TO postgres;

--
-- Name: bootstrap_company(text, text, text, text, text, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.bootstrap_company(p_bootstrap_key text, p_company_name text, p_company_slug text, p_admin_email text, p_admin_password text, p_admin_nombre text) RETURNS TABLE(company_id uuid, user_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_company_id uuid;
  v_user_id uuid;
  v_expected_key text;
begin

  -- 🔐 leer clave esperada desde config
  v_expected_key := current_setting('app.bootstrap_key', true);

  if v_expected_key is null or v_expected_key <> p_bootstrap_key then
    raise exception 'invalid bootstrap key';
  end if;

  insert into tenant.companies (name, slug)
  values (p_company_name, p_company_slug)
  returning id into v_company_id;

  insert into tenant.users (
    company_id,
    email,
    password,
    nombre,
    tipo_usuario
  )
  values (
    v_company_id,
    p_admin_email,
    p_admin_password,
    p_admin_nombre,
    'admin'
  )
  returning id into v_user_id;

  -- 🚀 SEED CRM DEFAULT
  perform tenant.crm_seed_default(v_company_id);

  return query
  select v_company_id, v_user_id;

end;
$$;


ALTER FUNCTION tenant.bootstrap_company(p_bootstrap_key text, p_company_name text, p_company_slug text, p_admin_email text, p_admin_password text, p_admin_nombre text) OWNER TO postgres;

--
-- Name: bootstrap_demo_company(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.bootstrap_demo_company() RETURNS TABLE(company_id uuid, user_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_company_id uuid;
  v_user_id uuid;
  v_slug text := 'demo_' || substr(gen_random_uuid()::text,1,8);
  v_now timestamptz := now();
  v_active_demos int;
begin

  perform set_config('search_path', 'tenant, public', true);

  -- 🔥 1️⃣ Contar demos activas
  select count(*)::int
  into v_active_demos
  from tenant.companies
  where is_demo = true
    and demo_expires_at > now();

  if v_active_demos >= 10 then
    raise exception 'demo_capacity_reached'
      using errcode = 'P0001';
  end if;

  -- 2️⃣ Crear empresa demo
  insert into tenant.companies(
    name,
    slug,
    is_demo,
    demo_expires_at
  )
  values (
    'Demo Company',
    v_slug,
    true,
    v_now + interval '30 minutes'
  )
  returning id into v_company_id;

  -- 3️⃣ Crear usuario admin demo
  insert into tenant.users(
    company_id,
    email,
    password,
    nombre,
    tipo_usuario
  )
  values (
    v_company_id,
    v_slug || '@demo.local',
    crypt(gen_random_uuid()::text, gen_salt('bf')),
    'Demo',
    'admin'
  )
  returning id into v_user_id;

  -- 🚀 SEED CRM DEFAULT
  perform tenant.crm_seed_default(v_company_id);

  return query
  select v_company_id, v_user_id;

end;
$$;


ALTER FUNCTION tenant.bootstrap_demo_company() OWNER TO postgres;

--
-- Name: calculate_combo_stock(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.calculate_combo_stock(p_product_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
  v_component jsonb;
  v_min_stock integer := null;
  v_component_stock integer;
  v_qty integer;
begin

  for v_component in
    select *
    from jsonb_array_elements(
      (
        select coalesce(metadata->'components','[]'::jsonb)
        from tenant.product_metadata
        where product_id = p_product_id
      )
    )
  loop

    v_qty := (v_component->>'quantity')::int;

    select stock
    into v_component_stock
    from tenant.products
    where id = (v_component->>'product_id')::uuid;

    v_component_stock := floor(v_component_stock / v_qty);

    if v_min_stock is null or v_component_stock < v_min_stock then
      v_min_stock := v_component_stock;
    end if;

  end loop;

  return coalesce(v_min_stock, 0);
end;
$$;


ALTER FUNCTION tenant.calculate_combo_stock(p_product_id uuid) OWNER TO postgres;

--
-- Name: cancel_order(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.cancel_order(p_company_id uuid, p_order_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
    v_order tenant.orders;
    v_item record;
begin

    -- =========================================
    -- VALIDAR
    -- =========================================

    select *
    into v_order
    from tenant.orders
    where id = p_order_id
      and company_id = p_company_id
      and status = 'reserved'
    for update;

    if not found then
        raise exception 'order_not_found';
    end if;

    -- =========================================
    -- LIBERAR STOCK
    -- =========================================

    for v_item in
        select *
        from tenant.order_items
        where order_id = p_order_id
    loop

        update tenant.products
        set reserved_stock =
            greatest(
                0,
                reserved_stock - v_item.quantity
            )
        where id = v_item.product_id
          and company_id = p_company_id;

    end loop;

    -- =========================================
    -- CANCELAR
    -- =========================================

    update tenant.orders
    set
        status = 'cancelled',
        cancelled_at = now()
    where id = p_order_id;

    return true;

end;
$$;


ALTER FUNCTION tenant.cancel_order(p_company_id uuid, p_order_id uuid) OWNER TO postgres;

--
-- Name: cancel_sale(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.cancel_sale(p_company_id uuid, p_sale_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_role text;
  v_item record;
BEGIN

  v_role := current_setting('app.current_role', true);

  IF v_role NOT IN ('admin', 'supervisor') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- 🔁 devolver stock
  FOR v_item IN
    SELECT product_id, quantity
    FROM tenant.sale_items
    WHERE sale_id = p_sale_id
  LOOP

    UPDATE tenant.products
    SET stock = stock + v_item.quantity
    WHERE id = v_item.product_id
      AND company_id = p_company_id;

    INSERT INTO tenant.stock_movements (
      company_id,
      product_id,
      movement_type,
      quantity,
      reference_id
    )
    VALUES (
      p_company_id,
      v_item.product_id,
      'cancel',
      v_item.quantity,
      p_sale_id
    );

  END LOOP;

  -- 🔥 marcar cancelada
  UPDATE tenant.sales
  SET status = 'cancelled'
  WHERE id = p_sale_id
    AND company_id = p_company_id;

END;
$$;


ALTER FUNCTION tenant.cancel_sale(p_company_id uuid, p_sale_id uuid) OWNER TO postgres;

--
-- Name: cash_closing_report(uuid, date); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.cash_closing_report(p_company_id uuid, p_date date DEFAULT CURRENT_DATE) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_role text;
BEGIN
    -- Configurar contexto
    PERFORM set_config('search_path', 'tenant, public', true);
    PERFORM set_config('row_security', 'off', true);

    v_role := current_setting('app.current_role', true);

    -- Solo administradores y supervisores
    IF v_role NOT IN ('admin', 'supervisor') THEN
        RAISE EXCEPTION 'forbidden';
    END IF;

    RETURN (
        SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
        FROM (
            SELECT
                u.id AS user_id,
                u.nombre AS operador,
                u.codigo_empleado,
                MIN(s.created_at) AS hora_ingreso,
                MAX(s.created_at) AS hora_ultima_venta,
                COUNT(s.id) AS total_ventas,
                COALESCE(SUM(s.total) FILTER (
                    WHERE s.payment_method = 'cash'
                ), 0) AS efectivo,
                COALESCE(SUM(s.total) FILTER (
                    WHERE s.payment_method = 'card'
                ), 0) AS tarjeta,
                COALESCE(SUM(s.total) FILTER (
                    WHERE s.payment_method = 'transfer'
                ), 0) AS transferencia,
                COALESCE(SUM(s.total), 0) AS total_facturado
            FROM tenant.users u
            LEFT JOIN tenant.sales s
                ON s.created_by = u.id
                AND s.company_id = p_company_id
                AND s.created_at::date = p_date
                AND COALESCE(s.status, 'pending') IN ('pending', 'confirmed')
            WHERE u.company_id = p_company_id
              AND u.tipo_usuario IN ('operador', 'supervisor', 'admin')
            GROUP BY u.id, u.nombre, u.codigo_empleado
        ) t
    );
END;
$$;


ALTER FUNCTION tenant.cash_closing_report(p_company_id uuid, p_date date) OWNER TO postgres;

--
-- Name: cleanup_expired_demos(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.cleanup_expired_demos() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_company_id uuid;
BEGIN
  FOR v_company_id IN
    SELECT id
    FROM tenant.companies
    WHERE is_demo = true
      AND demo_expires_at < now()
  LOOP
    -- Eliminar movimientos de stock
    DELETE FROM tenant.stock_movements
    WHERE company_id = v_company_id;

    -- Eliminar items de venta
    DELETE FROM tenant.sale_items
    WHERE sale_id IN (
      SELECT id FROM tenant.sales
      WHERE company_id = v_company_id
    );

    -- Eliminar ventas
    DELETE FROM tenant.sales
    WHERE company_id = v_company_id;

    -- Eliminar productos
    DELETE FROM tenant.products
    WHERE company_id = v_company_id;

    -- Eliminar usuarios
    DELETE FROM tenant.users
    WHERE company_id = v_company_id;

    -- Eliminar datos del CRM
    DELETE FROM tenant.crm_activities WHERE company_id = v_company_id;
    DELETE FROM tenant.crm_contacts WHERE company_id = v_company_id;
    DELETE FROM tenant.crm_leads WHERE company_id = v_company_id;
    DELETE FROM tenant.crm_stages WHERE company_id = v_company_id;
    DELETE FROM tenant.crm_pipelines WHERE company_id = v_company_id;

    -- Eliminar perfil
    DELETE FROM tenant.company_profile
    WHERE company_id = v_company_id;

    -- Finalmente eliminar la empresa
    DELETE FROM tenant.companies
    WHERE id = v_company_id;
  END LOOP;
END;
$$;


ALTER FUNCTION tenant.cleanup_expired_demos() OWNER TO postgres;

--
-- Name: confirm_order(uuid, uuid, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.confirm_order(p_company_id uuid, p_order_id uuid, p_payment_method text DEFAULT 'transfer'::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
    v_order tenant.orders;
    v_items jsonb;
    v_sale_id uuid;
    v_item record;
begin

    -- =========================================
    -- VALIDAR ORDER
    -- =========================================

    select *
    into v_order
    from tenant.orders
    where id = p_order_id
      and company_id = p_company_id
      and status = 'reserved'
      and expires_at > now()
    for update;

    if not found then
        raise exception 'order_not_available';
    end if;

    -- =========================================
    -- ARMAR ITEMS JSON
    -- =========================================

    select jsonb_agg(
        jsonb_build_object(
            'product_id', oi.product_id,
            'quantity', oi.quantity,
            'price', oi.unit_price
        )
    )
    into v_items
    from tenant.order_items oi
    where oi.order_id = p_order_id;

    if v_items is null then
        raise exception 'empty_order';
    end if;

    -- =========================================
    -- CREAR SALE
    -- =========================================

    v_sale_id := tenant.create_sale(
        p_company_id,
        v_items,
        p_payment_method
    );

    -- =========================================
    -- LIBERAR RESERVED STOCK
    -- =========================================

    for v_item in
        select *
        from tenant.order_items
        where order_id = p_order_id
    loop

        update tenant.products
        set reserved_stock =
            greatest(
                0,
                reserved_stock - v_item.quantity
            )
        where id = v_item.product_id
          and company_id = p_company_id;

    end loop;

    -- =========================================
    -- CERRAR ORDER
    -- =========================================

    update tenant.orders
    set
        status = 'paid',
        confirmed_at = now()
    where id = p_order_id;

    return v_sale_id;

end;
$$;


ALTER FUNCTION tenant.confirm_order(p_company_id uuid, p_order_id uuid, p_payment_method text) OWNER TO postgres;

--
-- Name: confirm_sale(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.confirm_sale(p_company_id uuid, p_sale_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_role text;
BEGIN

  v_role := current_setting('app.current_role', true);

  -- solo admin o caja
  IF v_role NOT IN ('admin','supervisor') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE tenant.sales
  SET status = 'confirmed'
  WHERE id = p_sale_id
    AND company_id = p_company_id;

END;
$$;


ALTER FUNCTION tenant.confirm_sale(p_company_id uuid, p_sale_id uuid) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;



CREATE FUNCTION tenant.create_company_profile(p_company_id uuid, p_profile_data jsonb) RETURNS tenant.company_profile
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_profile tenant.company_profile;
begin
  insert into tenant.company_profile (
    company_id,
    profile_data,
    profile_stage,
    profile_completed
  )
  values (
    p_company_id,
    coalesce(p_profile_data, '{}'::jsonb),
    1,
    false
  )
  returning * into v_profile;

  return v_profile;
exception
  when unique_violation then
    raise exception 'company profile already exists'
      using errcode = '23505';
end;
$$;


ALTER FUNCTION tenant.create_company_profile(p_company_id uuid, p_profile_data jsonb) OWNER TO postgres;

CREATE FUNCTION tenant.create_order_from_lead(p_company_id uuid, p_lead_id uuid, p_created_by uuid) RETURNS tenant.orders
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
    v_order tenant.orders;
begin

    -- =========================================
    -- VALIDAR LEAD
    -- =========================================
    if not exists (
        select 1
        from tenant.crm_leads l
        where l.id = p_lead_id
          and l.company_id = p_company_id
    ) then
        raise exception 'lead_not_found';
    end if;

    -- =========================================
    -- CANCELAR ÓRDENES RESERVADAS VENCIDAS
    -- =========================================
    update tenant.orders
    set
        status = 'expired',
        expired_at = now()
    where company_id = p_company_id
      and status = 'reserved'
      and expires_at < now();

    -- =========================================
    -- BUSCAR ÚLTIMA ORDEN DEL LEAD
    -- =========================================
    select *
    into v_order
    from tenant.orders
    where company_id = p_company_id
      and lead_id = p_lead_id
    order by created_at desc
    limit 1;

    -- =========================================
    -- VALIDAR ÚLTIMA ORDEN
    -- =========================================
    if found then

        if v_order.status = 'confirmed' then
            raise exception 'order_already_confirmed';
        end if;

        if v_order.status = 'paid' then
            raise exception 'order_already_paid';
        end if;

        if v_order.status = 'reserved'
           and v_order.expires_at > now()
        then
            return v_order;
        end if;

    end if;

    -- =========================================
    -- CREAR ORDER
    -- =========================================
    insert into tenant.orders (
        company_id,
        lead_id,
        status,
        expires_at,
        created_by
    )
    values (
        p_company_id,
        p_lead_id,
        'reserved',
        now() + interval '24 hours',
        p_created_by
    )
    returning *
    into v_order;

    return v_order;

end;
$$;


ALTER FUNCTION tenant.create_order_from_lead(p_company_id uuid, p_lead_id uuid, p_created_by uuid) OWNER TO postgres;


CREATE FUNCTION tenant.create_product(p_company_id uuid, p_name text, p_price numeric, p_stock integer DEFAULT 0, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS tenant.products
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_product tenant.products;
  v_metadata jsonb;
begin

  -- 🔥 asegurar metadata y type por defecto
  v_metadata := coalesce(p_metadata, '{}'::jsonb);

  if not (v_metadata ? 'type') then
    v_metadata := v_metadata || jsonb_build_object('type', 'simple');
  end if;

  insert into tenant.products (
    company_id, name, price, stock
  )
  values (
    p_company_id, p_name, p_price, coalesce(p_stock, 0)
  )
  returning * into v_product;

  insert into tenant.product_metadata (
    product_id,
    metadata
  )
  values (
    v_product.id,
    v_metadata
  );

  return v_product;
end;
$$;


ALTER FUNCTION tenant.create_product(p_company_id uuid, p_name text, p_price numeric, p_stock integer, p_metadata jsonb) OWNER TO postgres;

--
-- Name: create_reserved_order(uuid, uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.create_reserved_order(p_company_id uuid, p_lead_id uuid, p_created_by uuid) RETURNS tenant.orders
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
    v_order tenant.orders;
begin

    -- VALIDAR LEAD

    if not exists (
        select 1
        from tenant.crm_leads
        where id = p_lead_id
          and company_id = p_company_id
    ) then
        raise exception 'lead_not_found';
    end if;

    -- SI YA HAY UNA RESERVED ACTIVA
    -- DEVOLVERLA

    select *
    into v_order
    from tenant.orders
    where company_id = p_company_id
      and lead_id = p_lead_id
      and status = 'reserved'
      and expires_at > now()
    order by created_at desc
    limit 1;

    if found then
        return v_order;
    end if;

    -- CREAR RESERVED NUEVA

    insert into tenant.orders (
        company_id,
        lead_id,
        status,
        expires_at,
        created_by
    )
    values (
        p_company_id,
        p_lead_id,
        'reserved',
        now() + interval '24 hours',
        p_created_by
    )
    returning *
    into v_order;

    return v_order;

end;
$$;


ALTER FUNCTION tenant.create_reserved_order(p_company_id uuid, p_lead_id uuid, p_created_by uuid) OWNER TO postgres;

--
-- Name: create_sale(uuid, jsonb, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.create_sale(p_company_id uuid, p_items jsonb, p_payment_method text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_sale_id uuid;
  v_item jsonb;
  v_total numeric := 0;
  v_current_stock integer;
  v_user uuid;

  -- tipo producto principal
  v_type text;

  -- combo
  v_component jsonb;
  v_component_type text;

begin

  perform set_config('search_path', 'tenant, public', true);
  perform set_config('row_security', 'off', true);

  v_user := current_setting('app.user_id', true)::uuid;

  insert into tenant.sales (company_id, total, payment_method, created_by)
  values (p_company_id, 0, p_payment_method, v_user)
  returning id into v_sale_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop

    -- 🔥 tipo producto
    select coalesce(m.metadata->>'type', 'simple')
    into v_type
    from tenant.products p
    left join tenant.product_metadata m
      on m.product_id = p.id
    where p.id = (v_item->>'product_id')::uuid
      and p.company_id = p_company_id;

    if v_type is null then
      raise exception 'product not found';
    end if;

    -- 🔒 validar stock SOLO simple
    if v_type = 'simple' then

      select stock
      into v_current_stock
      from tenant.products
      where id = (v_item->>'product_id')::uuid
        and company_id = p_company_id
      for update;

      if v_current_stock < (v_item->>'quantity')::int then
        raise exception 'insufficient stock';
      end if;

    end if;

    -- ✔ guardar venta SIEMPRE
    insert into tenant.sale_items (
      sale_id,
      product_id,
      quantity,
      unit_price,
      subtotal
    )
    values (
      v_sale_id,
      (v_item->>'product_id')::uuid,
      (v_item->>'quantity')::int,
      (v_item->>'price')::numeric,
      (v_item->>'quantity')::int * (v_item->>'price')::numeric
    );

    -- 🔥 simple → descuenta normal
    if v_type = 'simple' then

      insert into tenant.stock_movements (
        company_id,
        product_id,
        movement_type,
        quantity,
        reference_id
      )
      values (
        p_company_id,
        (v_item->>'product_id')::uuid,
        'sale',
        -((v_item->>'quantity')::int),
        v_sale_id
      );

      update tenant.products
      set stock = stock - (v_item->>'quantity')::int
      where id = (v_item->>'product_id')::uuid
        and company_id = p_company_id;

    end if;

    -- 🔥 combo → recorrer componentes (SIN CAMBIOS)
    if v_type = 'combo' then

      for v_component in
        select *
        from jsonb_array_elements(
          (
            select coalesce(m.metadata->'components', '[]'::jsonb)
            from tenant.product_metadata m
            where m.product_id = (v_item->>'product_id')::uuid
          )
        )
      loop

        -- tipo del componente
        select coalesce(m2.metadata->>'type', 'simple')
        into v_component_type
        from tenant.products p2
        left join tenant.product_metadata m2
          on m2.product_id = p2.id
        where p2.id = (v_component->>'product_id')::uuid
          and p2.company_id = p_company_id;

        -- 🔥 SOLO simple descuenta
        if v_component_type = 'simple' then

          select stock
          into v_current_stock
          from tenant.products
          where id = (v_component->>'product_id')::uuid
            and company_id = p_company_id
          for update;

          if v_current_stock < ((v_component->>'quantity')::int * (v_item->>'quantity')::int) then
            raise exception 'insufficient stock (combo component)';
          end if;

          insert into tenant.stock_movements (
            company_id,
            product_id,
            movement_type,
            quantity,
            reference_id
          )
          values (
            p_company_id,
            (v_component->>'product_id')::uuid,
            'sale',
            -((v_component->>'quantity')::int * (v_item->>'quantity')::int),
            v_sale_id
          );

          update tenant.products
          set stock = stock - ((v_component->>'quantity')::int * (v_item->>'quantity')::int)
          where id = (v_component->>'product_id')::uuid
            and company_id = p_company_id;

        end if;

      end loop;

    end if;

    -- total
    v_total := v_total +
      ((v_item->>'quantity')::int * (v_item->>'price')::numeric);

  end loop;

  update tenant.sales
  set total = v_total
  where id = v_sale_id;

  return v_sale_id;
end;
$$;


ALTER FUNCTION tenant.create_sale(p_company_id uuid, p_items jsonb, p_payment_method text) OWNER TO postgres;



CREATE FUNCTION tenant.create_user(p_company_id uuid, p_nombre text, p_tipo_usuario text, p_password text) RETURNS tenant.users
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
  v_user tenant.users;
  v_email text;
  v_codigo text;
begin

  v_role := current_setting('app.current_role', true);

  if v_role <> 'admin' then
    raise exception 'forbidden';
  end if;

  if p_tipo_usuario not in ('operador','supervisor') then
    raise exception 'invalid role';
  end if;

  -- 🔥 email interno
  v_email := lower(replace(p_nombre, ' ', '')) 
             || '_' 
             || substr(gen_random_uuid()::text,1,6) 
             || '@local';

  -- 🔥 codigo empleado (6 chars alfanuméricos)
  v_codigo := upper(substr(md5(random()::text), 1, 6));

  insert into tenant.users (
    company_id,
    nombre,
    tipo_usuario,
    password,
    email,
    codigo_empleado
  )
  values (
    p_company_id,
    p_nombre,
    p_tipo_usuario,
    p_password,
    v_email,
    v_codigo
  )
  returning * into v_user;

  return v_user;

end;
$$;


ALTER FUNCTION tenant.create_user(p_company_id uuid, p_nombre text, p_tipo_usuario text, p_password text) OWNER TO postgres;

--
-- Name: create_user_simple(uuid, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.create_user_simple(p_company_id uuid, p_nombre text) RETURNS tenant.users
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_role text;
  v_user tenant.users;
BEGIN

  -- validar admin
  v_role := current_setting('app.current_role', true);

  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO tenant.users (
    company_id,
    nombre,
    tipo_usuario
  )
  VALUES (
    p_company_id,
    p_nombre,
    'vendedor'
  )
  RETURNING * INTO v_user;

  RETURN v_user;

END;
$$;


ALTER FUNCTION tenant.create_user_simple(p_company_id uuid, p_nombre text) OWNER TO postgres;


CREATE FUNCTION tenant.crm_add_activity(p_company_id uuid, p_lead_id uuid, p_note text) RETURNS tenant.crm_activities
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_user uuid;
  v_row tenant.crm_activities;
begin

  perform set_config('search_path','tenant, public',true);
  perform set_config('row_security','off',true);

  v_user := current_setting('app.user_id', true)::uuid;

  insert into tenant.crm_activities(
    company_id,
    lead_id,
    user_id,
    note
  )
  values (
    p_company_id,
    p_lead_id,
    v_user,
    p_note
  )
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION tenant.crm_add_activity(p_company_id uuid, p_lead_id uuid, p_note text) OWNER TO postgres;


CREATE FUNCTION tenant.crm_add_contact(p_company_id uuid, p_lead_id uuid, p_type text, p_value text, p_label text DEFAULT NULL::text, p_is_primary boolean DEFAULT false) RETURNS tenant.crm_contacts
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_row tenant.crm_contacts;
BEGIN

  INSERT INTO tenant.crm_contacts (
    company_id,
    lead_id,
    type,
    value,
    label,
    is_primary
  )
  VALUES (
    p_company_id,
    p_lead_id,
    p_type,
    p_value,
    p_label,
    p_is_primary
  )
  RETURNING * INTO v_row;

  RETURN v_row;

END;
$$;


ALTER FUNCTION tenant.crm_add_contact(p_company_id uuid, p_lead_id uuid, p_type text, p_value text, p_label text, p_is_primary boolean) OWNER TO postgres;

CREATE FUNCTION tenant.crm_create_lead(p_company_id uuid, p_pipeline_id uuid, p_stage_id uuid, p_title text, p_assigned_to uuid DEFAULT NULL::uuid) RETURNS tenant.crm_leads
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
  v_user uuid;
  v_row tenant.crm_leads;
begin

  perform set_config('search_path','tenant, public',true);
  perform set_config('row_security','off',true);

  v_role := current_setting('app.current_role', true);
  v_user := current_setting('app.user_id', true)::uuid;

  if v_role not in ('admin','vendedor') then
    raise exception 'forbidden';
  end if;

  insert into tenant.crm_leads(
    company_id,
    pipeline_id,
    stage_id,
    assigned_to,
    title
  )
  values (
    p_company_id,
    p_pipeline_id,
    p_stage_id,
    coalesce(p_assigned_to,v_user),
    p_title
  )
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION tenant.crm_create_lead(p_company_id uuid, p_pipeline_id uuid, p_stage_id uuid, p_title text, p_assigned_to uuid) OWNER TO postgres;




CREATE TABLE tenant.crm_pipelines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    name text NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE tenant.crm_pipelines OWNER TO postgres;

--
-- Name: crm_create_pipeline(uuid, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.crm_create_pipeline(p_company_id uuid, p_name text) RETURNS tenant.crm_pipelines
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
  v_row tenant.crm_pipelines;
begin

  perform set_config('search_path','tenant, public',true);
  perform set_config('row_security','off',true);

  v_role := current_setting('app.current_role', true);

  if v_role <> 'admin' then
    raise exception 'forbidden';
  end if;

  insert into tenant.crm_pipelines(company_id,name)
  values (p_company_id,p_name)
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION tenant.crm_create_pipeline(p_company_id uuid, p_name text) OWNER TO postgres;



CREATE FUNCTION tenant.crm_create_stage(p_company_id uuid, p_pipeline_id uuid, p_name text, p_position integer) RETURNS tenant.crm_stages
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
  v_row tenant.crm_stages;
begin

  perform set_config('search_path','tenant, public',true);
  perform set_config('row_security','off',true);

  v_role := current_setting('app.current_role', true);

  if v_role <> 'admin' then
    raise exception 'forbidden';
  end if;

  insert into tenant.crm_stages(company_id,pipeline_id,name,position)
  values (p_company_id,p_pipeline_id,p_name,p_position)
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION tenant.crm_create_stage(p_company_id uuid, p_pipeline_id uuid, p_name text, p_position integer) OWNER TO postgres;



CREATE FUNCTION tenant.crm_delete_stage(p_company_id uuid, p_stage_id uuid, p_role text DEFAULT 'user'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

  IF p_role <> 'admin' THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- 🚫 evitar borrar si hay leads
  IF EXISTS (
    SELECT 1
    FROM tenant.crm_leads
    WHERE stage_id = p_stage_id
      AND company_id = p_company_id
  ) THEN
    RAISE EXCEPTION 'stage_has_leads';
  END IF;

  DELETE FROM tenant.crm_stages
  WHERE id = p_stage_id
    AND company_id = p_company_id;

END;
$$;


ALTER FUNCTION tenant.crm_delete_stage(p_company_id uuid, p_stage_id uuid, p_role text) OWNER TO postgres;

--
-- Name: crm_list_activities(uuid, uuid, text, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.crm_list_activities(p_company_id uuid, p_lead_id uuid, p_role text DEFAULT 'user'::text, p_user_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_result jsonb;
BEGIN

  -- 🔐 validar acceso al lead
  IF NOT EXISTS (
    SELECT 1
    FROM tenant.crm_leads l
    WHERE l.id = p_lead_id
      AND l.company_id = p_company_id
      AND (
        p_role = 'admin'
        OR (p_user_id IS NOT NULL AND l.assigned_to = p_user_id)
      )
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- 📜 traer actividades
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'note', a.note,
        'type', a.type,
        'created_at', a.created_at
      )
      ORDER BY a.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_result
  FROM tenant.crm_activities a
  WHERE a.company_id = p_company_id
    AND a.lead_id = p_lead_id;

  RETURN v_result;

END;
$$;


ALTER FUNCTION tenant.crm_list_activities(p_company_id uuid, p_lead_id uuid, p_role text, p_user_id uuid) OWNER TO postgres;

--
-- Name: crm_list_board(uuid, uuid, text, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.crm_list_board(p_company_id uuid, p_assigned_to uuid DEFAULT NULL::uuid, p_role text DEFAULT 'user'::text, p_user_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_kpi jsonb;
BEGIN

  -- =========================
  -- KPI
  -- =========================
  SELECT jsonb_build_object(
    'open', coalesce(count(*) FILTER (WHERE l.status = 'open'), 0),
    'won',  coalesce(count(*) FILTER (WHERE l.status = 'won'), 0),
    'lost', coalesce(count(*) FILTER (WHERE l.status = 'lost'), 0),
    'total_value_open', coalesce(sum(l.value) FILTER (WHERE l.status = 'open'), 0)
  )
  INTO v_kpi
  FROM tenant.crm_leads l
  WHERE l.company_id = p_company_id
    AND (p_assigned_to IS NULL OR l.assigned_to = p_assigned_to)
    AND (
      p_role = 'admin'
      OR (p_user_id IS NOT NULL AND l.assigned_to = p_user_id)
    );

  -- =========================
  -- BOARD CON CONTACTOS
  -- =========================
  RETURN (
    SELECT jsonb_build_object(
      'kpi', v_kpi,
      'pipelines',
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'stages',
            (
              SELECT coalesce(
                jsonb_agg(
                  jsonb_build_object(
                    'id', s.id,
                    'name', s.name,
                    'position', s.position,
                    'leads',
                    coalesce(
                      (
                        SELECT jsonb_agg(
                          jsonb_build_object(
                            'id', l.id,
                            'title', l.title,
                            'value', l.value,
                            'status', l.status,
                            'assigned_to', l.assigned_to,

                            'contacts',
                            coalesce(
                              (
                                SELECT jsonb_agg(
                                  jsonb_build_object(
                                    'id', c.id,
                                    'type', c.type,
                                    'value', c.value,
                                    'label', c.label,
                                    'is_primary', c.is_primary
                                  )
                                )
                                FROM tenant.crm_contacts c
                                WHERE c.lead_id = l.id
                              ),
                              '[]'::jsonb
                            )
                          )
                        )
                        FROM tenant.crm_leads l
                        WHERE l.stage_id = s.id
                          AND l.company_id = p_company_id
                          AND (p_assigned_to IS NULL OR l.assigned_to = p_assigned_to)
                          AND (
                            p_role = 'admin'
                            OR (p_user_id IS NOT NULL AND l.assigned_to = p_user_id)
                          )
                      ),
                      '[]'::jsonb
                    )
                  )
                  ORDER BY s.position
                ),
                '[]'::jsonb
              )
              FROM tenant.crm_stages s
              WHERE s.pipeline_id = p.id
                AND s.company_id = p_company_id
            )
          )
        ),
        '[]'::jsonb
      )
    )
    FROM tenant.crm_pipelines p
    WHERE p.company_id = p_company_id
  );

END;
$$;


ALTER FUNCTION tenant.crm_list_board(p_company_id uuid, p_assigned_to uuid, p_role text, p_user_id uuid) OWNER TO postgres;

--
-- Name: crm_list_contacts(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.crm_list_contacts(p_company_id uuid, p_lead_id uuid) RETURNS jsonb
    LANGUAGE sql
    AS $$
  SELECT coalesce(
    jsonb_agg(c),
    '[]'::jsonb
  )
  FROM tenant.crm_contacts c
  WHERE c.company_id = p_company_id
    AND c.lead_id = p_lead_id;
$$;


ALTER FUNCTION tenant.crm_list_contacts(p_company_id uuid, p_lead_id uuid) OWNER TO postgres;

--
-- Name: crm_move_lead(uuid, uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.crm_move_lead(p_company_id uuid, p_lead_id uuid, p_new_stage_id uuid) RETURNS tenant.crm_leads
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
  v_user uuid;
  v_lead tenant.crm_leads;
begin

  perform set_config('search_path','tenant, public',true);
  perform set_config('row_security','off',true);

  v_role := current_setting('app.current_role', true);
  v_user := current_setting('app.user_id', true)::uuid;

  select * into v_lead
  from tenant.crm_leads
  where id = p_lead_id
  and company_id = p_company_id
  for update;

  if not found then
    raise exception 'lead not found';
  end if;

  if v_role = 'vendedor'
     and v_lead.assigned_to <> v_user then
     raise exception 'forbidden';
  end if;

  update tenant.crm_leads
  set stage_id = p_new_stage_id
  where id = p_lead_id
  returning * into v_lead;

  return v_lead;
end;
$$;


ALTER FUNCTION tenant.crm_move_lead(p_company_id uuid, p_lead_id uuid, p_new_stage_id uuid) OWNER TO postgres;

--
-- Name: crm_seed_default(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.crm_seed_default(p_company_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_pipeline_id uuid;
begin

  -- Crear pipeline default
  insert into tenant.crm_pipelines (
    company_id,
    name,
    is_default
  )
  values (
    p_company_id,
    'Pipeline Principal',
    true
  )
  returning id into v_pipeline_id;

  -- Crear stages base

  insert into tenant.crm_stages (company_id, pipeline_id, name, position)
  values
    (p_company_id, v_pipeline_id, 'Lead', 1),
    (p_company_id, v_pipeline_id, 'Contactado', 2),
    (p_company_id, v_pipeline_id, 'Propuesta', 3),
    (p_company_id, v_pipeline_id, 'Negociación', 4),
    (p_company_id, v_pipeline_id, 'Ganado', 5),
    (p_company_id, v_pipeline_id, 'Perdido', 6);

end;
$$;

ALTER FUNCTION tenant.crm_seed_default(p_company_id uuid) OWNER TO postgres;


CREATE FUNCTION tenant.crm_seed_missing_companies() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_company_id uuid;
begin

  for v_company_id in
    select c.id
    from tenant.companies c
    left join tenant.crm_pipelines p
      on p.company_id = c.id
    where p.id is null
  loop

    perform tenant.crm_seed_default(v_company_id);

  end loop;

end;
$$;


ALTER FUNCTION tenant.crm_seed_missing_companies() OWNER TO postgres;



CREATE FUNCTION tenant.crm_set_primary_contact(p_company_id uuid, p_contact_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_lead_id uuid;
  v_type text;
BEGIN

  SELECT lead_id, type
  INTO v_lead_id, v_type
  FROM tenant.crm_contacts
  WHERE id = p_contact_id;

  -- limpiar anteriores
  UPDATE tenant.crm_contacts
  SET is_primary = false
  WHERE lead_id = v_lead_id
    AND type = v_type;

  -- set nuevo
  UPDATE tenant.crm_contacts
  SET is_primary = true
  WHERE id = p_contact_id;

END;
$$;


ALTER FUNCTION tenant.crm_set_primary_contact(p_company_id uuid, p_contact_id uuid) OWNER TO postgres;

--
-- Name: crm_update_stage(uuid, uuid, text, integer, boolean, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.crm_update_stage(p_company_id uuid, p_stage_id uuid, p_name text, p_position integer, p_is_closed boolean, p_role text DEFAULT 'user'::text) RETURNS tenant.crm_stages
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_row tenant.crm_stages;
BEGIN

  -- 🔐 solo admin puede modificar
  IF p_role <> 'admin' THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE tenant.crm_stages
  SET
    name = coalesce(p_name, name),
    position = coalesce(p_position, position),
    is_closed = coalesce(p_is_closed, is_closed)
  WHERE id = p_stage_id
    AND company_id = p_company_id
  RETURNING * INTO v_row;

  IF v_row IS NULL THEN
    RAISE EXCEPTION 'stage_not_found';
  END IF;

  RETURN v_row;

END;
$$;


ALTER FUNCTION tenant.crm_update_stage(p_company_id uuid, p_stage_id uuid, p_name text, p_position integer, p_is_closed boolean, p_role text) OWNER TO postgres;

--
-- Name: dashboard_admin(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.dashboard_admin(p_company_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
  v_today jsonb;
  v_top jsonb;
  v_low jsonb;
begin
  perform set_config('search_path', 'tenant, public', true);
  perform set_config('row_security', 'off', true);

  v_role := current_setting('app.current_role', true);

  if v_role is null or v_role <> 'admin' then
    raise exception 'forbidden';
  end if;

  -- Ventas de hoy
  select json_build_object(
    'total_sales', coalesce(sum(s.total), 0),
    'transactions', coalesce(count(distinct s.id), 0),
    'total_items', coalesce(sum(si.quantity), 0)
  )
  into v_today
  from tenant.sales s
  left join tenant.sale_items si on si.sale_id = s.id
  where s.company_id = p_company_id
    and s.created_at::date = current_date;

  -- Top productos últimos 7 días
  select coalesce(json_agg(t), '[]'::json)
  into v_top
  from (
    select
      p.id as product_id,
      p.name,
      sum(si.quantity) as quantity
    from tenant.sale_items si
    join tenant.sales s on s.id = si.sale_id
    join tenant.products p on p.id = si.product_id
    where s.company_id = p_company_id
      and s.created_at >= current_date - interval '7 days'
    group by p.id, p.name
    order by quantity desc
    limit 5
  ) t;

  -- Stock bajo
  select coalesce(json_agg(t), '[]'::json)
  into v_low
  from (
    select id as product_id, name, stock
    from tenant.products
    where company_id = p_company_id
      and stock <= 5
    order by stock asc
  ) t;

  return json_build_object(
    'today', v_today,
    'top_products', v_top,
    'low_stock', v_low
  );
end;
$$;


ALTER FUNCTION tenant.dashboard_admin(p_company_id uuid) OWNER TO postgres;

--
-- Name: disable_company(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.disable_company(p_company_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin

    update tenant.companies
    set active = false
    where id = p_company_id;

end;
$$;


ALTER FUNCTION tenant.disable_company(p_company_id uuid) OWNER TO postgres;

--
-- Name: expire_orders(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.expire_orders() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
    v_order record;
    v_item record;
    v_count integer := 0;
begin

    -- =========================================
    -- BUSCAR ORDERS EXPIRADAS
    -- =========================================

    for v_order in
        select *
        from tenant.orders
        where status = 'reserved'
          and expires_at < now()
    loop

        -- =====================================
        -- LIBERAR RESERVED STOCK
        -- =====================================

        for v_item in
            select *
            from tenant.order_items
            where order_id = v_order.id
        loop

            update tenant.products
            set reserved_stock =
                greatest(
                    0,
                    reserved_stock - v_item.quantity
                )
            where id = v_item.product_id
              and company_id = v_order.company_id;

        end loop;

        -- =====================================
        -- MARCAR EXPIRADA
        -- =====================================

        update tenant.orders
        set
            status = 'expired',
            expired_at = now()
        where id = v_order.id;

        v_count := v_count + 1;

    end loop;

    return v_count;

end;
$$;


ALTER FUNCTION tenant.expire_orders() OWNER TO postgres;

--
-- Name: find_user_slugs(text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.find_user_slugs(p_email text) RETURNS TABLE(company_id uuid, slug text, company_name text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
  select
    c.id as company_id,
    c.slug,
    c.name as company_name
  from tenant.users u
  join tenant.companies c on c.id = u.company_id
  where
    lower(u.email) = lower(p_email)
    or upper(u.codigo_empleado) = upper(p_email)
  order by c.created_at asc
$$;


ALTER FUNCTION tenant.find_user_slugs(p_email text) OWNER TO postgres;

--
-- Name: get_company(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.get_company(p_company_id uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    AS $$
select jsonb_build_object(
    'company',
    row_to_json(c),

    'profile',
    (
        select row_to_json(cp)
        from tenant.company_profile cp
        where cp.company_id = c.id
    ),

    'users',
    (
        select coalesce(
            jsonb_agg(row_to_json(u)),
            '[]'::jsonb
        )
        from tenant.users u
        where u.company_id = c.id
    )
)
from tenant.companies c
where c.id = p_company_id;
$$;


ALTER FUNCTION tenant.get_company(p_company_id uuid) OWNER TO postgres;

--
-- Name: get_company_profile(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.get_company_profile(p_company_id uuid) RETURNS tenant.company_profile
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_profile tenant.company_profile;
begin
  select *
  into v_profile
  from tenant.company_profile
  where company_id = p_company_id;

  return v_profile;
end;
$$;


ALTER FUNCTION tenant.get_company_profile(p_company_id uuid) OWNER TO postgres;

--
-- Name: get_demo_principal(text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.get_demo_principal(p_company_slug text) RETURNS TABLE(company_id uuid, user_id uuid, tipo_usuario text, nombre text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
  select
    c.id as company_id,
    u.id as user_id,
    u.tipo_usuario,
    coalesce(u.nombre, 'Demo') as nombre
  from tenant.companies c
  join tenant.users u on u.company_id = c.id
  where c.slug = p_company_slug
  order by
    case when u.tipo_usuario = 'admin' then 0 else 1 end,
    u.created_at asc
  limit 1;
$$;


ALTER FUNCTION tenant.get_demo_principal(p_company_slug text) OWNER TO postgres;

--
-- Name: get_order(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.get_order(p_company_id uuid, p_order_id uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    AS $$
    select jsonb_build_object(
        'id', o.id,
        'status', o.status,
        'total', o.total,
        'expires_at', o.expires_at,
        'created_at', o.created_at,

        'items',
        coalesce(
            (
                select jsonb_agg(
                    jsonb_build_object(
                        'product_id', oi.product_id,
                        'quantity', oi.quantity,
                        'unit_price', oi.unit_price,
                        'subtotal', oi.subtotal
                    )
                )
                from tenant.order_items oi
                where oi.order_id = o.id
            ),
            '[]'::jsonb
        )
    )
    from tenant.orders o
    where o.id = p_order_id
      and o.company_id = p_company_id;
$$;


ALTER FUNCTION tenant.get_order(p_company_id uuid, p_order_id uuid) OWNER TO postgres;

--
-- Name: get_product(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.get_product(p_company_id uuid, p_product_id uuid) RETURNS TABLE(id uuid, company_id uuid, name text, price numeric, stock integer, image_url text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone, metadata jsonb)
    LANGUAGE sql SECURITY DEFINER
    AS $$
  select
    p.id,
    p.company_id,
    p.name,
    p.price,
    p.stock,
    p.image_url,
    p.is_active,
    p.created_at,
    p.updated_at,
    m.metadata
  from tenant.products p
  left join tenant.product_metadata m
    on m.product_id = p.id
  where p.company_id = p_company_id
    and p.id = p_product_id;
$$;


ALTER FUNCTION tenant.get_product(p_company_id uuid, p_product_id uuid) OWNER TO postgres;

--
-- Name: get_public_order(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.get_public_order(p_company_id uuid, p_lead_id uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    AS $$
    select jsonb_build_object(

        'id', o.id,
        'status', o.status,
        'total', o.total,
        'expires_at', o.expires_at,
        'created_at', o.created_at,

        'items',
        coalesce(
            (
                select jsonb_agg(
                    jsonb_build_object(
                        'product_id', oi.product_id,
                        'quantity', oi.quantity,
                        'unit_price', oi.unit_price,
                        'subtotal', oi.subtotal
                    )
                )
                from tenant.order_items oi
                where oi.order_id = o.id
            ),
            '[]'::jsonb
        )

    )
    from tenant.orders o
    where o.company_id = p_company_id
      and o.lead_id = p_lead_id
      and o.status = 'reserved'
      and o.expires_at > now()
    order by o.created_at desc
    limit 1;
$$;


ALTER FUNCTION tenant.get_public_order(p_company_id uuid, p_lead_id uuid) OWNER TO postgres;

--
-- Name: get_sale(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.get_sale(p_company_id uuid, p_sale_id uuid) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    AS $$
  select json_build_object(
    'id', s.id,
    'total', s.total,
    'payment_method', s.payment_method,
    'created_at', s.created_at,
    'items', json_agg(
      json_build_object(
        'product_id', si.product_id,
        'quantity', si.quantity,
        'unit_price', si.unit_price,
        'subtotal', si.subtotal
      )
    )
  )
  from tenant.sales s
  join tenant.sale_items si on si.sale_id = s.id
  where s.company_id = p_company_id
    and s.id = p_sale_id
  group by s.id;
$$;


ALTER FUNCTION tenant.get_sale(p_company_id uuid, p_sale_id uuid) OWNER TO postgres;

--
-- Name: init_company_profile(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.init_company_profile() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  insert into tenant.company_profile (company_id)
  values (new.id);

  return new;
end;
$$;


ALTER FUNCTION tenant.init_company_profile() OWNER TO postgres;

--
-- Name: init_demo_data(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.init_demo_data() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.is_demo = true then
    perform tenant.seed_demo_company(new.id);
  end if;

  return new;
end;
$$;


ALTER FUNCTION tenant.init_demo_data() OWNER TO postgres;

--
-- Name: list_companies(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_companies() RETURNS TABLE(id uuid, name text, slug text, is_demo boolean, created_at timestamp with time zone, users_count bigint)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    select
        c.id,
        c.name,
        c.slug,
        c.is_demo,
        c.created_at,
        count(u.id) as users_count
    from tenant.companies c
    left join tenant.users u
        on u.company_id = c.id
    group by
        c.id,
        c.name,
        c.slug,
        c.is_demo,
        c.created_at
    order by c.created_at desc;
$$;


ALTER FUNCTION tenant.list_companies() OWNER TO postgres;

--
-- Name: list_inventory(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_inventory(p_company_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_result jsonb;
  v_role text;
begin

  perform set_config('search_path', 'tenant, public', true);
  perform set_config('row_security', 'off', true);

  v_role := current_setting('app.current_role', true);

  if v_role is null or v_role <> 'admin' then
    raise exception 'forbidden';
  end if;

  select jsonb_agg(row_to_json(t))
  into v_result
  from (
    select
      p.id as product_id,
      p.name,
      p.price,
      p.stock,
      p.image_url,

      coalesce(m.metadata, '{}'::jsonb) as metadata, -- 🔥 NUEVO

      (p.price * p.stock) as stock_value,
      coalesce(count(sm.id), 0) as movements_count,
      max(sm.created_at) as last_movement,
      (p.stock <= 5) as is_low_stock

    from tenant.products p

    left join tenant.product_metadata m
      on m.product_id = p.id -- 🔥 JOIN metadata

    left join tenant.stock_movements sm
      on sm.product_id = p.id
      and sm.company_id = p_company_id

    where p.company_id = p_company_id

    group by
      p.id,
      p.name,
      p.price,
      p.stock,
      p.image_url,
      m.metadata -- 🔥 NECESARIO POR GROUP BY

  ) t;

  return coalesce(v_result, '[]'::jsonb);

end;
$$;


ALTER FUNCTION tenant.list_inventory(p_company_id uuid) OWNER TO postgres;

--
-- Name: list_orders(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_orders(p_company_id uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    AS $$
    select coalesce(
        jsonb_agg(
            jsonb_build_object(

                -- ORDER
                'id', o.id,
                'lead_id', o.lead_id,
                'status', o.status,
                'total', o.total,
                'expires_at', o.expires_at,
                'created_at', o.created_at,
                'confirmed_at', o.confirmed_at,

                -- CLIENTE
                'customer',
                jsonb_build_object(
                    'title', l.title,
                    'contact_name', l.contact_name,
                    'email', l.email,
                    'address', l.address,
                    'dni', l.dni,

                    -- TELEFONO PRINCIPAL
                    'phone',
                    (
                        select c.value
                        from tenant.crm_contacts c
                        where c.lead_id = l.id
                          and c.company_id = p_company_id
                          and c.type = 'phone'
                        order by c.is_primary desc, c.created_at asc
                        limit 1
                    )
                ),

                -- ITEMS
                'items',
                (
                    select coalesce(
                        jsonb_agg(
                            jsonb_build_object(
                                'product_id', oi.product_id,
                                'product_name', p.name,
                                'quantity', oi.quantity,
                                'unit_price', oi.unit_price,
                                'subtotal', oi.subtotal,
                                'image_url', p.image_url
                            )
                        ),
                        '[]'::jsonb
                    )
                    from tenant.order_items oi
                    join tenant.products p
                      on p.id = oi.product_id
                    where oi.order_id = o.id
                )

            )
            order by o.created_at desc
        ),
        '[]'::jsonb
    )
    from tenant.orders o
    join tenant.crm_leads l
      on l.id = o.lead_id
     and l.company_id = o.company_id
    where o.company_id = p_company_id;
$$;


ALTER FUNCTION tenant.list_orders(p_company_id uuid) OWNER TO postgres;

--
-- Name: list_products(uuid, boolean); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_products(p_company_id uuid, p_only_active boolean DEFAULT false) RETURNS SETOF tenant.products
    LANGUAGE sql SECURITY DEFINER
    AS $$
  select *
  from tenant.products
  where company_id = p_company_id
    and (not p_only_active or is_active = true)
  order by created_at desc;
$$;


ALTER FUNCTION tenant.list_products(p_company_id uuid, p_only_active boolean) OWNER TO postgres;

--
-- Name: list_products_full(uuid, boolean); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_products_full(p_company_id uuid, p_only_active boolean DEFAULT false) RETURNS TABLE(id uuid, company_id uuid, name text, price numeric, stock integer, image_url text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone, metadata jsonb)
    LANGUAGE sql SECURITY DEFINER
    AS $$
select
    p.id,
    p.company_id,
    p.name,
    p.price,

    greatest(
        0,
        p.stock - p.reserved_stock
    )::integer as stock,

    p.image_url,
    p.is_active,
    p.created_at,
    p.updated_at,
    coalesce(m.metadata, '{}'::jsonb) as metadata
from tenant.products p
left join tenant.product_metadata m
    on m.product_id = p.id
where p.company_id = p_company_id
  and (
      not p_only_active
      or p.is_active = true
  )
order by p.created_at desc;
$$;


ALTER FUNCTION tenant.list_products_full(p_company_id uuid, p_only_active boolean) OWNER TO postgres;

--
-- Name: list_products_operator(uuid, boolean); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_products_operator(p_company_id uuid, p_only_active boolean DEFAULT false) RETURNS SETOF tenant.products
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Evitar problemas de RLS y search_path
  PERFORM set_config('search_path', 'tenant, public', true);
  PERFORM set_config('row_security', 'off', true);

  RETURN QUERY
  SELECT *
  FROM tenant.products
  WHERE company_id = p_company_id
    AND (NOT p_only_active OR is_active = true)
  ORDER BY created_at DESC;
END;
$$;


ALTER FUNCTION tenant.list_products_operator(p_company_id uuid, p_only_active boolean) OWNER TO postgres;

--
-- Name: list_products_operator_full(uuid, boolean); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_products_operator_full(p_company_id uuid, p_only_active boolean DEFAULT false) RETURNS TABLE(id uuid, company_id uuid, name text, price numeric, stock integer, image_url text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  perform set_config('search_path', 'tenant, public', true);
  perform set_config('row_security', 'off', true);

  return query
  select
    p.id,
    p.company_id,
    p.name,
    p.price,
    p.stock,
    p.image_url,
    p.is_active,
    p.created_at,
    p.updated_at,
    coalesce(m.metadata, '{}'::jsonb) as metadata
  from tenant.products p
  left join tenant.product_metadata m
    on m.product_id = p.id
  where p.company_id = p_company_id
    and (not p_only_active or p.is_active = true)
  order by p.created_at desc;
end;
$$;


ALTER FUNCTION tenant.list_products_operator_full(p_company_id uuid, p_only_active boolean) OWNER TO postgres;

--
-- Name: list_sales(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_sales(p_company_id uuid) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    AS $$
  select json_agg(
    json_build_object(
      'id', s.id,
      'total', s.total,
      'payment_method', s.payment_method,
      'created_at', s.created_at,
      'items', (
        select json_agg(
          json_build_object(
            'product_id', si.product_id,
            'quantity', si.quantity,
            'unit_price', si.unit_price,
            'subtotal', si.subtotal
          )
        )
        from tenant.sale_items si
        where si.sale_id = s.id
      )
    )
    order by s.created_at desc
  )
  from tenant.sales s
  where s.company_id = p_company_id;
$$;


ALTER FUNCTION tenant.list_sales(p_company_id uuid) OWNER TO postgres;

--
-- Name: list_stock_movements(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.list_stock_movements(p_company_id uuid, p_product_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
begin
  perform set_config('search_path', 'tenant, public', true);
  perform set_config('row_security', 'off', true);

  v_role := current_setting('app.current_role', true);

  if v_role is null or v_role <> 'admin' then
    raise exception 'forbidden';
  end if;

  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', id,
          'movement_type', movement_type,
          'quantity', quantity,
          'reason', reason,
          'reference_id', reference_id,
          'created_at', created_at
        )
        order by created_at desc
      ),
      '[]'::jsonb
    )
    from tenant.stock_movements
    where company_id = p_company_id
      and product_id = p_product_id
  );
end;
$$;


ALTER FUNCTION tenant.list_stock_movements(p_company_id uuid, p_product_id uuid) OWNER TO postgres;

--
-- Name: login_universal(text, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.login_universal(p_email text, p_password text) RETURNS TABLE(user_id uuid, company_id uuid, slug text, nombre text, tipo_usuario text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT
        u.id AS user_id,
        u.company_id,
        c.slug,
        u.nombre,
        u.tipo_usuario
    FROM tenant.users u
    JOIN tenant.companies c ON c.id = u.company_id
    WHERE (
        LOWER(u.email) = LOWER(p_email)
        OR UPPER(u.codigo_empleado) = UPPER(p_email)
    )
    AND crypt(p_password, u.password) = u.password;
$$;


ALTER FUNCTION tenant.login_universal(p_email text, p_password text) OWNER TO postgres;

--
-- Name: login_user(text, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.login_user(p_company_slug text, p_email text) RETURNS TABLE(user_id uuid, company_id uuid, password_hash text, nombre text, tipo_usuario text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id,
    u.company_id,
    u.password,
    u.nombre,
    u.tipo_usuario
  FROM tenant.users u
  JOIN tenant.companies c ON c.id = u.company_id
  WHERE
    c.slug = p_company_slug
    AND (
      LOWER(u.email) = LOWER(p_email)
      OR UPPER(u.codigo_empleado) = UPPER(p_email)
    );
END;
$$;


ALTER FUNCTION tenant.login_user(p_company_slug text, p_email text) OWNER TO postgres;

--
-- Name: order_set_item(uuid, uuid, uuid, integer); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.order_set_item(p_company_id uuid, p_order_id uuid, p_product_id uuid, p_quantity integer) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
    v_order tenant.orders;
    v_product tenant.products;
    v_existing tenant.order_items;
    v_diff integer;
    v_available integer;
    v_total numeric(12,2);
begin

    -- =========================================
    -- VALIDAR CANTIDAD
    -- =========================================
    if p_quantity is null or p_quantity < 0 then
        raise exception 'invalid_quantity';
    end if;

    -- =========================================
    -- VALIDAR ORDER + LOCK
    -- =========================================
    select *
    into v_order
    from tenant.orders
    where id = p_order_id
      and company_id = p_company_id
      and status = 'reserved'
      and expires_at > now()
    for update;

    if not found then
        raise exception 'order_not_available';
    end if;

    -- =========================================
    -- VALIDAR PRODUCTO ACTIVO + LOCK
    -- =========================================
    select *
    into v_product
    from tenant.products
    where id = p_product_id
      and company_id = p_company_id
      and is_active = true
    for update;

    if not found then
        raise exception 'product_not_found';
    end if;

    -- =========================================
    -- ITEM EXISTENTE + LOCK
    -- =========================================
    select *
    into v_existing
    from tenant.order_items
    where order_id = p_order_id
      and product_id = p_product_id
    for update;

    -- =========================================
    -- CALCULAR DIFERENCIA
    -- =========================================
    v_diff := p_quantity - coalesce(v_existing.quantity, 0);

    -- =========================================
    -- VALIDAR STOCK DISPONIBLE
    -- =========================================
    v_available := v_product.stock - v_product.reserved_stock;

    if v_diff > 0 and v_available < v_diff then
        raise exception 'insufficient_stock';
    end if;

    -- =========================================
    -- ELIMINAR ITEM
    -- =========================================
    if p_quantity = 0 then

        if v_existing.id is not null then
            delete from tenant.order_items
            where id = v_existing.id;

            update tenant.products
            set reserved_stock = greatest(0, reserved_stock - v_existing.quantity)
            where id = p_product_id
              and company_id = p_company_id;
        end if;

    else

        -- =====================================
        -- INSERTAR ITEM
        -- =====================================
        if v_existing.id is null then

            insert into tenant.order_items (
                order_id,
                product_id,
                quantity,
                unit_price,
                subtotal
            )
            values (
                p_order_id,
                p_product_id,
                p_quantity,
                v_product.price,
                v_product.price * p_quantity
            );

        else

            -- =================================
            -- ACTUALIZAR ITEM
            -- =================================
            update tenant.order_items
            set
                quantity = p_quantity,
                unit_price = v_product.price,
                subtotal = v_product.price * p_quantity
            where id = v_existing.id;

        end if;

        -- =====================================
        -- AJUSTAR RESERVA
        -- =====================================
        update tenant.products
        set reserved_stock = greatest(0, reserved_stock + v_diff)
        where id = p_product_id
          and company_id = p_company_id;

    end if;

    -- =========================================
    -- RECALCULAR TOTAL
    -- =========================================
    select coalesce(sum(subtotal), 0)
    into v_total
    from tenant.order_items
    where order_id = p_order_id;

    update tenant.orders
    set total = v_total
    where id = p_order_id
      and company_id = p_company_id;

    -- =========================================
    -- RESPUESTA
    -- =========================================
    return json_build_object(
        'success', true,
        'order_id', p_order_id,
        'product_id', p_product_id,
        'quantity', p_quantity,
        'total', v_total
    );

end;
$$;


ALTER FUNCTION tenant.order_set_item(p_company_id uuid, p_order_id uuid, p_product_id uuid, p_quantity integer) OWNER TO postgres;

--
-- Name: recalculate_stock(uuid, uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.recalculate_stock(p_company_id uuid, p_product_id uuid) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    AS $$
  update tenant.products
  set stock = (
    select coalesce(sum(quantity), 0)
    from tenant.stock_movements
    where company_id = p_company_id
      and product_id = p_product_id
  )
  where id = p_product_id
    and company_id = p_company_id;
$$;


ALTER FUNCTION tenant.recalculate_stock(p_company_id uuid, p_product_id uuid) OWNER TO postgres;

--
-- Name: register_purchase(uuid, jsonb, text, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.register_purchase(p_company_id uuid, p_items jsonb, p_supplier text DEFAULT NULL::text, p_notes text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_purchase_id uuid;
  v_item jsonb;

  v_subtotal numeric := 0;
  v_iva numeric := 0;
  v_total numeric := 0;

  v_user uuid;

  v_qty int;
  v_price numeric;
  v_iva_unit numeric;
  v_sub numeric;

begin

  perform set_config('search_path', 'tenant, public', true);
  perform set_config('row_security', 'off', true);

  v_user := current_setting('app.user_id', true)::uuid;

  -- 🔹 crear cabecera
  insert into tenant.purchases (
    company_id,
    supplier,
    notes,
    subtotal,
    iva,
    total,
    created_by
  )
  values (
    p_company_id,
    p_supplier,
    p_notes,
    0,
    0,
    0,
    v_user
  )
  returning id into v_purchase_id;

  -- 🔹 recorrer items
  for v_item in select * from jsonb_array_elements(p_items)
  loop

    v_qty := (v_item->>'quantity')::int;
    v_price := (v_item->>'unit_price')::numeric;

    -- IVA opcional
    v_iva_unit := coalesce((v_item->>'iva_unit')::numeric, 0);

    v_sub := v_qty * v_price;

    -- 🔹 insertar item
    insert into tenant.purchase_items (
      purchase_id,
      product_id,
      quantity,
      unit_price,
      iva_unit,
      subtotal
    )
    values (
      v_purchase_id,
      (v_item->>'product_id')::uuid,
      v_qty,
      v_price,
      v_iva_unit,
      v_sub
    );

    -- 🔹 actualizar acumuladores
    v_subtotal := v_subtotal + v_sub;
    v_iva := v_iva + (v_iva_unit * v_qty);

    -- 🔥 usar tu función existente
    perform tenant.adjust_stock(
      p_company_id,
      (v_item->>'product_id')::uuid,
      v_qty,
      'purchase'
    );

  end loop;

  v_total := v_subtotal + v_iva;

  -- 🔹 cerrar cabecera
  update tenant.purchases
  set
    subtotal = v_subtotal,
    iva = v_iva,
    total = v_total
  where id = v_purchase_id;

  return v_purchase_id;

end;
$$;


ALTER FUNCTION tenant.register_purchase(p_company_id uuid, p_items jsonb, p_supplier text, p_notes text) OWNER TO postgres;

--
-- Name: return_sale(uuid, uuid, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.return_sale(p_company_id uuid, p_sale_id uuid, p_reason text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_return_id uuid;
  v_item record;
begin
  -- Validar que la venta exista y pertenezca a la empresa
  if not exists (
    select 1
    from tenant.sales
    where id = p_sale_id
      and company_id = p_company_id
  ) then
    raise exception 'sale not found';
  end if;

  -- Registrar devolución
  insert into tenant.sale_returns (
    company_id,
    sale_id,
    reason
  )
  values (
    p_company_id,
    p_sale_id,
    p_reason
  )
  returning id into v_return_id;

  -- Devolver stock por cada ítem vendido
  for v_item in
    select si.product_id, si.quantity
    from tenant.sale_items si
    join tenant.sales s on s.id = si.sale_id
    where si.sale_id = p_sale_id
      and s.company_id = p_company_id
  loop
    -- movimiento de stock
    insert into tenant.stock_movements (
      company_id,
      product_id,
      movement_type,
      quantity,
      reference_id
    )
    values (
      p_company_id,
      v_item.product_id,
      'return',
      v_item.quantity,
      v_return_id
    );

    -- actualizar stock cacheado
    update tenant.products
    set stock = stock + v_item.quantity
    where id = v_item.product_id
      and company_id = p_company_id;
  end loop;

  return v_return_id;
end;
$$;


ALTER FUNCTION tenant.return_sale(p_company_id uuid, p_sale_id uuid, p_reason text) OWNER TO postgres;

--
-- Name: seed_demo_company(uuid); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.seed_demo_company(p_company_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_product_id uuid;
  v_sale_id uuid;
  v_day int;
  v_qty int;
  v_price numeric;
begin

  perform set_config('search_path', 'tenant, public', true);

  ------------------------------------------------------------------
  -- 1️⃣ Crear 5 productos demo
  ------------------------------------------------------------------
  for v_day in 1..5 loop
    insert into tenant.products(company_id, name, price, stock)
    values (
      p_company_id,
      'Producto Demo ' || v_day,
      (random()*500 + 50)::numeric(12,2),
      0
    )
    returning id, price into v_product_id, v_price;

    insert into tenant.product_metadata(product_id)
    values (v_product_id);

    -- Cargar stock inicial via movimiento
    insert into tenant.stock_movements(
      company_id,
      product_id,
      movement_type,
      quantity,
      reason
    )
    values (
      p_company_id,
      v_product_id,
      'adjustment',
      100,
      'demo initial load'
    );
  end loop;


  ------------------------------------------------------------------
  -- 2️⃣ Generar 30 días de ventas simuladas
  ------------------------------------------------------------------
  for v_day in 1..30 loop

    insert into tenant.sales(company_id, total, payment_method, created_at)
    values (
      p_company_id,
      0,
      'cash',
      now() - (30 - v_day) * interval '1 day'
    )
    returning id into v_sale_id;

    for v_product_id, v_price in
      select id, price
      from tenant.products
      where company_id = p_company_id
      order by random()
      limit 2
    loop

      v_qty := (random()*3 + 1)::int;

      insert into tenant.sale_items(
        sale_id,
        product_id,
        quantity,
        unit_price,
        subtotal
      )
      values (
        v_sale_id,
        v_product_id,
        v_qty,
        v_price,
        v_qty * v_price
      );

      insert into tenant.stock_movements(
        company_id,
        product_id,
        movement_type,
        quantity,
        reference_id,
        created_at
      )
      values (
        p_company_id,
        v_product_id,
        'sale',
        -v_qty,
        v_sale_id,
        now() - (30 - v_day) * interval '1 day'
      );

    end loop;

    -- Actualizar total de la venta
    update tenant.sales s
    set total = (
      select sum(subtotal)
      from tenant.sale_items
      where sale_id = v_sale_id
    )
    where s.id = v_sale_id;

  end loop;


  ------------------------------------------------------------------
  -- 3️⃣ Recalcular stock final correctamente
  ------------------------------------------------------------------
  update tenant.products p
  set stock = (
    select coalesce(sum(quantity),0)
    from tenant.stock_movements sm
    where sm.product_id = p.id
      and sm.company_id = p_company_id
  )
  where p.company_id = p_company_id;

end;
$$;


ALTER FUNCTION tenant.seed_demo_company(p_company_id uuid) OWNER TO postgres;

--
-- Name: set_product_image(uuid, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.set_product_image(p_product_id uuid, p_image_url text) RETURNS tenant.products
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_product tenant.products;
begin
  update tenant.products
  set image_url = p_image_url
  where id = p_product_id
  returning * into v_product;

  if not found then
    raise exception 'product not found';
  end if;

  return v_product;
end;
$$;


ALTER FUNCTION tenant.set_product_image(p_product_id uuid, p_image_url text) OWNER TO postgres;

--
-- Name: set_product_image(uuid, uuid, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.set_product_image(p_company_id uuid, p_product_id uuid, p_image_url text) RETURNS tenant.products
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_product tenant.products;
begin
  update tenant.products
  set image_url = p_image_url
  where id = p_product_id
    and company_id = p_company_id
  returning * into v_product;

  if not found then
    raise exception 'product not found';
  end if;

  return v_product;
end;
$$;


ALTER FUNCTION tenant.set_product_image(p_company_id uuid, p_product_id uuid, p_image_url text) OWNER TO postgres;

--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION tenant.touch_updated_at() OWNER TO postgres;

--
-- Name: update_combo_stock(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.update_combo_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_product_id uuid;
  v_combo record;
begin

  -- 🔥 detectar origen
  if TG_TABLE_NAME = 'products' then
    v_product_id := NEW.id;
  else
    v_product_id := NEW.product_id;
  end if;

  -- 🔥 buscar combos que usan este producto
  for v_combo in
    select p.id
    from tenant.products p
    join tenant.product_metadata m
      on m.product_id = p.id
    where m.metadata->>'type' = 'combo'
      and exists (
        select 1
        from jsonb_array_elements(m.metadata->'components') comp
        where (comp->>'product_id')::uuid = v_product_id
      )
  loop

    update tenant.products
    set stock = tenant.calculate_combo_stock(v_combo.id)
    where id = v_combo.id;

  end loop;

  return null;
end;
$$;


ALTER FUNCTION tenant.update_combo_stock() OWNER TO postgres;

--
-- Name: update_company_profile(uuid, jsonb, integer, boolean); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.update_company_profile(p_company_id uuid, p_profile_data jsonb, p_profile_stage integer DEFAULT NULL::integer, p_profile_completed boolean DEFAULT NULL::boolean) RETURNS tenant.company_profile
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_profile tenant.company_profile;
begin
  update tenant.company_profile
  set
    profile_data =
      company_profile.profile_data || coalesce(p_profile_data, '{}'::jsonb),

    profile_stage =
      coalesce(p_profile_stage, profile_stage),

    profile_completed =
      coalesce(p_profile_completed, profile_completed)

  where company_id = p_company_id
  returning * into v_profile;

  if not found then
    raise exception 'company profile not found'
      using errcode = 'P0002';
  end if;

  return v_profile;
end;
$$;


ALTER FUNCTION tenant.update_company_profile(p_company_id uuid, p_profile_data jsonb, p_profile_stage integer, p_profile_completed boolean) OWNER TO postgres;

--
-- Name: update_product_admin(uuid, uuid, text, numeric, integer); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.update_product_admin(p_company_id uuid, p_product_id uuid, p_name text DEFAULT NULL::text, p_price numeric DEFAULT NULL::numeric, p_stock integer DEFAULT NULL::integer) RETURNS tenant.products
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
  v_product tenant.products;
  v_new_stock integer;
begin
  perform set_config('search_path', 'tenant, public', true);
  perform set_config('row_security', 'off', true);

  v_role := current_setting('app.current_role', true);

  if v_role is null or v_role <> 'admin' then
    raise exception 'forbidden';
  end if;

  -- 🔒 bloquear fila
  select *
  into v_product
  from tenant.products
  where id = p_product_id
    and company_id = p_company_id
  for update;

  if not found then
    raise exception 'product not found';
  end if;

  -- calcular nuevo stock
  v_new_stock := coalesce(p_stock, v_product.stock);

  if v_new_stock < 0 then
    raise exception 'stock cannot be negative';
  end if;

  -- actualizar
  update tenant.products
  set
    name  = coalesce(p_name, v_product.name),
    price = coalesce(p_price, v_product.price),
    stock = v_new_stock
  where id = p_product_id
    and company_id = p_company_id
  returning * into v_product;

  return v_product;
end;
$$;


ALTER FUNCTION tenant.update_product_admin(p_company_id uuid, p_product_id uuid, p_name text, p_price numeric, p_stock integer) OWNER TO postgres;


CREATE FUNCTION tenant.update_product_metadata(p_product_id uuid, p_metadata jsonb) RETURNS tenant.product_metadata
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_row tenant.product_metadata;
begin
  update tenant.product_metadata
  set metadata = metadata || p_metadata
  where product_id = p_product_id
  returning * into v_row;

  if not found then
    raise exception 'metadata not found';
  end if;

  return v_row;
end;
$$;


ALTER FUNCTION tenant.update_product_metadata(p_product_id uuid, p_metadata jsonb) OWNER TO postgres;

--
-- Name: update_product_metadata(uuid, uuid, jsonb); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.update_product_metadata(p_company_id uuid, p_product_id uuid, p_metadata jsonb) RETURNS tenant.product_metadata
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_row tenant.product_metadata;
begin
  update tenant.product_metadata m
  set metadata = metadata || p_metadata
  from tenant.products p
  where p.id = m.product_id
    and p.company_id = p_company_id
    and p.id = p_product_id
  returning m.* into v_row;

  if not found then
    raise exception 'metadata not found';
  end if;

  return v_row;
end;
$$;


ALTER FUNCTION tenant.update_product_metadata(p_company_id uuid, p_product_id uuid, p_metadata jsonb) OWNER TO postgres;

--
-- Name: users_create(text, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.users_create(p_nombre text, p_password text DEFAULT NULL::text) RETURNS tenant.users
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_role text;
  v_company_id uuid;
  v_user tenant.users;
BEGIN

  v_role := current_setting('app.current_role', true);
  v_company_id := current_setting('app.company_id', true)::uuid;

  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO tenant.users (
    company_id,
    nombre,
    password,
    tipo_usuario
  )
  VALUES (
    v_company_id,
    p_nombre,
    p_password,
    'vendedor'
  )
  RETURNING * INTO v_user;

  RETURN v_user;

END;
$$;


ALTER FUNCTION tenant.users_create(p_nombre text, p_password text) OWNER TO postgres;

--
-- Name: users_create(text, text, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.users_create(p_nombre text, p_password text, p_tipo_usuario text) RETURNS tenant.users
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_role text;
  v_user tenant.users;
  v_company uuid;
begin

  v_role := current_setting('app.current_role', true);
  v_company := current_setting('app.company_id', true)::uuid;

  if v_role <> 'admin' then
    raise exception 'forbidden';
  end if;

  if p_tipo_usuario not in ('operador','supervisor') then
    raise exception 'invalid_role';
  end if;

  insert into tenant.users (
    company_id,
    nombre,
    password,
    tipo_usuario
  )
  values (
    v_company,
    p_nombre,
    p_password,
    p_tipo_usuario
  )
  returning * into v_user;

  return v_user;

end;
$$;


ALTER FUNCTION tenant.users_create(p_nombre text, p_password text, p_tipo_usuario text) OWNER TO postgres;

--
-- Name: users_list(); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.users_list() RETURNS SETOF tenant.users
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_company_id uuid;
BEGIN

  v_company_id := current_setting('app.company_id', true)::uuid;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'no_company_context';
  END IF;

  RETURN QUERY
  SELECT *
  FROM tenant.users
  WHERE company_id = v_company_id
  ORDER BY created_at DESC;

END;
$$;


ALTER FUNCTION tenant.users_list() OWNER TO postgres;

--
-- Name: users_update(uuid, text, text, text); Type: FUNCTION; Schema: tenant; Owner: postgres
--

CREATE FUNCTION tenant.users_update(p_user_id uuid, p_nombre text DEFAULT NULL::text, p_password text DEFAULT NULL::text, p_tipo_usuario text DEFAULT NULL::text) RETURNS tenant.users
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_role text;
  v_company_id uuid;
  v_user tenant.users;
BEGIN

  v_role := current_setting('app.current_role', true);
  v_company_id := current_setting('app.company_id', true)::uuid;

  -- 🔐 solo admin
  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE tenant.users
  SET
    nombre = coalesce(p_nombre, nombre),
    password = coalesce(p_password, password),
    tipo_usuario = coalesce(p_tipo_usuario, tipo_usuario)
  WHERE id = p_user_id
    AND company_id = v_company_id
  RETURNING * INTO v_user;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;

  RETURN v_user;

END;
$$;


ALTER FUNCTION tenant.users_update(p_user_id uuid, p_nombre text, p_password text, p_tipo_usuario text) OWNER TO postgres;
