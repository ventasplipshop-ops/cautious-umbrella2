--
-- PostgreSQL database dump
--

\restrict bf8cbzWgvUptTfbya8qjNoWte7DaqaCX1yjDZAljAWnlRNjnqqBjmTtUQuZDxDw

-- Dumped from database version 14.24 (Ubuntu 14.24-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.24 (Ubuntu 14.24-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE IF EXISTS erp_dev;
--
-- Name: erp_dev; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE erp_dev WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'C.UTF-8';


\unrestrict bf8cbzWgvUptTfbya8qjNoWte7DaqaCX1yjDZAljAWnlRNjnqqBjmTtUQuZDxDw
\connect erp_dev
\restrict bf8cbzWgvUptTfbya8qjNoWte7DaqaCX1yjDZAljAWnlRNjnqqBjmTtUQuZDxDw

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: core; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA core;


--
-- Name: iam; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA iam;


--
-- Name: inv; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA inv;


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: item_type; Type: TYPE; Schema: core; Owner: -
--

CREATE TYPE core.item_type AS ENUM (
    'product',
    'service',
    'kit'
);


--
-- Name: actor_type; Type: TYPE; Schema: iam; Owner: -
--

CREATE TYPE iam.actor_type AS ENUM (
    'internal',
    'external'
);


--
-- Name: membership_status; Type: TYPE; Schema: iam; Owner: -
--

CREATE TYPE iam.membership_status AS ENUM (
    'invited',
    'active',
    'suspended'
);


--
-- Name: movement_type; Type: TYPE; Schema: inv; Owner: -
--

CREATE TYPE inv.movement_type AS ENUM (
    'purchase',
    'sale',
    'return',
    'adjustment',
    'transfer_out',
    'transfer_in'
);


--
-- Name: bootstrap_company(text, text); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.bootstrap_company(p_slug text, p_name text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_company_id uuid;
BEGIN
  INSERT INTO core.company (slug, name)
  VALUES (p_slug, p_name)
  RETURNING id INTO v_company_id;

  RETURN v_company_id;
END;
$$;


--
-- Name: bootstrap_full_company(text, text, uuid); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.bootstrap_full_company(p_slug text, p_name text, p_actor_id uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_company_id uuid;
  v_branch_id uuid;
BEGIN

  -- Crear company
  INSERT INTO core.company (slug, name)
  VALUES (p_slug, p_name)
  RETURNING id INTO v_company_id;

  -- Crear branch principal
  INSERT INTO core.branch (company_id, code, name, is_main)
  VALUES (v_company_id, 'MAIN', 'Principal', true)
  RETURNING id INTO v_branch_id;

  -- Crear membership owner
  INSERT INTO iam.membership (company_id, actor_id, status, is_owner)
  VALUES (v_company_id, p_actor_id, 'active', true);

  -- Crear roles base
  INSERT INTO iam.role (company_id, code, name)
  VALUES
    (v_company_id,'owner','Owner'),
    (v_company_id,'admin','Administrator'),
    (v_company_id,'manager','Manager'),
    (v_company_id,'cashier','Cashier'),
    (v_company_id,'warehouse','Warehouse');

  -- Seed permisos
  PERFORM iam.seed_role_permissions(v_company_id);

  -- Asignar rol owner
  INSERT INTO iam.actor_role (company_id, actor_id, role_code)
  VALUES (v_company_id, p_actor_id, 'owner');

  -- Asignar branch principal
  INSERT INTO iam.actor_branch (company_id, actor_id, branch_id)
  VALUES (v_company_id, p_actor_id, v_branch_id);

  RETURN v_company_id;

END;
$$;


--
-- Name: set_stock_tracking(); Type: FUNCTION; Schema: core; Owner: -
--

CREATE FUNCTION core.set_stock_tracking() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

  IF NEW.type = 'product' THEN
    NEW.is_stock_tracked := true;

  ELSIF NEW.type = 'service' THEN
    NEW.is_stock_tracked := false;

  ELSIF NEW.type = 'kit' THEN
    NEW.is_stock_tracked := false;

  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: get_active_memberships(uuid); Type: FUNCTION; Schema: iam; Owner: -
--

CREATE FUNCTION iam.get_active_memberships(p_actor_id uuid) RETURNS TABLE(company_id uuid)
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT company_id
  FROM iam.membership
  WHERE actor_id = p_actor_id
    AND status = 'active';
$$;


--
-- Name: has_perm(uuid, uuid, text); Type: FUNCTION; Schema: iam; Owner: -
--

CREATE FUNCTION iam.has_perm(p_company_id uuid, p_actor_id uuid, p_perm_code text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM iam.actor_role ar
    JOIN iam.role_permission rp
      ON rp.company_id = ar.company_id
     AND rp.role_code  = ar.role_code
    WHERE ar.company_id = p_company_id
      AND ar.actor_id   = p_actor_id
      AND rp.perm_code  = p_perm_code
  );
$$;


--
-- Name: login_full(text); Type: FUNCTION; Schema: iam; Owner: -
--

CREATE FUNCTION iam.login_full(p_email text) RETURNS TABLE(actor_id uuid, company_id uuid, branch_id uuid, roles text[])
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_actor_id uuid;
  v_company_id uuid;
  v_branch_id uuid;
BEGIN

  -- actor
  SELECT id INTO v_actor_id
  FROM iam.actor
  WHERE email = p_email
    AND is_active = true;

  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CREDENTIALS';
  END IF;

  -- membership activa
  SELECT company_id INTO v_company_id
  FROM iam.membership
  WHERE actor_id = v_actor_id
    AND status = 'active'
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'NO_ACTIVE_COMPANY';
  END IF;

  -- branch principal
  SELECT id INTO v_branch_id
  FROM core.branch
  WHERE company_id = v_company_id
    AND is_main = true
  LIMIT 1;

  IF v_branch_id IS NULL THEN
    RAISE EXCEPTION 'NO_MAIN_BRANCH';
  END IF;

  RETURN QUERY
  SELECT
    v_actor_id,
    v_company_id,
    v_branch_id,
    ARRAY(
      SELECT role_code
      FROM iam.actor_role
      WHERE actor_id = v_actor_id
        AND company_id = v_company_id
    );

END;
$$;


--
-- Name: prevent_remove_last_owner(); Type: FUNCTION; Schema: iam; Owner: -
--

CREATE FUNCTION iam.prevent_remove_last_owner() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  owner_count integer;
BEGIN
  SELECT COUNT(*) INTO owner_count
  FROM iam.membership
  WHERE company_id = OLD.company_id
    AND is_owner = true;

  IF owner_count <= 1 AND OLD.is_owner = true THEN
    RAISE EXCEPTION 'Cannot remove last owner';
  END IF;

  RETURN OLD;
END;
$$;


--
-- Name: register_company_full(text, text, text, text, text); Type: FUNCTION; Schema: iam; Owner: -
--

CREATE FUNCTION iam.register_company_full(p_company_name text, p_slug text, p_email text, p_password_hash text, p_full_name text) RETURNS TABLE(company_id uuid, actor_id uuid, branch_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_actor_id uuid;
  v_company_id uuid;
  v_branch_id uuid;
BEGIN

  -- validar email duplicado
  IF EXISTS (
    SELECT 1 FROM iam.actor WHERE email = p_email
  ) THEN
    RAISE EXCEPTION 'EMAIL_ALREADY_REGISTERED';
  END IF;

  -- crear actor
  INSERT INTO iam.actor (type, email, password_hash, full_name)
  VALUES ('internal', p_email, p_password_hash, p_full_name)
  RETURNING id INTO v_actor_id;

  -- validar slug duplicado
  IF EXISTS (
    SELECT 1 FROM core.company WHERE slug = p_slug
  ) THEN
    RAISE EXCEPTION 'COMPANY_SLUG_EXISTS';
  END IF;

  -- crear company
  INSERT INTO core.company (slug, name)
  VALUES (p_slug, p_company_name)
  RETURNING id INTO v_company_id;

  -- membership owner
  INSERT INTO iam.membership (company_id, actor_id, status, is_owner)
  VALUES (v_company_id, v_actor_id, 'active', true);

  -- branch principal
  INSERT INTO core.branch (company_id, code, name, is_main)
  VALUES (v_company_id, 'MAIN', 'Principal', true)
  RETURNING id INTO v_branch_id;

  -- roles base
  INSERT INTO iam.role (company_id, code, name)
  VALUES
    (v_company_id,'owner','Owner'),
    (v_company_id,'admin','Administrator'),
    (v_company_id,'manager','Manager'),
    (v_company_id,'cashier','Cashier'),
    (v_company_id,'warehouse','Warehouse');

  -- permisos
  PERFORM iam.seed_role_permissions(v_company_id);

  -- asignar rol owner
  INSERT INTO iam.actor_role (company_id, actor_id, role_code)
  VALUES (v_company_id, v_actor_id, 'owner');

  -- asignar branch
  INSERT INTO iam.actor_branch (company_id, actor_id, branch_id)
  VALUES (v_company_id, v_actor_id, v_branch_id);

  RETURN QUERY
  SELECT v_company_id, v_actor_id, v_branch_id;

END;
$$;


--
-- Name: seed_role_permissions(uuid); Type: FUNCTION; Schema: iam; Owner: -
--

CREATE FUNCTION iam.seed_role_permissions(p_company_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

  -- OWNER: todos los permisos existentes
  INSERT INTO iam.role_permission (company_id, role_code, perm_code)
  SELECT p_company_id, 'owner', p.code
  FROM iam.permission p
  ON CONFLICT DO NOTHING;

  -- ADMIN
  INSERT INTO iam.role_permission (company_id, role_code, perm_code)
  VALUES
    (p_company_id,'admin','company.manage'),
    (p_company_id,'admin','iam.user.create'),
    (p_company_id,'admin','iam.user.read'),
    (p_company_id,'admin','iam.user.update'),
    (p_company_id,'admin','iam.user.disable'),
    (p_company_id,'admin','iam.role.assign'),
    (p_company_id,'admin','iam.branch.assign'),

    (p_company_id,'admin','inv.item.create'),
    (p_company_id,'admin','inv.stock.move'),
    (p_company_id,'admin','inv.stock.adjust'),
    (p_company_id,'admin','inv.transfer.create'),
    (p_company_id,'admin','inv.transfer.receive'),
    (p_company_id,'admin','inv.transfer.cancel'),
    (p_company_id,'admin','inv.reserve'),
    (p_company_id,'admin','inv.confirm'),
    (p_company_id,'admin','inv.release')
  ON CONFLICT DO NOTHING;

  -- WAREHOUSE
  INSERT INTO iam.role_permission (company_id, role_code, perm_code)
  VALUES
    (p_company_id,'warehouse','inv.item.create'),
    (p_company_id,'warehouse','inv.stock.move'),
    (p_company_id,'warehouse','inv.stock.adjust'),
    (p_company_id,'warehouse','inv.transfer.create'),
    (p_company_id,'warehouse','inv.transfer.receive'),
    (p_company_id,'warehouse','inv.transfer.cancel')
  ON CONFLICT DO NOTHING;

  -- CASHIER
  INSERT INTO iam.role_permission (company_id, role_code, perm_code)
  VALUES
    (p_company_id,'cashier','inv.reserve'),
    (p_company_id,'cashier','inv.confirm'),
    (p_company_id,'cashier','inv.release')
  ON CONFLICT DO NOTHING;

  -- MANAGER
  INSERT INTO iam.role_permission (company_id, role_code, perm_code)
  VALUES
    (p_company_id,'manager','inv.item.create'),
    (p_company_id,'manager','inv.stock.move'),
    (p_company_id,'manager','inv.transfer.create'),
    (p_company_id,'manager','inv.transfer.receive'),
    (p_company_id,'manager','inv.reserve'),
    (p_company_id,'manager','inv.confirm'),
    (p_company_id,'manager','inv.release')
  ON CONFLICT DO NOTHING;

END;
$$;


--
-- Name: seed_reason_codes(uuid); Type: FUNCTION; Schema: inv; Owner: -
--

CREATE FUNCTION inv.seed_reason_codes(p_company_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO inv.reason_code (company_id, code, label, description)
  VALUES
    (p_company_id, 'damage',            'Rotura / Daño',          'Producto dañado o roto'),
    (p_company_id, 'expiry',            'Vencimiento',            'Producto vencido'),
    (p_company_id, 'inventory_count',   'Conteo físico',          'Ajuste por inventario físico'),
    (p_company_id, 'theft',             'Robo / Pérdida',         'Merma por pérdida/robo'),
    (p_company_id, 'manual_correction', 'Corrección manual',      'Corrección administrativa')
  ON CONFLICT (company_id, code) DO NOTHING;
END;
$$;


--
-- Name: trg_company_seed_reason_codes(); Type: FUNCTION; Schema: inv; Owner: -
--

CREATE FUNCTION inv.trg_company_seed_reason_codes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  PERFORM inv.seed_reason_codes(NEW.id);
  RETURN NEW;
END;
$$;


--
-- Name: update_stock_balance(); Type: FUNCTION; Schema: inv; Owner: -
--

CREATE FUNCTION inv.update_stock_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

  -- Solo para items que trackean stock
  IF EXISTS (
    SELECT 1
    FROM core.item i
    WHERE i.id = NEW.item_id
      AND i.company_id = NEW.company_id
      AND i.is_stock_tracked = true
  ) THEN

    INSERT INTO inv.stock_balance (
      company_id,
      branch_id,
      item_id,
      quantity
    )
    VALUES (
      NEW.company_id,
      NEW.branch_id,
      NEW.item_id,
      NEW.quantity
    )
    ON CONFLICT (company_id, branch_id, item_id)
    DO UPDATE
      SET quantity = inv.stock_balance.quantity + EXCLUDED.quantity;

  END IF;

  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: branch; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.branch (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    is_main boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: company; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.company (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: item; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    sku text NOT NULL,
    name text NOT NULL,
    description text,
    type core.item_type DEFAULT 'product'::core.item_type NOT NULL,
    price numeric(14,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_stock_tracked boolean DEFAULT true NOT NULL,
    CONSTRAINT item_price_check CHECK ((price >= (0)::numeric))
);


--
-- Name: TABLE item; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON TABLE core.item IS 'ERP Item (product/service/kit)';


--
-- Name: COLUMN item.price; Type: COMMENT; Schema: core; Owner: -
--

COMMENT ON COLUMN core.item.price IS 'Sale price without tax';


--
-- Name: item_component; Type: TABLE; Schema: core; Owner: -
--

CREATE TABLE core.item_component (
    parent_item_id uuid NOT NULL,
    component_item_id uuid NOT NULL,
    quantity numeric(14,2) NOT NULL,
    company_id uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT item_component_no_self_reference CHECK ((parent_item_id <> component_item_id)),
    CONSTRAINT item_component_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: actor; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.actor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type iam.actor_type NOT NULL,
    email public.citext NOT NULL,
    password_hash text NOT NULL,
    full_name text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: actor_branch; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.actor_branch (
    company_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    branch_id uuid NOT NULL
);


--
-- Name: actor_role; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.actor_role (
    company_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    role_code text NOT NULL
);


--
-- Name: membership; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.membership (
    company_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    status iam.membership_status DEFAULT 'invited'::iam.membership_status NOT NULL,
    is_owner boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: permission; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.permission (
    code text NOT NULL,
    description text NOT NULL
);


--
-- Name: role; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.role (
    company_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL
);


--
-- Name: role_permission; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.role_permission (
    company_id uuid NOT NULL,
    role_code text NOT NULL,
    perm_code text NOT NULL
);


--
-- Name: session; Type: TABLE; Schema: iam; Owner: -
--

CREATE TABLE iam.session (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid NOT NULL,
    company_id uuid NOT NULL,
    refresh_token text NOT NULL,
    user_agent text,
    ip_address text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked boolean DEFAULT false NOT NULL
);


--
-- Name: reason_code; Type: TABLE; Schema: inv; Owner: -
--

CREATE TABLE inv.reason_code (
    company_id uuid NOT NULL,
    code text NOT NULL,
    label text NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stock_balance; Type: TABLE; Schema: inv; Owner: -
--

CREATE TABLE inv.stock_balance (
    company_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity numeric(14,2) DEFAULT 0 NOT NULL,
    reserved_quantity numeric(14,2) DEFAULT 0 NOT NULL,
    CONSTRAINT reserved_not_negative CHECK ((reserved_quantity >= (0)::numeric))
);


--
-- Name: stock_ledger; Type: TABLE; Schema: inv; Owner: -
--

CREATE TABLE inv.stock_ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    item_id uuid NOT NULL,
    movement_type inv.movement_type NOT NULL,
    quantity numeric(14,2) NOT NULL,
    reference_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    reason_code text,
    CONSTRAINT stock_adjustment_requires_reason CHECK (((movement_type <> 'adjustment'::inv.movement_type) OR (reason_code IS NOT NULL))),
    CONSTRAINT stock_quantity_not_zero CHECK ((quantity <> (0)::numeric)),
    CONSTRAINT stock_quantity_sign_check CHECK ((((movement_type = ANY (ARRAY['purchase'::inv.movement_type, 'return'::inv.movement_type, 'transfer_in'::inv.movement_type])) AND (quantity > (0)::numeric)) OR ((movement_type = ANY (ARRAY['sale'::inv.movement_type, 'transfer_out'::inv.movement_type])) AND (quantity < (0)::numeric)) OR (movement_type = 'adjustment'::inv.movement_type)))
);


--
-- Name: stock_reservation; Type: TABLE; Schema: inv; Owner: -
--

CREATE TABLE inv.stock_reservation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    reference_id text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stock_reservation_line; Type: TABLE; Schema: inv; Owner: -
--

CREATE TABLE inv.stock_reservation_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reservation_id uuid NOT NULL,
    company_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity numeric(14,2) NOT NULL,
    CONSTRAINT stock_reservation_line_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: stock_transfer; Type: TABLE; Schema: inv; Owner: -
--

CREATE TABLE inv.stock_transfer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    from_branch_id uuid NOT NULL,
    to_branch_id uuid NOT NULL,
    reference_id text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    received_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    CONSTRAINT stock_transfer_check CHECK ((from_branch_id <> to_branch_id)),
    CONSTRAINT stock_transfer_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'received'::text, 'cancelled'::text])))
);


--
-- Name: stock_transfer_line; Type: TABLE; Schema: inv; Owner: -
--

CREATE TABLE inv.stock_transfer_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transfer_id uuid NOT NULL,
    company_id uuid NOT NULL,
    item_id uuid NOT NULL,
    quantity numeric(14,2) NOT NULL,
    CONSTRAINT stock_transfer_line_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Data for Name: branch; Type: TABLE DATA; Schema: core; Owner: -
--

COPY core.branch (id, company_id, code, name, is_main, is_active, created_at) FROM stdin;
aa2b0c3a-193c-46d8-9721-e5ddf0e70037	fb51208e-e879-41d3-b208-052b723af854	MAIN	Principal	t	t	2026-02-22 16:36:14.643847+01
d0c40d9a-26a6-4bc5-b59d-a3ef76fa563b	fb51208e-e879-41d3-b208-052b723af854	SEC	Sucursal Secundaria	f	t	2026-02-24 03:43:03.365488+01
0a22400f-4494-4eba-8f47-b703b0612e20	f5b30c46-18bb-49f2-bf47-cd768809fdd7	MAIN	Principal	t	t	2026-02-24 15:12:27.535992+01
1a0edcbc-501f-4c37-83b6-7537c025ef2a	f5b30c46-18bb-49f2-bf47-cd768809fdd7	SEC	Sucursal Secundaria	f	t	2026-02-24 15:20:15.831234+01
bbf04174-4bb1-4beb-8443-690760753446	b95c4f17-0e67-4198-bc04-8344993910cb	MAIN	Principal	t	t	2026-02-25 01:53:06.314406+01
8844e87e-ff49-4208-be9b-87be40d41176	3fac05be-c11f-4cf4-8c60-a082a9c04467	MAIN	Principal	t	t	2026-02-25 02:28:15.002531+01
9cd665e7-8b96-4f55-9568-2249728d6b7f	e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	MAIN	Principal	t	t	2026-02-25 02:53:24.69242+01
\.


--
-- Data for Name: company; Type: TABLE DATA; Schema: core; Owner: -
--

COPY core.company (id, slug, name, is_active, created_at) FROM stdin;
fb51208e-e879-41d3-b208-052b723af854	mayorista-center	Mayorista Center	t	2026-02-22 16:36:14.643847+01
f5b30c46-18bb-49f2-bf47-cd768809fdd7	empresa-test	Empresa Test	t	2026-02-24 15:12:27.535992+01
b95c4f17-0e67-4198-bc04-8344993910cb	plip-foods-3	Plip Foods SA	t	2026-02-25 01:53:06.314406+01
3fac05be-c11f-4cf4-8c60-a082a9c04467	plipfoods-group	Plip Foods Group	t	2026-02-25 02:28:15.002531+01
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	atlas-industrial	Atlas Industrial Group	t	2026-02-25 02:53:24.69242+01
\.


--
-- Data for Name: item; Type: TABLE DATA; Schema: core; Owner: -
--

COPY core.item (id, company_id, sku, name, description, type, price, is_active, created_at, is_stock_tracked) FROM stdin;
2abac2d4-25fa-4e21-be77-a690b4b1d308	fb51208e-e879-41d3-b208-052b723af854	SKU-DIRECT	Direct Insert	\N	product	50.00	t	2026-02-22 20:40:42.939547+01	t
6d607225-4d5d-47c4-9a70-d2c5dba66b4c	fb51208e-e879-41d3-b208-052b723af854	SKU-TEST-01	Producto Limpio	\N	product	200.00	t	2026-02-22 21:20:55.156882+01	t
4b76a3f7-57b7-434d-855b-e01980c63ad8	fb51208e-e879-41d3-b208-052b723af854	SKU-002	Vaso Térmico 500ml	Vaso descartable térmico blanco	product	350.00	t	2026-02-22 22:06:16.886578+01	t
151a662c-4424-4a13-9a8b-4343d910fdd7	fb51208e-e879-41d3-b208-052b723af854	PROD-A	Producto A	\N	product	100.00	t	2026-02-23 03:43:59.673085+01	t
1b253900-95d4-4908-8def-0841cb81a502	fb51208e-e879-41d3-b208-052b723af854	PROD-B	Producto B	\N	product	50.00	t	2026-02-23 03:44:15.782572+01	t
d88197a6-b473-4132-b689-c9c435ab1a68	fb51208e-e879-41d3-b208-052b723af854	KIT-001	Kit Demo	\N	kit	300.00	t	2026-02-23 03:44:27.246337+01	f
d01f03e3-88e2-4a01-a75d-9fbf559881fd	fb51208e-e879-41d3-b208-052b723af854	PROD-A2	Producto A2	\N	product	100.00	t	2026-02-24 01:02:52.376002+01	t
a452ca08-adef-477d-8bb4-56d600e94251	fb51208e-e879-41d3-b208-052b723af854	PROD-B2	Producto B2	\N	product	50.00	t	2026-02-24 01:02:52.448966+01	t
3c6f95e1-4bf4-44cc-852c-6f07460ab538	fb51208e-e879-41d3-b208-052b723af854	KIT-1	Kit 1	\N	kit	150.00	t	2026-02-24 01:02:52.511209+01	f
978460a4-cced-4b16-836a-5f5b2993dd4d	f5b30c46-18bb-49f2-bf47-cd768809fdd7	SKU-001	Producto Test	\N	product	100.00	t	2026-02-24 15:14:22.940979+01	t
e08cf53a-975d-4552-8176-a870e6ec7058	f5b30c46-18bb-49f2-bf47-cd768809fdd7	COMP-A	Componente A	\N	product	50.00	t	2026-02-24 15:15:40.868534+01	t
4594d78a-662f-40bb-8a9c-f5c25d4590e8	f5b30c46-18bb-49f2-bf47-cd768809fdd7	COMP-B	Componente B	\N	product	30.00	t	2026-02-24 15:15:48.155845+01	t
b9022fa5-72e1-459a-83e7-8d7716fd6424	f5b30c46-18bb-49f2-bf47-cd768809fdd7	KIT-001	Kit Combo	\N	kit	120.00	t	2026-02-24 15:16:06.857634+01	f
ff6f1fc3-907a-4cd1-8592-fa2cfbb323e0	e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	SKU-ATLAS-001	Motor Industrial X1	\N	product	2500.00	t	2026-02-25 02:54:03.101165+01	t
\.


--
-- Data for Name: item_component; Type: TABLE DATA; Schema: core; Owner: -
--

COPY core.item_component (parent_item_id, component_item_id, quantity, company_id, is_active, created_at) FROM stdin;
d88197a6-b473-4132-b689-c9c435ab1a68	151a662c-4424-4a13-9a8b-4343d910fdd7	2.00	fb51208e-e879-41d3-b208-052b723af854	t	2026-02-23 03:44:39.189179+01
d88197a6-b473-4132-b689-c9c435ab1a68	1b253900-95d4-4908-8def-0841cb81a502	1.00	fb51208e-e879-41d3-b208-052b723af854	t	2026-02-23 03:44:48.928607+01
3c6f95e1-4bf4-44cc-852c-6f07460ab538	a452ca08-adef-477d-8bb4-56d600e94251	1.00	fb51208e-e879-41d3-b208-052b723af854	t	2026-02-24 01:10:22.027104+01
3c6f95e1-4bf4-44cc-852c-6f07460ab538	d01f03e3-88e2-4a01-a75d-9fbf559881fd	2.00	fb51208e-e879-41d3-b208-052b723af854	t	2026-02-24 01:32:06.389523+01
b9022fa5-72e1-459a-83e7-8d7716fd6424	e08cf53a-975d-4552-8176-a870e6ec7058	2.00	f5b30c46-18bb-49f2-bf47-cd768809fdd7	t	2026-02-24 15:16:14.755332+01
b9022fa5-72e1-459a-83e7-8d7716fd6424	4594d78a-662f-40bb-8a9c-f5c25d4590e8	1.00	f5b30c46-18bb-49f2-bf47-cd768809fdd7	t	2026-02-24 15:16:23.258254+01
\.


--
-- Data for Name: actor; Type: TABLE DATA; Schema: iam; Owner: -
--

COPY iam.actor (id, type, email, password_hash, full_name, is_active, created_at) FROM stdin;
453afce7-e780-4e4b-bee1-3059037177f3	internal	edwin@mayorista.com	$2b$10$846o7936xq/N6UUXILYoIORnlUe/WkT2HzUMfJSBmD0cQ3QrNuSNW	Edwin Abello	t	2026-02-22 16:36:14.643847+01
d4de44f0-2da0-4038-a797-cee556105229	internal	owner@test.com	$2b$10$Rv.MqPTOIrnyXS8jf0ZGn.t1rd7TuC2d99WOXvzr9C.t5L2sDtCIq	Owner Test	t	2026-02-24 15:12:27.535992+01
caeb8ab1-eedf-4f37-a6a3-353bf1a45fa4	internal	ceo3@plipfoods.com	$2b$10$UQ/2egQI66.p8Mg8EnwNo.mWnISQvWyk7wCTtQk15vlCGwbg1brzi	Edwin CEO	t	2026-02-25 01:53:06.314406+01
2117a873-690d-41e8-a35a-dab50a4524df	internal	ceo@plipfoods.group	$2b$10$fK8WLq.UR1sHxomqwy56TOGXZeeU/zhhRVqbVdNmxjlmvrnDQ2cNS	Edwin Founder	t	2026-02-25 02:28:15.002531+01
ae62842e-7956-41c3-933d-e92a2a3dda43	internal	founder@atlasindustrial.io	$2b$10$JWuchjy74H8kiiSvp4dRi.8sKOoaYXKBUblqHwaFABLs5pn1h7rtK	Alexander Torres	t	2026-02-25 02:53:24.69242+01
\.


--
-- Data for Name: actor_branch; Type: TABLE DATA; Schema: iam; Owner: -
--

COPY iam.actor_branch (company_id, actor_id, branch_id) FROM stdin;
fb51208e-e879-41d3-b208-052b723af854	453afce7-e780-4e4b-bee1-3059037177f3	aa2b0c3a-193c-46d8-9721-e5ddf0e70037
f5b30c46-18bb-49f2-bf47-cd768809fdd7	d4de44f0-2da0-4038-a797-cee556105229	0a22400f-4494-4eba-8f47-b703b0612e20
b95c4f17-0e67-4198-bc04-8344993910cb	caeb8ab1-eedf-4f37-a6a3-353bf1a45fa4	bbf04174-4bb1-4beb-8443-690760753446
3fac05be-c11f-4cf4-8c60-a082a9c04467	2117a873-690d-41e8-a35a-dab50a4524df	8844e87e-ff49-4208-be9b-87be40d41176
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	ae62842e-7956-41c3-933d-e92a2a3dda43	9cd665e7-8b96-4f55-9568-2249728d6b7f
\.


--
-- Data for Name: actor_role; Type: TABLE DATA; Schema: iam; Owner: -
--

COPY iam.actor_role (company_id, actor_id, role_code) FROM stdin;
fb51208e-e879-41d3-b208-052b723af854	453afce7-e780-4e4b-bee1-3059037177f3	owner
f5b30c46-18bb-49f2-bf47-cd768809fdd7	d4de44f0-2da0-4038-a797-cee556105229	owner
b95c4f17-0e67-4198-bc04-8344993910cb	caeb8ab1-eedf-4f37-a6a3-353bf1a45fa4	owner
3fac05be-c11f-4cf4-8c60-a082a9c04467	2117a873-690d-41e8-a35a-dab50a4524df	owner
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	ae62842e-7956-41c3-933d-e92a2a3dda43	owner
\.


--
-- Data for Name: membership; Type: TABLE DATA; Schema: iam; Owner: -
--

COPY iam.membership (company_id, actor_id, status, is_owner, created_at) FROM stdin;
fb51208e-e879-41d3-b208-052b723af854	453afce7-e780-4e4b-bee1-3059037177f3	active	t	2026-02-22 16:36:14.643847+01
f5b30c46-18bb-49f2-bf47-cd768809fdd7	d4de44f0-2da0-4038-a797-cee556105229	active	t	2026-02-24 15:12:27.535992+01
b95c4f17-0e67-4198-bc04-8344993910cb	caeb8ab1-eedf-4f37-a6a3-353bf1a45fa4	active	t	2026-02-25 01:53:06.314406+01
3fac05be-c11f-4cf4-8c60-a082a9c04467	2117a873-690d-41e8-a35a-dab50a4524df	active	t	2026-02-25 02:28:15.002531+01
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	ae62842e-7956-41c3-933d-e92a2a3dda43	active	t	2026-02-25 02:53:24.69242+01
\.


--
-- Data for Name: permission; Type: TABLE DATA; Schema: iam; Owner: -
--

COPY iam.permission (code, description) FROM stdin;
company.manage	Administrar configuración empresa
iam.user.create	Crear usuarios
iam.user.read	Ver usuarios
iam.user.update	Editar usuarios
iam.user.disable	Desactivar usuarios
iam.role.assign	Asignar roles
iam.branch.assign	Asignar sucursales
inv.item.create	Crear items
inv.stock.move	Movimientos stock (in/out/return)
inv.stock.adjust	Ajustes stock
inv.transfer.create	Crear transferencias
inv.transfer.receive	Recibir transferencias
inv.transfer.cancel	Cancelar transferencias
inv.reserve	Reservar stock
inv.confirm	Confirmar reserva
inv.release	Liberar reserva
\.


--
-- Data for Name: role; Type: TABLE DATA; Schema: iam; Owner: -
--

COPY iam.role (company_id, code, name) FROM stdin;
fb51208e-e879-41d3-b208-052b723af854	owner	Owner
fb51208e-e879-41d3-b208-052b723af854	admin	Administrator
fb51208e-e879-41d3-b208-052b723af854	manager	Manager
fb51208e-e879-41d3-b208-052b723af854	cashier	Cashier
fb51208e-e879-41d3-b208-052b723af854	warehouse	Warehouse
f5b30c46-18bb-49f2-bf47-cd768809fdd7	owner	Owner
f5b30c46-18bb-49f2-bf47-cd768809fdd7	admin	Administrator
f5b30c46-18bb-49f2-bf47-cd768809fdd7	manager	Manager
f5b30c46-18bb-49f2-bf47-cd768809fdd7	cashier	Cashier
f5b30c46-18bb-49f2-bf47-cd768809fdd7	warehouse	Warehouse
b95c4f17-0e67-4198-bc04-8344993910cb	owner	Owner
b95c4f17-0e67-4198-bc04-8344993910cb	admin	Administrator
b95c4f17-0e67-4198-bc04-8344993910cb	manager	Manager
b95c4f17-0e67-4198-bc04-8344993910cb	cashier	Cashier
b95c4f17-0e67-4198-bc04-8344993910cb	warehouse	Warehouse
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	Owner
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	Administrator
3fac05be-c11f-4cf4-8c60-a082a9c04467	manager	Manager
3fac05be-c11f-4cf4-8c60-a082a9c04467	cashier	Cashier
3fac05be-c11f-4cf4-8c60-a082a9c04467	warehouse	Warehouse
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	Owner
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	Administrator
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manager	Manager
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	cashier	Cashier
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	warehouse	Warehouse
\.


--
-- Data for Name: role_permission; Type: TABLE DATA; Schema: iam; Owner: -
--

COPY iam.role_permission (company_id, role_code, perm_code) FROM stdin;
b95c4f17-0e67-4198-bc04-8344993910cb	owner	company.manage
b95c4f17-0e67-4198-bc04-8344993910cb	owner	iam.user.create
b95c4f17-0e67-4198-bc04-8344993910cb	owner	iam.user.read
b95c4f17-0e67-4198-bc04-8344993910cb	owner	iam.user.update
b95c4f17-0e67-4198-bc04-8344993910cb	owner	iam.user.disable
b95c4f17-0e67-4198-bc04-8344993910cb	owner	iam.role.assign
b95c4f17-0e67-4198-bc04-8344993910cb	owner	iam.branch.assign
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.item.create
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.stock.move
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.stock.adjust
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.transfer.create
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.transfer.receive
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.transfer.cancel
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.reserve
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.confirm
b95c4f17-0e67-4198-bc04-8344993910cb	owner	inv.release
b95c4f17-0e67-4198-bc04-8344993910cb	admin	company.manage
b95c4f17-0e67-4198-bc04-8344993910cb	admin	iam.user.create
b95c4f17-0e67-4198-bc04-8344993910cb	admin	iam.user.read
b95c4f17-0e67-4198-bc04-8344993910cb	admin	iam.user.update
b95c4f17-0e67-4198-bc04-8344993910cb	admin	iam.user.disable
b95c4f17-0e67-4198-bc04-8344993910cb	admin	iam.role.assign
b95c4f17-0e67-4198-bc04-8344993910cb	admin	iam.branch.assign
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.item.create
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.stock.move
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.stock.adjust
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.transfer.create
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.transfer.receive
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.transfer.cancel
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.reserve
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.confirm
b95c4f17-0e67-4198-bc04-8344993910cb	admin	inv.release
b95c4f17-0e67-4198-bc04-8344993910cb	warehouse	inv.item.create
b95c4f17-0e67-4198-bc04-8344993910cb	warehouse	inv.stock.move
b95c4f17-0e67-4198-bc04-8344993910cb	warehouse	inv.stock.adjust
b95c4f17-0e67-4198-bc04-8344993910cb	warehouse	inv.transfer.create
b95c4f17-0e67-4198-bc04-8344993910cb	warehouse	inv.transfer.receive
b95c4f17-0e67-4198-bc04-8344993910cb	warehouse	inv.transfer.cancel
b95c4f17-0e67-4198-bc04-8344993910cb	cashier	inv.reserve
b95c4f17-0e67-4198-bc04-8344993910cb	cashier	inv.confirm
b95c4f17-0e67-4198-bc04-8344993910cb	cashier	inv.release
b95c4f17-0e67-4198-bc04-8344993910cb	manager	inv.item.create
b95c4f17-0e67-4198-bc04-8344993910cb	manager	inv.stock.move
b95c4f17-0e67-4198-bc04-8344993910cb	manager	inv.transfer.create
b95c4f17-0e67-4198-bc04-8344993910cb	manager	inv.transfer.receive
b95c4f17-0e67-4198-bc04-8344993910cb	manager	inv.reserve
b95c4f17-0e67-4198-bc04-8344993910cb	manager	inv.confirm
b95c4f17-0e67-4198-bc04-8344993910cb	manager	inv.release
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	company.manage
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	iam.user.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	iam.user.read
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	iam.user.update
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	iam.user.disable
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	iam.role.assign
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	iam.branch.assign
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.item.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.stock.move
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.stock.adjust
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.transfer.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.transfer.receive
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.transfer.cancel
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.reserve
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.confirm
3fac05be-c11f-4cf4-8c60-a082a9c04467	owner	inv.release
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	company.manage
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	iam.user.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	iam.user.read
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	iam.user.update
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	iam.user.disable
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	iam.role.assign
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	iam.branch.assign
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.item.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.stock.move
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.stock.adjust
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.transfer.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.transfer.receive
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.transfer.cancel
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.reserve
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.confirm
3fac05be-c11f-4cf4-8c60-a082a9c04467	admin	inv.release
3fac05be-c11f-4cf4-8c60-a082a9c04467	warehouse	inv.item.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	warehouse	inv.stock.move
3fac05be-c11f-4cf4-8c60-a082a9c04467	warehouse	inv.stock.adjust
3fac05be-c11f-4cf4-8c60-a082a9c04467	warehouse	inv.transfer.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	warehouse	inv.transfer.receive
3fac05be-c11f-4cf4-8c60-a082a9c04467	warehouse	inv.transfer.cancel
3fac05be-c11f-4cf4-8c60-a082a9c04467	cashier	inv.reserve
3fac05be-c11f-4cf4-8c60-a082a9c04467	cashier	inv.confirm
3fac05be-c11f-4cf4-8c60-a082a9c04467	cashier	inv.release
3fac05be-c11f-4cf4-8c60-a082a9c04467	manager	inv.item.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	manager	inv.stock.move
3fac05be-c11f-4cf4-8c60-a082a9c04467	manager	inv.transfer.create
3fac05be-c11f-4cf4-8c60-a082a9c04467	manager	inv.transfer.receive
3fac05be-c11f-4cf4-8c60-a082a9c04467	manager	inv.reserve
3fac05be-c11f-4cf4-8c60-a082a9c04467	manager	inv.confirm
3fac05be-c11f-4cf4-8c60-a082a9c04467	manager	inv.release
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	company.manage
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	iam.user.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	iam.user.read
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	iam.user.update
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	iam.user.disable
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	iam.role.assign
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	iam.branch.assign
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.item.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.stock.move
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.stock.adjust
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.transfer.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.transfer.receive
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.transfer.cancel
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.reserve
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.confirm
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	owner	inv.release
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	company.manage
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	iam.user.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	iam.user.read
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	iam.user.update
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	iam.user.disable
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	iam.role.assign
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	iam.branch.assign
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.item.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.stock.move
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.stock.adjust
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.transfer.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.transfer.receive
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.transfer.cancel
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.reserve
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.confirm
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	admin	inv.release
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	warehouse	inv.item.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	warehouse	inv.stock.move
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	warehouse	inv.stock.adjust
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	warehouse	inv.transfer.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	warehouse	inv.transfer.receive
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	warehouse	inv.transfer.cancel
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	cashier	inv.reserve
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	cashier	inv.confirm
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	cashier	inv.release
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manager	inv.item.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manager	inv.stock.move
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manager	inv.transfer.create
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manager	inv.transfer.receive
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manager	inv.reserve
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manager	inv.confirm
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manager	inv.release
\.


--
-- Data for Name: session; Type: TABLE DATA; Schema: iam; Owner: -
--

COPY iam.session (id, actor_id, company_id, refresh_token, user_agent, ip_address, created_at, expires_at, revoked) FROM stdin;
3c6e5744-2008-4004-8c83-ce9afca8bf12	453afce7-e780-4e4b-bee1-3059037177f3	fb51208e-e879-41d3-b208-052b723af854	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6IjQ1M2FmY2U3LWU3ODAtNGU0Yi1iZWUxLTMwNTkwMzcxNzdmMyIsImNvbXBhbnlfaWQiOiJmYjUxMjA4ZS1lODc5LTQxZDMtYjIwOC0wNTJiNzIzYWY4NTQiLCJpYXQiOjE3NzE3NzU4MDYsImV4cCI6MTc3NDM2NzgwNn0.Wgn0X976Xn438QVecIO3BaE5HYojYFUoaxxvjSBKlzo	\N	\N	2026-02-22 16:56:46.075038+01	2026-03-24 16:56:46.075038+01	t
8f3a5625-a2a1-4ede-a004-b97abd935b7d	453afce7-e780-4e4b-bee1-3059037177f3	fb51208e-e879-41d3-b208-052b723af854	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6IjQ1M2FmY2U3LWU3ODAtNGU0Yi1iZWUxLTMwNTkwMzcxNzdmMyIsImNvbXBhbnlfaWQiOiJmYjUxMjA4ZS1lODc5LTQxZDMtYjIwOC0wNTJiNzIzYWY4NTQiLCJpYXQiOjE3NzE3Nzg1OTcsImV4cCI6MTc3NDM3MDU5N30.q-jukXm6i3oATrPqJVhPot7di-6PIZLZ6AyK9xMqQ6s	\N	\N	2026-02-22 17:43:17.790994+01	2026-03-24 17:43:17.790994+01	t
372f745f-dd3d-4c00-9aa5-19ec9826575b	453afce7-e780-4e4b-bee1-3059037177f3	fb51208e-e879-41d3-b208-052b723af854	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6IjQ1M2FmY2U3LWU3ODAtNGU0Yi1iZWUxLTMwNTkwMzcxNzdmMyIsImNvbXBhbnlfaWQiOiJmYjUxMjA4ZS1lODc5LTQxZDMtYjIwOC0wNTJiNzIzYWY4NTQiLCJpYXQiOjE3NzE3ODg1MDYsImV4cCI6MTc3NDM4MDUwNn0.4LgImv3JmgpsZWtDGbHin7UIQqTQe378n-0B4jrFqGk	\N	\N	2026-02-22 20:28:26.323748+01	2026-03-24 20:28:26.323748+01	f
876c3ce8-6db8-4534-8156-836518e32358	453afce7-e780-4e4b-bee1-3059037177f3	fb51208e-e879-41d3-b208-052b723af854	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6IjQ1M2FmY2U3LWU3ODAtNGU0Yi1iZWUxLTMwNTkwMzcxNzdmMyIsImNvbXBhbnlfaWQiOiJmYjUxMjA4ZS1lODc5LTQxZDMtYjIwOC0wNTJiNzIzYWY4NTQiLCJpYXQiOjE3NzE4MTQ1MzEsImV4cCI6MTc3NDQwNjUzMX0.Q0OnjSLTp-JfvxPotB4gqTTxL59LMQcoYltQrj4Bnr4	\N	\N	2026-02-23 03:42:11.357133+01	2026-03-25 03:42:11.357133+01	f
45c87969-09db-423c-8bb3-26912cc72c63	453afce7-e780-4e4b-bee1-3059037177f3	fb51208e-e879-41d3-b208-052b723af854	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6IjQ1M2FmY2U3LWU3ODAtNGU0Yi1iZWUxLTMwNTkwMzcxNzdmMyIsImNvbXBhbnlfaWQiOiJmYjUxMjA4ZS1lODc5LTQxZDMtYjIwOC0wNTJiNzIzYWY4NTQiLCJpYXQiOjE3NzE4ODg2MDUsImV4cCI6MTc3NDQ4MDYwNX0.KNlrowKfJqKiMx5YgwM7kMcvQdwK3Bbc1pbIimC6bAQ	\N	\N	2026-02-24 00:16:45.518763+01	2026-03-26 00:16:45.518763+01	f
b1acc401-25ad-40ad-b7ef-7fca159a1e73	453afce7-e780-4e4b-bee1-3059037177f3	fb51208e-e879-41d3-b208-052b723af854	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6IjQ1M2FmY2U3LWU3ODAtNGU0Yi1iZWUxLTMwNTkwMzcxNzdmMyIsImNvbXBhbnlfaWQiOiJmYjUxMjA4ZS1lODc5LTQxZDMtYjIwOC0wNTJiNzIzYWY4NTQiLCJpYXQiOjE3NzE5MDA3MzUsImV4cCI6MTc3NDQ5MjczNX0.mvgYFLw5SeNwYH_Vccb1aXVYsaAro8G-X7h5R5-bSJc	\N	\N	2026-02-24 03:38:55.544091+01	2026-03-26 03:38:55.544091+01	f
22b4bbc5-e40c-4143-9d40-4a5e0c68a170	d4de44f0-2da0-4038-a797-cee556105229	f5b30c46-18bb-49f2-bf47-cd768809fdd7	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6ImQ0ZGU0NGYwLTJkYTAtNDAzOC1hNzk3LWNlZTU1NjEwNTIyOSIsImNvbXBhbnlfaWQiOiJmNWIzMGM0Ni0xOGJiLTQ5ZjItYmY0Ny1jZDc2ODgwOWZkZDciLCJpYXQiOjE3NzE5NDIzNTksImV4cCI6MTc3NDUzNDM1OX0.Od1kgCL9K0uUcBe2UdWl8DoHEXK60qYlAa5HiKftkSE	\N	\N	2026-02-24 15:12:39.330218+01	2026-03-26 15:12:39.330218+01	f
1282dcb5-c244-4f24-8dc1-03e36588c2f0	2117a873-690d-41e8-a35a-dab50a4524df	3fac05be-c11f-4cf4-8c60-a082a9c04467	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6IjIxMTdhODczLTY5MGQtNDFlOC1hMzVhLWRhYjUwYTQ1MjRkZiIsImNvbXBhbnlfaWQiOiIzZmFjMDViZS1jMTFmLTRjZjQtOGM2MC1hMDgyYTljMDQ0NjciLCJpYXQiOjE3NzE5ODMxNDUsImV4cCI6MTc3NDU3NTE0NX0.YxF6RdblIzBLbtOUTOr9iAdv7pBhq7GBQQ-zzQ0OcJQ	\N	\N	2026-02-25 02:32:25.067593+01	2026-03-27 02:32:25.067593+01	f
3cdeb4ed-0cd4-4f37-b28b-650130b35738	ae62842e-7956-41c3-933d-e92a2a3dda43	e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6ImFlNjI4NDJlLTc5NTYtNDFjMy05MzNkLWU5MmEyYTNkZGE0MyIsImNvbXBhbnlfaWQiOiJlNzlkZDJkMC1hMGY4LTQ4ZjEtOTcxMy03MGE4NDAzYzNlYTgiLCJpYXQiOjE3NzE5ODQ0MTUsImV4cCI6MTc3NDU3NjQxNX0.23JQRxkZv30OAiT3u8C47RZUI1A0Zaiiq6GOer41bsg	\N	\N	2026-02-25 02:53:35.813854+01	2026-03-27 02:53:35.813854+01	f
26d14040-8e83-4263-90e6-24afe8a1f963	453afce7-e780-4e4b-bee1-3059037177f3	fb51208e-e879-41d3-b208-052b723af854	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY3Rvcl9pZCI6IjQ1M2FmY2U3LWU3ODAtNGU0Yi1iZWUxLTMwNTkwMzcxNzdmMyIsImNvbXBhbnlfaWQiOiJmYjUxMjA4ZS1lODc5LTQxZDMtYjIwOC0wNTJiNzIzYWY4NTQiLCJpYXQiOjE3NzIxNTI2MjMsImV4cCI6MTc3NDc0NDYyM30.MjCMXZWG7UuLUcS8WkgldI5ANdXR8op4szuX2v3elWQ	\N	\N	2026-02-27 01:37:03.692353+01	2026-03-29 01:37:03.692353+01	f
\.


--
-- Data for Name: reason_code; Type: TABLE DATA; Schema: inv; Owner: -
--

COPY inv.reason_code (company_id, code, label, description, is_active, created_at) FROM stdin;
fb51208e-e879-41d3-b208-052b723af854	expiry	Vencimiento	Producto vencido	t	2026-02-23 00:19:14.884208+01
fb51208e-e879-41d3-b208-052b723af854	inventory_count	Conteo físico	Ajuste por inventario físico	t	2026-02-23 00:19:14.884208+01
fb51208e-e879-41d3-b208-052b723af854	theft	Robo / Pérdida	Merma por pérdida/robo	t	2026-02-23 00:19:14.884208+01
fb51208e-e879-41d3-b208-052b723af854	manual_correction	Corrección manual	Corrección administrativa	t	2026-02-23 00:19:14.884208+01
fb51208e-e879-41d3-b208-052b723af854	transfer_correction	Corrección transferencia	Ajuste por error en traslado	t	2026-02-23 00:33:08.424831+01
fb51208e-e879-41d3-b208-052b723af854	damage	Rotura / Daño	Producto dañado o roto	f	2026-02-23 00:19:14.884208+01
f5b30c46-18bb-49f2-bf47-cd768809fdd7	damage	Rotura / Daño	Producto dañado o roto	t	2026-02-24 15:12:27.535992+01
f5b30c46-18bb-49f2-bf47-cd768809fdd7	expiry	Vencimiento	Producto vencido	t	2026-02-24 15:12:27.535992+01
f5b30c46-18bb-49f2-bf47-cd768809fdd7	inventory_count	Conteo físico	Ajuste por inventario físico	t	2026-02-24 15:12:27.535992+01
f5b30c46-18bb-49f2-bf47-cd768809fdd7	theft	Robo / Pérdida	Merma por pérdida/robo	t	2026-02-24 15:12:27.535992+01
f5b30c46-18bb-49f2-bf47-cd768809fdd7	manual_correction	Corrección manual	Corrección administrativa	t	2026-02-24 15:12:27.535992+01
b95c4f17-0e67-4198-bc04-8344993910cb	damage	Rotura / Daño	Producto dañado o roto	t	2026-02-25 01:53:06.314406+01
b95c4f17-0e67-4198-bc04-8344993910cb	expiry	Vencimiento	Producto vencido	t	2026-02-25 01:53:06.314406+01
b95c4f17-0e67-4198-bc04-8344993910cb	inventory_count	Conteo físico	Ajuste por inventario físico	t	2026-02-25 01:53:06.314406+01
b95c4f17-0e67-4198-bc04-8344993910cb	theft	Robo / Pérdida	Merma por pérdida/robo	t	2026-02-25 01:53:06.314406+01
b95c4f17-0e67-4198-bc04-8344993910cb	manual_correction	Corrección manual	Corrección administrativa	t	2026-02-25 01:53:06.314406+01
3fac05be-c11f-4cf4-8c60-a082a9c04467	damage	Rotura / Daño	Producto dañado o roto	t	2026-02-25 02:28:15.002531+01
3fac05be-c11f-4cf4-8c60-a082a9c04467	expiry	Vencimiento	Producto vencido	t	2026-02-25 02:28:15.002531+01
3fac05be-c11f-4cf4-8c60-a082a9c04467	inventory_count	Conteo físico	Ajuste por inventario físico	t	2026-02-25 02:28:15.002531+01
3fac05be-c11f-4cf4-8c60-a082a9c04467	theft	Robo / Pérdida	Merma por pérdida/robo	t	2026-02-25 02:28:15.002531+01
3fac05be-c11f-4cf4-8c60-a082a9c04467	manual_correction	Corrección manual	Corrección administrativa	t	2026-02-25 02:28:15.002531+01
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	damage	Rotura / Daño	Producto dañado o roto	t	2026-02-25 02:53:24.69242+01
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	expiry	Vencimiento	Producto vencido	t	2026-02-25 02:53:24.69242+01
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	inventory_count	Conteo físico	Ajuste por inventario físico	t	2026-02-25 02:53:24.69242+01
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	theft	Robo / Pérdida	Merma por pérdida/robo	t	2026-02-25 02:53:24.69242+01
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	manual_correction	Corrección manual	Corrección administrativa	t	2026-02-25 02:53:24.69242+01
\.


--
-- Data for Name: stock_balance; Type: TABLE DATA; Schema: inv; Owner: -
--

COPY inv.stock_balance (company_id, branch_id, item_id, quantity, reserved_quantity) FROM stdin;
fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	a452ca08-adef-477d-8bb4-56d600e94251	4.00	0.00
fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	d01f03e3-88e2-4a01-a75d-9fbf559881fd	14.00	0.00
fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	151a662c-4424-4a13-9a8b-4343d910fdd7	73.00	0.00
fb51208e-e879-41d3-b208-052b723af854	d0c40d9a-26a6-4bc5-b59d-a3ef76fa563b	151a662c-4424-4a13-9a8b-4343d910fdd7	7.00	0.00
f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	978460a4-cced-4b16-836a-5f5b2993dd4d	15.00	0.00
f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	4594d78a-662f-40bb-8a9c-f5c25d4590e8	47.00	0.00
f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	e08cf53a-975d-4552-8176-a870e6ec7058	94.00	0.00
e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	9cd665e7-8b96-4f55-9568-2249728d6b7f	ff6f1fc3-907a-4cd1-8592-fa2cfbb323e0	45.00	0.00
\.


--
-- Data for Name: stock_ledger; Type: TABLE DATA; Schema: inv; Owner: -
--

COPY inv.stock_ledger (id, company_id, branch_id, item_id, movement_type, quantity, reference_id, created_at, reason_code) FROM stdin;
31291a3c-a4ec-44c5-a586-be317d7dfa84	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	6d607225-4d5d-47c4-9a70-d2c5dba66b4c	purchase	50.00	\N	2026-02-22 21:44:24.609112+01	\N
b477a1c6-14ca-4bc3-a92d-f477e38241f1	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	4b76a3f7-57b7-434d-855b-e01980c63ad8	purchase	100.00	\N	2026-02-22 22:08:01.284872+01	\N
fecabd7b-ff75-402f-b8a7-fccce54f9645	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	4b76a3f7-57b7-434d-855b-e01980c63ad8	sale	-30.00	\N	2026-02-22 22:09:10.953902+01	\N
c7bb49fa-81b9-4a42-8e55-a3f33ade7b87	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	151a662c-4424-4a13-9a8b-4343d910fdd7	purchase	100.00	\N	2026-02-23 03:56:23.677624+01	\N
47753b46-540d-4334-b920-64595bf42b9c	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	151a662c-4424-4a13-9a8b-4343d910fdd7	sale	-10.00	704ac899-8710-4abf-ab2b-6f899e6e2c35	2026-02-23 05:23:55.680505+01	\N
8f10104b-51ee-4b61-a191-c8315c0e6d12	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	151a662c-4424-4a13-9a8b-4343d910fdd7	sale	-10.00	8b7f23d3-2bd9-47c5-8b6b-83edc75ee249	2026-02-24 00:28:51.629475+01	\N
7d3cccec-e6b8-4493-98e7-014c89d39004	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	d01f03e3-88e2-4a01-a75d-9fbf559881fd	purchase	20.00	\N	2026-02-24 01:11:00.900004+01	\N
a9622d22-5b5e-4f56-8cc1-33a1b64394dc	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	a452ca08-adef-477d-8bb4-56d600e94251	purchase	10.00	\N	2026-02-24 01:11:00.93399+01	\N
58bb990a-08ec-498f-a02b-36721fcbc665	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	a452ca08-adef-477d-8bb4-56d600e94251	sale	-3.00	62b30321-9e7b-402c-94b0-6a9fbae56138	2026-02-24 01:31:13.640121+01	\N
2912ca7e-5f83-43c5-89f4-ba26302ba425	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	a452ca08-adef-477d-8bb4-56d600e94251	sale	-3.00	a169807e-2ada-4817-84d3-7c1506f249be	2026-02-24 01:35:20.688565+01	\N
7b8a09dc-b1eb-4e7a-aac8-f9b26de87c1e	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	d01f03e3-88e2-4a01-a75d-9fbf559881fd	sale	-6.00	a169807e-2ada-4817-84d3-7c1506f249be	2026-02-24 01:35:20.688565+01	\N
d5759f2e-0e26-4327-81fb-a1af814e3126	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	151a662c-4424-4a13-9a8b-4343d910fdd7	transfer_out	-7.00	TR-001	2026-02-24 04:24:36.14255+01	\N
d660500e-0f41-43d3-887f-22ea1906dc3b	fb51208e-e879-41d3-b208-052b723af854	d0c40d9a-26a6-4bc5-b59d-a3ef76fa563b	151a662c-4424-4a13-9a8b-4343d910fdd7	transfer_in	7.00	TR-001	2026-02-24 04:24:36.14255+01	\N
41b30a02-a882-4e26-b9eb-570a754af720	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	978460a4-cced-4b16-836a-5f5b2993dd4d	purchase	20.00	\N	2026-02-24 15:14:30.708936+01	\N
13a29042-a36c-416a-bf17-6eea3ebf8c22	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	978460a4-cced-4b16-836a-5f5b2993dd4d	sale	-5.00	ORDER-001	2026-02-24 15:15:03.726808+01	\N
b0f2ed0b-d1df-4dfe-aeb2-7ff2a23d97df	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	e08cf53a-975d-4552-8176-a870e6ec7058	purchase	100.00	\N	2026-02-24 15:15:54.604+01	\N
b50702f3-a468-490f-8638-1654dcd22664	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	4594d78a-662f-40bb-8a9c-f5c25d4590e8	purchase	50.00	\N	2026-02-24 15:16:00.859232+01	\N
d1d128dd-b8ae-4300-a0ef-1bb6f6e3981a	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	4594d78a-662f-40bb-8a9c-f5c25d4590e8	sale	-3.00	KIT-ORDER-001	2026-02-24 15:17:03.877106+01	\N
acdc4d16-a03b-461d-9499-45e7fd6818cb	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	e08cf53a-975d-4552-8176-a870e6ec7058	sale	-6.00	KIT-ORDER-001	2026-02-24 15:17:03.877106+01	\N
fbe11e94-e203-4a51-bc5a-958c7093b604	e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	9cd665e7-8b96-4f55-9568-2249728d6b7f	ff6f1fc3-907a-4cd1-8592-fa2cfbb323e0	purchase	50.00	PO-001	2026-02-25 02:55:28.194391+01	\N
290c158c-da63-4f50-98e6-e5db99ded16f	e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	9cd665e7-8b96-4f55-9568-2249728d6b7f	ff6f1fc3-907a-4cd1-8592-fa2cfbb323e0	sale	-5.00	SO-001	2026-02-25 02:56:18.206534+01	\N
\.


--
-- Data for Name: stock_reservation; Type: TABLE DATA; Schema: inv; Owner: -
--

COPY inv.stock_reservation (id, company_id, branch_id, reference_id, status, created_at) FROM stdin;
886032ba-d36c-4229-8ef9-d6fcf4ed2ef6	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	704ac899-8710-4abf-ab2b-6f899e6e2c35	confirmed	2026-02-23 04:47:46.651277+01
b25a72f9-d25b-4d29-b7a2-b733fb6d1118	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	8b7f23d3-2bd9-47c5-8b6b-83edc75ee249	confirmed	2026-02-24 00:27:54.466133+01
57ec546b-1fab-4023-848f-6bb9ff847172	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	42b7d3ce-f3ac-47e6-b12b-12162747d5bd	released	2026-02-24 00:29:33.367637+01
08702df5-80a7-4711-92cf-3279f91cd363	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	62b30321-9e7b-402c-94b0-6a9fbae56138	confirmed	2026-02-24 01:11:13.208718+01
97abc9fb-684d-4198-8357-5298c0f75205	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	a169807e-2ada-4817-84d3-7c1506f249be	confirmed	2026-02-24 01:34:27.873104+01
0f925f2c-0e84-4122-84f3-fb51342ef454	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	ORDER-001	confirmed	2026-02-24 15:14:49.411756+01
679ba59d-de5a-4889-80f4-51a6ba8eacf7	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	KIT-ORDER-001	confirmed	2026-02-24 15:16:30.589535+01
ab7f1abf-fca5-4a0a-825a-16463e396c45	e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	9cd665e7-8b96-4f55-9568-2249728d6b7f	SO-001	confirmed	2026-02-25 02:55:58.891431+01
\.


--
-- Data for Name: stock_reservation_line; Type: TABLE DATA; Schema: inv; Owner: -
--

COPY inv.stock_reservation_line (id, reservation_id, company_id, branch_id, item_id, quantity) FROM stdin;
d28a8f6b-d675-406a-8585-f7673a2db233	886032ba-d36c-4229-8ef9-d6fcf4ed2ef6	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	151a662c-4424-4a13-9a8b-4343d910fdd7	10.00
8be1b891-6628-4973-9b01-7ccc9322df91	b25a72f9-d25b-4d29-b7a2-b733fb6d1118	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	151a662c-4424-4a13-9a8b-4343d910fdd7	10.00
ed60078d-12fc-43e4-9183-2f614ee7d56b	57ec546b-1fab-4023-848f-6bb9ff847172	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	151a662c-4424-4a13-9a8b-4343d910fdd7	7.00
ce3f7411-27b8-460d-8b1c-a56a0d9e9bfc	08702df5-80a7-4711-92cf-3279f91cd363	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	a452ca08-adef-477d-8bb4-56d600e94251	3.00
5d00d171-7057-4b39-8d61-b7c975a90ab2	97abc9fb-684d-4198-8357-5298c0f75205	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	a452ca08-adef-477d-8bb4-56d600e94251	3.00
1e826437-0df9-48e8-a211-6a8673348e9a	97abc9fb-684d-4198-8357-5298c0f75205	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	d01f03e3-88e2-4a01-a75d-9fbf559881fd	6.00
9d80eada-3a65-4c73-9dc1-f6255a71f328	0f925f2c-0e84-4122-84f3-fb51342ef454	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	978460a4-cced-4b16-836a-5f5b2993dd4d	5.00
e25b9ec8-c9d4-4450-ac5c-daa27f8c3800	679ba59d-de5a-4889-80f4-51a6ba8eacf7	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	4594d78a-662f-40bb-8a9c-f5c25d4590e8	3.00
01d4a761-ca05-485c-b7fe-af52384d6b96	679ba59d-de5a-4889-80f4-51a6ba8eacf7	f5b30c46-18bb-49f2-bf47-cd768809fdd7	0a22400f-4494-4eba-8f47-b703b0612e20	e08cf53a-975d-4552-8176-a870e6ec7058	6.00
fbc0064a-088c-462b-8890-b4279ba5ca8f	ab7f1abf-fca5-4a0a-825a-16463e396c45	e79dd2d0-a0f8-48f1-9713-70a8403c3ea8	9cd665e7-8b96-4f55-9568-2249728d6b7f	ff6f1fc3-907a-4cd1-8592-fa2cfbb323e0	5.00
\.


--
-- Data for Name: stock_transfer; Type: TABLE DATA; Schema: inv; Owner: -
--

COPY inv.stock_transfer (id, company_id, from_branch_id, to_branch_id, reference_id, status, created_at, received_at, cancelled_at) FROM stdin;
05cce9e1-5ae5-4e62-ad55-0e35351bb3f9	fb51208e-e879-41d3-b208-052b723af854	aa2b0c3a-193c-46d8-9721-e5ddf0e70037	d0c40d9a-26a6-4bc5-b59d-a3ef76fa563b	TR-001	received	2026-02-24 03:51:38.383191+01	2026-02-24 04:24:36.14255+01	\N
\.


--
-- Data for Name: stock_transfer_line; Type: TABLE DATA; Schema: inv; Owner: -
--

COPY inv.stock_transfer_line (id, transfer_id, company_id, item_id, quantity) FROM stdin;
c6c098ee-4704-466b-98ef-d188b8aa09be	05cce9e1-5ae5-4e62-ad55-0e35351bb3f9	fb51208e-e879-41d3-b208-052b723af854	151a662c-4424-4a13-9a8b-4343d910fdd7	7.00
\.


--
-- Name: branch branch_company_id_code_key; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.branch
    ADD CONSTRAINT branch_company_id_code_key UNIQUE (company_id, code);


--
-- Name: branch branch_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.branch
    ADD CONSTRAINT branch_pkey PRIMARY KEY (id);


--
-- Name: company company_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (id);


--
-- Name: company company_slug_key; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.company
    ADD CONSTRAINT company_slug_key UNIQUE (slug);


--
-- Name: item item_company_id_sku_key; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.item
    ADD CONSTRAINT item_company_id_sku_key UNIQUE (company_id, sku);


--
-- Name: item_component item_component_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.item_component
    ADD CONSTRAINT item_component_pkey PRIMARY KEY (company_id, parent_item_id, component_item_id);


--
-- Name: item item_pkey; Type: CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- Name: actor_branch actor_branch_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_branch
    ADD CONSTRAINT actor_branch_pkey PRIMARY KEY (company_id, actor_id, branch_id);


--
-- Name: actor actor_email_key; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor
    ADD CONSTRAINT actor_email_key UNIQUE (email);


--
-- Name: actor actor_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor
    ADD CONSTRAINT actor_pkey PRIMARY KEY (id);


--
-- Name: actor_role actor_role_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_role
    ADD CONSTRAINT actor_role_pkey PRIMARY KEY (company_id, actor_id, role_code);


--
-- Name: membership membership_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.membership
    ADD CONSTRAINT membership_pkey PRIMARY KEY (company_id, actor_id);


--
-- Name: permission permission_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.permission
    ADD CONSTRAINT permission_pkey PRIMARY KEY (code);


--
-- Name: role_permission role_permission_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.role_permission
    ADD CONSTRAINT role_permission_pkey PRIMARY KEY (company_id, role_code, perm_code);


--
-- Name: role role_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (company_id, code);


--
-- Name: session session_pkey; Type: CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (id);


--
-- Name: reason_code reason_code_pkey; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.reason_code
    ADD CONSTRAINT reason_code_pkey PRIMARY KEY (company_id, code);


--
-- Name: stock_balance stock_balance_pkey; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_balance
    ADD CONSTRAINT stock_balance_pkey PRIMARY KEY (company_id, branch_id, item_id);


--
-- Name: stock_ledger stock_ledger_pkey; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_ledger
    ADD CONSTRAINT stock_ledger_pkey PRIMARY KEY (id);


--
-- Name: stock_reservation stock_reservation_company_id_reference_id_key; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_reservation
    ADD CONSTRAINT stock_reservation_company_id_reference_id_key UNIQUE (company_id, reference_id);


--
-- Name: stock_reservation_line stock_reservation_line_pkey; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_reservation_line
    ADD CONSTRAINT stock_reservation_line_pkey PRIMARY KEY (id);


--
-- Name: stock_reservation stock_reservation_pkey; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_reservation
    ADD CONSTRAINT stock_reservation_pkey PRIMARY KEY (id);


--
-- Name: stock_transfer stock_transfer_company_id_reference_id_key; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer
    ADD CONSTRAINT stock_transfer_company_id_reference_id_key UNIQUE (company_id, reference_id);


--
-- Name: stock_transfer_line stock_transfer_line_pkey; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer_line
    ADD CONSTRAINT stock_transfer_line_pkey PRIMARY KEY (id);


--
-- Name: stock_transfer_line stock_transfer_line_transfer_id_item_id_key; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer_line
    ADD CONSTRAINT stock_transfer_line_transfer_id_item_id_key UNIQUE (transfer_id, item_id);


--
-- Name: stock_transfer stock_transfer_pkey; Type: CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer
    ADD CONSTRAINT stock_transfer_pkey PRIMARY KEY (id);


--
-- Name: branch_company_id_idx; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX branch_company_id_idx ON core.branch USING btree (company_id);


--
-- Name: core_branch_company_id_id_idx; Type: INDEX; Schema: core; Owner: -
--

CREATE UNIQUE INDEX core_branch_company_id_id_idx ON core.branch USING btree (company_id, id);


--
-- Name: core_item_company_id_id_idx; Type: INDEX; Schema: core; Owner: -
--

CREATE UNIQUE INDEX core_item_company_id_id_idx ON core.item USING btree (company_id, id);


--
-- Name: core_item_company_idx; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX core_item_company_idx ON core.item USING btree (company_id);


--
-- Name: item_component_parent_idx; Type: INDEX; Schema: core; Owner: -
--

CREATE INDEX item_component_parent_idx ON core.item_component USING btree (company_id, parent_item_id);


--
-- Name: actor_branch_company_id_actor_id_idx; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX actor_branch_company_id_actor_id_idx ON iam.actor_branch USING btree (company_id, actor_id);


--
-- Name: actor_role_company_id_actor_id_idx; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX actor_role_company_id_actor_id_idx ON iam.actor_role USING btree (company_id, actor_id);


--
-- Name: membership_actor_id_idx; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX membership_actor_id_idx ON iam.membership USING btree (actor_id);


--
-- Name: membership_company_id_actor_id_idx; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX membership_company_id_actor_id_idx ON iam.membership USING btree (company_id, actor_id);


--
-- Name: role_permission_company_id_perm_code_idx; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX role_permission_company_id_perm_code_idx ON iam.role_permission USING btree (company_id, perm_code);


--
-- Name: session_actor_id_idx; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX session_actor_id_idx ON iam.session USING btree (actor_id);


--
-- Name: session_company_id_idx; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX session_company_id_idx ON iam.session USING btree (company_id);


--
-- Name: session_refresh_token_idx; Type: INDEX; Schema: iam; Owner: -
--

CREATE INDEX session_refresh_token_idx ON iam.session USING btree (refresh_token);


--
-- Name: inv_reason_code_company_active_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX inv_reason_code_company_active_idx ON inv.reason_code USING btree (company_id, is_active);


--
-- Name: stock_ledger_branch_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_ledger_branch_idx ON inv.stock_ledger USING btree (branch_id);


--
-- Name: stock_ledger_company_branch_item_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_ledger_company_branch_item_idx ON inv.stock_ledger USING btree (company_id, branch_id, item_id);


--
-- Name: stock_ledger_company_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_ledger_company_idx ON inv.stock_ledger USING btree (company_id);


--
-- Name: stock_ledger_item_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_ledger_item_idx ON inv.stock_ledger USING btree (item_id);


--
-- Name: stock_res_line_lookup_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_res_line_lookup_idx ON inv.stock_reservation_line USING btree (company_id, branch_id, item_id);


--
-- Name: stock_transfer_company_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_transfer_company_idx ON inv.stock_transfer USING btree (company_id);


--
-- Name: stock_transfer_line_company_item_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_transfer_line_company_item_idx ON inv.stock_transfer_line USING btree (company_id, item_id);


--
-- Name: stock_transfer_line_transfer_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_transfer_line_transfer_idx ON inv.stock_transfer_line USING btree (transfer_id);


--
-- Name: stock_transfer_status_idx; Type: INDEX; Schema: inv; Owner: -
--

CREATE INDEX stock_transfer_status_idx ON inv.stock_transfer USING btree (company_id, status);


--
-- Name: company trg_seed_reason_codes; Type: TRIGGER; Schema: core; Owner: -
--

CREATE TRIGGER trg_seed_reason_codes AFTER INSERT ON core.company FOR EACH ROW EXECUTE FUNCTION inv.trg_company_seed_reason_codes();


--
-- Name: item trg_set_stock_tracking; Type: TRIGGER; Schema: core; Owner: -
--

CREATE TRIGGER trg_set_stock_tracking BEFORE INSERT OR UPDATE ON core.item FOR EACH ROW EXECUTE FUNCTION core.set_stock_tracking();


--
-- Name: membership trg_prevent_last_owner; Type: TRIGGER; Schema: iam; Owner: -
--

CREATE TRIGGER trg_prevent_last_owner BEFORE DELETE OR UPDATE ON iam.membership FOR EACH ROW EXECUTE FUNCTION iam.prevent_remove_last_owner();


--
-- Name: stock_ledger trg_update_stock_balance; Type: TRIGGER; Schema: inv; Owner: -
--

CREATE TRIGGER trg_update_stock_balance AFTER INSERT ON inv.stock_ledger FOR EACH ROW EXECUTE FUNCTION inv.update_stock_balance();


--
-- Name: branch branch_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.branch
    ADD CONSTRAINT branch_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: item item_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.item
    ADD CONSTRAINT item_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: item_component item_component_component_fk; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.item_component
    ADD CONSTRAINT item_component_component_fk FOREIGN KEY (company_id, component_item_id) REFERENCES core.item(company_id, id) ON DELETE CASCADE;


--
-- Name: item_component item_component_parent_fk; Type: FK CONSTRAINT; Schema: core; Owner: -
--

ALTER TABLE ONLY core.item_component
    ADD CONSTRAINT item_component_parent_fk FOREIGN KEY (company_id, parent_item_id) REFERENCES core.item(company_id, id) ON DELETE CASCADE;


--
-- Name: actor_branch actor_branch_actor_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_branch
    ADD CONSTRAINT actor_branch_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES iam.actor(id) ON DELETE CASCADE;


--
-- Name: actor_branch actor_branch_branch_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_branch
    ADD CONSTRAINT actor_branch_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES core.branch(id) ON DELETE CASCADE;


--
-- Name: actor_branch actor_branch_company_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_branch
    ADD CONSTRAINT actor_branch_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: actor_branch actor_branch_company_match; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_branch
    ADD CONSTRAINT actor_branch_company_match FOREIGN KEY (company_id, branch_id) REFERENCES core.branch(company_id, id) ON DELETE CASCADE;


--
-- Name: actor_role actor_role_actor_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_role
    ADD CONSTRAINT actor_role_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES iam.actor(id) ON DELETE CASCADE;


--
-- Name: actor_role actor_role_company_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_role
    ADD CONSTRAINT actor_role_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: actor_role actor_role_company_id_role_code_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.actor_role
    ADD CONSTRAINT actor_role_company_id_role_code_fkey FOREIGN KEY (company_id, role_code) REFERENCES iam.role(company_id, code) ON DELETE CASCADE;


--
-- Name: membership membership_actor_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.membership
    ADD CONSTRAINT membership_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES iam.actor(id) ON DELETE CASCADE;


--
-- Name: membership membership_company_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.membership
    ADD CONSTRAINT membership_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: role role_company_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.role
    ADD CONSTRAINT role_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: role_permission role_permission_company_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.role_permission
    ADD CONSTRAINT role_permission_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: role_permission role_permission_company_id_role_code_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.role_permission
    ADD CONSTRAINT role_permission_company_id_role_code_fkey FOREIGN KEY (company_id, role_code) REFERENCES iam.role(company_id, code) ON DELETE CASCADE;


--
-- Name: role_permission role_permission_perm_code_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.role_permission
    ADD CONSTRAINT role_permission_perm_code_fkey FOREIGN KEY (perm_code) REFERENCES iam.permission(code) ON DELETE CASCADE;


--
-- Name: session session_actor_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.session
    ADD CONSTRAINT session_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES iam.actor(id) ON DELETE CASCADE;


--
-- Name: session session_company_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: -
--

ALTER TABLE ONLY iam.session
    ADD CONSTRAINT session_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: reason_code reason_code_company_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.reason_code
    ADD CONSTRAINT reason_code_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: stock_balance stock_balance_company_id_branch_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_balance
    ADD CONSTRAINT stock_balance_company_id_branch_id_fkey FOREIGN KEY (company_id, branch_id) REFERENCES core.branch(company_id, id) ON DELETE CASCADE;


--
-- Name: stock_balance stock_balance_company_id_item_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_balance
    ADD CONSTRAINT stock_balance_company_id_item_id_fkey FOREIGN KEY (company_id, item_id) REFERENCES core.item(company_id, id) ON DELETE CASCADE;


--
-- Name: stock_ledger stock_ledger_branch_company_match; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_ledger
    ADD CONSTRAINT stock_ledger_branch_company_match FOREIGN KEY (company_id, branch_id) REFERENCES core.branch(company_id, id) ON DELETE CASCADE;


--
-- Name: stock_ledger stock_ledger_company_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_ledger
    ADD CONSTRAINT stock_ledger_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: stock_ledger stock_ledger_item_company_match; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_ledger
    ADD CONSTRAINT stock_ledger_item_company_match FOREIGN KEY (company_id, item_id) REFERENCES core.item(company_id, id) ON DELETE CASCADE;


--
-- Name: stock_ledger stock_ledger_reason_code_fk; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_ledger
    ADD CONSTRAINT stock_ledger_reason_code_fk FOREIGN KEY (company_id, reason_code) REFERENCES inv.reason_code(company_id, code);


--
-- Name: stock_reservation stock_res_branch_company_match; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_reservation
    ADD CONSTRAINT stock_res_branch_company_match FOREIGN KEY (company_id, branch_id) REFERENCES core.branch(company_id, id) ON DELETE CASCADE;


--
-- Name: stock_reservation_line stock_res_line_item_company_match; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_reservation_line
    ADD CONSTRAINT stock_res_line_item_company_match FOREIGN KEY (company_id, item_id) REFERENCES core.item(company_id, id) ON DELETE CASCADE;


--
-- Name: stock_reservation stock_reservation_company_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_reservation
    ADD CONSTRAINT stock_reservation_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: stock_reservation_line stock_reservation_line_reservation_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_reservation_line
    ADD CONSTRAINT stock_reservation_line_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES inv.stock_reservation(id) ON DELETE CASCADE;


--
-- Name: stock_transfer stock_transfer_company_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer
    ADD CONSTRAINT stock_transfer_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: stock_transfer stock_transfer_from_branch_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer
    ADD CONSTRAINT stock_transfer_from_branch_id_fkey FOREIGN KEY (from_branch_id) REFERENCES core.branch(id);


--
-- Name: stock_transfer_line stock_transfer_line_company_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer_line
    ADD CONSTRAINT stock_transfer_line_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.company(id) ON DELETE CASCADE;


--
-- Name: stock_transfer_line stock_transfer_line_item_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer_line
    ADD CONSTRAINT stock_transfer_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES core.item(id);


--
-- Name: stock_transfer_line stock_transfer_line_transfer_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer_line
    ADD CONSTRAINT stock_transfer_line_transfer_id_fkey FOREIGN KEY (transfer_id) REFERENCES inv.stock_transfer(id) ON DELETE CASCADE;


--
-- Name: stock_transfer stock_transfer_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: inv; Owner: -
--

ALTER TABLE ONLY inv.stock_transfer
    ADD CONSTRAINT stock_transfer_to_branch_id_fkey FOREIGN KEY (to_branch_id) REFERENCES core.branch(id);


--
-- PostgreSQL database dump complete
--

\unrestrict bf8cbzWgvUptTfbya8qjNoWte7DaqaCX1yjDZAljAWnlRNjnqqBjmTtUQuZDxDw

