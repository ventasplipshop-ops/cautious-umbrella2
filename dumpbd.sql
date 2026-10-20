CREATE OR REPLACE FUNCTION reciclaje.crear_socio(

    p_company_id uuid,

    p_nombre text,

    p_documento text DEFAULT NULL,

    p_telefono text DEFAULT NULL,

    p_direccion text DEFAULT NULL,

    p_observaciones text DEFAULT NULL

)
RETURNS reciclaje.socios
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_codigo text;

    v_socio reciclaje.socios;

BEGIN

    IF reciclaje.limpiar_texto(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    v_codigo := reciclaje.generar_codigo(
        p_company_id,
        'SOC'
    );

    INSERT INTO reciclaje.socios (

        company_id,
        codigo,
        nombre,
        documento,
        telefono,
        direccion,
        observaciones

    )
    VALUES (

        p_company_id,

        v_codigo,

        reciclaje.limpiar_texto(p_nombre),

        reciclaje.texto_nulo(p_documento),

        reciclaje.texto_nulo(p_telefono),

        reciclaje.texto_nulo(p_direccion),

        reciclaje.texto_nulo(p_observaciones)

    )
    RETURNING *
    INTO v_socio;

    RETURN v_socio;

END;
$$;

CREATE OR REPLACE FUNCTION reciclaje.obtener_socio(

    p_company_id uuid,

    p_id uuid

)
RETURNS reciclaje.socios
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT *

FROM reciclaje.socios

WHERE company_id = p_company_id
AND id = p_id
AND activo = true;

$$;

CREATE OR REPLACE FUNCTION reciclaje.listar_socios(

    p_company_id uuid

)
RETURNS SETOF reciclaje.socios
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT *

FROM reciclaje.socios

WHERE company_id = p_company_id
AND activo = true

ORDER BY nombre;

$$;

CREATE OR REPLACE FUNCTION reciclaje.actualizar_socio(

    p_company_id uuid,

    p_id uuid,

    p_nombre text,

    p_documento text,

    p_telefono text,

    p_direccion text,

    p_observaciones text

)
RETURNS reciclaje.socios
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_socio reciclaje.socios;

BEGIN

    IF reciclaje.limpiar_texto(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    UPDATE reciclaje.socios

    SET

        nombre = reciclaje.limpiar_texto(p_nombre),

        documento = reciclaje.texto_nulo(p_documento),

        telefono = reciclaje.texto_nulo(p_telefono),

        direccion = reciclaje.texto_nulo(p_direccion),

        observaciones = reciclaje.texto_nulo(p_observaciones),

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_id

    RETURNING *
    INTO v_socio;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Socio no encontrado.';
    END IF;

    RETURN v_socio;

END;
$$;

CREATE OR REPLACE FUNCTION reciclaje.eliminar_socio(

    p_company_id uuid,

    p_id uuid

)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
BEGIN

    UPDATE reciclaje.socios

    SET

        activo = false,

        updated_at = now()

    WHERE company_id = p_company_id
    AND id = p_id;

    RETURN FOUND;

END;
$$;










CREATE OR REPLACE FUNCTION reciclaje.crear_transportista(

    p_company_id uuid,

    p_nombre text,

    p_telefono text DEFAULT NULL,

    p_placa text,

    p_activo boolean DEFAULT true

)
RETURNS reciclaje.transportistas
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_codigo text;

    v_transportista reciclaje.transportistas;

BEGIN

    IF trim(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    IF trim(p_placa) = '' THEN
        RAISE EXCEPTION 'La placa es obligatoria.';
    END IF;

    v_codigo := reciclaje.generar_codigo(
        p_company_id,
        'TRA'
    );

    INSERT INTO reciclaje.transportistas (

        company_id,

        codigo,

        nombre,

        telefono,

        placa,

        activo

    )
    VALUES (

        p_company_id,

        v_codigo,

        trim(p_nombre),

        nullif(trim(p_telefono), ''),

        upper(trim(p_placa)),

        coalesce(p_activo, true)

    )
    RETURNING *
    INTO v_transportista;

    RETURN v_transportista;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.obtener_transportista(

    p_company_id uuid,

    p_id uuid

)
RETURNS reciclaje.transportistas
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS
$$
DECLARE

    v_transportista reciclaje.transportistas;

BEGIN

    SELECT *
    INTO v_transportista
    FROM reciclaje.transportistas
    WHERE company_id = p_company_id
      AND id = p_id
      AND activo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transportista no encontrado.';
    END IF;

    RETURN v_transportista;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.listar_transportistas(

    p_company_id uuid

)
RETURNS SETOF reciclaje.transportistas
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT *

FROM reciclaje.transportistas

WHERE company_id = p_company_id
  AND activo = true

ORDER BY nombre;

$$;


CREATE OR REPLACE FUNCTION reciclaje.actualizar_transportista(

    p_company_id uuid,

    p_id uuid,

    p_nombre text,

    p_telefono text,

    p_placa text

)
RETURNS reciclaje.transportistas
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_transportista reciclaje.transportistas;

BEGIN

    IF trim(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    IF trim(p_placa) = '' THEN
        RAISE EXCEPTION 'La placa es obligatoria.';
    END IF;

    UPDATE reciclaje.transportistas

    SET

        nombre = trim(p_nombre),

        telefono = nullif(trim(p_telefono), ''),

        placa = upper(trim(p_placa)),

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_id

    RETURNING *
    INTO v_transportista;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transportista no encontrado.';
    END IF;

    RETURN v_transportista;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.eliminar_transportista(

    p_company_id uuid,

    p_id uuid

)
RETURNS reciclaje.transportistas
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_transportista reciclaje.transportistas;

BEGIN

    UPDATE reciclaje.transportistas

    SET

        activo = false,

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_id

    RETURNING *
    INTO v_transportista;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transportista no encontrado.';
    END IF;

    RETURN v_transportista;

END;
$$;





CREATE OR REPLACE FUNCTION reciclaje.crear_material(

    p_company_id uuid,

    p_nombre text,

    p_unidad text DEFAULT 'kg',

    p_metadata jsonb DEFAULT '{}'

)
RETURNS reciclaje.materiales
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_codigo text;

    v_material reciclaje.materiales;

BEGIN

    IF trim(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    IF trim(p_unidad) = '' THEN
        RAISE EXCEPTION 'La unidad es obligatoria.';
    END IF;

    v_codigo := reciclaje.generar_codigo(
        p_company_id,
        'MAT'
    );

    INSERT INTO reciclaje.materiales (

        company_id,

        codigo,

        nombre,

        unidad,

        metadata

    )
    VALUES (

        p_company_id,

        v_codigo,

        trim(p_nombre),

        lower(trim(p_unidad)),

        coalesce(p_metadata, '{}')

    )
    RETURNING *
    INTO v_material;

    RETURN v_material;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.obtener_material(

    p_company_id uuid,

    p_id uuid

)
RETURNS reciclaje.materiales
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS
$$
DECLARE

    v_material reciclaje.materiales;

BEGIN

    SELECT *
    INTO v_material
    FROM reciclaje.materiales
    WHERE company_id = p_company_id
      AND id = p_id
      AND activo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Material no encontrado.';
    END IF;

    RETURN v_material;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.listar_materiales(

    p_company_id uuid

)
RETURNS SETOF reciclaje.materiales
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT *

FROM reciclaje.materiales

WHERE company_id = p_company_id
  AND activo = true

ORDER BY nombre;

$$;


CREATE OR REPLACE FUNCTION reciclaje.actualizar_material(

    p_company_id uuid,

    p_id uuid,

    p_nombre text,

    p_unidad text,

    p_metadata jsonb

)
RETURNS reciclaje.materiales
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_material reciclaje.materiales;

BEGIN

    IF trim(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    IF trim(p_unidad) = '' THEN
        RAISE EXCEPTION 'La unidad es obligatoria.';
    END IF;

    UPDATE reciclaje.materiales

    SET

        nombre = trim(p_nombre),

        unidad = lower(trim(p_unidad)),

        metadata = coalesce(p_metadata, '{}'),

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_id

    RETURNING *
    INTO v_material;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Material no encontrado.';
    END IF;

    RETURN v_material;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.eliminar_material(

    p_company_id uuid,

    p_id uuid

)
RETURNS reciclaje.materiales
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_material reciclaje.materiales;

BEGIN

    UPDATE reciclaje.materiales

    SET

        activo = false,

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_id

    RETURNING *
    INTO v_material;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Material no encontrado.';
    END IF;

    RETURN v_material;

END;
$$;








CREATE OR REPLACE FUNCTION reciclaje.actualizar_stock_material(

    p_company_id uuid,

    p_material_id uuid,

    p_cantidad numeric

)
RETURNS reciclaje.materiales
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_material reciclaje.materiales;

BEGIN

    IF p_cantidad = 0 THEN
        RAISE EXCEPTION 'La cantidad no puede ser cero.';
    END IF;

    UPDATE reciclaje.materiales

    SET

        stock = stock + p_cantidad,

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_material_id
      AND stock + p_cantidad >= 0

    RETURNING *
    INTO v_material;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Material no encontrado.';
    END IF;

    IF v_material.stock < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente.';
    END IF;

    RETURN v_material;

END;
$$;










CREATE OR REPLACE FUNCTION reciclaje.crear_deposito(

    p_company_id uuid,

    p_nombre text,

    p_direccion text DEFAULT NULL,

    p_activo boolean DEFAULT true

)
RETURNS reciclaje.depositos
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_codigo text;

    v_deposito reciclaje.depositos;

BEGIN

    IF trim(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    v_codigo := reciclaje.generar_codigo(
        p_company_id,
        'DEP'
    );

    INSERT INTO reciclaje.depositos (

        company_id,

        codigo,

        nombre,

        direccion,

        activo

    )
    VALUES (

        p_company_id,

        v_codigo,

        trim(p_nombre),

        nullif(trim(p_direccion), ''),

        coalesce(p_activo, true)

    )
    RETURNING *
    INTO v_deposito;

    RETURN v_deposito;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.obtener_deposito(

    p_company_id uuid,

    p_id uuid

)
RETURNS reciclaje.depositos
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS
$$
DECLARE

    v_deposito reciclaje.depositos;

BEGIN

    SELECT *
    INTO v_deposito
    FROM reciclaje.depositos
    WHERE company_id = p_company_id
      AND id = p_id
      AND activo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Depósito no encontrado.';
    END IF;

    RETURN v_deposito;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.listar_depositos(

    p_company_id uuid

)
RETURNS SETOF reciclaje.depositos
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT *

FROM reciclaje.depositos

WHERE company_id = p_company_id
  AND activo = true

ORDER BY nombre;

$$;


CREATE OR REPLACE FUNCTION reciclaje.actualizar_deposito(

    p_company_id uuid,

    p_id uuid,

    p_nombre text,

    p_direccion text

)
RETURNS reciclaje.depositos
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_deposito reciclaje.depositos;

BEGIN

    IF trim(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    UPDATE reciclaje.depositos

    SET

        nombre = trim(p_nombre),

        direccion = nullif(trim(p_direccion), ''),

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_id

    RETURNING *
    INTO v_deposito;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Depósito no encontrado.';
    END IF;

    RETURN v_deposito;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.eliminar_deposito(

    p_company_id uuid,

    p_id uuid

)
RETURNS reciclaje.depositos
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_deposito reciclaje.depositos;

BEGIN

    UPDATE reciclaje.depositos

    SET

        activo = false,

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_id

    RETURNING *
    INTO v_deposito;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Depósito no encontrado.';
    END IF;

    RETURN v_deposito;

END;
$$;







CREATE OR REPLACE FUNCTION reciclaje.crear_orden_compra(

    p_company_id uuid,

    p_orden jsonb

)
RETURNS reciclaje.ordenes_compra
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_codigo text;

    v_orden reciclaje.ordenes_compra;

    v_material jsonb;

    v_pago jsonb;

    v_subtotal numeric(14,2) := 0;

BEGIN

    ----------------------------------------------------
    -- Validaciones
    ----------------------------------------------------

    IF jsonb_array_length(
        coalesce(
            p_orden->'materiales',
            '[]'::jsonb
        )
    ) = 0 THEN

        RAISE EXCEPTION
        'La orden debe contener al menos un material.';

    END IF;

    IF jsonb_array_length(
        coalesce(
            p_orden->'pagos',
            '[]'::jsonb
        )
    ) = 0 THEN

        RAISE EXCEPTION
        'Debe indicar al menos una forma de pago.';

    END IF;

    ----------------------------------------------------
    -- Código
    ----------------------------------------------------

    v_codigo := reciclaje.generar_codigo(

        p_company_id,

        'OC'

    );

    ----------------------------------------------------
    -- Cabecera
    ----------------------------------------------------

    INSERT INTO reciclaje.ordenes_compra(

        company_id,

        codigo,

        socio_id,

        transportista_id,

        estado,

        subtotal,

        total,

        observaciones

    )

    VALUES(

        p_company_id,

        v_codigo,

        (p_orden->>'socio_id')::uuid,

        (p_orden->>'transportista_id')::uuid,

        'borrador',

        0,

        0,

        reciclaje.texto_nulo(
            p_orden->>'observaciones'
        )

    )

    RETURNING *

    INTO v_orden;

    ----------------------------------------------------
    -- Detalle
    ----------------------------------------------------

    FOR v_material IN

        SELECT *

        FROM jsonb_array_elements(
            p_orden->'materiales'
        )

    LOOP

        INSERT INTO reciclaje.ordenes_compra_detalle(

            orden_compra_id,

            material_id,

            cantidad,

            precio_unitario,

            subtotal

        )

        VALUES(

            v_orden.id,

            (v_material->>'material_id')::uuid,

            (v_material->>'cantidad')::numeric,

            (v_material->>'precio_unitario')::numeric,

            (v_material->>'cantidad')::numeric
            *
            (v_material->>'precio_unitario')::numeric

        );

        v_subtotal :=

            v_subtotal +

            (

                (v_material->>'cantidad')::numeric

                *

                (v_material->>'precio_unitario')::numeric

            );

    END LOOP;

    ----------------------------------------------------
    -- Pagos
    ----------------------------------------------------

    FOR v_pago IN

        SELECT *

        FROM jsonb_array_elements(
            p_orden->'pagos'
        )

    LOOP

        INSERT INTO reciclaje.ordenes_compra_pagos(

            orden_compra_id,

            forma_pago_id,

            moneda_id,

            monto,

            referencia,

            observaciones

        )

        VALUES(

            v_orden.id,

            (v_pago->>'forma_pago_id')::uuid,

            (v_pago->>'moneda_id')::uuid,

            (v_pago->>'monto')::numeric,

            reciclaje.texto_nulo(
                v_pago->>'referencia'
            ),

            reciclaje.texto_nulo(
                v_pago->>'observaciones'
            )

        );

    END LOOP;

    ----------------------------------------------------
    -- Totales
    ----------------------------------------------------

    UPDATE reciclaje.ordenes_compra

    SET

        subtotal = v_subtotal,

        total = v_subtotal,

        updated_at = now()

    WHERE id = v_orden.id

    RETURNING *

    INTO v_orden;

    ----------------------------------------------------
    -- Resultado
    ----------------------------------------------------

    RETURN v_orden;

END;
$$;


CREATE OR REPLACE FUNCTION reciclaje.actualizar_orden_compra(

    p_company_id uuid,

    p_orden_id uuid,

    p_orden jsonb

)
RETURNS reciclaje.ordenes_compra
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_orden reciclaje.ordenes_compra;

    v_material jsonb;

    v_pago jsonb;

    v_subtotal numeric(14,2) := 0;

BEGIN

    ----------------------------------------------------
    -- Buscar orden
    ----------------------------------------------------

    SELECT *
    INTO v_orden
    FROM reciclaje.ordenes_compra
    WHERE company_id = p_company_id
      AND id = p_orden_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La orden de compra no existe.';
    END IF;

    IF v_orden.estado <> 'borrador' THEN
        RAISE EXCEPTION 'La orden ya no puede modificarse.';
    END IF;

    ----------------------------------------------------
    -- Actualizar cabecera
    ----------------------------------------------------

    UPDATE reciclaje.ordenes_compra

    SET

        socio_id = (p_orden->>'socio_id')::uuid,

        transportista_id = (p_orden->>'transportista_id')::uuid,

        observaciones = reciclaje.texto_nulo(
            p_orden->>'observaciones'
        ),

        updated_at = now()

    WHERE id = p_orden_id;

    ----------------------------------------------------
    -- Eliminar detalle anterior
    ----------------------------------------------------

    DELETE
    FROM reciclaje.ordenes_compra_detalle
    WHERE orden_compra_id = p_orden_id;

    ----------------------------------------------------
    -- Insertar nuevo detalle
    ----------------------------------------------------

    FOR v_material IN

        SELECT *
        FROM jsonb_array_elements(
            p_orden->'materiales'
        )

    LOOP

        INSERT INTO reciclaje.ordenes_compra_detalle(

            orden_compra_id,

            material_id,

            cantidad,

            precio_unitario,

            subtotal

        )

        VALUES(

            p_orden_id,

            (v_material->>'material_id')::uuid,

            (v_material->>'cantidad')::numeric,

            (v_material->>'precio_unitario')::numeric,

            (v_material->>'cantidad')::numeric
            *
            (v_material->>'precio_unitario')::numeric

        );

        v_subtotal :=

            v_subtotal +

            (

                (v_material->>'cantidad')::numeric

                *

                (v_material->>'precio_unitario')::numeric

            );

    END LOOP;

    ----------------------------------------------------
    -- Eliminar pagos anteriores
    ----------------------------------------------------

    DELETE
    FROM reciclaje.ordenes_compra_pagos
    WHERE orden_compra_id = p_orden_id;

    ----------------------------------------------------
    -- Insertar nuevos pagos
    ----------------------------------------------------

    FOR v_pago IN

        SELECT *
        FROM jsonb_array_elements(
            p_orden->'pagos'
        )

    LOOP

        INSERT INTO reciclaje.ordenes_compra_pagos(

            orden_compra_id,

            forma_pago_id,

            moneda_id,

            monto,

            referencia,

            observaciones

        )

        VALUES(

            p_orden_id,

            (v_pago->>'forma_pago_id')::uuid,

            (v_pago->>'moneda_id')::uuid,

            (v_pago->>'monto')::numeric,

            reciclaje.texto_nulo(
                v_pago->>'referencia'
            ),

            reciclaje.texto_nulo(
                v_pago->>'observaciones'
            )

        );

    END LOOP;

    ----------------------------------------------------
    -- Actualizar totales
    ----------------------------------------------------

    UPDATE reciclaje.ordenes_compra

    SET

        subtotal = v_subtotal,

        total = v_subtotal,

        updated_at = now()

    WHERE id = p_orden_id

    RETURNING *
    INTO v_orden;

    ----------------------------------------------------
    -- Resultado
    ----------------------------------------------------

    RETURN v_orden;

END;
$$;











CREATE OR REPLACE FUNCTION reciclaje.crear_recepcion(

    p_company_id uuid,

    p_orden_compra_id uuid,

    p_recibido_por text DEFAULT NULL,

    p_observaciones text DEFAULT NULL

)
RETURNS reciclaje.recepciones
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_codigo text;

    v_recepcion reciclaje.recepciones;

    v_orden reciclaje.ordenes_compra;

BEGIN

    ----------------------------------------------------
    -- Validar orden
    ----------------------------------------------------

    SELECT *
    INTO v_orden
    FROM reciclaje.ordenes_compra
    WHERE company_id = p_company_id
      AND id = p_orden_compra_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La orden de compra no existe.';
    END IF;

    IF v_orden.estado <> 'borrador' THEN
        RAISE EXCEPTION 'La orden ya fue enviada a recepción.';
    END IF;

    ----------------------------------------------------
    -- Validar detalle
    ----------------------------------------------------

    IF NOT EXISTS (

        SELECT 1

        FROM reciclaje.ordenes_compra_detalle

        WHERE orden_compra_id = p_orden_compra_id

    ) THEN

        RAISE EXCEPTION
        'La orden de compra no contiene materiales.';

    END IF;

    ----------------------------------------------------
    -- Validar que no exista otra recepción
    ----------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM reciclaje.recepciones

        WHERE company_id = p_company_id
          AND orden_compra_id = p_orden_compra_id
          AND estado <> 'cancelada'

    ) THEN

        RAISE EXCEPTION
        'La orden ya posee una recepción.';

    END IF;

    ----------------------------------------------------
    -- Generar código
    ----------------------------------------------------

    v_codigo := reciclaje.generar_codigo(

        p_company_id,

        'REC'

    );

    ----------------------------------------------------
    -- Crear recepción
    ----------------------------------------------------

    INSERT INTO reciclaje.recepciones(

        company_id,

        codigo,

        orden_compra_id,

        estado,

        recibido_por,

        observaciones

    )

    VALUES(

        p_company_id,

        v_codigo,

        p_orden_compra_id,

        'borrador',

        reciclaje.texto_nulo(p_recibido_por),

        reciclaje.texto_nulo(p_observaciones)

    )

    RETURNING *

    INTO v_recepcion;

    ----------------------------------------------------
    -- Copiar detalle
    ----------------------------------------------------

    INSERT INTO reciclaje.recepciones_detalle(

        recepcion_id,

        material_id,

        cantidad,

        precio_unitario,

        moneda,

        subtotal,

        observaciones

    )

    SELECT

        v_recepcion.id,

        material_id,

        cantidad,

        precio_unitario,

        moneda,

        subtotal,

        observaciones

    FROM reciclaje.ordenes_compra_detalle

    WHERE orden_compra_id = p_orden_compra_id;

    ----------------------------------------------------
    -- Cambiar estado de la orden
    ----------------------------------------------------

    UPDATE reciclaje.ordenes_compra

    SET

        estado = 'en_ruta',

        updated_at = now()

    WHERE id = p_orden_compra_id;

    ----------------------------------------------------
    -- Resultado
    ----------------------------------------------------

    RETURN v_recepcion;

END;
$$;

GRANT EXECUTE
ON FUNCTION reciclaje.crear_recepcion(uuid,uuid,text,text)
TO tenant_app;

CREATE OR REPLACE FUNCTION reciclaje.listar_ordenes_compra(

    p_company_id uuid

)
RETURNS SETOF reciclaje.ordenes_compra
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT *

FROM reciclaje.ordenes_compra

WHERE company_id = p_company_id

ORDER BY created_at DESC;

$$;

GRANT EXECUTE
ON FUNCTION reciclaje.listar_ordenes_compra(uuid)
TO tenant_app;


CREATE OR REPLACE FUNCTION reciclaje.cancelar_orden_compra(

    p_company_id uuid,

    p_orden_compra_id uuid

)
RETURNS reciclaje.ordenes_compra
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_orden reciclaje.ordenes_compra;

BEGIN

    SELECT *

    INTO v_orden

    FROM reciclaje.ordenes_compra

    WHERE company_id = p_company_id
      AND id = p_orden_compra_id

    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La orden de compra no existe.';
    END IF;

    IF v_orden.estado <> 'borrador' THEN
        RAISE EXCEPTION 'Solo se puede cancelar una orden en borrador.';
    END IF;

    UPDATE reciclaje.ordenes_compra

    SET

        estado = 'cancelada',

        updated_at = now()

    WHERE id = p_orden_compra_id

    RETURNING *

    INTO v_orden;

    RETURN v_orden;

END;
$$;

GRANT EXECUTE
ON FUNCTION reciclaje.cancelar_orden_compra(uuid,uuid)
TO tenant_app;













CREATE OR REPLACE FUNCTION reciclaje.confirmar_recepcion(

    p_company_id uuid,

    p_recepcion_id uuid

)
RETURNS reciclaje.recepciones
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_recepcion reciclaje.recepciones;

    v_detalle record;

    v_socio_id uuid;

    v_transportista_id uuid;

BEGIN

    ----------------------------------------------------
    -- Buscar recepción
    ----------------------------------------------------

    SELECT *
    INTO v_recepcion
    FROM reciclaje.recepciones
    WHERE company_id = p_company_id
      AND id = p_recepcion_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La recepción no existe.';
    END IF;

    IF v_recepcion.estado <> 'borrador' THEN
        RAISE EXCEPTION 'La recepción ya fue confirmada.';
    END IF;

    IF v_recepcion.deposito_id IS NULL THEN
        RAISE EXCEPTION
        'Debe seleccionar un depósito antes de confirmar la recepción.';
    END IF;

    ----------------------------------------------------
    -- Datos de la orden
    ----------------------------------------------------

    SELECT

        socio_id,

        transportista_id

    INTO

        v_socio_id,

        v_transportista_id

    FROM reciclaje.ordenes_compra

    WHERE id = v_recepcion.orden_compra_id;

    ----------------------------------------------------
    -- Actualizar stock y movimientos
    ----------------------------------------------------

    FOR v_detalle IN

        SELECT *

        FROM reciclaje.recepciones_detalle

        WHERE recepcion_id = p_recepcion_id

    LOOP

        UPDATE reciclaje.materiales

        SET

            stock = stock + v_detalle.cantidad,

            updated_at = now()

        WHERE company_id = p_company_id
          AND id = v_detalle.material_id;

        INSERT INTO reciclaje.movimientos_stock(

            company_id,

            material_id,

            tipo_movimiento,

            cantidad,

            origen,

            origen_id,

            socio_id,

            transportista_id,

            orden_compra_id,

            recepcion_id,

            observaciones

        )

        VALUES(

            p_company_id,

            v_detalle.material_id,

            'entrada',

            v_detalle.cantidad,

            'recepcion',

            p_recepcion_id,

            v_socio_id,

            v_transportista_id,

            v_recepcion.orden_compra_id,

            p_recepcion_id,

            'Entrada por recepción confirmada'

        );

    END LOOP;

    ----------------------------------------------------
    -- Confirmar recepción
    ----------------------------------------------------

    UPDATE reciclaje.recepciones

    SET

        estado = 'confirmada',

        confirmed_at = now()

    WHERE id = p_recepcion_id;

    ----------------------------------------------------
    -- Actualizar orden
    ----------------------------------------------------

    UPDATE reciclaje.ordenes_compra

    SET

        estado = 'recibida',

        updated_at = now()

    WHERE id = v_recepcion.orden_compra_id;

    ----------------------------------------------------
    -- Resultado
    ----------------------------------------------------

    SELECT *

    INTO v_recepcion

    FROM reciclaje.recepciones

    WHERE id = p_recepcion_id;

    RETURN v_recepcion;

END;
$$;

GRANT EXECUTE
ON FUNCTION reciclaje.confirmar_recepcion(uuid,uuid)
TO tenant_app;


CREATE OR REPLACE FUNCTION reciclaje.obtener_recepcion(

    p_company_id uuid,

    p_id uuid

)
RETURNS reciclaje.recepciones
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS
$$
DECLARE

    v_recepcion reciclaje.recepciones;

BEGIN

    SELECT *
    INTO v_recepcion
    FROM reciclaje.recepciones
    WHERE company_id = p_company_id
      AND id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La recepción no existe.';
    END IF;

    RETURN v_recepcion;

END;
$$;



CREATE OR REPLACE FUNCTION reciclaje.listar_recepciones(

    p_company_id uuid

)
RETURNS SETOF reciclaje.recepciones
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT *

FROM reciclaje.recepciones

WHERE company_id = p_company_id

ORDER BY created_at DESC;

$$;



CREATE OR REPLACE FUNCTION reciclaje.actualizar_recepcion(

    p_company_id uuid,

    p_recepcion_id uuid,

    p_recepcion jsonb

)
RETURNS reciclaje.recepciones
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_recepcion reciclaje.recepciones;

    v_material jsonb;

BEGIN

    ----------------------------------------------------
    -- Buscar recepción
    ----------------------------------------------------

    SELECT *
    INTO v_recepcion
    FROM reciclaje.recepciones
    WHERE company_id = p_company_id
      AND id = p_recepcion_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La recepción no existe.';
    END IF;

    IF v_recepcion.estado <> 'borrador' THEN
        RAISE EXCEPTION 'La recepción ya fue confirmada.';
    END IF;

    IF jsonb_array_length(
        coalesce(
            p_recepcion->'materiales',
            '[]'::jsonb
        )
    ) = 0 THEN

        RAISE EXCEPTION
        'La recepción debe contener al menos un material.';

    END IF;

    ----------------------------------------------------
    -- Actualizar cabecera
    ----------------------------------------------------

    UPDATE reciclaje.recepciones

    SET

        deposito_id = (p_recepcion->>'deposito_id')::uuid,

        recibido_por = reciclaje.texto_nulo(
            p_recepcion->>'recibido_por'
        ),

        observaciones = reciclaje.texto_nulo(
            p_recepcion->>'observaciones'
        )

    WHERE id = p_recepcion_id;

    ----------------------------------------------------
    -- Reemplazar detalle
    ----------------------------------------------------

    DELETE
    FROM reciclaje.recepciones_detalle
    WHERE recepcion_id = p_recepcion_id;

    FOR v_material IN

        SELECT *

        FROM jsonb_array_elements(
            p_recepcion->'materiales'
        )

    LOOP

        INSERT INTO reciclaje.recepciones_detalle(

            recepcion_id,

            material_id,

            cantidad,

            precio_unitario,

            moneda,

            subtotal,

            observaciones

        )

        VALUES(

            p_recepcion_id,

            (v_material->>'material_id')::uuid,

            (v_material->>'cantidad')::numeric,

            (v_material->>'precio_unitario')::numeric,

            v_material->>'moneda',

            (v_material->>'cantidad')::numeric
            *
            (v_material->>'precio_unitario')::numeric,

            reciclaje.texto_nulo(
                v_material->>'observaciones'
            )

        );

    END LOOP;

    ----------------------------------------------------
    -- Resultado
    ----------------------------------------------------

    SELECT *

    INTO v_recepcion

    FROM reciclaje.recepciones

    WHERE id = p_recepcion_id;

    RETURN v_recepcion;

END;
$$;

GRANT EXECUTE
ON FUNCTION reciclaje.actualizar_recepcion(uuid,uuid,jsonb)
TO tenant_app;



CREATE OR REPLACE FUNCTION reciclaje.cancelar_recepcion(

    p_company_id uuid,

    p_recepcion_id uuid

)
RETURNS reciclaje.recepciones
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
DECLARE

    v_recepcion reciclaje.recepciones;

BEGIN

    SELECT *
    INTO v_recepcion
    FROM reciclaje.recepciones
    WHERE company_id = p_company_id
      AND id = p_recepcion_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La recepción no existe.';
    END IF;

    IF v_recepcion.estado <> 'borrador' THEN
        RAISE EXCEPTION 'Solo se puede cancelar una recepción en borrador.';
    END IF;

    UPDATE reciclaje.recepciones

    SET

        estado = 'cancelada'

    WHERE id = p_recepcion_id

    RETURNING *

    INTO v_recepcion;

    UPDATE reciclaje.ordenes_compra

    SET

        estado = 'borrador',

        updated_at = now()

    WHERE id = v_recepcion.orden_compra_id;

    RETURN v_recepcion;

END;
$$;



GRANT EXECUTE ON FUNCTION reciclaje.obtener_recepcion(uuid,uuid) TO tenant_app;

GRANT EXECUTE ON FUNCTION reciclaje.listar_recepciones(uuid) TO tenant_app;

GRANT EXECUTE ON FUNCTION reciclaje.actualizar_recepcion(uuid,uuid,jsonb) TO tenant_app;

GRANT EXECUTE ON FUNCTION reciclaje.cancelar_recepcion(uuid,uuid) TO tenant_app;