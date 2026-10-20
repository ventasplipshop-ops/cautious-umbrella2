--
-- PostgreSQL database dump
--

\restrict OEw3QvX7RxrJtsACu9vbXxTAy9erS3h51xPBMd42d44sdtcR5GHKnbxHp56B2tQ

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



-- ======================================================
-- SCHEMA
-- ======================================================

--
-- Name: reciclaje; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA reciclaje;


ALTER SCHEMA reciclaje OWNER TO postgres;



-- ======================================================
-- TYPE
-- ======================================================

--
-- Name: estado_orden; Type: TYPE; Schema: reciclaje; Owner: postgres
--

CREATE TYPE reciclaje.estado_orden AS ENUM (
    'borrador',
    'en_ruta',
    'recibida',
    'cancelada'
);


ALTER TYPE reciclaje.estado_orden OWNER TO postgres;


--
-- Name: estado_recepcion; Type: TYPE; Schema: reciclaje; Owner: postgres
--

CREATE TYPE reciclaje.estado_recepcion AS ENUM (
    'borrador',
    'confirmada',
    'cancelada'
);


ALTER TYPE reciclaje.estado_recepcion OWNER TO postgres;


--
-- Name: etapa_operacion; Type: TYPE; Schema: reciclaje; Owner: postgres
--

CREATE TYPE reciclaje.etapa_operacion AS ENUM (
    'precarga',
    'en_proceso',
    'finalizada'
);


ALTER TYPE reciclaje.etapa_operacion OWNER TO postgres;


--
-- Name: tipo_movimiento; Type: TYPE; Schema: reciclaje; Owner: postgres
--

CREATE TYPE reciclaje.tipo_movimiento AS ENUM (
    'entrada',
    'salida',
    'ajuste',
    'traslado'
);


ALTER TYPE reciclaje.tipo_movimiento OWNER TO postgres;


--
-- Name: tipo_operacion; Type: TYPE; Schema: reciclaje; Owner: postgres
--

CREATE TYPE reciclaje.tipo_operacion AS ENUM (
    'compra',
    'venta'
);


ALTER TYPE reciclaje.tipo_operacion OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;



-- ======================================================
-- TABLE
-- ======================================================

--
-- Name: depositos; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.depositos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    direccion text,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE reciclaje.depositos OWNER TO postgres;


--
-- Name: finanzas; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.finanzas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    origen_tipo text DEFAULT 'manual'::text,
    origen_id uuid,
    fecha_emision timestamp with time zone DEFAULT now() NOT NULL,
    fecha_vencimiento timestamp with time zone,
    tipo_cambio numeric(14,6) NOT NULL,
    importe_base numeric(14,2) NOT NULL,
    observaciones text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    tipo text NOT NULL,
    anulado boolean DEFAULT false NOT NULL,
    responsable_nombre text,
    responsable_telefono text,
    responsable_tipo text,
    CONSTRAINT finanzas_importe_base_check CHECK ((importe_base >= (0)::numeric)),
    CONSTRAINT finanzas_origen_tipo_check CHECK ((origen_tipo = ANY (ARRAY['manual'::text, 'orden_compra'::text, 'orden_venta'::text, 'recepcion'::text, 'gasto'::text, 'ingreso'::text, 'prestamo'::text, 'ajuste'::text]))),
    CONSTRAINT finanzas_tipo_cambio_check CHECK ((tipo_cambio > (0)::numeric)),
    CONSTRAINT finanzas_tipo_check CHECK ((tipo = ANY (ARRAY['cxp'::text, 'cxc'::text])))
);


ALTER TABLE reciclaje.finanzas OWNER TO postgres;


--
-- Name: formas_pago; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.formas_pago (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE reciclaje.formas_pago OWNER TO postgres;


--
-- Name: materiales; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.materiales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    unidad text DEFAULT 'kg'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    precio_base numeric(14,2) DEFAULT 0 NOT NULL,
    precio_mayorista numeric(14,2) DEFAULT 0 NOT NULL,
    imagen_url text,
    compuesto boolean DEFAULT false NOT NULL,
    CONSTRAINT materiales_precio_base_check CHECK ((precio_base >= (0)::numeric)),
    CONSTRAINT materiales_precio_mayorista_check CHECK ((precio_mayorista >= (0)::numeric))
);


ALTER TABLE reciclaje.materiales OWNER TO postgres;


--
-- Name: monedas; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.monedas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    simbolo text,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE reciclaje.monedas OWNER TO postgres;


--
-- Name: movimientos_caja; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.movimientos_caja (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    tipo text NOT NULL,
    monto numeric(14,2) NOT NULL,
    moneda text NOT NULL,
    tipo_cambio numeric(14,6) DEFAULT 1 NOT NULL,
    monto_ars numeric(14,2) NOT NULL,
    forma_pago text,
    referencia text,
    concepto text NOT NULL,
    descripcion text,
    origen_tipo text,
    origen_id uuid,
    responsable_tipo text,
    responsable_id uuid,
    responsable_nombre text,
    comprobante_url text,
    observaciones text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE reciclaje.movimientos_caja OWNER TO postgres;


--
-- Name: movimientos_stock; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.movimientos_stock (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    material_id uuid NOT NULL,
    tipo_movimiento reciclaje.tipo_movimiento NOT NULL,
    cantidad numeric(14,3) NOT NULL,
    origen text NOT NULL,
    origen_id uuid,
    socio_id uuid,
    transportista_id uuid,
    orden_compra_id uuid,
    recepcion_id uuid,
    observaciones text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deposito_id uuid,
    movimiento_grupo_id uuid,
    CONSTRAINT movimientos_stock_cantidad_check CHECK ((cantidad <> (0)::numeric))
);


ALTER TABLE reciclaje.movimientos_stock OWNER TO postgres;


--
-- Name: numeradores; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.numeradores (
    company_id uuid NOT NULL,
    tipo_documento text NOT NULL,
    ultimo_numero integer DEFAULT 0 NOT NULL
);


ALTER TABLE reciclaje.numeradores OWNER TO postgres;


--
-- Name: operaciones; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.operaciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    tipo reciclaje.tipo_operacion DEFAULT 'compra'::reciclaje.tipo_operacion NOT NULL,
    etapa reciclaje.etapa_operacion DEFAULT 'precarga'::reciclaje.etapa_operacion NOT NULL,
    socio_id uuid,
    transportista_id uuid,
    deposito_id uuid,
    monto numeric(14,2),
    materiales jsonb DEFAULT '[]'::jsonb NOT NULL,
    pagos jsonb DEFAULT '[]'::jsonb NOT NULL,
    recibido_por text,
    responsable_nombre text,
    responsable_tipo text,
    observaciones text,
    orden_compra_id uuid,
    recepcion_id uuid,
    finanza_id uuid,
    finalizada boolean DEFAULT false NOT NULL,
    finalizada_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    movimiento_salida_id uuid,
    grupo_salida_id uuid,
    CONSTRAINT operaciones_materiales_array_check CHECK ((jsonb_typeof(materiales) = 'array'::text)),
    CONSTRAINT operaciones_monto_check CHECK (((monto IS NULL) OR (monto >= (0)::numeric))),
    CONSTRAINT operaciones_pagos_array_check CHECK ((jsonb_typeof(pagos) = 'array'::text))
);


ALTER TABLE reciclaje.operaciones OWNER TO postgres;


--
-- Name: ordenes_compra; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.ordenes_compra (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    codigo text NOT NULL,
    socio_id uuid NOT NULL,
    transportista_id uuid NOT NULL,
    estado reciclaje.estado_orden DEFAULT 'borrador'::reciclaje.estado_orden NOT NULL,
    observaciones text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    subtotal numeric(14,2) DEFAULT 0 NOT NULL,
    total numeric(14,2) DEFAULT 0 NOT NULL
);


ALTER TABLE reciclaje.ordenes_compra OWNER TO postgres;


--
-- Name: ordenes_compra_detalle; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.ordenes_compra_detalle (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    orden_compra_id uuid NOT NULL,
    material_id uuid NOT NULL,
    cantidad numeric(14,3) NOT NULL,
    precio_unitario numeric(14,2) NOT NULL,
    subtotal numeric(14,2) NOT NULL,
    observaciones text,
    CONSTRAINT ordenes_compra_detalle_cantidad_check CHECK ((cantidad > (0)::numeric)),
    CONSTRAINT ordenes_compra_detalle_precio_check CHECK ((precio_unitario >= (0)::numeric)),
    CONSTRAINT ordenes_compra_detalle_subtotal_check CHECK ((subtotal >= (0)::numeric))
);


ALTER TABLE reciclaje.ordenes_compra_detalle OWNER TO postgres;


--
-- Name: ordenes_compra_pagos; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.ordenes_compra_pagos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    orden_compra_id uuid NOT NULL,
    forma_pago_id uuid NOT NULL,
    moneda_id uuid NOT NULL,
    monto numeric(14,2) NOT NULL,
    referencia text,
    observaciones text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ordenes_compra_pagos_monto_check CHECK ((monto >= (0)::numeric))
);


ALTER TABLE reciclaje.ordenes_compra_pagos OWNER TO postgres;


--
-- Name: precios_socios; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.precios_socios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    socio_id uuid NOT NULL,
    material_id uuid NOT NULL,
    precio numeric(14,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    observaciones text,
    CONSTRAINT precios_socios_precio_check CHECK ((precio >= (0)::numeric))
);


ALTER TABLE reciclaje.precios_socios OWNER TO postgres;


--
-- Name: recepciones; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.recepciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    codigo text NOT NULL,
    orden_compra_id uuid NOT NULL,
    estado reciclaje.estado_recepcion DEFAULT 'borrador'::reciclaje.estado_recepcion NOT NULL,
    recibido_por text,
    observaciones text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    confirmed_at timestamp with time zone,
    deposito_id uuid
);


ALTER TABLE reciclaje.recepciones OWNER TO postgres;


--
-- Name: recepciones_detalle; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.recepciones_detalle (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recepcion_id uuid NOT NULL,
    material_id uuid NOT NULL,
    cantidad numeric(14,3) NOT NULL,
    precio_unitario numeric(14,2) NOT NULL,
    subtotal numeric(14,2) NOT NULL,
    observaciones text,
    CONSTRAINT recepciones_detalle_cantidad_check CHECK ((cantidad > (0)::numeric)),
    CONSTRAINT recepciones_detalle_precio_check CHECK ((precio_unitario >= (0)::numeric)),
    CONSTRAINT recepciones_detalle_subtotal_check CHECK ((subtotal >= (0)::numeric))
);


ALTER TABLE reciclaje.recepciones_detalle OWNER TO postgres;


--
-- Name: socios; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.socios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    documento text,
    telefono text,
    direccion text,
    observaciones text,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    latitud numeric(10,7),
    longitud numeric(10,7)
);


ALTER TABLE reciclaje.socios OWNER TO postgres;


--
-- Name: transportistas; Type: TABLE; Schema: reciclaje; Owner: postgres
--

CREATE TABLE reciclaje.transportistas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    telefono text,
    placa text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE reciclaje.transportistas OWNER TO postgres;



-- ======================================================
-- FUNCTION
-- ======================================================

--
-- Name: actualizar_deposito(uuid, uuid, text, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.actualizar_deposito(p_company_id uuid, p_id uuid, p_nombre text, p_direccion text) RETURNS reciclaje.depositos
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.actualizar_deposito(p_company_id uuid, p_id uuid, p_nombre text, p_direccion text) OWNER TO postgres;


--
-- Name: actualizar_finanza(uuid, uuid, text, numeric, numeric, text, uuid, timestamp with time zone, text, text, text, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.actualizar_finanza(p_company_id uuid, p_finanza_id uuid, p_tipo text, p_tipo_cambio numeric, p_importe_base numeric, p_origen_tipo text DEFAULT 'manual'::text, p_origen_id uuid DEFAULT NULL::uuid, p_fecha_vencimiento timestamp with time zone DEFAULT NULL::timestamp with time zone, p_observaciones text DEFAULT NULL::text, p_responsable_nombre text DEFAULT NULL::text, p_responsable_telefono text DEFAULT NULL::text, p_responsable_tipo text DEFAULT NULL::text) RETURNS reciclaje.finanzas
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_finanza reciclaje.finanzas;
BEGIN

    UPDATE reciclaje.finanzas
       SET tipo = p_tipo,
           origen_tipo = p_origen_tipo,
           origen_id = p_origen_id,
           fecha_vencimiento = p_fecha_vencimiento,
           tipo_cambio = p_tipo_cambio,
           importe_base = p_importe_base,
           observaciones = p_observaciones,
           responsable_nombre = p_responsable_nombre,
           responsable_telefono = p_responsable_telefono,
           responsable_tipo = p_responsable_tipo
     WHERE id = p_finanza_id
       AND company_id = p_company_id
    RETURNING *
      INTO v_finanza;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Finanza no encontrada.';
    END IF;

    RETURN v_finanza;

END;
$$;


ALTER FUNCTION reciclaje.actualizar_finanza(p_company_id uuid, p_finanza_id uuid, p_tipo text, p_tipo_cambio numeric, p_importe_base numeric, p_origen_tipo text, p_origen_id uuid, p_fecha_vencimiento timestamp with time zone, p_observaciones text, p_responsable_nombre text, p_responsable_telefono text, p_responsable_tipo text) OWNER TO postgres;


--
-- Name: actualizar_material(uuid, uuid, text, text, jsonb, numeric, numeric, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.actualizar_material(p_company_id uuid, p_id uuid, p_nombre text, p_unidad text, p_metadata jsonb, p_precio_base numeric DEFAULT 0, p_precio_mayorista numeric DEFAULT 0, p_imagen_url text DEFAULT NULL::text) RETURNS reciclaje.materiales
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_material reciclaje.materiales;

BEGIN

    IF trim(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    IF trim(p_unidad) = '' THEN
        RAISE EXCEPTION 'La unidad es obligatoria.';
    END IF;

    IF coalesce(p_precio_base, 0) < 0 THEN
        RAISE EXCEPTION 'El precio base no puede ser negativo.';
    END IF;

    IF coalesce(p_precio_mayorista, 0) < 0 THEN
        RAISE EXCEPTION 'El precio mayorista no puede ser negativo.';
    END IF;

    UPDATE reciclaje.materiales

    SET
        nombre = trim(p_nombre),

        unidad = lower(trim(p_unidad)),

        metadata = coalesce(p_metadata, '{}'),

        precio_base = coalesce(p_precio_base, 0),

        precio_mayorista = coalesce(p_precio_mayorista, 0),

        imagen_url = CASE
            WHEN p_imagen_url IS NULL
                THEN imagen_url
            ELSE reciclaje.texto_nulo(p_imagen_url)
        END,

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


ALTER FUNCTION reciclaje.actualizar_material(p_company_id uuid, p_id uuid, p_nombre text, p_unidad text, p_metadata jsonb, p_precio_base numeric, p_precio_mayorista numeric, p_imagen_url text) OWNER TO postgres;


--
-- Name: actualizar_orden_compra(uuid, uuid, jsonb); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.actualizar_orden_compra(p_company_id uuid, p_orden_id uuid, p_orden jsonb) RETURNS reciclaje.ordenes_compra
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.actualizar_orden_compra(p_company_id uuid, p_orden_id uuid, p_orden jsonb) OWNER TO postgres;


--
-- Name: actualizar_recepcion(uuid, uuid, jsonb); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.actualizar_recepcion(p_company_id uuid, p_recepcion_id uuid, p_recepcion jsonb) RETURNS reciclaje.recepciones
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_recepcion reciclaje.recepciones;

    v_material jsonb;

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

    UPDATE reciclaje.recepciones

    SET

        deposito_id =
            nullif(p_recepcion->>'deposito_id', '')::uuid,

        recibido_por = reciclaje.texto_nulo(
            p_recepcion->>'recibido_por'
        ),

        observaciones = reciclaje.texto_nulo(
            p_recepcion->>'observaciones'
        )

    WHERE company_id = p_company_id
      AND id = p_recepcion_id;

    DELETE
    FROM reciclaje.recepciones_detalle
    WHERE recepcion_id = p_recepcion_id;

    FOR v_material IN

        SELECT *
        FROM jsonb_array_elements(
            p_recepcion->'materiales'
        )

    LOOP

        INSERT INTO reciclaje.recepciones_detalle (

            recepcion_id,

            material_id,

            cantidad,

            precio_unitario,

            subtotal,

            observaciones

        )
        VALUES (

            p_recepcion_id,

            (v_material->>'material_id')::uuid,

            (v_material->>'cantidad')::numeric,

            (v_material->>'precio_unitario')::numeric,

            (v_material->>'cantidad')::numeric
            *
            (v_material->>'precio_unitario')::numeric,

            reciclaje.texto_nulo(
                v_material->>'observaciones'
            )

        );

    END LOOP;

    SELECT *
    INTO v_recepcion
    FROM reciclaje.recepciones
    WHERE company_id = p_company_id
      AND id = p_recepcion_id;

    RETURN v_recepcion;

END;
$$;


ALTER FUNCTION reciclaje.actualizar_recepcion(p_company_id uuid, p_recepcion_id uuid, p_recepcion jsonb) OWNER TO postgres;


--
-- Name: actualizar_socio(uuid, uuid, text, text, text, text, text, numeric, numeric); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.actualizar_socio(p_company_id uuid, p_id uuid, p_nombre text, p_documento text DEFAULT NULL::text, p_telefono text DEFAULT NULL::text, p_direccion text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text, p_latitud numeric DEFAULT NULL::numeric, p_longitud numeric DEFAULT NULL::numeric) RETURNS reciclaje.socios
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_socio reciclaje.socios;

BEGIN

    IF trim(coalesce(p_nombre, '')) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    ----------------------------------------------------
    -- Validar coordenadas
    ----------------------------------------------------

    IF p_latitud IS NOT NULL
       AND (p_latitud < -90 OR p_latitud > 90) THEN

        RAISE EXCEPTION
        'La latitud debe estar entre -90 y 90.';

    END IF;

    IF p_longitud IS NOT NULL
       AND (p_longitud < -180 OR p_longitud > 180) THEN

        RAISE EXCEPTION
        'La longitud debe estar entre -180 y 180.';

    END IF;

    ----------------------------------------------------
    -- Actualizar
    ----------------------------------------------------

    UPDATE reciclaje.socios

    SET
        nombre = trim(p_nombre),

        documento =
            reciclaje.texto_nulo(p_documento),

        telefono =
            reciclaje.texto_nulo(p_telefono),

        direccion =
            reciclaje.texto_nulo(p_direccion),

        observaciones =
            reciclaje.texto_nulo(p_observaciones),

        latitud = p_latitud,

        longitud = p_longitud,

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


ALTER FUNCTION reciclaje.actualizar_socio(p_company_id uuid, p_id uuid, p_nombre text, p_documento text, p_telefono text, p_direccion text, p_observaciones text, p_latitud numeric, p_longitud numeric) OWNER TO postgres;


--
-- Name: actualizar_stock_material(uuid, uuid, numeric); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.actualizar_stock_material(p_company_id uuid, p_material_id uuid, p_cantidad numeric) RETURNS reciclaje.materiales
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.actualizar_stock_material(p_company_id uuid, p_material_id uuid, p_cantidad numeric) OWNER TO postgres;


--
-- Name: actualizar_transportista(uuid, uuid, text, text, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.actualizar_transportista(p_company_id uuid, p_id uuid, p_nombre text, p_telefono text, p_placa text) RETURNS reciclaje.transportistas
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.actualizar_transportista(p_company_id uuid, p_id uuid, p_nombre text, p_telefono text, p_placa text) OWNER TO postgres;


--
-- Name: anular_finanza(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.anular_finanza(p_company_id uuid, p_finanza_id uuid) RETURNS reciclaje.finanzas
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_finanza reciclaje.finanzas;
BEGIN

    UPDATE reciclaje.finanzas
       SET anulado = true
     WHERE id = p_finanza_id
       AND company_id = p_company_id
       AND anulado = false
    RETURNING *
      INTO v_finanza;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Finanza no encontrada o ya anulada.';
    END IF;

    RETURN v_finanza;

END;
$$;


ALTER FUNCTION reciclaje.anular_finanza(p_company_id uuid, p_finanza_id uuid) OWNER TO postgres;


--
-- Name: bootstrap(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE OR REPLACE FUNCTION reciclaje.bootstrap(p_company_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT jsonb_build_object(

    ----------------------------------------------------
    -- Monedas
    ----------------------------------------------------

    'monedas',

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', m.id,
                    'codigo', m.codigo,
                    'nombre', m.nombre,
                    'simbolo', m.simbolo
                )
                ORDER BY m.nombre
            )
            FROM reciclaje.monedas m
            WHERE m.activo = true
        ),
        '[]'::jsonb
    ),

    ----------------------------------------------------
    -- Formas de pago
    ----------------------------------------------------

    'formas_pago',

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', fp.id,
                    'codigo', fp.codigo,
                    'nombre', fp.nombre
                )
                ORDER BY fp.nombre
            )
            FROM reciclaje.formas_pago fp
            WHERE fp.activo = true
        ),
        '[]'::jsonb
    ),

    ----------------------------------------------------
    -- Materiales
    ----------------------------------------------------

    'materiales',

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', m.id,
                    'codigo', m.codigo,
                    'nombre', m.nombre,
                    'unidad', m.unidad,
                    'stock', m.stock,
                    'compuesto', m.compuesto,
                    'precio_base', m.precio_base,
                    'precio_mayorista', m.precio_mayorista,
                    'imagen_url', m.imagen_url
                )
                ORDER BY m.nombre
            )
            FROM reciclaje.listar_materiales(p_company_id) m
        ),
        '[]'::jsonb
    ),

    ----------------------------------------------------
    -- Socios
    ----------------------------------------------------

    'socios',

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', s.id,
                    'codigo', s.codigo,
                    'nombre', s.nombre,
                    'direccion', s.direccion,
                    'latitud', s.latitud,
                    'longitud', s.longitud
                )
                ORDER BY s.nombre
            )
            FROM reciclaje.listar_socios(p_company_id) s
        ),
        '[]'::jsonb
    ),

    ----------------------------------------------------
    -- Transportistas
    ----------------------------------------------------

    'transportistas',

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', t.id,
                    'codigo', t.codigo,
                    'nombre', t.nombre,
                    'placa', t.placa
                )
                ORDER BY t.nombre
            )
            FROM reciclaje.listar_transportistas(p_company_id) t
        ),
        '[]'::jsonb
    ),

    ----------------------------------------------------
    -- Depósitos
    ----------------------------------------------------

    'depositos',

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', d.id,
                    'codigo', d.codigo,
                    'nombre', d.nombre
                )
                ORDER BY d.nombre
            )
            FROM reciclaje.listar_depositos(p_company_id) d
        ),
        '[]'::jsonb
    ),

    ----------------------------------------------------
    -- ENUMS LEGADOS
    ----------------------------------------------------

    'estados_orden',
    reciclaje.enum_to_json('estado_orden'),

    'estados_recepcion',
    reciclaje.enum_to_json('estado_recepcion'),

    'tipos_movimiento',
    reciclaje.enum_to_json('tipo_movimiento'),

    ----------------------------------------------------
    -- ENUMS OPERACIONES / PIPELINE
    ----------------------------------------------------

    'tipos_operacion',
    reciclaje.enum_to_json('tipo_operacion'),

    'etapas_operacion',
    reciclaje.enum_to_json('etapa_operacion')

);

$$;


ALTER FUNCTION reciclaje.bootstrap(p_company_id uuid) OWNER TO postgres;


--
-- Name: cancelar_recepcion(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.cancelar_recepcion(p_company_id uuid, p_recepcion_id uuid) RETURNS reciclaje.recepciones
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.cancelar_recepcion(p_company_id uuid, p_recepcion_id uuid) OWNER TO postgres;


--
-- Name: confirmar_operacion(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.confirmar_operacion(p_company_id uuid, p_operacion_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_operacion reciclaje.operaciones;

    v_orden reciclaje.ordenes_compra;

    v_recepcion reciclaje.recepciones;

    v_orden_json jsonb;

    v_recepcion_json jsonb;

BEGIN

    ------------------------------------------------------------
    -- 1. BLOQUEAR OPERACIÓN
    ------------------------------------------------------------

    SELECT *
    INTO v_operacion
    FROM reciclaje.operaciones
    WHERE company_id = p_company_id
      AND id = p_operacion_id
    FOR UPDATE;


    IF NOT FOUND THEN

        RAISE EXCEPTION
            'La operación no existe.';

    END IF;


    ------------------------------------------------------------
    -- 2. IDEMPOTENCIA
    ------------------------------------------------------------

    IF v_operacion.finalizada = true THEN

        RETURN jsonb_build_object(

            'ok', true,

            'ya_finalizada', true,

            'operacion_id', v_operacion.id,

            'orden_compra_id',
                v_operacion.orden_compra_id,

            'recepcion_id',
                v_operacion.recepcion_id,

            'finanza_id',
                v_operacion.finanza_id

        );

    END IF;


    ------------------------------------------------------------
    -- VALIDAR OPERACIÓN COMPLETA
    ------------------------------------------------------------

    IF v_operacion.socio_id IS NULL THEN

        RAISE EXCEPTION
            'Debe indicar el socio.';

    END IF;


    IF v_operacion.transportista_id IS NULL THEN

        RAISE EXCEPTION
            'Debe indicar el transportista.';

    END IF;


    IF v_operacion.deposito_id IS NULL THEN

        RAISE EXCEPTION
            'Debe indicar el depósito de recepción.';

    END IF;


    IF v_operacion.monto IS NULL THEN

        RAISE EXCEPTION
            'Debe indicar el monto definitivo de la compra.';

    END IF;


    IF jsonb_array_length(
        COALESCE(
            v_operacion.materiales,
            '[]'::jsonb
        )
    ) = 0 THEN

        RAISE EXCEPTION
            'Debe indicar al menos un material.';

    END IF;


    IF jsonb_array_length(
        COALESCE(
            v_operacion.pagos,
            '[]'::jsonb
        )
    ) = 0 THEN

        RAISE EXCEPTION
            'Debe indicar al menos un pago.';

    END IF;


    ------------------------------------------------------------
    -- CONSTRUIR ORDEN
    ------------------------------------------------------------

    v_orden_json :=
        jsonb_build_object(

            'socio_id',
                v_operacion.socio_id,

            'transportista_id',
                v_operacion.transportista_id,

            'materiales',
                v_operacion.materiales,

            'pagos',
                v_operacion.pagos,

            'observaciones',
                v_operacion.observaciones

        );


    ------------------------------------------------------------
    -- CREAR ORDEN
    ------------------------------------------------------------

    SELECT *
    INTO v_orden
    FROM reciclaje.crear_orden_compra(
        p_company_id,
        v_orden_json
    );


    ------------------------------------------------------------
    -- FIJAR MONTO DEFINITIVO
    ------------------------------------------------------------

    UPDATE reciclaje.ordenes_compra

    SET
        total = v_operacion.monto,
        updated_at = now()

    WHERE company_id = p_company_id
      AND id = v_orden.id

    RETURNING *
    INTO v_orden;


    ------------------------------------------------------------
    -- CREAR RECEPCIÓN
    ------------------------------------------------------------

    SELECT *
    INTO v_recepcion
    FROM reciclaje.crear_recepcion(

        p_company_id,

        v_orden.id,

        v_operacion.recibido_por,

        v_operacion.observaciones

    );


    ------------------------------------------------------------
    -- COMPLETAR RECEPCIÓN
    ------------------------------------------------------------

    v_recepcion_json :=
        jsonb_build_object(

            'deposito_id',
                v_operacion.deposito_id,

            'recibido_por',
                v_operacion.recibido_por,

            'observaciones',
                v_operacion.observaciones,

            'materiales',
                v_operacion.materiales

        );


    SELECT *
    INTO v_recepcion
    FROM reciclaje.actualizar_recepcion(

        p_company_id,

        v_recepcion.id,

        v_recepcion_json

    );


    ------------------------------------------------------------
    -- CONFIRMAR RECEPCIÓN
    ------------------------------------------------------------

    SELECT *
    INTO v_recepcion
    FROM reciclaje.confirmar_recepcion(

        p_company_id,

        v_recepcion.id

    );


    ------------------------------------------------------------
    -- CERRAR OPERACIÓN
    ------------------------------------------------------------

    UPDATE reciclaje.operaciones

    SET

        tipo =
            'compra'::reciclaje.tipo_operacion,

        etapa =
            'finalizada'::reciclaje.etapa_operacion,

        orden_compra_id =
            v_orden.id,

        recepcion_id =
            v_recepcion.id,

        finalizada =
            true,

        finalizada_at =
            now(),

        updated_at =
            now()

    WHERE company_id = p_company_id
      AND id = p_operacion_id

    RETURNING *
    INTO v_operacion;


    ------------------------------------------------------------
    -- RESPUESTA
    ------------------------------------------------------------

    RETURN jsonb_build_object(

        'ok', true,

        'operacion_id',
            v_operacion.id,

        'monto',
            v_operacion.monto,

        'orden_compra',
            jsonb_build_object(

                'id',
                    v_orden.id,

                'subtotal',
                    v_orden.subtotal,

                'total',
                    v_orden.total,

                'estado',
                    v_orden.estado

            ),

        'recepcion',
            jsonb_build_object(

                'id',
                    v_recepcion.id,

                'estado',
                    v_recepcion.estado,

                'deposito_id',
                    v_recepcion.deposito_id,

                'confirmed_at',
                    v_recepcion.confirmed_at

            )

    );

END;
$$;


ALTER FUNCTION reciclaje.confirmar_operacion(p_company_id uuid, p_operacion_id uuid) OWNER TO postgres;


--
-- Name: confirmar_operaciones_transportista(uuid, uuid, jsonb); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.confirmar_operaciones_transportista(p_company_id uuid, p_transportista_id uuid, p_datos jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    ------------------------------------------------------------
    -- DATOS GENERALES
    ------------------------------------------------------------

    v_deposito_id uuid;

    v_movimiento_grupo_id uuid :=
        gen_random_uuid();

    v_operacion reciclaje.operaciones;

    v_orden reciclaje.ordenes_compra;

    v_recepcion reciclaje.recepciones;

    v_orden_json jsonb;

    v_recepcion_json jsonb;

    v_item jsonb;

    v_material_id uuid;

    v_cantidad numeric(14,3);

    v_cantidad_operaciones integer := 0;

    v_cantidad_materiales integer := 0;

    v_resultados jsonb := '[]'::jsonb;


    ------------------------------------------------------------
    -- COMPATIBILIDAD CON PAGOS DEL MODELO ANTERIOR
    ------------------------------------------------------------

    v_pagos_orden jsonb;

    v_forma_pago_id uuid;

    v_moneda_id uuid;

BEGIN

    ------------------------------------------------------------
    -- 1. VALIDACIONES GENERALES
    ------------------------------------------------------------

    IF p_transportista_id IS NULL THEN

        RAISE EXCEPTION
            'Debe indicar el transportista.';

    END IF;


    IF NOT EXISTS (

        SELECT 1
        FROM reciclaje.transportistas

        WHERE company_id = p_company_id
          AND id = p_transportista_id
          AND activo = true

    ) THEN

        RAISE EXCEPTION
            'El transportista no existe o está inactivo.';

    END IF;


    ------------------------------------------------------------
    -- 2. DEPÓSITO
    ------------------------------------------------------------

    v_deposito_id :=
        NULLIF(
            p_datos->>'deposito_id',
            ''
        )::uuid;


    IF v_deposito_id IS NULL THEN

        RAISE EXCEPTION
            'Debe indicar el depósito.';

    END IF;


    IF NOT EXISTS (

        SELECT 1
        FROM reciclaje.depositos

        WHERE company_id = p_company_id
          AND id = v_deposito_id
          AND activo = true

    ) THEN

        RAISE EXCEPTION
            'El depósito no existe o está inactivo.';

    END IF;


    ------------------------------------------------------------
    -- 3. VALIDAR INVENTARIO
    ------------------------------------------------------------

    IF jsonb_typeof(
        COALESCE(
            p_datos->'inventario',
            '[]'::jsonb
        )
    ) <> 'array'
    THEN

        RAISE EXCEPTION
            'inventario debe ser un array.';

    END IF;


    IF jsonb_array_length(
        COALESCE(
            p_datos->'inventario',
            '[]'::jsonb
        )
    ) = 0
    THEN

        RAISE EXCEPTION
            'Debe indicar el inventario físico recibido.';

    END IF;


    ------------------------------------------------------------
    -- 4. RESOLVER MONEDA ARS PARA PAGO TÉCNICO
    ------------------------------------------------------------

    SELECT id
    INTO v_moneda_id
    FROM reciclaje.monedas
    WHERE codigo = 'ARS'
      AND activo = true
    LIMIT 1;


    IF v_moneda_id IS NULL THEN

        RAISE EXCEPTION
            'No existe una moneda ARS activa para generar el pago técnico.';

    END IF;


    ------------------------------------------------------------
    -- 5. RESOLVER FORMA DE PAGO PARA COMPATIBILIDAD
    --
    -- Preferimos "pendiente".
    -- Si no existe, usamos una forma de pago activa disponible.
    ------------------------------------------------------------

    SELECT id
    INTO v_forma_pago_id
    FROM reciclaje.formas_pago
    WHERE codigo = 'pendiente'
      AND activo = true
    LIMIT 1;


    IF v_forma_pago_id IS NULL THEN

        SELECT id
        INTO v_forma_pago_id
        FROM reciclaje.formas_pago
        WHERE activo = true
        ORDER BY created_at, id
        LIMIT 1;

    END IF;


    IF v_forma_pago_id IS NULL THEN

        RAISE EXCEPTION
            'No existe una forma de pago activa para generar el pago técnico.';

    END IF;


    ------------------------------------------------------------
    -- 6. BLOQUEAR TODAS LAS OPERACIONES DEL TRANSPORTISTA
    ------------------------------------------------------------

    PERFORM o.id

    FROM reciclaje.operaciones o

    WHERE o.company_id = p_company_id

      AND o.transportista_id =
          p_transportista_id

      AND o.etapa =
          'en_proceso'::reciclaje.etapa_operacion

      AND COALESCE(
          o.finalizada,
          false
      ) = false

    ORDER BY o.id

    FOR UPDATE;


    ------------------------------------------------------------
    -- 7. VERIFICAR QUE HAYA OPERACIONES
    ------------------------------------------------------------

    SELECT COUNT(*)

    INTO v_cantidad_operaciones

    FROM reciclaje.operaciones o

    WHERE o.company_id = p_company_id

      AND o.transportista_id =
          p_transportista_id

      AND o.etapa =
          'en_proceso'::reciclaje.etapa_operacion

      AND COALESCE(
          o.finalizada,
          false
      ) = false;


    IF v_cantidad_operaciones = 0 THEN

        RAISE EXCEPTION
            'El transportista no tiene operaciones en proceso.';

    END IF;


    ------------------------------------------------------------
    -- 8. VALIDAR INVENTARIO FÍSICO ANTES DE CREAR NADA
    ------------------------------------------------------------

    FOR v_item IN

        SELECT value
        FROM jsonb_array_elements(
            p_datos->'inventario'
        )

    LOOP

        v_material_id :=
            NULLIF(
                v_item->>'material_id',
                ''
            )::uuid;


        v_cantidad :=
            NULLIF(
                v_item->>'cantidad',
                ''
            )::numeric;


        IF v_material_id IS NULL THEN

            RAISE EXCEPTION
                'Todos los movimientos de inventario deben indicar material_id.';

        END IF;


        IF v_cantidad IS NULL THEN

            RAISE EXCEPTION
                'Todos los movimientos de inventario deben indicar cantidad.';

        END IF;


        IF v_cantidad < 0 THEN

            RAISE EXCEPTION
                'La cantidad física recibida no puede ser negativa.';

        END IF;


        IF NOT EXISTS (

            SELECT 1

            FROM reciclaje.materiales m

            WHERE m.company_id = p_company_id
              AND m.id = v_material_id
              AND m.activo = true

        ) THEN

            RAISE EXCEPTION
                'Uno de los materiales enviados no existe o está inactivo.';

        END IF;


        --------------------------------------------------------
        -- EL MATERIAL DEBE EXISTIR EN ALGUNA OPERACIÓN
        --------------------------------------------------------

        IF NOT EXISTS (

            SELECT 1

            FROM reciclaje.operaciones o

            CROSS JOIN LATERAL
                jsonb_array_elements(
                    COALESCE(
                        o.materiales,
                        '[]'::jsonb
                    )
                ) AS mat

            WHERE o.company_id = p_company_id

              AND o.transportista_id =
                  p_transportista_id

              AND o.etapa =
                  'en_proceso'::reciclaje.etapa_operacion

              AND COALESCE(
                  o.finalizada,
                  false
              ) = false

              AND NULLIF(
                    mat->>'material_id',
                    ''
                  )::uuid = v_material_id

        ) THEN

            RAISE EXCEPTION
                'El inventario contiene un material que no pertenece a las operaciones del transportista.';

        END IF;

    END LOOP;


    ------------------------------------------------------------
    -- 9. EVITAR MATERIALES REPETIDOS EN INVENTARIO
    ------------------------------------------------------------

    IF EXISTS (

        SELECT 1

        FROM (

            SELECT
                NULLIF(
                    value->>'material_id',
                    ''
                )::uuid AS material_id,

                COUNT(*) AS cantidad

            FROM jsonb_array_elements(
                p_datos->'inventario'
            )

            GROUP BY
                NULLIF(
                    value->>'material_id',
                    ''
                )::uuid

            HAVING COUNT(*) > 1

        ) duplicados

    ) THEN

        RAISE EXCEPTION
            'El inventario debe estar consolidado: cada material puede aparecer una sola vez.';

    END IF;


    ------------------------------------------------------------
    -- 10. PROCESAR CADA OPERACIÓN COMERCIAL INDIVIDUALMENTE
    ------------------------------------------------------------

    FOR v_operacion IN

        SELECT *

        FROM reciclaje.operaciones

        WHERE company_id = p_company_id

          AND transportista_id =
              p_transportista_id

          AND etapa =
              'en_proceso'::reciclaje.etapa_operacion

          AND COALESCE(
              finalizada,
              false
          ) = false

        ORDER BY created_at, id

    LOOP

        --------------------------------------------------------
        -- VALIDACIONES COMERCIALES
        --------------------------------------------------------

        IF v_operacion.tipo <>
           'compra'::reciclaje.tipo_operacion
        THEN

            RAISE EXCEPTION
                'La confirmación múltiple solo admite operaciones de compra.';

        END IF;


        IF v_operacion.socio_id IS NULL THEN

            RAISE EXCEPTION
                'Una operación no tiene socio.';

        END IF;


        IF v_operacion.monto IS NULL THEN

            RAISE EXCEPTION
                'Una operación no tiene monto definitivo.';

        END IF;


        IF v_operacion.monto < 0 THEN

            RAISE EXCEPTION
                'Una operación tiene un monto definitivo inválido.';

        END IF;


        IF jsonb_array_length(
            COALESCE(
                v_operacion.materiales,
                '[]'::jsonb
            )
        ) = 0
        THEN

            RAISE EXCEPTION
                'Una operación no contiene materiales.';

        END IF;


        --------------------------------------------------------
        -- 11. COMPATIBILIDAD DE PAGOS
        --
        -- Si la operación ya tiene pagos, se respetan.
        --
        -- Si no tiene pagos, creamos uno técnico por exactamente
        -- el mismo monto definitivo de la operación.
        --
        -- Esto permite reutilizar crear_orden_compra() sin
        -- obligar al frontend nuevo a manejar pagos.
        --------------------------------------------------------

        IF jsonb_array_length(
            COALESCE(
                v_operacion.pagos,
                '[]'::jsonb
            )
        ) > 0
        THEN

            v_pagos_orden :=
                v_operacion.pagos;

        ELSE

            v_pagos_orden :=
                jsonb_build_array(

                    jsonb_build_object(

                        'forma_pago_id',
                            v_forma_pago_id,

                        'moneda_id',
                            v_moneda_id,

                        'monto',
                            v_operacion.monto,

                        'referencia',
                            NULL,

                        'observaciones',
                            'Pago técnico generado automáticamente al confirmar la operación'

                    )

                );

        END IF;


        --------------------------------------------------------
        -- 12. CONSTRUIR ORDEN DE ESTA OPERACIÓN
        --------------------------------------------------------

        v_orden_json :=
            jsonb_build_object(

                'socio_id',
                    v_operacion.socio_id,

                'transportista_id',
                    p_transportista_id,

                'materiales',
                    v_operacion.materiales,

                'pagos',
                    v_pagos_orden,

                'observaciones',
                    v_operacion.observaciones

            );


        --------------------------------------------------------
        -- 13. CREAR ORDEN
        --------------------------------------------------------

        SELECT *

        INTO v_orden

        FROM reciclaje.crear_orden_compra(

            p_company_id,

            v_orden_json

        );


        --------------------------------------------------------
        -- 14. FIJAR MONTO ACORDADO
        --------------------------------------------------------

        UPDATE reciclaje.ordenes_compra

        SET

            total =
                v_operacion.monto,

            updated_at =
                now()

        WHERE company_id = p_company_id
          AND id = v_orden.id

        RETURNING *

        INTO v_orden;


        --------------------------------------------------------
        -- 15. CREAR RECEPCIÓN INDIVIDUAL
        --------------------------------------------------------

        SELECT *

        INTO v_recepcion

        FROM reciclaje.crear_recepcion(

            p_company_id,

            v_orden.id,

            v_operacion.recibido_por,

            v_operacion.observaciones

        );


        --------------------------------------------------------
        -- 16. COMPLETAR RECEPCIÓN
        --
        -- Conservamos materiales COMERCIALES de la operación.
        -- El inventario físico se procesa después por separado.
        --------------------------------------------------------

        v_recepcion_json :=
            jsonb_build_object(

                'deposito_id',
                    v_deposito_id,

                'recibido_por',
                    v_operacion.recibido_por,

                'observaciones',
                    v_operacion.observaciones,

                'materiales',
                    v_operacion.materiales

            );


        SELECT *

        INTO v_recepcion

        FROM reciclaje.actualizar_recepcion(

            p_company_id,

            v_recepcion.id,

            v_recepcion_json

        );


        --------------------------------------------------------
        -- 17. CONFIRMAR DOCUMENTALMENTE RECEPCIÓN
        --
        -- NO llamar confirmar_recepcion().
        -- Esa función ingresaría al stock la cantidad comercial.
        --------------------------------------------------------

        UPDATE reciclaje.recepciones

        SET

            estado =
                'confirmada',

            confirmed_at =
                now()

        WHERE company_id = p_company_id
          AND id = v_recepcion.id

        RETURNING *

        INTO v_recepcion;


        --------------------------------------------------------
        -- 18. ORDEN = RECIBIDA
        --
        -- ENUM CORRECTO:
        -- estado_orden = 'recibida'
        --------------------------------------------------------

        UPDATE reciclaje.ordenes_compra

        SET

            estado =
                'recibida'::reciclaje.estado_orden,

            updated_at =
                now()

        WHERE company_id = p_company_id
          AND id = v_orden.id

        RETURNING *

        INTO v_orden;


        --------------------------------------------------------
        -- 19. CERRAR ESTA OPERACIÓN
        --
        -- ENUM CORRECTO:
        -- etapa_operacion = 'finalizada'
        --------------------------------------------------------

        UPDATE reciclaje.operaciones

        SET

            tipo =
                'compra'::reciclaje.tipo_operacion,

            etapa =
                'finalizada'::reciclaje.etapa_operacion,

            deposito_id =
                v_deposito_id,

            orden_compra_id =
                v_orden.id,

            recepcion_id =
                v_recepcion.id,

            finalizada =
                true,

            finalizada_at =
                now(),

            updated_at =
                now()

        WHERE company_id = p_company_id
          AND id = v_operacion.id;


        --------------------------------------------------------
        -- 20. ACUMULAR RESULTADO
        --------------------------------------------------------

        v_resultados :=
            v_resultados
            ||
            jsonb_build_array(

                jsonb_build_object(

                    'operacion_id',
                        v_operacion.id,

                    'socio_id',
                        v_operacion.socio_id,

                    'orden_compra_id',
                        v_orden.id,

                    'recepcion_id',
                        v_recepcion.id,

                    'monto',
                        v_operacion.monto

                )

            );

    END LOOP;


    ------------------------------------------------------------
    -- 21. INVENTARIO FÍSICO REAL
    --
    -- UNA SOLA VEZ por material consolidado.
    ------------------------------------------------------------

    FOR v_item IN

        SELECT value

        FROM jsonb_array_elements(
            p_datos->'inventario'
        )

    LOOP

        v_material_id :=
            NULLIF(
                v_item->>'material_id',
                ''
            )::uuid;


        v_cantidad :=
            NULLIF(
                v_item->>'cantidad',
                ''
            )::numeric;


        --------------------------------------------------------
        -- CANTIDAD 0 ES VÁLIDA
        --------------------------------------------------------

        IF v_cantidad > 0 THEN

            ----------------------------------------------------
            -- STOCK GLOBAL
            ----------------------------------------------------

            UPDATE reciclaje.materiales

            SET

                stock =
                    stock + v_cantidad,

                updated_at =
                    now()

            WHERE company_id = p_company_id
              AND id = v_material_id;


            ----------------------------------------------------
            -- MOVIMIENTO DE INVENTARIO CONSOLIDADO
            ----------------------------------------------------

            INSERT INTO reciclaje.movimientos_stock (

                company_id,

                deposito_id,

                material_id,

                tipo_movimiento,

                cantidad,

                origen,

                origen_id,

                socio_id,

                transportista_id,

                orden_compra_id,

                recepcion_id,

                observaciones,

                movimiento_grupo_id

            )

            VALUES (

                p_company_id,

                v_deposito_id,

                v_material_id,

                'entrada',

                v_cantidad,

                'recepcion_multicarga',

                v_movimiento_grupo_id,

                NULL,

                p_transportista_id,

                NULL,

                NULL,

                'Entrada física consolidada de operaciones del transportista',

                v_movimiento_grupo_id

            );


            v_cantidad_materiales :=
                v_cantidad_materiales + 1;

        END IF;

    END LOOP;


    ------------------------------------------------------------
    -- 22. RESPUESTA
    ------------------------------------------------------------

    RETURN jsonb_build_object(

        'ok',
            true,

        'transportista_id',
            p_transportista_id,

        'deposito_id',
            v_deposito_id,

        'movimiento_grupo_id',
            v_movimiento_grupo_id,

        'operaciones_confirmadas',
            v_cantidad_operaciones,

        'materiales_ingresados',
            v_cantidad_materiales,

        'operaciones',
            v_resultados,

        'inventario',
            p_datos->'inventario'

    );

END;
$$;


ALTER FUNCTION reciclaje.confirmar_operaciones_transportista(p_company_id uuid, p_transportista_id uuid, p_datos jsonb) OWNER TO postgres;


--
-- Name: confirmar_recepcion(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.confirmar_recepcion(p_company_id uuid, p_recepcion_id uuid) RETURNS reciclaje.recepciones
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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

    WHERE company_id = p_company_id
      AND id = v_recepcion.orden_compra_id;

    ----------------------------------------------------
    -- Actualizar stock y movimientos
    ----------------------------------------------------

    FOR v_detalle IN

        SELECT *
        FROM reciclaje.recepciones_detalle
        WHERE recepcion_id = p_recepcion_id

    LOOP

        ------------------------------------------------
        -- Stock global actual
        ------------------------------------------------

        UPDATE reciclaje.materiales

        SET
            stock = stock + v_detalle.cantidad,
            updated_at = now()

        WHERE company_id = p_company_id
          AND id = v_detalle.material_id;

        ------------------------------------------------
        -- Movimiento de inventario
        ------------------------------------------------

        INSERT INTO reciclaje.movimientos_stock(

            company_id,

            deposito_id,

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

            v_recepcion.deposito_id,

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

    WHERE company_id = p_company_id
      AND id = p_recepcion_id;

    ----------------------------------------------------
    -- Actualizar orden
    ----------------------------------------------------

    UPDATE reciclaje.ordenes_compra

    SET
        estado = 'recibida',
        updated_at = now()

    WHERE company_id = p_company_id
      AND id = v_recepcion.orden_compra_id;

    ----------------------------------------------------
    -- Resultado
    ----------------------------------------------------

    SELECT *
    INTO v_recepcion
    FROM reciclaje.recepciones
    WHERE company_id = p_company_id
      AND id = p_recepcion_id;

    RETURN v_recepcion;

END;
$$;


ALTER FUNCTION reciclaje.confirmar_recepcion(p_company_id uuid, p_recepcion_id uuid) OWNER TO postgres;


--
-- Name: crear_deposito(uuid, text, text, boolean); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.crear_deposito(p_company_id uuid, p_nombre text, p_direccion text DEFAULT NULL::text, p_activo boolean DEFAULT true) RETURNS reciclaje.depositos
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.crear_deposito(p_company_id uuid, p_nombre text, p_direccion text, p_activo boolean) OWNER TO postgres;


--
-- Name: crear_finanza(uuid, text, numeric, numeric, text, uuid, timestamp with time zone, text, text, text, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.crear_finanza(p_company_id uuid, p_tipo text, p_tipo_cambio numeric, p_importe_base numeric, p_origen_tipo text DEFAULT 'manual'::text, p_origen_id uuid DEFAULT NULL::uuid, p_fecha_vencimiento timestamp with time zone DEFAULT NULL::timestamp with time zone, p_observaciones text DEFAULT NULL::text, p_responsable_nombre text DEFAULT NULL::text, p_responsable_telefono text DEFAULT NULL::text, p_responsable_tipo text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id uuid;
BEGIN

    INSERT INTO reciclaje.finanzas (
        company_id,
        tipo,
        origen_tipo,
        origen_id,
        fecha_vencimiento,
        tipo_cambio,
        importe_base,
        observaciones,
        responsable_nombre,
        responsable_telefono,
        responsable_tipo
    )
    VALUES (
        p_company_id,
        p_tipo,
        p_origen_tipo,
        p_origen_id,
        p_fecha_vencimiento,
        p_tipo_cambio,
        p_importe_base,
        p_observaciones,
        p_responsable_nombre,
        p_responsable_telefono,
        p_responsable_tipo
    )
    RETURNING id
    INTO v_id;

    RETURN v_id;

END;
$$;


ALTER FUNCTION reciclaje.crear_finanza(p_company_id uuid, p_tipo text, p_tipo_cambio numeric, p_importe_base numeric, p_origen_tipo text, p_origen_id uuid, p_fecha_vencimiento timestamp with time zone, p_observaciones text, p_responsable_nombre text, p_responsable_telefono text, p_responsable_tipo text) OWNER TO postgres;


--
-- Name: crear_material(uuid, text, text, jsonb, numeric, numeric, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.crear_material(p_company_id uuid, p_nombre text, p_unidad text DEFAULT 'kg'::text, p_metadata jsonb DEFAULT '{}'::jsonb, p_precio_base numeric DEFAULT 0, p_precio_mayorista numeric DEFAULT 0, p_imagen_url text DEFAULT NULL::text) RETURNS reciclaje.materiales
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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

    IF coalesce(p_precio_base, 0) < 0 THEN
        RAISE EXCEPTION 'El precio base no puede ser negativo.';
    END IF;

    IF coalesce(p_precio_mayorista, 0) < 0 THEN
        RAISE EXCEPTION 'El precio mayorista no puede ser negativo.';
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
        metadata,
        precio_base,
        precio_mayorista,
        imagen_url

    )
    VALUES (

        p_company_id,
        v_codigo,
        trim(p_nombre),
        lower(trim(p_unidad)),
        coalesce(p_metadata, '{}'),
        coalesce(p_precio_base, 0),
        coalesce(p_precio_mayorista, 0),
        reciclaje.texto_nulo(p_imagen_url)

    )
    RETURNING *
    INTO v_material;

    RETURN v_material;

END;
$$;


ALTER FUNCTION reciclaje.crear_material(p_company_id uuid, p_nombre text, p_unidad text, p_metadata jsonb, p_precio_base numeric, p_precio_mayorista numeric, p_imagen_url text) OWNER TO postgres;


--
-- Name: crear_orden_compra(uuid, jsonb); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.crear_orden_compra(p_company_id uuid, p_orden jsonb) RETURNS reciclaje.ordenes_compra
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.crear_orden_compra(p_company_id uuid, p_orden jsonb) OWNER TO postgres;


--
-- Name: crear_recepcion(uuid, uuid, text, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.crear_recepcion(p_company_id uuid, p_orden_compra_id uuid, p_recibido_por text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text) RETURNS reciclaje.recepciones
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_codigo text;

    v_recepcion reciclaje.recepciones;

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
        RAISE EXCEPTION 'La orden ya fue enviada a recepción.';
    END IF;

    IF NOT EXISTS (

        SELECT 1
        FROM reciclaje.ordenes_compra_detalle
        WHERE orden_compra_id = p_orden_compra_id

    ) THEN

        RAISE EXCEPTION
        'La orden de compra no contiene materiales.';

    END IF;

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

    v_codigo := reciclaje.generar_codigo(
        p_company_id,
        'REC'
    );

    INSERT INTO reciclaje.recepciones (

        company_id,

        codigo,

        orden_compra_id,

        estado,

        recibido_por,

        observaciones

    )
    VALUES (

        p_company_id,

        v_codigo,

        p_orden_compra_id,

        'borrador',

        reciclaje.texto_nulo(p_recibido_por),

        reciclaje.texto_nulo(p_observaciones)

    )
    RETURNING *
    INTO v_recepcion;

    INSERT INTO reciclaje.recepciones_detalle (

        recepcion_id,

        material_id,

        cantidad,

        precio_unitario,

        subtotal,

        observaciones

    )
    SELECT

        v_recepcion.id,

        material_id,

        cantidad,

        precio_unitario,

        subtotal,

        observaciones

    FROM reciclaje.ordenes_compra_detalle

    WHERE orden_compra_id = p_orden_compra_id;

    UPDATE reciclaje.ordenes_compra

    SET
        estado = 'en_ruta',
        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_orden_compra_id;

    RETURN v_recepcion;

END;
$$;


ALTER FUNCTION reciclaje.crear_recepcion(p_company_id uuid, p_orden_compra_id uuid, p_recibido_por text, p_observaciones text) OWNER TO postgres;


--
-- Name: crear_socio(uuid, text, text, text, text, text, numeric, numeric); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.crear_socio(p_company_id uuid, p_nombre text, p_documento text DEFAULT NULL::text, p_telefono text DEFAULT NULL::text, p_direccion text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text, p_latitud numeric DEFAULT NULL::numeric, p_longitud numeric DEFAULT NULL::numeric) RETURNS reciclaje.socios
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_codigo text;
    v_socio reciclaje.socios;

BEGIN

    IF trim(coalesce(p_nombre, '')) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    ----------------------------------------------------
    -- Validar coordenadas
    ----------------------------------------------------

    IF p_latitud IS NOT NULL
       AND (p_latitud < -90 OR p_latitud > 90) THEN

        RAISE EXCEPTION
        'La latitud debe estar entre -90 y 90.';

    END IF;

    IF p_longitud IS NOT NULL
       AND (p_longitud < -180 OR p_longitud > 180) THEN

        RAISE EXCEPTION
        'La longitud debe estar entre -180 y 180.';

    END IF;

    ----------------------------------------------------
    -- Generar código
    ----------------------------------------------------

    v_codigo := reciclaje.generar_codigo(
        p_company_id,
        'SOC'
    );

    ----------------------------------------------------
    -- Crear socio
    ----------------------------------------------------

    INSERT INTO reciclaje.socios (

        company_id,
        codigo,
        nombre,
        documento,
        telefono,
        direccion,
        observaciones,
        latitud,
        longitud

    )
    VALUES (

        p_company_id,
        v_codigo,
        trim(p_nombre),

        reciclaje.texto_nulo(p_documento),
        reciclaje.texto_nulo(p_telefono),
        reciclaje.texto_nulo(p_direccion),
        reciclaje.texto_nulo(p_observaciones),

        p_latitud,
        p_longitud

    )
    RETURNING *
    INTO v_socio;

    RETURN v_socio;

END;
$$;


ALTER FUNCTION reciclaje.crear_socio(p_company_id uuid, p_nombre text, p_documento text, p_telefono text, p_direccion text, p_observaciones text, p_latitud numeric, p_longitud numeric) OWNER TO postgres;


--
-- Name: crear_transportista(uuid, text, text, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.crear_transportista(p_company_id uuid, p_nombre text, p_telefono text DEFAULT NULL::text, p_placa text DEFAULT NULL::text) RETURNS reciclaje.transportistas
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_codigo text;

    v_transportista reciclaje.transportistas;

BEGIN

    IF reciclaje.limpiar_texto(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio.';
    END IF;

    IF reciclaje.limpiar_texto(p_placa) = '' THEN
        RAISE EXCEPTION 'La placa es obligatoria.';
    END IF;

    v_codigo := reciclaje.generar_codigo(
        p_company_id,
        'CAM'
    );

    INSERT INTO reciclaje.transportistas (

        company_id,

        codigo,

        nombre,

        telefono,

        placa

    )
    VALUES (

        p_company_id,

        v_codigo,

        reciclaje.limpiar_texto(p_nombre),

        reciclaje.texto_nulo(p_telefono),

        upper(
            reciclaje.limpiar_texto(p_placa)
        )

    )
    RETURNING *
    INTO v_transportista;

    RETURN v_transportista;

END;
$$;


ALTER FUNCTION reciclaje.crear_transportista(p_company_id uuid, p_nombre text, p_telefono text, p_placa text) OWNER TO postgres;


--
-- Name: eliminar_deposito(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.eliminar_deposito(p_company_id uuid, p_id uuid) RETURNS reciclaje.depositos
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.eliminar_deposito(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: eliminar_finanza(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.eliminar_finanza(p_company_id uuid, p_finanza_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

    DELETE
      FROM reciclaje.finanzas
     WHERE id = p_finanza_id
       AND company_id = p_company_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Finanza no encontrada.';
    END IF;

END;
$$;


ALTER FUNCTION reciclaje.eliminar_finanza(p_company_id uuid, p_finanza_id uuid) OWNER TO postgres;


--
-- Name: eliminar_material(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.eliminar_material(p_company_id uuid, p_id uuid) RETURNS reciclaje.materiales
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.eliminar_material(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: eliminar_operacion_multicarga(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.eliminar_operacion_multicarga(p_company_id uuid, p_operacion_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_operacion reciclaje.operaciones;

    v_grupo_salida_id uuid;
    v_movimiento_salida_id uuid;

    v_movimiento reciclaje.movimientos_caja%ROWTYPE;

    v_operaciones_restantes integer;

    v_movimiento_devolucion_id uuid;

BEGIN

    ------------------------------------------------------------
    -- 1. BUSCAR Y BLOQUEAR OPERACIÓN
    ------------------------------------------------------------

    SELECT *
    INTO v_operacion
    FROM reciclaje.operaciones
    WHERE company_id = p_company_id
      AND id = p_operacion_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La operación no existe.';
    END IF;


    ------------------------------------------------------------
    -- 2. FINALIZADA NO SE PUEDE ELIMINAR
    ------------------------------------------------------------

    IF COALESCE(v_operacion.finalizada, false) = true
       OR v_operacion.etapa =
          'finalizada'::reciclaje.etapa_operacion
    THEN

        RAISE EXCEPTION
            'Una operación finalizada no puede eliminarse.';

    END IF;


    ------------------------------------------------------------
    -- 3. GUARDAR RELACIÓN ANTES DE ELIMINAR
    ------------------------------------------------------------

    v_grupo_salida_id :=
        v_operacion.grupo_salida_id;

    v_movimiento_salida_id :=
        v_operacion.movimiento_salida_id;


    ------------------------------------------------------------
    -- 4. SI NO PERTENECE A MULTICARGA
    --
    -- Puede ser una precarga normal.
    ------------------------------------------------------------

    IF v_grupo_salida_id IS NULL THEN

        DELETE FROM reciclaje.operaciones
        WHERE company_id = p_company_id
          AND id = p_operacion_id;


        RETURN jsonb_build_object(

            'ok',
                true,

            'operacion_id',
                p_operacion_id,

            'grupo_salida_id',
                NULL,

            'operaciones_restantes',
                0,

            'devolucion_generada',
                false,

            'movimiento_devolucion_id',
                NULL

        );

    END IF;


    ------------------------------------------------------------
    -- 5. BLOQUEAR EL RESTO DEL GRUPO
    ------------------------------------------------------------

    PERFORM o.id
    FROM reciclaje.operaciones o
    WHERE o.company_id = p_company_id
      AND o.grupo_salida_id = v_grupo_salida_id
    ORDER BY o.id
    FOR UPDATE;


    ------------------------------------------------------------
    -- 6. ELIMINAR SOLAMENTE ESTA OPERACIÓN
    ------------------------------------------------------------

    DELETE FROM reciclaje.operaciones
    WHERE company_id = p_company_id
      AND id = p_operacion_id;


    ------------------------------------------------------------
    -- 7. CONTAR CUÁNTAS QUEDAN DEL MISMO GRUPO
    ------------------------------------------------------------

    SELECT COUNT(*)
    INTO v_operaciones_restantes
    FROM reciclaje.operaciones
    WHERE company_id = p_company_id
      AND grupo_salida_id = v_grupo_salida_id;


    ------------------------------------------------------------
    -- 8. SI TODAVÍA QUEDA AL MENOS UNA:
    --    NO TOCAR CAJA
    ------------------------------------------------------------

    IF v_operaciones_restantes > 0 THEN

        RETURN jsonb_build_object(

            'ok',
                true,

            'operacion_id',
                p_operacion_id,

            'grupo_salida_id',
                v_grupo_salida_id,

            'operaciones_restantes',
                v_operaciones_restantes,

            'devolucion_generada',
                false,

            'movimiento_devolucion_id',
                NULL

        );

    END IF;


    ------------------------------------------------------------
    -- 9. ERA LA ÚLTIMA OPERACIÓN DEL GRUPO
    --
    -- Si hubo dinero entregado, recuperamos el movimiento
    -- original.
    ------------------------------------------------------------

    IF v_movimiento_salida_id IS NOT NULL THEN

        SELECT *
        INTO v_movimiento
        FROM reciclaje.movimientos_caja
        WHERE company_id = p_company_id
          AND id = v_movimiento_salida_id
        FOR UPDATE;


        IF NOT FOUND THEN

            RAISE EXCEPTION
                'No se encontró el movimiento de Caja asociado al grupo.';

        END IF;


        --------------------------------------------------------
        -- EVITAR DEVOLUCIÓN DOBLE
        --------------------------------------------------------

        IF EXISTS (

            SELECT 1

            FROM reciclaje.movimientos_caja mc

            WHERE mc.company_id = p_company_id

              AND mc.tipo = 'entrada'

              AND mc.origen_tipo =
                  'devolucion_grupo_operaciones'

              AND mc.origen_id =
                  v_grupo_salida_id

        )
        THEN

            RAISE EXCEPTION
                'La devolución de este grupo ya fue registrada.';

        END IF;


        --------------------------------------------------------
        -- 10. CREAR CONTRAMOVIMIENTO
        --------------------------------------------------------

        INSERT INTO reciclaje.movimientos_caja (

            company_id,

            tipo,

            monto,

            moneda,

            tipo_cambio,

            monto_ars,

            forma_pago,

            referencia,

            concepto,

            descripcion,

            origen_tipo,

            origen_id,

            responsable_tipo,

            responsable_id,

            responsable_nombre,

            comprobante_url,

            observaciones

        )

        VALUES (

            p_company_id,

            'entrada',

            v_movimiento.monto,

            v_movimiento.moneda,

            v_movimiento.tipo_cambio,

            v_movimiento.monto_ars,

            v_movimiento.forma_pago,

            v_movimiento.referencia,

            'devolucion_cancelacion_multicarga',

            'Devolución total de fondos por eliminación de la última operación del grupo',

            'devolucion_grupo_operaciones',

            v_grupo_salida_id,

            v_movimiento.responsable_tipo,

            v_movimiento.responsable_id,

            v_movimiento.responsable_nombre,

            NULL,

            'Contramovimiento de la salida de Caja '
            || v_movimiento.id::text

        )

        RETURNING id
        INTO v_movimiento_devolucion_id;

    END IF;


    ------------------------------------------------------------
    -- 11. RESULTADO
    ------------------------------------------------------------

    RETURN jsonb_build_object(

        'ok',
            true,

        'operacion_id',
            p_operacion_id,

        'grupo_salida_id',
            v_grupo_salida_id,

        'operaciones_restantes',
            0,

        'devolucion_generada',
            v_movimiento_devolucion_id IS NOT NULL,

        'movimiento_salida_id',
            v_movimiento_salida_id,

        'movimiento_devolucion_id',
            v_movimiento_devolucion_id

    );

END;
$$;


ALTER FUNCTION reciclaje.eliminar_operacion_multicarga(p_company_id uuid, p_operacion_id uuid) OWNER TO postgres;


--
-- Name: eliminar_operacion(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.eliminar_operacion(p_company_id uuid, p_operacion_id uuid) RETURNS reciclaje.operaciones
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_operacion reciclaje.operaciones;

    v_movimiento reciclaje.movimientos_caja%ROWTYPE;

BEGIN

    ------------------------------------------------------------
    -- 1. BUSCAR Y BLOQUEAR OPERACIÓN
    ------------------------------------------------------------

    SELECT *
    INTO v_operacion
    FROM reciclaje.operaciones
    WHERE company_id = p_company_id
      AND id = p_operacion_id
    FOR UPDATE;


    IF NOT FOUND THEN

        RAISE EXCEPTION
            'La operación no existe.';

    END IF;


    ------------------------------------------------------------
    -- 2. FINALIZADA NO SE PUEDE ELIMINAR
    ------------------------------------------------------------

    IF v_operacion.finalizada = true
       OR v_operacion.etapa = 'finalizada'::reciclaje.etapa_operacion
    THEN

        RAISE EXCEPTION
            'Una operación finalizada no puede eliminarse.';

    END IF;


    ------------------------------------------------------------
    -- 3. SI ESTÁ EN PROCESO:
    --    REVERTIR LAS SALIDAS DE CAJA DE ESTA OPERACIÓN
    --
    -- NO borramos el movimiento original.
    -- Creamos una ENTRADA compensatoria para conservar
    -- la trazabilidad.
    ------------------------------------------------------------

    IF v_operacion.etapa = 'en_proceso'::reciclaje.etapa_operacion
    THEN

        FOR v_movimiento IN

            SELECT mc.*
            FROM reciclaje.movimientos_caja mc
            WHERE mc.company_id = p_company_id
              AND mc.origen_tipo = 'operacion'
              AND mc.origen_id = p_operacion_id
              AND mc.tipo = 'salida'
            ORDER BY mc.created_at

        LOOP

            INSERT INTO reciclaje.movimientos_caja (

                company_id,

                tipo,

                monto,

                moneda,

                tipo_cambio,

                monto_ars,

                forma_pago,

                referencia,

                concepto,

                descripcion,

                origen_tipo,

                origen_id,

                responsable_tipo,

                responsable_id,

                responsable_nombre,

                comprobante_url,

                observaciones

            )

            VALUES (

                p_company_id,

                'entrada',

                v_movimiento.monto,

                v_movimiento.moneda,

                v_movimiento.tipo_cambio,

                v_movimiento.monto_ars,

                v_movimiento.forma_pago,

                v_movimiento.referencia,

                'devolucion_cancelacion_operacion',

                'Devolución de fondos por eliminación de operación',

                'operacion',

                p_operacion_id,

                v_movimiento.responsable_tipo,

                v_movimiento.responsable_id,

                v_movimiento.responsable_nombre,

                NULL,

                'Movimiento compensatorio de la salida de caja '
                || v_movimiento.id::text

            );

        END LOOP;

    END IF;


    ------------------------------------------------------------
    -- 4. ELIMINAR OPERACIÓN
    ------------------------------------------------------------

    DELETE FROM reciclaje.operaciones
    WHERE company_id = p_company_id
      AND id = p_operacion_id;


    ------------------------------------------------------------
    -- 5. DEVOLVER OPERACIÓN ELIMINADA
    ------------------------------------------------------------

    RETURN v_operacion;

END;
$$;


ALTER FUNCTION reciclaje.eliminar_operacion(p_company_id uuid, p_operacion_id uuid) OWNER TO postgres;


--
-- Name: eliminar_orden_compra(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.eliminar_orden_compra(p_company_id uuid, p_id uuid) RETURNS reciclaje.ordenes_compra
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_orden reciclaje.ordenes_compra;

BEGIN

    SELECT *
    INTO v_orden
    FROM reciclaje.ordenes_compra
    WHERE company_id = p_company_id
      AND id = p_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La orden de compra no existe.';
    END IF;

    IF v_orden.estado <> 'borrador' THEN
        RAISE EXCEPTION 'Solo se puede eliminar una orden en borrador.';
    END IF;

    DELETE FROM reciclaje.ordenes_compra
    WHERE id = p_id
      AND company_id = p_company_id
    RETURNING *
    INTO v_orden;

    RETURN v_orden;

END;
$$;


ALTER FUNCTION reciclaje.eliminar_orden_compra(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: eliminar_socio(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.eliminar_socio(p_company_id uuid, p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.eliminar_socio(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: eliminar_transportista(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.eliminar_transportista(p_company_id uuid, p_id uuid) RETURNS reciclaje.transportistas
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.eliminar_transportista(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: enum_to_json(text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.enum_to_json(p_enum text) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$

SELECT COALESCE(

    jsonb_agg(

        jsonb_build_object(

            'id', enumlabel,

            'nombre',
            initcap(
                replace(enumlabel,'_',' ')
            )

        )

        ORDER BY enumsortorder

    ),

    '[]'::jsonb

)

FROM pg_enum e

JOIN pg_type t

ON t.oid = e.enumtypid

JOIN pg_namespace n

ON n.oid = t.typnamespace

WHERE

    n.nspname = 'reciclaje'

AND

    t.typname = p_enum;

$$;


ALTER FUNCTION reciclaje.enum_to_json(p_enum text) OWNER TO postgres;


--
-- Name: generar_codigo(uuid, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.generar_codigo(p_company_id uuid, p_tipo_documento text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_prefijo text;
    v_numero integer;
BEGIN

    v_prefijo := upper(trim(p_tipo_documento));

    INSERT INTO reciclaje.numeradores (
        company_id,
        tipo_documento,
        ultimo_numero
    )
    VALUES (
        p_company_id,
        v_prefijo,
        1
    )
    ON CONFLICT (
        company_id,
        tipo_documento
    )
    DO UPDATE
    SET ultimo_numero = reciclaje.numeradores.ultimo_numero + 1
    RETURNING ultimo_numero
    INTO v_numero;

    RETURN format(
        '%s-%06s',
        v_prefijo,
        v_numero
    );

END;
$$;


ALTER FUNCTION reciclaje.generar_codigo(p_company_id uuid, p_tipo_documento text) OWNER TO postgres;


--
-- Name: guardar_precio_socio(uuid, uuid, uuid, numeric, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.guardar_precio_socio(p_company_id uuid, p_socio_id uuid, p_material_id uuid, p_precio numeric, p_observaciones text DEFAULT NULL::text) RETURNS reciclaje.precios_socios
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_precio reciclaje.precios_socios;
BEGIN

    IF p_precio IS NULL OR p_precio < 0 THEN
        RAISE EXCEPTION 'El precio no puede ser nulo ni negativo.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.socios
        WHERE company_id = p_company_id
          AND id = p_socio_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'El socio no existe.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.materiales
        WHERE company_id = p_company_id
          AND id = p_material_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'El material no existe.';
    END IF;


    INSERT INTO reciclaje.precios_socios (
        company_id,
        socio_id,
        material_id,
        precio,
        observaciones
    )
    VALUES (
        p_company_id,
        p_socio_id,
        p_material_id,
        p_precio,
        reciclaje.texto_nulo(p_observaciones)
    )

    ON CONFLICT (company_id, socio_id, material_id)

    DO UPDATE SET
        precio = EXCLUDED.precio,
        observaciones = EXCLUDED.observaciones,
        updated_at = now()

    RETURNING *
    INTO v_precio;


    RETURN v_precio;

END;
$$;


ALTER FUNCTION reciclaje.guardar_precio_socio(p_company_id uuid, p_socio_id uuid, p_material_id uuid, p_precio numeric, p_observaciones text) OWNER TO postgres;


--
-- Name: iniciar_operaciones_multicarga(uuid, jsonb); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.iniciar_operaciones_multicarga(p_company_id uuid, p_datos jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_operacion_ids uuid[];

    v_transportista_id uuid;
    v_transportista_nombre text;

    v_grupo_salida_id uuid;

    v_caja jsonb;

    v_monto numeric(14,2) := 0;
    v_moneda text;
    v_tipo_cambio numeric(14,6) := 1;
    v_monto_ars numeric(14,2) := 0;

    v_movimiento_salida_id uuid;

    v_cantidad_solicitada integer;
    v_cantidad_valida integer;
    v_cantidad_actualizada integer;

BEGIN

    ------------------------------------------------------------
    -- 1. VALIDAR OPERACIONES
    ------------------------------------------------------------

    IF jsonb_typeof(
        COALESCE(
            p_datos->'operacion_ids',
            '[]'::jsonb
        )
    ) <> 'array'
    THEN
        RAISE EXCEPTION
            'operacion_ids debe ser un array.';
    END IF;


    SELECT ARRAY_AGG(DISTINCT x::uuid)
    INTO v_operacion_ids
    FROM jsonb_array_elements_text(
        COALESCE(
            p_datos->'operacion_ids',
            '[]'::jsonb
        )
    ) AS t(x);


    v_cantidad_solicitada :=
        COALESCE(
            array_length(v_operacion_ids, 1),
            0
        );


    IF v_cantidad_solicitada = 0 THEN
        RAISE EXCEPTION
            'Debe indicar al menos una operación.';
    END IF;


    ------------------------------------------------------------
    -- 2. TRANSPORTISTA
    ------------------------------------------------------------

    v_transportista_id :=
        NULLIF(
            p_datos->>'transportista_id',
            ''
        )::uuid;


    IF v_transportista_id IS NULL THEN
        RAISE EXCEPTION
            'Debe indicar el transportista.';
    END IF;


    SELECT t.nombre
    INTO v_transportista_nombre
    FROM reciclaje.transportistas t
    WHERE t.company_id = p_company_id
      AND t.id = v_transportista_id
      AND t.activo = true;


    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El transportista no existe o está inactivo.';
    END IF;


    ------------------------------------------------------------
    -- 3. BLOQUEAR OPERACIONES
    ------------------------------------------------------------

    PERFORM o.id
    FROM reciclaje.operaciones o
    WHERE o.company_id = p_company_id
      AND o.id = ANY(v_operacion_ids)
    ORDER BY o.id
    FOR UPDATE;


    ------------------------------------------------------------
    -- 4. VALIDAR QUE TODAS PUEDAN SALIR
    ------------------------------------------------------------

    SELECT COUNT(*)
    INTO v_cantidad_valida
    FROM reciclaje.operaciones o
    WHERE o.company_id = p_company_id
      AND o.id = ANY(v_operacion_ids)
      AND o.etapa = 'precarga'::reciclaje.etapa_operacion
      AND COALESCE(o.finalizada, false) = false
      AND o.grupo_salida_id IS NULL;


    IF v_cantidad_valida <> v_cantidad_solicitada THEN
        RAISE EXCEPTION
            'Todas las operaciones deben existir, estar en precarga y no pertenecer a otra salida.';
    END IF;


    ------------------------------------------------------------
    -- 5. CREAR IDENTIFICADOR COMÚN DEL VIAJE
    ------------------------------------------------------------

    v_grupo_salida_id :=
        gen_random_uuid();


    ------------------------------------------------------------
    -- 6. DATOS DE CAJA
    ------------------------------------------------------------

    v_caja :=
        COALESCE(
            p_datos->'caja',
            '{}'::jsonb
        );


    v_monto :=
        COALESCE(
            NULLIF(
                v_caja->>'monto',
                ''
            )::numeric,
            0
        );


    IF v_monto < 0 THEN
        RAISE EXCEPTION
            'El monto entregado no puede ser negativo.';
    END IF;


    ------------------------------------------------------------
    -- 7. SI HUBO DINERO ENTREGADO
    ------------------------------------------------------------

    IF v_monto > 0 THEN

        v_moneda :=
            NULLIF(
                trim(v_caja->>'moneda'),
                ''
            );


        IF v_moneda IS NULL THEN
            RAISE EXCEPTION
                'Debe indicar la moneda.';
        END IF;


        --------------------------------------------------------
        -- ARS SIEMPRE TC = 1
        --------------------------------------------------------

        IF upper(v_moneda) = 'ARS' THEN

            v_tipo_cambio := 1;

        ELSE

            v_tipo_cambio :=
                COALESCE(
                    NULLIF(
                        v_caja->>'tipo_cambio',
                        ''
                    )::numeric,
                    0
                );


            IF v_tipo_cambio <= 0 THEN
                RAISE EXCEPTION
                    'Debe indicar un tipo de cambio mayor a cero.';
            END IF;

        END IF;


        v_monto_ars :=
            ROUND(
                v_monto * v_tipo_cambio,
                2
            );


        --------------------------------------------------------
        -- UN ÚNICO MOVIMIENTO DE CAJA PARA TODO EL GRUPO
        --------------------------------------------------------

        INSERT INTO reciclaje.movimientos_caja (

            company_id,

            tipo,

            monto,

            moneda,

            tipo_cambio,

            monto_ars,

            forma_pago,

            referencia,

            concepto,

            descripcion,

            origen_tipo,

            origen_id,

            responsable_tipo,

            responsable_id,

            responsable_nombre,

            comprobante_url,

            observaciones

        )

        VALUES (

            p_company_id,

            'salida',

            v_monto,

            v_moneda,

            v_tipo_cambio,

            v_monto_ars,

            reciclaje.texto_nulo(
                v_caja->>'forma_pago'
            ),

            reciclaje.texto_nulo(
                v_caja->>'referencia'
            ),

            'entrega_operacion_multicarga',

            CASE
                WHEN v_cantidad_solicitada = 1
                THEN
                    'Entrega de fondos al transportista para iniciar operación'
                ELSE
                    'Entrega de fondos al transportista para '
                    || v_cantidad_solicitada::text
                    || ' operaciones'
            END,

            'grupo_operaciones',

            v_grupo_salida_id,

            'transportista',

            v_transportista_id,

            v_transportista_nombre,

            reciclaje.texto_nulo(
                v_caja->>'comprobante_url'
            ),

            reciclaje.texto_nulo(
                v_caja->>'observaciones'
            )

        )

        RETURNING id
        INTO v_movimiento_salida_id;

    END IF;


    ------------------------------------------------------------
    -- 8. PASAR TODAS LAS OPERACIONES A EN_PROCESO
    ------------------------------------------------------------

    UPDATE reciclaje.operaciones

    SET

        transportista_id =
            v_transportista_id,

        grupo_salida_id =
            v_grupo_salida_id,

        movimiento_salida_id =
            v_movimiento_salida_id,

        etapa =
            'en_proceso'::reciclaje.etapa_operacion,

        updated_at =
            now()

    WHERE company_id = p_company_id
      AND id = ANY(v_operacion_ids);


    GET DIAGNOSTICS
        v_cantidad_actualizada = ROW_COUNT;


    IF v_cantidad_actualizada <> v_cantidad_solicitada THEN
        RAISE EXCEPTION
            'No fue posible iniciar todas las operaciones.';
    END IF;


    ------------------------------------------------------------
    -- 9. RESPUESTA
    ------------------------------------------------------------

    RETURN jsonb_build_object(

        'ok',
            true,

        'grupo_salida_id',
            v_grupo_salida_id,

        'movimiento_salida_id',
            v_movimiento_salida_id,

        'transportista_id',
            v_transportista_id,

        'transportista_nombre',
            v_transportista_nombre,

        'cantidad_operaciones',
            v_cantidad_solicitada,

        'monto_entregado',
            v_monto,

        'moneda',
            v_moneda,

        'tipo_cambio',
            v_tipo_cambio,

        'monto_ars',
            v_monto_ars,

        'operaciones',
            (
                SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(

                            'id',
                                o.id,

                            'socio_id',
                                o.socio_id,

                            'etapa',
                                o.etapa,

                            'transportista_id',
                                o.transportista_id,

                            'grupo_salida_id',
                                o.grupo_salida_id,

                            'movimiento_salida_id',
                                o.movimiento_salida_id

                        )
                        ORDER BY o.created_at
                    ),
                    '[]'::jsonb
                )

                FROM reciclaje.operaciones o

                WHERE o.company_id = p_company_id
                  AND o.grupo_salida_id = v_grupo_salida_id
            )

    );

END;
$$;


ALTER FUNCTION reciclaje.iniciar_operaciones_multicarga(p_company_id uuid, p_datos jsonb) OWNER TO postgres;


--
-- Name: limpiar_texto(text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.limpiar_texto(p_texto text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT trim(coalesce(p_texto, ''));
$$;


ALTER FUNCTION reciclaje.limpiar_texto(p_texto text) OWNER TO postgres;


--
-- Name: listar_depositos(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_depositos(p_company_id uuid) RETURNS SETOF reciclaje.depositos
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT *

FROM reciclaje.depositos

WHERE company_id = p_company_id
  AND activo = true

ORDER BY nombre;

$$;


ALTER FUNCTION reciclaje.listar_depositos(p_company_id uuid) OWNER TO postgres;


--
-- Name: listar_finanzas(uuid, boolean); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_finanzas(p_company_id uuid, p_incluir_anuladas boolean DEFAULT false) RETURNS SETOF reciclaje.finanzas
    LANGUAGE plpgsql
    AS $$
BEGIN

    RETURN QUERY
    SELECT *
      FROM reciclaje.finanzas
     WHERE company_id = p_company_id
       AND (p_incluir_anuladas OR NOT anulado)
     ORDER BY fecha_emision DESC, created_at DESC;

END;
$$;


ALTER FUNCTION reciclaje.listar_finanzas(p_company_id uuid, p_incluir_anuladas boolean) OWNER TO postgres;


--
-- Name: listar_finanzas(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_finanzas(p_company_id uuid) RETURNS SETOF reciclaje.finanzas
    LANGUAGE plpgsql
    AS $$
BEGIN

    RETURN QUERY

    SELECT *
      FROM reciclaje.finanzas
     WHERE company_id = p_company_id
     ORDER BY fecha_emision DESC, created_at DESC;

END;
$$;


ALTER FUNCTION reciclaje.listar_finanzas(p_company_id uuid) OWNER TO postgres;


--
-- Name: listar_inventario(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_inventario(p_company_id uuid, p_deposito_id uuid DEFAULT NULL::uuid) RETURNS TABLE(deposito_id uuid, deposito_codigo text, deposito_nombre text, material_id uuid, material_codigo text, material_nombre text, unidad text, imagen_url text, entradas numeric, salidas numeric, ajustes numeric, traslados numeric, stock numeric)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
    SELECT

        d.id AS deposito_id,
        d.codigo AS deposito_codigo,
        d.nombre AS deposito_nombre,

        m.id AS material_id,
        m.codigo AS material_codigo,
        m.nombre AS material_nombre,
        m.unidad,
        m.imagen_url,

        ----------------------------------------------------
        -- ENTRADAS
        ----------------------------------------------------

        COALESCE(
            SUM(ABS(ms.cantidad))
            FILTER (
                WHERE ms.tipo_movimiento = 'entrada'
            ),
            0
        ) AS entradas,

        ----------------------------------------------------
        -- SALIDAS
        ----------------------------------------------------

        COALESCE(
            SUM(ABS(ms.cantidad))
            FILTER (
                WHERE ms.tipo_movimiento = 'salida'
            ),
            0
        ) AS salidas,

        ----------------------------------------------------
        -- AJUSTES
        ----------------------------------------------------

        COALESCE(
            SUM(ms.cantidad)
            FILTER (
                WHERE ms.tipo_movimiento = 'ajuste'
            ),
            0
        ) AS ajustes,

        ----------------------------------------------------
        -- TRASLADOS
        --
        -- origen  = negativo
        -- destino = positivo
        ----------------------------------------------------

        COALESCE(
            SUM(ms.cantidad)
            FILTER (
                WHERE ms.tipo_movimiento = 'traslado'
            ),
            0
        ) AS traslados,

        ----------------------------------------------------
        -- STOCK REAL DEL DEPÓSITO
        ----------------------------------------------------

        COALESCE(
            SUM(
                CASE

                    WHEN ms.tipo_movimiento = 'entrada'
                        THEN ABS(ms.cantidad)

                    WHEN ms.tipo_movimiento = 'salida'
                        THEN -ABS(ms.cantidad)

                    WHEN ms.tipo_movimiento = 'ajuste'
                        THEN ms.cantidad

                    WHEN ms.tipo_movimiento = 'traslado'
                        THEN ms.cantidad

                    ELSE 0

                END
            ),
            0
        ) AS stock


    FROM reciclaje.movimientos_stock ms


    JOIN reciclaje.materiales m
      ON m.id = ms.material_id
     AND m.company_id = p_company_id


    JOIN reciclaje.depositos d
      ON d.id = ms.deposito_id
     AND d.company_id = p_company_id


    WHERE ms.company_id = p_company_id

      AND (
          p_deposito_id IS NULL
          OR ms.deposito_id = p_deposito_id
      )


    GROUP BY

        d.id,
        d.codigo,
        d.nombre,

        m.id,
        m.codigo,
        m.nombre,
        m.unidad,
        m.imagen_url


    ORDER BY

        d.nombre,
        m.nombre;
$$;


ALTER FUNCTION reciclaje.listar_inventario(p_company_id uuid, p_deposito_id uuid) OWNER TO postgres;


--
-- Name: listar_materiales(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_materiales(p_company_id uuid) RETURNS SETOF reciclaje.materiales
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT *

FROM reciclaje.materiales

WHERE company_id = p_company_id
  AND activo = true

ORDER BY nombre;

$$;


ALTER FUNCTION reciclaje.listar_materiales(p_company_id uuid) OWNER TO postgres;


--
-- Name: listar_movimientos_caja(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_movimientos_caja(p_company_id uuid) RETURNS TABLE(id uuid, tipo text, monto numeric, moneda text, tipo_cambio numeric, monto_ars numeric, forma_pago text, referencia text, concepto text, descripcion text, origen_tipo text, origen_id uuid, responsable_tipo text, responsable_id uuid, responsable_nombre text, socio_nombre text, comprobante_url text, observaciones text, created_at timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    AS $$

    SELECT

        mc.id,
        mc.tipo,
        mc.monto,
        mc.moneda,
        mc.tipo_cambio,
        mc.monto_ars,
        mc.forma_pago,
        mc.referencia,
        mc.concepto,
        mc.descripcion,

        mc.origen_tipo,
        mc.origen_id,

        mc.responsable_tipo,
        mc.responsable_id,
        mc.responsable_nombre,

        CASE
            WHEN mc.origen_tipo = 'operacion'
            THEN s.nombre
            ELSE NULL
        END AS socio_nombre,

        mc.comprobante_url,
        mc.observaciones,
        mc.created_at

    FROM reciclaje.movimientos_caja mc

    LEFT JOIN reciclaje.operaciones o
        ON mc.origen_tipo = 'operacion'
       AND o.id = mc.origen_id
       AND o.company_id = mc.company_id

    LEFT JOIN reciclaje.socios s
        ON s.id = o.socio_id
       AND s.company_id = mc.company_id

    WHERE mc.company_id = p_company_id

      ----------------------------------------------------------
      -- SOLO MOVIMIENTOS DEL DÍA ACTUAL
      ----------------------------------------------------------

      AND mc.created_at >= CURRENT_DATE
      AND mc.created_at < CURRENT_DATE + INTERVAL '1 day'

    ORDER BY
        mc.created_at DESC,
        mc.id DESC;

$$;


ALTER FUNCTION reciclaje.listar_movimientos_caja(p_company_id uuid) OWNER TO postgres;


--
-- Name: listar_movimientos_stock(uuid, uuid, uuid, reciclaje.tipo_movimiento, integer); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_movimientos_stock(p_company_id uuid, p_deposito_id uuid DEFAULT NULL::uuid, p_material_id uuid DEFAULT NULL::uuid, p_tipo_movimiento reciclaje.tipo_movimiento DEFAULT NULL::reciclaje.tipo_movimiento, p_limite integer DEFAULT 100) RETURNS TABLE(id uuid, created_at timestamp with time zone, deposito_id uuid, deposito_codigo text, deposito_nombre text, material_id uuid, material_codigo text, material_nombre text, unidad text, tipo_movimiento reciclaje.tipo_movimiento, cantidad numeric, origen text, origen_id uuid, socio_id uuid, socio_nombre text, transportista_id uuid, transportista_nombre text, orden_compra_id uuid, orden_codigo text, recepcion_id uuid, recepcion_codigo text, observaciones text)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
    SELECT

        ms.id,
        ms.created_at,

        d.id,
        d.codigo,
        d.nombre,

        m.id,
        m.codigo,
        m.nombre,
        m.unidad,

        ms.tipo_movimiento,
        ms.cantidad,

        ms.origen,
        ms.origen_id,

        s.id,
        s.nombre,

        t.id,
        t.nombre,

        oc.id,
        oc.codigo,

        r.id,
        r.codigo,

        ms.observaciones

    FROM reciclaje.movimientos_stock ms

    JOIN reciclaje.materiales m
      ON m.id = ms.material_id
     AND m.company_id = p_company_id

    LEFT JOIN reciclaje.depositos d
      ON d.id = ms.deposito_id
     AND d.company_id = p_company_id

    LEFT JOIN reciclaje.socios s
      ON s.id = ms.socio_id
     AND s.company_id = p_company_id

    LEFT JOIN reciclaje.transportistas t
      ON t.id = ms.transportista_id
     AND t.company_id = p_company_id

    LEFT JOIN reciclaje.ordenes_compra oc
      ON oc.id = ms.orden_compra_id
     AND oc.company_id = p_company_id

    LEFT JOIN reciclaje.recepciones r
      ON r.id = ms.recepcion_id
     AND r.company_id = p_company_id

    WHERE ms.company_id = p_company_id

      AND (
          p_deposito_id IS NULL
          OR ms.deposito_id = p_deposito_id
      )

      AND (
          p_material_id IS NULL
          OR ms.material_id = p_material_id
      )

      AND (
          p_tipo_movimiento IS NULL
          OR ms.tipo_movimiento = p_tipo_movimiento
      )

    ORDER BY ms.created_at DESC

    LIMIT LEAST(
        GREATEST(COALESCE(p_limite, 100), 1),
        500
    );
$$;


ALTER FUNCTION reciclaje.listar_movimientos_stock(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_tipo_movimiento reciclaje.tipo_movimiento, p_limite integer) OWNER TO postgres;


--
-- Name: listar_operaciones(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_operaciones(p_company_id uuid) RETURNS TABLE(id uuid, tipo reciclaje.tipo_operacion, etapa reciclaje.etapa_operacion, socio_id uuid, socio_nombre text, direccion text, latitud numeric, longitud numeric, transportista_id uuid, transportista_nombre text, resumen_materiales text, monto numeric, finalizada boolean, created_at timestamp with time zone, updated_at timestamp with time zone, finalizada_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT

    o.id,

    o.tipo,
    o.etapa,

    o.socio_id,

    COALESCE(
        s.nombre,
        'Sin socio asignado'
    ) AS socio_nombre,

    COALESCE(
        s.direccion,
        'Sin dirección'
    ) AS direccion,

    s.latitud,
    s.longitud,

    o.transportista_id,

    COALESCE(
        t.nombre,
        'Sin transportista'
    ) AS transportista_nombre,

    CASE

        WHEN jsonb_array_length(
            COALESCE(
                o.materiales,
                '[]'::jsonb
            )
        ) = 0
        THEN 'No tiene materiales aún'

        WHEN jsonb_array_length(
            COALESCE(
                o.materiales,
                '[]'::jsonb
            )
        ) = 1
        THEN '1 material'

        ELSE
            jsonb_array_length(
                COALESCE(
                    o.materiales,
                    '[]'::jsonb
                )
            )::text
            || ' materiales'

    END AS resumen_materiales,

    o.monto,

    o.finalizada,

    o.created_at,
    o.updated_at,
    o.finalizada_at

FROM reciclaje.operaciones o

LEFT JOIN reciclaje.socios s
       ON s.id = o.socio_id
      AND s.company_id = p_company_id

LEFT JOIN reciclaje.transportistas t
       ON t.id = o.transportista_id
      AND t.company_id = p_company_id

WHERE o.company_id = p_company_id

  AND (

        COALESCE(o.finalizada, false) = false

        OR

        (
            o.finalizada = true
            AND o.finalizada_at >= now() - interval '1 day'
        )

      )

ORDER BY
    o.finalizada ASC,
    o.updated_at DESC;

$$;


ALTER FUNCTION reciclaje.listar_operaciones(p_company_id uuid) OWNER TO postgres;


--
-- Name: listar_ordenes_compra(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_ordenes_compra(p_company_id uuid) RETURNS TABLE(id uuid, company_id uuid, codigo text, socio_id uuid, socio_codigo text, socio_nombre text, transportista_id uuid, transportista_codigo text, transportista_nombre text, transportista_placa text, estado reciclaje.estado_orden, observaciones text, cantidad_materiales bigint, cantidad_total numeric, cantidad_pagos bigint, created_at timestamp with time zone, updated_at timestamp with time zone, subtotal numeric, total numeric)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT

    oc.id,
    oc.company_id,
    oc.codigo,

    s.id,
    s.codigo,
    s.nombre,

    t.id,
    t.codigo,
    t.nombre,
    t.placa,

    oc.estado,
    oc.observaciones,

    COALESCE(md.cantidad_materiales,0),
    COALESCE(md.cantidad_total,0),
    COALESCE(pg.cantidad_pagos,0),

    oc.created_at,
    oc.updated_at,

    oc.subtotal,
    oc.total

FROM reciclaje.ordenes_compra oc

JOIN reciclaje.socios s
ON s.id = oc.socio_id

JOIN reciclaje.transportistas t
ON t.id = oc.transportista_id

LEFT JOIN (

    SELECT

        orden_compra_id,

        COUNT(*) AS cantidad_materiales,

        SUM(cantidad) AS cantidad_total

    FROM reciclaje.ordenes_compra_detalle

    GROUP BY orden_compra_id

) md

ON md.orden_compra_id = oc.id

LEFT JOIN (

    SELECT

        orden_compra_id,

        COUNT(*) AS cantidad_pagos

    FROM reciclaje.ordenes_compra_pagos

    GROUP BY orden_compra_id

) pg

ON pg.orden_compra_id = oc.id

WHERE oc.company_id = p_company_id

ORDER BY oc.created_at DESC;

$$;


ALTER FUNCTION reciclaje.listar_ordenes_compra(p_company_id uuid) OWNER TO postgres;


--
-- Name: listar_recepciones(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_recepciones(p_company_id uuid) RETURNS TABLE(id uuid, codigo text, estado reciclaje.estado_recepcion, orden_compra_id uuid, orden_codigo text, orden_estado reciclaje.estado_orden, socio_id uuid, socio_codigo text, socio_nombre text, transportista_id uuid, transportista_codigo text, transportista_nombre text, transportista_placa text, deposito_id uuid, deposito_codigo text, deposito_nombre text, recibido_por text, observaciones text, subtotal numeric, total numeric, materiales jsonb, pagos jsonb, created_at timestamp with time zone, confirmed_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT

    r.id,

    r.codigo,

    r.estado,

    r.orden_compra_id,

    oc.codigo AS orden_codigo,

    oc.estado AS orden_estado,

    s.id AS socio_id,

    s.codigo AS socio_codigo,

    s.nombre AS socio_nombre,

    t.id AS transportista_id,

    t.codigo AS transportista_codigo,

    t.nombre AS transportista_nombre,

    t.placa AS transportista_placa,

    d.id AS deposito_id,

    d.codigo AS deposito_codigo,

    d.nombre AS deposito_nombre,

    r.recibido_por,

    r.observaciones,

    oc.subtotal,

    oc.total,

    ----------------------------------------------------
    -- Materiales recibidos
    ----------------------------------------------------

    COALESCE(

        (

            SELECT jsonb_agg(

                jsonb_build_object(

                    'id',
                    rd.id,

                    'material_id',
                    rd.material_id,

                    'material_codigo',
                    m.codigo,

                    'material_nombre',
                    m.nombre,

                    'unidad',
                    m.unidad,

                    'cantidad',
                    rd.cantidad,

                    'precio_unitario',
                    rd.precio_unitario,

                    'subtotal',
                    rd.subtotal,

                    'observaciones',
                    rd.observaciones

                )

                ORDER BY m.nombre

            )

            FROM reciclaje.recepciones_detalle rd

            JOIN reciclaje.materiales m
              ON m.id = rd.material_id
             AND m.company_id = p_company_id

            WHERE rd.recepcion_id = r.id

        ),

        '[]'::jsonb

    ) AS materiales,

    ----------------------------------------------------
    -- Pagos de la orden
    ----------------------------------------------------

    COALESCE(

        (

            SELECT jsonb_agg(

                jsonb_build_object(

                    'id',
                    op.id,

                    'forma_pago_id',
                    op.forma_pago_id,

                    'forma_pago_codigo',
                    fp.codigo,

                    'forma_pago_nombre',
                    fp.nombre,

                    'moneda_id',
                    op.moneda_id,

                    'moneda_codigo',
                    mo.codigo,

                    'moneda_nombre',
                    mo.nombre,

                    'moneda_simbolo',
                    mo.simbolo,

                    'monto',
                    op.monto,

                    'referencia',
                    op.referencia,

                    'observaciones',
                    op.observaciones

                )

                ORDER BY op.created_at

            )

            FROM reciclaje.ordenes_compra_pagos op

            JOIN reciclaje.formas_pago fp
              ON fp.id = op.forma_pago_id

            JOIN reciclaje.monedas mo
              ON mo.id = op.moneda_id

            WHERE op.orden_compra_id = oc.id

        ),

        '[]'::jsonb

    ) AS pagos,

    r.created_at,

    r.confirmed_at

FROM reciclaje.recepciones r

JOIN reciclaje.ordenes_compra oc
  ON oc.id = r.orden_compra_id
 AND oc.company_id = p_company_id

JOIN reciclaje.socios s
  ON s.id = oc.socio_id
 AND s.company_id = p_company_id

JOIN reciclaje.transportistas t
  ON t.id = oc.transportista_id
 AND t.company_id = p_company_id

LEFT JOIN reciclaje.depositos d
  ON d.id = r.deposito_id
 AND d.company_id = p_company_id

WHERE r.company_id = p_company_id

ORDER BY r.created_at DESC;

$$;


ALTER FUNCTION reciclaje.listar_recepciones(p_company_id uuid) OWNER TO postgres;


--
-- Name: listar_socios(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_socios(p_company_id uuid) RETURNS SETOF reciclaje.socios
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT *

FROM reciclaje.socios

WHERE company_id = p_company_id
AND activo = true

ORDER BY nombre;

$$;


ALTER FUNCTION reciclaje.listar_socios(p_company_id uuid) OWNER TO postgres;


--
-- Name: listar_transportistas(uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.listar_transportistas(p_company_id uuid) RETURNS SETOF reciclaje.transportistas
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT *

FROM reciclaje.transportistas

WHERE company_id = p_company_id
  AND activo = true

ORDER BY nombre;

$$;


ALTER FUNCTION reciclaje.listar_transportistas(p_company_id uuid) OWNER TO postgres;


--
-- Name: obtener_deposito(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_deposito(p_company_id uuid, p_id uuid) RETURNS reciclaje.depositos
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.obtener_deposito(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: obtener_finanza(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_finanza(p_company_id uuid, p_finanza_id uuid) RETURNS reciclaje.finanzas
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_finanza reciclaje.finanzas;
BEGIN

    SELECT *
      INTO v_finanza
      FROM reciclaje.finanzas
     WHERE id = p_finanza_id
       AND company_id = p_company_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Finanza no encontrada.';
    END IF;

    RETURN v_finanza;

END;
$$;


ALTER FUNCTION reciclaje.obtener_finanza(p_company_id uuid, p_finanza_id uuid) OWNER TO postgres;


--
-- Name: obtener_material(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_material(p_company_id uuid, p_id uuid) RETURNS reciclaje.materiales
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.obtener_material(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: obtener_operacion(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_operacion(p_company_id uuid, p_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT jsonb_build_object(

    ------------------------------------------------------------
    -- OPERACIÓN
    ------------------------------------------------------------

    'id', o.id,
    'company_id', o.company_id,

    'tipo', o.tipo,
    'etapa', o.etapa,

    'monto', o.monto,

    ------------------------------------------------------------
    -- SOCIO
    ------------------------------------------------------------

    'socio',
        CASE
            WHEN s.id IS NULL THEN NULL
            ELSE jsonb_build_object(
                'id', s.id,
                'codigo', s.codigo,
                'nombre', s.nombre,
                'direccion', s.direccion,
                'latitud', s.latitud,
                'longitud', s.longitud
            )
        END,

    ------------------------------------------------------------
    -- TRANSPORTISTA
    ------------------------------------------------------------

    'transportista',
        CASE
            WHEN t.id IS NULL THEN NULL
            ELSE jsonb_build_object(
                'id', t.id,
                'codigo', t.codigo,
                'nombre', t.nombre,
                'telefono', t.telefono,
                'placa', t.placa
            )
        END,

    ------------------------------------------------------------
    -- DEPÓSITO
    ------------------------------------------------------------

    'deposito',
        CASE
            WHEN d.id IS NULL THEN NULL
            ELSE jsonb_build_object(
                'id', d.id,
                'codigo', d.codigo,
                'nombre', d.nombre
            )
        END,

    ------------------------------------------------------------
    -- MATERIALES ENRIQUECIDOS
    ------------------------------------------------------------

    'materiales',

    COALESCE(
        (
            SELECT jsonb_agg(

                jsonb_build_object(

                    'material_id',
                        x.material_id,

                    'codigo',
                        m.codigo,

                    'nombre',
                        m.nombre,

                    'unidad',
                        m.unidad,

                    'imagen_url',
                        m.imagen_url,

                    'cantidad',
                        x.cantidad,

                    'precio_unitario',
                        x.precio_unitario,

                    'subtotal',
                        x.cantidad * x.precio_unitario,

                    'guardar_precio_socio',
                        x.guardar_precio_socio

                )

            )

            FROM (

                SELECT

                    (j->>'material_id')::uuid
                        AS material_id,

                    COALESCE(
                        NULLIF(j->>'cantidad', '')::numeric,
                        0
                    ) AS cantidad,

                    COALESCE(
                        NULLIF(j->>'precio_unitario', '')::numeric,
                        0
                    ) AS precio_unitario,

                    COALESCE(
                        NULLIF(j->>'guardar_precio_socio', '')::boolean,
                        false
                    ) AS guardar_precio_socio

                FROM jsonb_array_elements(
                    COALESCE(
                        o.materiales,
                        '[]'::jsonb
                    )
                ) j

            ) x

            LEFT JOIN reciclaje.materiales m
                   ON m.id = x.material_id
                  AND m.company_id = p_company_id

        ),
        '[]'::jsonb
    ),

    ------------------------------------------------------------
    -- PAGOS ENRIQUECIDOS
    ------------------------------------------------------------

    'pagos',

    COALESCE(
        (
            SELECT jsonb_agg(

                jsonb_build_object(

                    'forma_pago_id',
                        x.forma_pago_id,

                    'forma_pago_codigo',
                        fp.codigo,

                    'forma_pago_nombre',
                        fp.nombre,

                    'moneda_id',
                        x.moneda_id,

                    'moneda_codigo',
                        mo.codigo,

                    'moneda_nombre',
                        mo.nombre,

                    'moneda_simbolo',
                        mo.simbolo,

                    'monto',
                        x.monto,

                    'referencia',
                        x.referencia,

                    'observaciones',
                        x.observaciones

                )

            )

            FROM (

                SELECT

                    (j->>'forma_pago_id')::uuid
                        AS forma_pago_id,

                    (j->>'moneda_id')::uuid
                        AS moneda_id,

                    COALESCE(
                        NULLIF(j->>'monto', '')::numeric,
                        0
                    ) AS monto,

                    NULLIF(
                        trim(j->>'referencia'),
                        ''
                    ) AS referencia,

                    NULLIF(
                        trim(j->>'observaciones'),
                        ''
                    ) AS observaciones

                FROM jsonb_array_elements(
                    COALESCE(
                        o.pagos,
                        '[]'::jsonb
                    )
                ) j

            ) x

            LEFT JOIN reciclaje.formas_pago fp
                   ON fp.id = x.forma_pago_id

            LEFT JOIN reciclaje.monedas mo
                   ON mo.id = x.moneda_id

        ),
        '[]'::jsonb
    ),

    ------------------------------------------------------------
    -- RECEPCIÓN / RESPONSABLE
    ------------------------------------------------------------

    'recibido_por',
        o.recibido_por,

    'responsable_nombre',
        o.responsable_nombre,

    'responsable_tipo',
        o.responsable_tipo,

    'observaciones',
        o.observaciones,

    ------------------------------------------------------------
    -- RESULTADO
    ------------------------------------------------------------

    'finalizada',
        o.finalizada,

    'orden_compra_id',
        o.orden_compra_id,

    'recepcion_id',
        o.recepcion_id,

    'finanza_id',
        o.finanza_id,

    ------------------------------------------------------------
    -- FECHAS
    ------------------------------------------------------------

    'created_at',
        o.created_at,

    'updated_at',
        o.updated_at,

    'finalizada_at',
        o.finalizada_at

)

FROM reciclaje.operaciones o

LEFT JOIN reciclaje.socios s
       ON s.id = o.socio_id
      AND s.company_id = p_company_id

LEFT JOIN reciclaje.transportistas t
       ON t.id = o.transportista_id
      AND t.company_id = p_company_id

LEFT JOIN reciclaje.depositos d
       ON d.id = o.deposito_id
      AND d.company_id = p_company_id

WHERE o.company_id = p_company_id
  AND o.id = p_id;

$$;


ALTER FUNCTION reciclaje.obtener_operacion(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: obtener_orden_compra(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_orden_compra(p_company_id uuid, p_id uuid) RETURNS TABLE(id uuid, company_id uuid, codigo text, socio_id uuid, socio_codigo text, socio_nombre text, transportista_id uuid, transportista_codigo text, transportista_nombre text, transportista_placa text, estado reciclaje.estado_orden, observaciones text, subtotal numeric, total numeric, cantidad_materiales bigint, cantidad_total numeric, cantidad_pagos bigint, materiales jsonb, pagos jsonb, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT
    oc.id,
    oc.company_id,
    oc.codigo,

    s.id AS socio_id,
    s.codigo AS socio_codigo,
    s.nombre AS socio_nombre,

    t.id AS transportista_id,
    t.codigo AS transportista_codigo,
    t.nombre AS transportista_nombre,
    t.placa AS transportista_placa,

    oc.estado,
    oc.observaciones,

    oc.subtotal,
    oc.total,

    (
        SELECT COUNT(*)
        FROM reciclaje.ordenes_compra_detalle ocd
        WHERE ocd.orden_compra_id = oc.id
    ) AS cantidad_materiales,

    COALESCE(
        (
            SELECT SUM(ocd.cantidad)
            FROM reciclaje.ordenes_compra_detalle ocd
            WHERE ocd.orden_compra_id = oc.id
        ),
        0
    ) AS cantidad_total,

    (
        SELECT COUNT(*)
        FROM reciclaje.ordenes_compra_pagos ocp
        WHERE ocp.orden_compra_id = oc.id
    ) AS cantidad_pagos,

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', ocd.id,
                    'material_id', ocd.material_id,
                    'material_codigo', m.codigo,
                    'material_nombre', m.nombre,
                    'material_unidad', m.unidad,
                    'cantidad', ocd.cantidad,
                    'precio_unitario', ocd.precio_unitario,
                    'subtotal', ocd.subtotal,
                    'observaciones', ocd.observaciones
                )
                ORDER BY m.nombre
            )
            FROM reciclaje.ordenes_compra_detalle ocd
            JOIN reciclaje.materiales m
              ON m.id = ocd.material_id
             AND m.company_id = p_company_id
            WHERE ocd.orden_compra_id = oc.id
        ),
        '[]'::jsonb
    ) AS materiales,

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', ocp.id,
                    'forma_pago_id', ocp.forma_pago_id,
                    'forma_pago_codigo', fp.codigo,
                    'forma_pago_nombre', fp.nombre,
                    'moneda_id', ocp.moneda_id,
                    'moneda_codigo', mo.codigo,
                    'moneda_nombre', mo.nombre,
                    'moneda_simbolo', mo.simbolo,
                    'monto', ocp.monto,
                    'referencia', ocp.referencia,
                    'observaciones', ocp.observaciones
                )
                ORDER BY ocp.created_at
            )
            FROM reciclaje.ordenes_compra_pagos ocp
            JOIN reciclaje.formas_pago fp
              ON fp.id = ocp.forma_pago_id
            JOIN reciclaje.monedas mo
              ON mo.id = ocp.moneda_id
            WHERE ocp.orden_compra_id = oc.id
        ),
        '[]'::jsonb
    ) AS pagos,

    oc.created_at,
    oc.updated_at

FROM reciclaje.ordenes_compra oc

JOIN reciclaje.socios s
  ON s.id = oc.socio_id
 AND s.company_id = p_company_id

JOIN reciclaje.transportistas t
  ON t.id = oc.transportista_id
 AND t.company_id = p_company_id

WHERE oc.company_id = p_company_id
  AND oc.id = p_id;

$$;


ALTER FUNCTION reciclaje.obtener_orden_compra(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: obtener_precios_material_socio(uuid, uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_precios_material_socio(p_company_id uuid, p_socio_id uuid, p_material_id uuid) RETURNS TABLE(material_id uuid, precio_base numeric, precio_mayorista numeric, precio_socio numeric, ultimo_precio numeric, ultimo_precio_fecha timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT

    m.id AS material_id,

    m.precio_base,

    m.precio_mayorista,

    ps.precio AS precio_socio,

    ultimo.precio_unitario AS ultimo_precio,

    ultimo.fecha AS ultimo_precio_fecha

FROM reciclaje.materiales m

LEFT JOIN reciclaje.precios_socios ps
       ON ps.company_id = p_company_id
      AND ps.socio_id = p_socio_id
      AND ps.material_id = m.id

LEFT JOIN LATERAL (

    SELECT

        ocd.precio_unitario,

        oc.created_at AS fecha

    FROM reciclaje.ordenes_compra_detalle ocd

    JOIN reciclaje.ordenes_compra oc
      ON oc.id = ocd.orden_compra_id

    WHERE oc.company_id = p_company_id
      AND oc.socio_id = p_socio_id
      AND ocd.material_id = m.id

    ORDER BY oc.created_at DESC

    LIMIT 1

) ultimo ON TRUE

WHERE m.company_id = p_company_id
  AND m.id = p_material_id;

$$;


ALTER FUNCTION reciclaje.obtener_precios_material_socio(p_company_id uuid, p_socio_id uuid, p_material_id uuid) OWNER TO postgres;


--
-- Name: obtener_recepcion(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_recepcion(p_company_id uuid, p_id uuid) RETURNS TABLE(id uuid, company_id uuid, codigo text, estado reciclaje.estado_recepcion, orden_compra_id uuid, orden_codigo text, orden_estado reciclaje.estado_orden, socio_id uuid, socio_codigo text, socio_nombre text, transportista_id uuid, transportista_codigo text, transportista_nombre text, transportista_placa text, deposito_id uuid, deposito_codigo text, deposito_nombre text, recibido_por text, observaciones text, subtotal numeric, total numeric, cantidad_materiales bigint, cantidad_total numeric, materiales jsonb, pagos jsonb, created_at timestamp with time zone, confirmed_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT
    r.id,
    r.company_id,
    r.codigo,
    r.estado,

    oc.id AS orden_compra_id,
    oc.codigo AS orden_codigo,
    oc.estado AS orden_estado,

    s.id AS socio_id,
    s.codigo AS socio_codigo,
    s.nombre AS socio_nombre,

    t.id AS transportista_id,
    t.codigo AS transportista_codigo,
    t.nombre AS transportista_nombre,
    t.placa AS transportista_placa,

    d.id AS deposito_id,
    d.codigo AS deposito_codigo,
    d.nombre AS deposito_nombre,

    r.recibido_por,
    r.observaciones,

    COALESCE(
        (
            SELECT SUM(rd.subtotal)
            FROM reciclaje.recepciones_detalle rd
            WHERE rd.recepcion_id = r.id
        ),
        0
    ) AS subtotal,

    COALESCE(
        (
            SELECT SUM(rd.subtotal)
            FROM reciclaje.recepciones_detalle rd
            WHERE rd.recepcion_id = r.id
        ),
        0
    ) AS total,

    (
        SELECT COUNT(*)
        FROM reciclaje.recepciones_detalle rd
        WHERE rd.recepcion_id = r.id
    ) AS cantidad_materiales,

    COALESCE(
        (
            SELECT SUM(rd.cantidad)
            FROM reciclaje.recepciones_detalle rd
            WHERE rd.recepcion_id = r.id
        ),
        0
    ) AS cantidad_total,

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', rd.id,
                    'material_id', rd.material_id,
                    'material_codigo', m.codigo,
                    'material_nombre', m.nombre,
                    'unidad', m.unidad,
                    'cantidad', rd.cantidad,
                    'precio_unitario', rd.precio_unitario,
                    'subtotal', rd.subtotal,
                    'observaciones', rd.observaciones
                )
                ORDER BY m.nombre
            )
            FROM reciclaje.recepciones_detalle rd
            JOIN reciclaje.materiales m
              ON m.id = rd.material_id
             AND m.company_id = p_company_id
            WHERE rd.recepcion_id = r.id
        ),
        '[]'::jsonb
    ) AS materiales,

    COALESCE(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', op.id,
                    'forma_pago_id', op.forma_pago_id,
                    'forma_pago_codigo', fp.codigo,
                    'forma_pago_nombre', fp.nombre,
                    'moneda_id', op.moneda_id,
                    'moneda_codigo', mo.codigo,
                    'moneda_nombre', mo.nombre,
                    'moneda_simbolo', mo.simbolo,
                    'monto', op.monto,
                    'referencia', op.referencia,
                    'observaciones', op.observaciones
                )
                ORDER BY op.created_at
            )
            FROM reciclaje.ordenes_compra_pagos op
            JOIN reciclaje.formas_pago fp
              ON fp.id = op.forma_pago_id
            JOIN reciclaje.monedas mo
              ON mo.id = op.moneda_id
            WHERE op.orden_compra_id = oc.id
        ),
        '[]'::jsonb
    ) AS pagos,

    r.created_at,
    r.confirmed_at

FROM reciclaje.recepciones r

JOIN reciclaje.ordenes_compra oc
  ON oc.id = r.orden_compra_id
 AND oc.company_id = p_company_id

JOIN reciclaje.socios s
  ON s.id = oc.socio_id
 AND s.company_id = p_company_id

JOIN reciclaje.transportistas t
  ON t.id = oc.transportista_id
 AND t.company_id = p_company_id

LEFT JOIN reciclaje.depositos d
  ON d.id = r.deposito_id
 AND d.company_id = p_company_id

WHERE r.company_id = p_company_id
  AND r.id = p_id;

$$;


ALTER FUNCTION reciclaje.obtener_recepcion(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: obtener_socio(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_socio(p_company_id uuid, p_id uuid) RETURNS reciclaje.socios
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$

SELECT *

FROM reciclaje.socios

WHERE company_id = p_company_id
AND id = p_id
AND activo = true;

$$;


ALTER FUNCTION reciclaje.obtener_socio(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: obtener_transportista(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_transportista(p_company_id uuid, p_id uuid) RETURNS reciclaje.transportistas
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
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


ALTER FUNCTION reciclaje.obtener_transportista(p_company_id uuid, p_id uuid) OWNER TO postgres;


--
-- Name: obtener_ultimo_pedido_socio(uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.obtener_ultimo_pedido_socio(p_company_id uuid, p_socio_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE

    v_orden reciclaje.ordenes_compra;
    v_resultado jsonb;

BEGIN

    ----------------------------------------------------
    -- Validar socio
    ----------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.socios
        WHERE company_id = p_company_id
          AND id = p_socio_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'El socio no existe.';
    END IF;

    ----------------------------------------------------
    -- Buscar última orden
    ----------------------------------------------------

    SELECT oc.*
    INTO v_orden
    FROM reciclaje.ordenes_compra oc
    WHERE oc.company_id = p_company_id
      AND oc.socio_id = p_socio_id
    ORDER BY oc.created_at DESC
    LIMIT 1;

    ----------------------------------------------------
    -- Socio sin pedidos
    ----------------------------------------------------

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    ----------------------------------------------------
    -- Construir respuesta
    ----------------------------------------------------

    SELECT jsonb_build_object(

        'id', oc.id,
        'codigo', oc.codigo,

        'socio_id', oc.socio_id,

        'transportista_id', oc.transportista_id,

        'estado', oc.estado,

        'observaciones', oc.observaciones,

        'subtotal', oc.subtotal,
        'total', oc.total,

        'created_at', oc.created_at,

        ------------------------------------------------
        -- Materiales
        ------------------------------------------------

        'materiales',

        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(

                        'material_id', d.material_id,

                        'cantidad', d.cantidad,

                        'precio_unitario', d.precio_unitario,

                        'subtotal', d.subtotal,

                        'material_codigo', m.codigo,

                        'material_nombre', m.nombre,

                        'material_unidad', m.unidad,

                        'precio_base', m.precio_base,

                        'precio_mayorista', m.precio_mayorista,

                        'imagen_url', m.imagen_url

                    )
                    ORDER BY m.nombre
                )

                FROM reciclaje.ordenes_compra_detalle d

                JOIN reciclaje.materiales m
                  ON m.id = d.material_id
                 AND m.company_id = p_company_id

                WHERE d.orden_compra_id = oc.id
            ),
            '[]'::jsonb
        ),

        ------------------------------------------------
        -- Pagos
        ------------------------------------------------

        'pagos',

        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(

                        'forma_pago_id', p.forma_pago_id,

                        'moneda_id', p.moneda_id,

                        'monto', p.monto,

                        'referencia', p.referencia,

                        'observaciones', p.observaciones

                    )
                )

                FROM reciclaje.ordenes_compra_pagos p

                WHERE p.orden_compra_id = oc.id
            ),
            '[]'::jsonb
        )

    )
    INTO v_resultado

    FROM reciclaje.ordenes_compra oc

    WHERE oc.id = v_orden.id
      AND oc.company_id = p_company_id;

    RETURN v_resultado;

END;
$$;


ALTER FUNCTION reciclaje.obtener_ultimo_pedido_socio(p_company_id uuid, p_socio_id uuid) OWNER TO postgres;


--
-- Name: registrar_ajuste(uuid, uuid, uuid, numeric, text, text, uuid, uuid); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.registrar_ajuste(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text DEFAULT NULL::text, p_origen text DEFAULT 'manual'::text, p_origen_id uuid DEFAULT NULL::uuid, p_movimiento_grupo_id uuid DEFAULT NULL::uuid) RETURNS reciclaje.movimientos_stock
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_stock numeric;
    v_stock_resultante numeric;

    v_movimiento reciclaje.movimientos_stock;

BEGIN

    ----------------------------------------------------
    -- VALIDACIONES
    ----------------------------------------------------

    IF p_cantidad IS NULL OR p_cantidad = 0 THEN

        RAISE EXCEPTION
            'El ajuste no puede ser cero.';

    END IF;


    IF NOT EXISTS (

        SELECT 1
        FROM reciclaje.depositos

        WHERE company_id = p_company_id
          AND id = p_deposito_id
          AND activo = true

    ) THEN

        RAISE EXCEPTION
            'Depósito no encontrado.';

    END IF;


    IF NOT EXISTS (

        SELECT 1
        FROM reciclaje.materiales

        WHERE company_id = p_company_id
          AND id = p_material_id
          AND activo = true

    ) THEN

        RAISE EXCEPTION
            'Material no encontrado.';

    END IF;


    ----------------------------------------------------
    -- STOCK ACTUAL DEL DEPÓSITO
    ----------------------------------------------------

    SELECT COALESCE(stock, 0)

    INTO v_stock

    FROM reciclaje.listar_inventario(
        p_company_id,
        p_deposito_id
    )

    WHERE material_id = p_material_id;


    v_stock := COALESCE(v_stock, 0);


    v_stock_resultante :=
        v_stock + p_cantidad;


    ----------------------------------------------------
    -- NO PERMITIR STOCK NEGATIVO
    ----------------------------------------------------

    IF v_stock_resultante < 0 THEN

        RAISE EXCEPTION
            'El ajuste dejaría stock negativo. Stock actual: %, ajuste: %.',
            v_stock,
            p_cantidad;

    END IF;


    ----------------------------------------------------
    -- REGISTRAR MOVIMIENTO
    ----------------------------------------------------

    INSERT INTO reciclaje.movimientos_stock (

        company_id,

        deposito_id,

        material_id,

        tipo_movimiento,

        cantidad,

        origen,

        origen_id,

        observaciones,

        movimiento_grupo_id

    )

    VALUES (

        p_company_id,

        p_deposito_id,

        p_material_id,

        'ajuste',

        p_cantidad,

        COALESCE(
            reciclaje.texto_nulo(p_origen),
            'manual'
        ),

        p_origen_id,

        reciclaje.texto_nulo(p_observaciones),

        p_movimiento_grupo_id

    )

    RETURNING *
    INTO v_movimiento;


    ----------------------------------------------------
    -- ACTUALIZAR STOCK GLOBAL
    ----------------------------------------------------

    UPDATE reciclaje.materiales

    SET

        stock = stock + p_cantidad,

        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_material_id;


    RETURN v_movimiento;

END;
$$;


ALTER FUNCTION reciclaje.registrar_ajuste(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text, p_origen text, p_origen_id uuid, p_movimiento_grupo_id uuid) OWNER TO postgres;


--
-- Name: registrar_ajuste(uuid, uuid, uuid, numeric, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.registrar_ajuste(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text DEFAULT NULL::text) RETURNS reciclaje.movimientos_stock
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_stock numeric;
    v_stock_resultante numeric;

    v_movimiento reciclaje.movimientos_stock;

BEGIN

    ----------------------------------------------------
    -- Validaciones
    ----------------------------------------------------

    IF p_cantidad IS NULL OR p_cantidad = 0 THEN
        RAISE EXCEPTION
        'El ajuste no puede ser cero.';
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.depositos
        WHERE company_id = p_company_id
          AND id = p_deposito_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Depósito no encontrado.';
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.materiales
        WHERE company_id = p_company_id
          AND id = p_material_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Material no encontrado.';
    END IF;


    ----------------------------------------------------
    -- Stock actual
    ----------------------------------------------------

    SELECT COALESCE(stock, 0)
    INTO v_stock
    FROM reciclaje.listar_inventario(
        p_company_id,
        p_deposito_id
    )
    WHERE material_id = p_material_id;


    v_stock := COALESCE(v_stock, 0);

    v_stock_resultante :=
        v_stock + p_cantidad;


    ----------------------------------------------------
    -- No permitir inventario negativo
    ----------------------------------------------------

    IF v_stock_resultante < 0 THEN

        RAISE EXCEPTION
        'El ajuste dejaría stock negativo. Stock actual: %, ajuste: %.',
        v_stock,
        p_cantidad;

    END IF;


    ----------------------------------------------------
    -- Registrar ajuste
    ----------------------------------------------------

    INSERT INTO reciclaje.movimientos_stock (

        company_id,
        deposito_id,
        material_id,

        tipo_movimiento,
        cantidad,

        origen,

        observaciones

    )
    VALUES (

        p_company_id,
        p_deposito_id,
        p_material_id,

        'ajuste',
        p_cantidad,

        'manual',

        reciclaje.texto_nulo(p_observaciones)

    )

    RETURNING *
    INTO v_movimiento;


    ----------------------------------------------------
    -- Stock global
    ----------------------------------------------------

    UPDATE reciclaje.materiales

    SET
        stock = stock + p_cantidad,
        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_material_id;


    RETURN v_movimiento;

END;
$$;


ALTER FUNCTION reciclaje.registrar_ajuste(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text) OWNER TO postgres;


--
-- Name: registrar_salida(uuid, uuid, uuid, numeric, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.registrar_salida(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text DEFAULT NULL::text) RETURNS reciclaje.movimientos_stock
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_stock numeric;
    v_movimiento reciclaje.movimientos_stock;

BEGIN

    ----------------------------------------------------
    -- Validaciones
    ----------------------------------------------------

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION
        'La cantidad debe ser mayor que cero.';
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.depositos
        WHERE company_id = p_company_id
          AND id = p_deposito_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Depósito no encontrado.';
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.materiales
        WHERE company_id = p_company_id
          AND id = p_material_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Material no encontrado.';
    END IF;


    ----------------------------------------------------
    -- Stock disponible
    ----------------------------------------------------

    SELECT COALESCE(stock, 0)
    INTO v_stock
    FROM reciclaje.listar_inventario(
        p_company_id,
        p_deposito_id
    )
    WHERE material_id = p_material_id;


    v_stock := COALESCE(v_stock, 0);


    IF p_cantidad > v_stock THEN

        RAISE EXCEPTION
        'Stock insuficiente. Disponible: %, solicitado: %.',
        v_stock,
        p_cantidad;

    END IF;


    ----------------------------------------------------
    -- Crear salida
    ----------------------------------------------------

    INSERT INTO reciclaje.movimientos_stock (

        company_id,
        deposito_id,
        material_id,

        tipo_movimiento,
        cantidad,

        origen,

        observaciones

    )
    VALUES (

        p_company_id,
        p_deposito_id,
        p_material_id,

        'salida',
        ABS(p_cantidad),

        'manual',

        reciclaje.texto_nulo(p_observaciones)

    )

    RETURNING *
    INTO v_movimiento;


    ----------------------------------------------------
    -- Mantener stock global de materiales
    ----------------------------------------------------

    UPDATE reciclaje.materiales

    SET
        stock = stock - ABS(p_cantidad),
        updated_at = now()

    WHERE company_id = p_company_id
      AND id = p_material_id;


    RETURN v_movimiento;

END;
$$;


ALTER FUNCTION reciclaje.registrar_salida(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text) OWNER TO postgres;


--
-- Name: registrar_traslado(uuid, uuid, uuid, uuid, numeric, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.registrar_traslado(p_company_id uuid, p_deposito_origen_id uuid, p_deposito_destino_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_stock numeric;

    v_grupo_id uuid;

BEGIN

    ----------------------------------------------------
    -- Validaciones
    ----------------------------------------------------

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION
        'La cantidad debe ser mayor que cero.';
    END IF;


    IF p_deposito_origen_id = p_deposito_destino_id THEN
        RAISE EXCEPTION
        'El depósito de origen y destino no pueden ser iguales.';
    END IF;


    ----------------------------------------------------
    -- Validar depósito origen
    ----------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.depositos
        WHERE company_id = p_company_id
          AND id = p_deposito_origen_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION
        'Depósito de origen no encontrado.';
    END IF;


    ----------------------------------------------------
    -- Validar depósito destino
    ----------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.depositos
        WHERE company_id = p_company_id
          AND id = p_deposito_destino_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION
        'Depósito de destino no encontrado.';
    END IF;


    ----------------------------------------------------
    -- Validar material
    ----------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM reciclaje.materiales
        WHERE company_id = p_company_id
          AND id = p_material_id
          AND activo = true
    ) THEN
        RAISE EXCEPTION
        'Material no encontrado.';
    END IF;


    ----------------------------------------------------
    -- Stock disponible en origen
    ----------------------------------------------------

    SELECT COALESCE(stock, 0)
    INTO v_stock
    FROM reciclaje.listar_inventario(
        p_company_id,
        p_deposito_origen_id
    )
    WHERE material_id = p_material_id;


    v_stock := COALESCE(v_stock, 0);


    IF p_cantidad > v_stock THEN

        RAISE EXCEPTION
        'Stock insuficiente en depósito origen. Disponible: %, solicitado: %.',
        v_stock,
        p_cantidad;

    END IF;


    ----------------------------------------------------
    -- Identificador del traslado
    ----------------------------------------------------

    v_grupo_id := gen_random_uuid();


    ----------------------------------------------------
    -- SALIDA DEL DEPÓSITO ORIGEN
    ----------------------------------------------------

    INSERT INTO reciclaje.movimientos_stock (

        company_id,
        deposito_id,
        material_id,

        tipo_movimiento,
        cantidad,

        origen,

        movimiento_grupo_id,

        observaciones

    )
    VALUES (

        p_company_id,
        p_deposito_origen_id,
        p_material_id,

        'traslado',
        -ABS(p_cantidad),

        'traslado',

        v_grupo_id,

        reciclaje.texto_nulo(p_observaciones)

    );


    ----------------------------------------------------
    -- ENTRADA AL DEPÓSITO DESTINO
    ----------------------------------------------------

    INSERT INTO reciclaje.movimientos_stock (

        company_id,
        deposito_id,
        material_id,

        tipo_movimiento,
        cantidad,

        origen,

        movimiento_grupo_id,

        observaciones

    )
    VALUES (

        p_company_id,
        p_deposito_destino_id,
        p_material_id,

        'traslado',
        ABS(p_cantidad),

        'traslado',

        v_grupo_id,

        reciclaje.texto_nulo(p_observaciones)

    );


    ----------------------------------------------------
    -- IMPORTANTE:
    -- NO modificamos materiales.stock.
    --
    -- El material solamente cambió de depósito.
    -- El stock global sigue siendo exactamente el mismo.
    ----------------------------------------------------


    RETURN v_grupo_id;

END;
$$;


ALTER FUNCTION reciclaje.registrar_traslado(p_company_id uuid, p_deposito_origen_id uuid, p_deposito_destino_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text) OWNER TO postgres;


--
-- Name: registrar_venta(uuid, jsonb); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.registrar_venta(p_company_id uuid, p_venta jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_deposito_id uuid;

    v_materiales jsonb;

    v_item jsonb;

    v_material_id uuid;

    v_material_nombre text;

    v_cantidad numeric;

    v_monto numeric(14,2);

    v_moneda text;

    v_tipo_cambio numeric(14,6);

    v_monto_ars numeric(14,2);

    v_forma_pago text;

    v_referencia text;

    v_observaciones text;

    v_descripcion text := '';

    v_movimiento_caja reciclaje.movimientos_caja;

    v_movimiento_stock reciclaje.movimientos_stock;

    v_movimientos_stock jsonb := '[]'::jsonb;

BEGIN

    ------------------------------------------------------------
    -- 1. DATOS GENERALES
    ------------------------------------------------------------

    v_deposito_id :=
        NULLIF(
            p_venta->>'deposito_id',
            ''
        )::uuid;


    IF v_deposito_id IS NULL THEN

        RAISE EXCEPTION
            'Debe indicar el depósito.';

    END IF;


    v_materiales :=
        COALESCE(
            p_venta->'materiales',
            '[]'::jsonb
        );


    IF jsonb_typeof(v_materiales) <> 'array'
       OR jsonb_array_length(v_materiales) = 0
    THEN

        RAISE EXCEPTION
            'Debe indicar al menos un material.';

    END IF;


    ------------------------------------------------------------
    -- 2. MONTO
    ------------------------------------------------------------

    v_monto :=
        COALESCE(
            NULLIF(
                p_venta->>'monto',
                ''
            )::numeric,
            0
        );


    IF v_monto <= 0 THEN

        RAISE EXCEPTION
            'El monto de la venta debe ser mayor a cero.';

    END IF;


    ------------------------------------------------------------
    -- 3. MONEDA
    ------------------------------------------------------------

    v_moneda :=
        UPPER(
            COALESCE(
                NULLIF(
                    trim(p_venta->>'moneda'),
                    ''
                ),
                'ARS'
            )
        );


    IF v_moneda = 'ARS' THEN

        v_tipo_cambio := 1;

    ELSE

        v_tipo_cambio :=
            COALESCE(
                NULLIF(
                    p_venta->>'tipo_cambio',
                    ''
                )::numeric,
                0
            );


        IF v_tipo_cambio <= 0 THEN

            RAISE EXCEPTION
                'Debe indicar un tipo de cambio mayor a cero.';

        END IF;

    END IF;


    v_monto_ars :=
        ROUND(
            v_monto * v_tipo_cambio,
            2
        );


    ------------------------------------------------------------
    -- 4. OTROS DATOS
    ------------------------------------------------------------

    v_forma_pago :=
        reciclaje.texto_nulo(
            p_venta->>'forma_pago'
        );


    v_referencia :=
        reciclaje.texto_nulo(
            p_venta->>'referencia'
        );


    v_observaciones :=
        reciclaje.texto_nulo(
            p_venta->>'observaciones'
        );


    ------------------------------------------------------------
    -- 5. RECORRER MATERIALES
    ------------------------------------------------------------

    FOR v_item IN

        SELECT value
        FROM jsonb_array_elements(v_materiales)

    LOOP

        v_material_id :=
            NULLIF(
                v_item->>'material_id',
                ''
            )::uuid;


        v_cantidad :=
            COALESCE(
                NULLIF(
                    v_item->>'cantidad',
                    ''
                )::numeric,
                0
            );


        IF v_material_id IS NULL THEN

            RAISE EXCEPTION
                'Todos los materiales deben indicar material_id.';

        END IF;


        IF v_cantidad <= 0 THEN

            RAISE EXCEPTION
                'Todas las cantidades deben ser mayores a cero.';

        END IF;


        ------------------------------------------------------------
        -- NOMBRE REAL DEL MATERIAL
        ------------------------------------------------------------

        SELECT nombre

        INTO v_material_nombre

        FROM reciclaje.materiales

        WHERE company_id = p_company_id
          AND id = v_material_id
          AND activo = true;


        IF NOT FOUND THEN

            RAISE EXCEPTION
                'Material no encontrado o inactivo: %.',
                v_material_id;

        END IF;


        ------------------------------------------------------------
        -- CONSTRUIR DESCRIPCIÓN AUTOMÁTICAMENTE
        ------------------------------------------------------------

        IF v_descripcion <> '' THEN

            v_descripcion :=
                v_descripcion || ', ';

        END IF;


        v_descripcion :=
            v_descripcion
            || v_material_nombre
            || ' '
            || v_cantidad;


        ------------------------------------------------------------
        -- REGISTRAR SALIDA DE INVENTARIO
        ------------------------------------------------------------

        SELECT *

        INTO v_movimiento_stock

        FROM reciclaje.registrar_salida(

            p_company_id,

            v_deposito_id,

            v_material_id,

            v_cantidad,

            'Venta de ' ||
            v_material_nombre

        );


        ------------------------------------------------------------
        -- GUARDAR RESULTADO
        ------------------------------------------------------------

        v_movimientos_stock :=
            v_movimientos_stock
            ||
            jsonb_build_array(

                jsonb_build_object(

                    'movimiento_id',
                        v_movimiento_stock.id,

                    'material_id',
                        v_material_id,

                    'material_nombre',
                        v_material_nombre,

                    'cantidad',
                        v_cantidad

                )

            );

    END LOOP;


    ------------------------------------------------------------
    -- 6. REGISTRAR ENTRADA EN CAJA
    ------------------------------------------------------------

    INSERT INTO reciclaje.movimientos_caja (

        company_id,

        tipo,

        monto,

        moneda,

        tipo_cambio,

        monto_ars,

        forma_pago,

        referencia,

        concepto,

        descripcion,

        origen_tipo,

        observaciones

    )

    VALUES (

        p_company_id,

        'entrada',

        v_monto,

        v_moneda,

        v_tipo_cambio,

        v_monto_ars,

        v_forma_pago,

        v_referencia,

        'venta',

        'Venta: ' || v_descripcion,

        'venta',

        v_observaciones

    )

    RETURNING *

    INTO v_movimiento_caja;


    ------------------------------------------------------------
    -- 7. RESPUESTA
    ------------------------------------------------------------

    RETURN jsonb_build_object(

        'ok',
            true,

        'movimiento_caja',
            to_jsonb(v_movimiento_caja),

        'materiales',
            v_movimientos_stock,

        'monto',
            v_monto,

        'moneda',
            v_moneda,

        'tipo_cambio',
            v_tipo_cambio,

        'monto_ars',
            v_monto_ars,

        'descripcion',
            'Venta: ' || v_descripcion

    );

END;
$$;


ALTER FUNCTION reciclaje.registrar_venta(p_company_id uuid, p_venta jsonb) OWNER TO postgres;


--
-- Name: texto_nulo(text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.texto_nulo(p_texto text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT nullif(trim(coalesce(p_texto, '')), '');
$$;


ALTER FUNCTION reciclaje.texto_nulo(p_texto text) OWNER TO postgres;


--
-- Name: transformar_material(uuid, uuid, uuid, numeric, jsonb, text); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.transformar_material(p_company_id uuid, p_deposito_id uuid, p_material_origen_id uuid, p_cantidad_origen numeric, p_resultados jsonb, p_observaciones text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_grupo_id uuid := gen_random_uuid();

    v_item jsonb;

    v_material_destino_id uuid;
    v_cantidad_destino numeric;

    v_movimiento reciclaje.movimientos_stock;

    v_movimientos jsonb := '[]'::jsonb;

    v_total_resultado numeric := 0;
    v_merma numeric := 0;

BEGIN

    ----------------------------------------------------
    -- 1. VALIDAR CANTIDAD DE ORIGEN
    ----------------------------------------------------

    IF p_cantidad_origen IS NULL
       OR p_cantidad_origen <= 0
    THEN

        RAISE EXCEPTION
            'La cantidad a procesar debe ser mayor que cero.';

    END IF;


    ----------------------------------------------------
    -- 2. VALIDAR RESULTADOS
    ----------------------------------------------------

    IF jsonb_typeof(
        COALESCE(
            p_resultados,
            '[]'::jsonb
        )
    ) <> 'array'
    THEN

        RAISE EXCEPTION
            'Los resultados deben ser un array.';

    END IF;


    IF jsonb_array_length(
        COALESCE(
            p_resultados,
            '[]'::jsonb
        )
    ) = 0
    THEN

        RAISE EXCEPTION
            'Debe indicar al menos un material resultante.';

    END IF;


    ----------------------------------------------------
    -- 3. VALIDAR MATERIAL ORIGEN COMO COMPUESTO
    ----------------------------------------------------

    IF NOT EXISTS (

        SELECT 1

        FROM reciclaje.materiales

        WHERE company_id = p_company_id
          AND id = p_material_origen_id
          AND activo = true
          AND compuesto = true

    ) THEN

        RAISE EXCEPTION
            'El material de origen no existe, está inactivo o no es compuesto.';

    END IF;


    ----------------------------------------------------
    -- 4. VALIDAR RESULTADOS Y CALCULAR TOTAL
    --
    -- Todavía NO modificamos inventario.
    ----------------------------------------------------

    FOR v_item IN

        SELECT value

        FROM jsonb_array_elements(
            p_resultados
        )

    LOOP

        v_material_destino_id :=
            NULLIF(
                v_item->>'material_id',
                ''
            )::uuid;


        v_cantidad_destino :=
            NULLIF(
                v_item->>'cantidad',
                ''
            )::numeric;


        IF v_material_destino_id IS NULL THEN

            RAISE EXCEPTION
                'Todos los resultados deben indicar material_id.';

        END IF;


        IF v_cantidad_destino IS NULL
           OR v_cantidad_destino <= 0
        THEN

            RAISE EXCEPTION
                'Todas las cantidades resultantes deben ser mayores que cero.';

        END IF;


        IF v_material_destino_id =
           p_material_origen_id
        THEN

            RAISE EXCEPTION
                'El material resultante no puede ser el mismo material compuesto de origen.';

        END IF;


        IF NOT EXISTS (

            SELECT 1

            FROM reciclaje.materiales

            WHERE company_id = p_company_id
              AND id = v_material_destino_id
              AND activo = true

        ) THEN

            RAISE EXCEPTION
                'Uno de los materiales resultantes no existe o está inactivo.';

        END IF;


        v_total_resultado :=
            v_total_resultado
            + v_cantidad_destino;

    END LOOP;


    ----------------------------------------------------
    -- 5. VALIDAR BALANCE
    ----------------------------------------------------

    IF v_total_resultado > p_cantidad_origen THEN

        RAISE EXCEPTION
            'La cantidad resultante (%) no puede superar la cantidad procesada (%).',
            v_total_resultado,
            p_cantidad_origen;

    END IF;


    v_merma :=
        p_cantidad_origen
        - v_total_resultado;


    ----------------------------------------------------
    -- 6. SACAR MATERIAL COMPUESTO
    --
    -- registrar_ajuste hace:
    -- - validación de stock
    -- - movimiento_stock
    -- - actualización de materiales.stock
    ----------------------------------------------------

    SELECT *

    INTO v_movimiento

    FROM reciclaje.registrar_ajuste(

        p_company_id,

        p_deposito_id,

        p_material_origen_id,

        -ABS(p_cantidad_origen),

        p_observaciones,

        'transformacion',

        v_grupo_id,

        v_grupo_id

    );


    v_movimientos :=
        v_movimientos
        ||
        jsonb_build_array(

            jsonb_build_object(

                'movimiento_id',
                    v_movimiento.id,

                'material_id',
                    p_material_origen_id,

                'cantidad',
                    -ABS(p_cantidad_origen),

                'tipo',
                    'origen'

            )

        );


    ----------------------------------------------------
    -- 7. INGRESAR MATERIALES RESULTANTES
    ----------------------------------------------------

    FOR v_item IN

        SELECT value

        FROM jsonb_array_elements(
            p_resultados
        )

    LOOP

        v_material_destino_id :=
            (v_item->>'material_id')::uuid;


        v_cantidad_destino :=
            (v_item->>'cantidad')::numeric;


        SELECT *

        INTO v_movimiento

        FROM reciclaje.registrar_ajuste(

            p_company_id,

            p_deposito_id,

            v_material_destino_id,

            ABS(v_cantidad_destino),

            p_observaciones,

            'transformacion',

            v_grupo_id,

            v_grupo_id

        );


        v_movimientos :=
            v_movimientos
            ||
            jsonb_build_array(

                jsonb_build_object(

                    'movimiento_id',
                        v_movimiento.id,

                    'material_id',
                        v_material_destino_id,

                    'cantidad',
                        ABS(v_cantidad_destino),

                    'tipo',
                        'resultado'

                )

            );

    END LOOP;


    ----------------------------------------------------
    -- 8. RESULTADO
    ----------------------------------------------------

    RETURN jsonb_build_object(

        'ok',
            true,

        'movimiento_grupo_id',
            v_grupo_id,

        'deposito_id',
            p_deposito_id,

        'material_origen_id',
            p_material_origen_id,

        'cantidad_procesada',
            p_cantidad_origen,

        'cantidad_resultante',
            v_total_resultado,

        'merma',
            v_merma,

        'movimientos',
            v_movimientos

    );

END;
$$;


ALTER FUNCTION reciclaje.transformar_material(p_company_id uuid, p_deposito_id uuid, p_material_origen_id uuid, p_cantidad_origen numeric, p_resultados jsonb, p_observaciones text) OWNER TO postgres;


--
-- Name: upsert_operacion(uuid, jsonb); Type: FUNCTION; Schema: reciclaje; Owner: postgres
--

CREATE FUNCTION reciclaje.upsert_operacion(p_company_id uuid, p_operacion jsonb) RETURNS reciclaje.operaciones
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

    v_operacion reciclaje.operaciones;

    v_id uuid;

    ------------------------------------------------------------
    -- NUEVO: CONTROL DE TRANSICIÓN / CAJA
    ------------------------------------------------------------

    v_etapa_anterior reciclaje.etapa_operacion;

    v_caja jsonb;

    v_monto_caja numeric(14,2);

    v_tipo_cambio numeric(14,6);

    v_monto_ars numeric(14,2);

    v_transportista_nombre text;

BEGIN

    ------------------------------------------------------------
    -- ID OPCIONAL
    ------------------------------------------------------------

    v_id :=
        NULLIF(
            p_operacion->>'id',
            ''
        )::uuid;


    ------------------------------------------------------------
    -- VALIDACIONES BÁSICAS
    ------------------------------------------------------------

    IF p_operacion ? 'monto'
       AND NULLIF(p_operacion->>'monto', '') IS NOT NULL
       AND (p_operacion->>'monto')::numeric < 0
    THEN

        RAISE EXCEPTION
            'El monto no puede ser negativo.';

    END IF;


    IF p_operacion ? 'materiales'
       AND jsonb_typeof(
            COALESCE(
                p_operacion->'materiales',
                '[]'::jsonb
            )
       ) <> 'array'
    THEN

        RAISE EXCEPTION
            'materiales debe ser un array.';

    END IF;


    IF p_operacion ? 'pagos'
       AND jsonb_typeof(
            COALESCE(
                p_operacion->'pagos',
                '[]'::jsonb
            )
       ) <> 'array'
    THEN

        RAISE EXCEPTION
            'pagos debe ser un array.';

    END IF;


    ------------------------------------------------------------
    -- CREAR
    ------------------------------------------------------------

    IF v_id IS NULL THEN

        INSERT INTO reciclaje.operaciones (

            company_id,

            tipo,

            etapa,

            socio_id,

            transportista_id,

            deposito_id,

            monto,

            materiales,

            pagos,

            recibido_por,

            responsable_nombre,

            responsable_tipo,

            observaciones,

            updated_at

        )

        VALUES (

            p_company_id,

            COALESCE(
                NULLIF(p_operacion->>'tipo', '')::reciclaje.tipo_operacion,
                'compra'::reciclaje.tipo_operacion
            ),

            COALESCE(
                NULLIF(p_operacion->>'etapa', '')::reciclaje.etapa_operacion,
                'precarga'::reciclaje.etapa_operacion
            ),

            NULLIF(
                p_operacion->>'socio_id',
                ''
            )::uuid,

            NULLIF(
                p_operacion->>'transportista_id',
                ''
            )::uuid,

            NULLIF(
                p_operacion->>'deposito_id',
                ''
            )::uuid,

            NULLIF(
                p_operacion->>'monto',
                ''
            )::numeric,

            COALESCE(
                p_operacion->'materiales',
                '[]'::jsonb
            ),

            COALESCE(
                p_operacion->'pagos',
                '[]'::jsonb
            ),

            reciclaje.texto_nulo(
                p_operacion->>'recibido_por'
            ),

            reciclaje.texto_nulo(
                p_operacion->>'responsable_nombre'
            ),

            reciclaje.texto_nulo(
                p_operacion->>'responsable_tipo'
            ),

            reciclaje.texto_nulo(
                p_operacion->>'observaciones'
            ),

            now()

        )

        RETURNING *
        INTO v_operacion;


    ------------------------------------------------------------
    -- ACTUALIZAR
    ------------------------------------------------------------

    ELSE

        SELECT *
        INTO v_operacion
        FROM reciclaje.operaciones
        WHERE company_id = p_company_id
          AND id = v_id
        FOR UPDATE;


        IF NOT FOUND THEN

            RAISE EXCEPTION
                'La operación no existe.';

        END IF;


        IF v_operacion.finalizada = true THEN

            RAISE EXCEPTION
                'La operación ya fue finalizada y no puede modificarse.';

        END IF;


        ------------------------------------------------------------
        -- GUARDAR ETAPA ANTERIOR
        ------------------------------------------------------------

        v_etapa_anterior :=
            v_operacion.etapa;


        ------------------------------------------------------------
        -- ACTUALIZACIÓN NORMAL
        ------------------------------------------------------------

        UPDATE reciclaje.operaciones

        SET

            tipo =
                CASE
                    WHEN p_operacion ? 'tipo'
                    THEN NULLIF(
                        p_operacion->>'tipo',
                        ''
                    )::reciclaje.tipo_operacion
                    ELSE tipo
                END,

            etapa =
                CASE
                    WHEN p_operacion ? 'etapa'
                    THEN NULLIF(
                        p_operacion->>'etapa',
                        ''
                    )::reciclaje.etapa_operacion
                    ELSE etapa
                END,

            socio_id =
                CASE
                    WHEN p_operacion ? 'socio_id'
                    THEN NULLIF(
                        p_operacion->>'socio_id',
                        ''
                    )::uuid
                    ELSE socio_id
                END,

            transportista_id =
                CASE
                    WHEN p_operacion ? 'transportista_id'
                    THEN NULLIF(
                        p_operacion->>'transportista_id',
                        ''
                    )::uuid
                    ELSE transportista_id
                END,

            deposito_id =
                CASE
                    WHEN p_operacion ? 'deposito_id'
                    THEN NULLIF(
                        p_operacion->>'deposito_id',
                        ''
                    )::uuid
                    ELSE deposito_id
                END,

            monto =
                CASE
                    WHEN p_operacion ? 'monto'
                    THEN NULLIF(
                        p_operacion->>'monto',
                        ''
                    )::numeric
                    ELSE monto
                END,

            materiales =
                CASE
                    WHEN p_operacion ? 'materiales'
                    THEN COALESCE(
                        p_operacion->'materiales',
                        '[]'::jsonb
                    )
                    ELSE materiales
                END,

            pagos =
                CASE
                    WHEN p_operacion ? 'pagos'
                    THEN COALESCE(
                        p_operacion->'pagos',
                        '[]'::jsonb
                    )
                    ELSE pagos
                END,

            recibido_por =
                CASE
                    WHEN p_operacion ? 'recibido_por'
                    THEN reciclaje.texto_nulo(
                        p_operacion->>'recibido_por'
                    )
                    ELSE recibido_por
                END,

            responsable_nombre =
                CASE
                    WHEN p_operacion ? 'responsable_nombre'
                    THEN reciclaje.texto_nulo(
                        p_operacion->>'responsable_nombre'
                    )
                    ELSE responsable_nombre
                END,

            responsable_tipo =
                CASE
                    WHEN p_operacion ? 'responsable_tipo'
                    THEN reciclaje.texto_nulo(
                        p_operacion->>'responsable_tipo'
                    )
                    ELSE responsable_tipo
                END,

            observaciones =
                CASE
                    WHEN p_operacion ? 'observaciones'
                    THEN reciclaje.texto_nulo(
                        p_operacion->>'observaciones'
                    )
                    ELSE observaciones
                END,

            updated_at = now()

        WHERE company_id = p_company_id
          AND id = v_id

        RETURNING *
        INTO v_operacion;


        ------------------------------------------------------------
        -- NUEVO:
        -- PRECARGA -> EN PROCESO
        --
        -- ESTA ES LA ÚNICA TRANSICIÓN QUE PUEDE GENERAR
        -- UNA SALIDA DE CAJA.
        ------------------------------------------------------------

        IF v_etapa_anterior =
                'precarga'::reciclaje.etapa_operacion

           AND v_operacion.etapa =
                'en_proceso'::reciclaje.etapa_operacion

        THEN

            --------------------------------------------------------
            -- CAJA OPCIONAL
            --
            -- Si no viene caja, equivale a monto 0.
            --------------------------------------------------------

            v_caja :=
                COALESCE(
                    p_operacion->'caja',
                    '{}'::jsonb
                );


            v_monto_caja :=
                COALESCE(
                    NULLIF(
                        v_caja->>'monto',
                        ''
                    )::numeric,
                    0
                );


            --------------------------------------------------------
            -- NO PERMITIR SALIDA NEGATIVA
            --------------------------------------------------------

            IF v_monto_caja < 0 THEN

                RAISE EXCEPTION
                    'El monto entregado no puede ser negativo.';

            END IF;


            --------------------------------------------------------
            -- MONTO 0:
            --
            -- La operación igualmente puede salir.
            -- No existe movimiento físico de dinero.
            --------------------------------------------------------

            IF v_monto_caja > 0 THEN

                ----------------------------------------------------
                -- PARA ENTREGAR DINERO DEBE HABER TRANSPORTISTA
                ----------------------------------------------------

                IF v_operacion.transportista_id IS NULL THEN

                    RAISE EXCEPTION
                        'Debe indicar el transportista antes de entregar dinero.';

                END IF;


                ----------------------------------------------------
                -- MONEDA
                ----------------------------------------------------

                IF NULLIF(
                    trim(v_caja->>'moneda'),
                    ''
                ) IS NULL THEN

                    RAISE EXCEPTION
                        'Debe indicar la moneda del dinero entregado.';

                END IF;


                ----------------------------------------------------
                -- TIPO DE CAMBIO
                ----------------------------------------------------

                v_tipo_cambio :=
                    COALESCE(
                        NULLIF(
                            v_caja->>'tipo_cambio',
                            ''
                        )::numeric,
                        1
                    );


                IF v_tipo_cambio <= 0 THEN

                    RAISE EXCEPTION
                        'El tipo de cambio debe ser mayor a cero.';

                END IF;


                ----------------------------------------------------
                -- EQUIVALENTE ARS
                --
                -- Lo calcula el backend.
                -- El front no tiene que enviar monto_ars.
                ----------------------------------------------------

                v_monto_ars :=
                    ROUND(
                        v_monto_caja * v_tipo_cambio,
                        2
                    );


                ----------------------------------------------------
                -- OBTENER NOMBRE REAL DEL TRANSPORTISTA
                ----------------------------------------------------

                SELECT t.nombre
                INTO v_transportista_nombre
                FROM reciclaje.transportistas t
                WHERE t.company_id = p_company_id
                  AND t.id = v_operacion.transportista_id;


                IF NOT FOUND THEN

                    RAISE EXCEPTION
                        'El transportista indicado no existe.';

                END IF;


                ----------------------------------------------------
                -- REGISTRAR SALIDA REAL DE CAJA
                ----------------------------------------------------

                INSERT INTO reciclaje.movimientos_caja (

                    company_id,

                    tipo,

                    monto,

                    moneda,

                    tipo_cambio,

                    monto_ars,

                    forma_pago,

                    referencia,

                    concepto,

                    descripcion,

                    origen_tipo,

                    origen_id,

                    responsable_tipo,

                    responsable_id,

                    responsable_nombre,

                    comprobante_url,

                    observaciones

                )

                VALUES (

                    p_company_id,

                    'salida',

                    v_monto_caja,

                    trim(
                        v_caja->>'moneda'
                    ),

                    v_tipo_cambio,

                    v_monto_ars,

                    reciclaje.texto_nulo(
                        v_caja->>'forma_pago'
                    ),

                    reciclaje.texto_nulo(
                        v_caja->>'referencia'
                    ),

                    'entrega_operacion',

                    COALESCE(
                        reciclaje.texto_nulo(
                            v_caja->>'descripcion'
                        ),
                        'Entrega de fondos al transportista para iniciar operación'
                    ),

                    'operacion',

                    v_operacion.id,

                    'transportista',

                    v_operacion.transportista_id,

                    v_transportista_nombre,

                    reciclaje.texto_nulo(
                        v_caja->>'comprobante_url'
                    ),

                    reciclaje.texto_nulo(
                        v_caja->>'observaciones'
                    )

                );

            END IF;

        END IF;

    END IF;


    ------------------------------------------------------------
    -- RESULTADO
    ------------------------------------------------------------

    RETURN v_operacion;

END;
$$;


ALTER FUNCTION reciclaje.upsert_operacion(p_company_id uuid, p_operacion jsonb) OWNER TO postgres;



-- ======================================================
-- INDEX
-- ======================================================

--
-- Name: idx_movimientos_stock_deposito; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_movimientos_stock_deposito ON reciclaje.movimientos_stock USING btree (company_id, deposito_id);



--
-- Name: idx_movimientos_stock_grupo; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_movimientos_stock_grupo ON reciclaje.movimientos_stock USING btree (movimiento_grupo_id);



--
-- Name: idx_movimientos_stock_material; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_movimientos_stock_material ON reciclaje.movimientos_stock USING btree (company_id, material_id);



--
-- Name: idx_operaciones_company; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_operaciones_company ON reciclaje.operaciones USING btree (company_id);



--
-- Name: idx_operaciones_finalizada; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_operaciones_finalizada ON reciclaje.operaciones USING btree (company_id, finalizada);



--
-- Name: idx_operaciones_grupo_salida; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_operaciones_grupo_salida ON reciclaje.operaciones USING btree (company_id, grupo_salida_id);



--
-- Name: idx_operaciones_movimiento_salida; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_operaciones_movimiento_salida ON reciclaje.operaciones USING btree (company_id, movimiento_salida_id);



--
-- Name: idx_operaciones_pipeline; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_operaciones_pipeline ON reciclaje.operaciones USING btree (company_id, tipo, etapa);



--
-- Name: idx_operaciones_socio; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_operaciones_socio ON reciclaje.operaciones USING btree (company_id, socio_id);



--
-- Name: idx_operaciones_transportista; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_operaciones_transportista ON reciclaje.operaciones USING btree (company_id, transportista_id);



--
-- Name: idx_precios_socios_company; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_precios_socios_company ON reciclaje.precios_socios USING btree (company_id);



--
-- Name: idx_precios_socios_material; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_precios_socios_material ON reciclaje.precios_socios USING btree (material_id);



--
-- Name: idx_precios_socios_socio; Type: INDEX; Schema: reciclaje; Owner: postgres
--

CREATE INDEX idx_precios_socios_socio ON reciclaje.precios_socios USING btree (socio_id);




-- ======================================================
-- CONSTRAINT
-- ======================================================

--
-- Name: depositos depositos_codigo_key; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.depositos
    ADD CONSTRAINT depositos_codigo_key UNIQUE (codigo);



--
-- Name: depositos depositos_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.depositos
    ADD CONSTRAINT depositos_pkey PRIMARY KEY (id);



--
-- Name: finanzas finanzas_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.finanzas
    ADD CONSTRAINT finanzas_pkey PRIMARY KEY (id);



--
-- Name: formas_pago formas_pago_codigo_key; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.formas_pago
    ADD CONSTRAINT formas_pago_codigo_key UNIQUE (codigo);



--
-- Name: formas_pago formas_pago_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.formas_pago
    ADD CONSTRAINT formas_pago_pkey PRIMARY KEY (id);



--
-- Name: materiales materiales_codigo_key; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.materiales
    ADD CONSTRAINT materiales_codigo_key UNIQUE (codigo);



--
-- Name: materiales materiales_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.materiales
    ADD CONSTRAINT materiales_pkey PRIMARY KEY (id);



--
-- Name: monedas monedas_codigo_key; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.monedas
    ADD CONSTRAINT monedas_codigo_key UNIQUE (codigo);



--
-- Name: monedas monedas_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.monedas
    ADD CONSTRAINT monedas_pkey PRIMARY KEY (id);



--
-- Name: movimientos_caja movimientos_caja_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.movimientos_caja
    ADD CONSTRAINT movimientos_caja_pkey PRIMARY KEY (id);



--
-- Name: movimientos_stock movimientos_stock_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.movimientos_stock
    ADD CONSTRAINT movimientos_stock_pkey PRIMARY KEY (id);



--
-- Name: numeradores numeradores_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.numeradores
    ADD CONSTRAINT numeradores_pkey PRIMARY KEY (company_id, tipo_documento);



--
-- Name: operaciones operaciones_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.operaciones
    ADD CONSTRAINT operaciones_pkey PRIMARY KEY (id);



--
-- Name: ordenes_compra ordenes_compra_codigo_key; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra
    ADD CONSTRAINT ordenes_compra_codigo_key UNIQUE (codigo);



--
-- Name: ordenes_compra ordenes_compra_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra
    ADD CONSTRAINT ordenes_compra_pkey PRIMARY KEY (id);



--
-- Name: ordenes_compra_detalle ordenes_compra_detalle_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra_detalle
    ADD CONSTRAINT ordenes_compra_detalle_pkey PRIMARY KEY (id);



--
-- Name: ordenes_compra_pagos ordenes_compra_pagos_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra_pagos
    ADD CONSTRAINT ordenes_compra_pagos_pkey PRIMARY KEY (id);



--
-- Name: precios_socios precios_socios_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.precios_socios
    ADD CONSTRAINT precios_socios_pkey PRIMARY KEY (id);



--
-- Name: precios_socios precios_socios_unique; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.precios_socios
    ADD CONSTRAINT precios_socios_unique UNIQUE (company_id, socio_id, material_id);



--
-- Name: recepciones recepciones_codigo_key; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.recepciones
    ADD CONSTRAINT recepciones_codigo_key UNIQUE (codigo);



--
-- Name: recepciones recepciones_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.recepciones
    ADD CONSTRAINT recepciones_pkey PRIMARY KEY (id);



--
-- Name: recepciones_detalle recepciones_detalle_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.recepciones_detalle
    ADD CONSTRAINT recepciones_detalle_pkey PRIMARY KEY (id);



--
-- Name: socios socios_codigo_key; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.socios
    ADD CONSTRAINT socios_codigo_key UNIQUE (codigo);



--
-- Name: socios socios_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.socios
    ADD CONSTRAINT socios_pkey PRIMARY KEY (id);



--
-- Name: transportistas transportistas_codigo_key; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.transportistas
    ADD CONSTRAINT transportistas_codigo_key UNIQUE (codigo);



--
-- Name: transportistas transportistas_pkey; Type: CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.transportistas
    ADD CONSTRAINT transportistas_pkey PRIMARY KEY (id);




-- ======================================================
-- ACL
-- ======================================================

--
-- Name: FUNCTION actualizar_deposito(p_company_id uuid, p_id uuid, p_nombre text, p_direccion text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.actualizar_deposito(p_company_id uuid, p_id uuid, p_nombre text, p_direccion text) TO tenant_app;



--
-- Name: FUNCTION actualizar_finanza(p_company_id uuid, p_finanza_id uuid, p_tipo text, p_tipo_cambio numeric, p_importe_base numeric, p_origen_tipo text, p_origen_id uuid, p_fecha_vencimiento timestamp with time zone, p_observaciones text, p_responsable_nombre text, p_responsable_telefono text, p_responsable_tipo text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.actualizar_finanza(p_company_id uuid, p_finanza_id uuid, p_tipo text, p_tipo_cambio numeric, p_importe_base numeric, p_origen_tipo text, p_origen_id uuid, p_fecha_vencimiento timestamp with time zone, p_observaciones text, p_responsable_nombre text, p_responsable_telefono text, p_responsable_tipo text) TO tenant_app;



--
-- Name: FUNCTION actualizar_material(p_company_id uuid, p_id uuid, p_nombre text, p_unidad text, p_metadata jsonb, p_precio_base numeric, p_precio_mayorista numeric, p_imagen_url text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.actualizar_material(p_company_id uuid, p_id uuid, p_nombre text, p_unidad text, p_metadata jsonb, p_precio_base numeric, p_precio_mayorista numeric, p_imagen_url text) TO tenant_app;



--
-- Name: FUNCTION actualizar_orden_compra(p_company_id uuid, p_orden_id uuid, p_orden jsonb); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.actualizar_orden_compra(p_company_id uuid, p_orden_id uuid, p_orden jsonb) TO tenant_app;



--
-- Name: FUNCTION actualizar_recepcion(p_company_id uuid, p_recepcion_id uuid, p_recepcion jsonb); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.actualizar_recepcion(p_company_id uuid, p_recepcion_id uuid, p_recepcion jsonb) TO tenant_app;



--
-- Name: FUNCTION actualizar_socio(p_company_id uuid, p_id uuid, p_nombre text, p_documento text, p_telefono text, p_direccion text, p_observaciones text, p_latitud numeric, p_longitud numeric); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.actualizar_socio(p_company_id uuid, p_id uuid, p_nombre text, p_documento text, p_telefono text, p_direccion text, p_observaciones text, p_latitud numeric, p_longitud numeric) TO tenant_app;



--
-- Name: FUNCTION actualizar_stock_material(p_company_id uuid, p_material_id uuid, p_cantidad numeric); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.actualizar_stock_material(p_company_id uuid, p_material_id uuid, p_cantidad numeric) TO tenant_app;



--
-- Name: FUNCTION actualizar_transportista(p_company_id uuid, p_id uuid, p_nombre text, p_telefono text, p_placa text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.actualizar_transportista(p_company_id uuid, p_id uuid, p_nombre text, p_telefono text, p_placa text) TO tenant_app;



--
-- Name: FUNCTION anular_finanza(p_company_id uuid, p_finanza_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.anular_finanza(p_company_id uuid, p_finanza_id uuid) TO tenant_app;



--
-- Name: FUNCTION bootstrap(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.bootstrap(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION cancelar_recepcion(p_company_id uuid, p_recepcion_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.cancelar_recepcion(p_company_id uuid, p_recepcion_id uuid) TO tenant_app;



--
-- Name: FUNCTION confirmar_operacion(p_company_id uuid, p_operacion_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.confirmar_operacion(p_company_id uuid, p_operacion_id uuid) TO tenant_app;



--
-- Name: FUNCTION confirmar_operaciones_transportista(p_company_id uuid, p_transportista_id uuid, p_datos jsonb); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.confirmar_operaciones_transportista(p_company_id uuid, p_transportista_id uuid, p_datos jsonb) TO tenant_app;



--
-- Name: FUNCTION confirmar_recepcion(p_company_id uuid, p_recepcion_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.confirmar_recepcion(p_company_id uuid, p_recepcion_id uuid) TO tenant_app;



--
-- Name: FUNCTION crear_deposito(p_company_id uuid, p_nombre text, p_direccion text, p_activo boolean); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.crear_deposito(p_company_id uuid, p_nombre text, p_direccion text, p_activo boolean) TO tenant_app;



--
-- Name: FUNCTION crear_finanza(p_company_id uuid, p_tipo text, p_tipo_cambio numeric, p_importe_base numeric, p_origen_tipo text, p_origen_id uuid, p_fecha_vencimiento timestamp with time zone, p_observaciones text, p_responsable_nombre text, p_responsable_telefono text, p_responsable_tipo text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.crear_finanza(p_company_id uuid, p_tipo text, p_tipo_cambio numeric, p_importe_base numeric, p_origen_tipo text, p_origen_id uuid, p_fecha_vencimiento timestamp with time zone, p_observaciones text, p_responsable_nombre text, p_responsable_telefono text, p_responsable_tipo text) TO tenant_app;



--
-- Name: FUNCTION crear_material(p_company_id uuid, p_nombre text, p_unidad text, p_metadata jsonb, p_precio_base numeric, p_precio_mayorista numeric, p_imagen_url text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.crear_material(p_company_id uuid, p_nombre text, p_unidad text, p_metadata jsonb, p_precio_base numeric, p_precio_mayorista numeric, p_imagen_url text) TO tenant_app;



--
-- Name: FUNCTION crear_orden_compra(p_company_id uuid, p_orden jsonb); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.crear_orden_compra(p_company_id uuid, p_orden jsonb) TO tenant_app;



--
-- Name: FUNCTION crear_recepcion(p_company_id uuid, p_orden_compra_id uuid, p_recibido_por text, p_observaciones text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.crear_recepcion(p_company_id uuid, p_orden_compra_id uuid, p_recibido_por text, p_observaciones text) TO tenant_app;



--
-- Name: FUNCTION crear_socio(p_company_id uuid, p_nombre text, p_documento text, p_telefono text, p_direccion text, p_observaciones text, p_latitud numeric, p_longitud numeric); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.crear_socio(p_company_id uuid, p_nombre text, p_documento text, p_telefono text, p_direccion text, p_observaciones text, p_latitud numeric, p_longitud numeric) TO tenant_app;



--
-- Name: FUNCTION crear_transportista(p_company_id uuid, p_nombre text, p_telefono text, p_placa text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.crear_transportista(p_company_id uuid, p_nombre text, p_telefono text, p_placa text) TO tenant_app;



--
-- Name: FUNCTION eliminar_deposito(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.eliminar_deposito(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION eliminar_finanza(p_company_id uuid, p_finanza_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.eliminar_finanza(p_company_id uuid, p_finanza_id uuid) TO tenant_app;



--
-- Name: FUNCTION eliminar_material(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.eliminar_material(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION eliminar_operacion_multicarga(p_company_id uuid, p_operacion_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.eliminar_operacion_multicarga(p_company_id uuid, p_operacion_id uuid) TO tenant_app;



--
-- Name: FUNCTION eliminar_operacion(p_company_id uuid, p_operacion_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.eliminar_operacion(p_company_id uuid, p_operacion_id uuid) TO tenant_app;



--
-- Name: FUNCTION eliminar_orden_compra(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.eliminar_orden_compra(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION eliminar_socio(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.eliminar_socio(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION eliminar_transportista(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.eliminar_transportista(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION enum_to_json(p_enum text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.enum_to_json(p_enum text) TO tenant_app;



--
-- Name: FUNCTION generar_codigo(p_company_id uuid, p_tipo_documento text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.generar_codigo(p_company_id uuid, p_tipo_documento text) TO tenant_app;



--
-- Name: FUNCTION guardar_precio_socio(p_company_id uuid, p_socio_id uuid, p_material_id uuid, p_precio numeric, p_observaciones text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.guardar_precio_socio(p_company_id uuid, p_socio_id uuid, p_material_id uuid, p_precio numeric, p_observaciones text) TO tenant_app;



--
-- Name: FUNCTION iniciar_operaciones_multicarga(p_company_id uuid, p_datos jsonb); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.iniciar_operaciones_multicarga(p_company_id uuid, p_datos jsonb) TO tenant_app;



--
-- Name: FUNCTION limpiar_texto(p_texto text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.limpiar_texto(p_texto text) TO tenant_app;



--
-- Name: FUNCTION listar_depositos(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_depositos(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_finanzas(p_company_id uuid, p_incluir_anuladas boolean); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_finanzas(p_company_id uuid, p_incluir_anuladas boolean) TO tenant_app;



--
-- Name: FUNCTION listar_finanzas(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_finanzas(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_inventario(p_company_id uuid, p_deposito_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_inventario(p_company_id uuid, p_deposito_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_materiales(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_materiales(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_movimientos_caja(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_movimientos_caja(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_movimientos_stock(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_tipo_movimiento reciclaje.tipo_movimiento, p_limite integer); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_movimientos_stock(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_tipo_movimiento reciclaje.tipo_movimiento, p_limite integer) TO tenant_app;



--
-- Name: FUNCTION listar_operaciones(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_operaciones(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_ordenes_compra(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_ordenes_compra(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_recepciones(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_recepciones(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_socios(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_socios(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION listar_transportistas(p_company_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.listar_transportistas(p_company_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_deposito(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_deposito(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_finanza(p_company_id uuid, p_finanza_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_finanza(p_company_id uuid, p_finanza_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_material(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_material(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_operacion(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_operacion(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_orden_compra(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_orden_compra(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_precios_material_socio(p_company_id uuid, p_socio_id uuid, p_material_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_precios_material_socio(p_company_id uuid, p_socio_id uuid, p_material_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_recepcion(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_recepcion(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_socio(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_socio(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_transportista(p_company_id uuid, p_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_transportista(p_company_id uuid, p_id uuid) TO tenant_app;



--
-- Name: FUNCTION obtener_ultimo_pedido_socio(p_company_id uuid, p_socio_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.obtener_ultimo_pedido_socio(p_company_id uuid, p_socio_id uuid) TO tenant_app;



--
-- Name: FUNCTION registrar_ajuste(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text, p_origen text, p_origen_id uuid, p_movimiento_grupo_id uuid); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.registrar_ajuste(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text, p_origen text, p_origen_id uuid, p_movimiento_grupo_id uuid) TO tenant_app;



--
-- Name: FUNCTION registrar_ajuste(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.registrar_ajuste(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text) TO tenant_app;



--
-- Name: FUNCTION registrar_salida(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.registrar_salida(p_company_id uuid, p_deposito_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text) TO tenant_app;



--
-- Name: FUNCTION registrar_traslado(p_company_id uuid, p_deposito_origen_id uuid, p_deposito_destino_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.registrar_traslado(p_company_id uuid, p_deposito_origen_id uuid, p_deposito_destino_id uuid, p_material_id uuid, p_cantidad numeric, p_observaciones text) TO tenant_app;



--
-- Name: FUNCTION registrar_venta(p_company_id uuid, p_venta jsonb); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.registrar_venta(p_company_id uuid, p_venta jsonb) TO tenant_app;



--
-- Name: FUNCTION texto_nulo(p_texto text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.texto_nulo(p_texto text) TO tenant_app;



--
-- Name: FUNCTION transformar_material(p_company_id uuid, p_deposito_id uuid, p_material_origen_id uuid, p_cantidad_origen numeric, p_resultados jsonb, p_observaciones text); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.transformar_material(p_company_id uuid, p_deposito_id uuid, p_material_origen_id uuid, p_cantidad_origen numeric, p_resultados jsonb, p_observaciones text) TO tenant_app;



--
-- Name: FUNCTION upsert_operacion(p_company_id uuid, p_operacion jsonb); Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT ALL ON FUNCTION reciclaje.upsert_operacion(p_company_id uuid, p_operacion jsonb) TO tenant_app;



--
-- Name: SCHEMA reciclaje; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA reciclaje TO tenant_app;



--
-- Name: TABLE depositos; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.depositos TO tenant_app;



--
-- Name: TABLE finanzas; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.finanzas TO tenant_app;



--
-- Name: TABLE formas_pago; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.formas_pago TO tenant_app;



--
-- Name: TABLE materiales; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.materiales TO tenant_app;



--
-- Name: TABLE monedas; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.monedas TO tenant_app;



--
-- Name: TABLE movimientos_caja; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.movimientos_caja TO tenant_app;



--
-- Name: TABLE movimientos_stock; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.movimientos_stock TO tenant_app;



--
-- Name: TABLE numeradores; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.numeradores TO tenant_app;



--
-- Name: TABLE operaciones; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.operaciones TO tenant_app;



--
-- Name: TABLE ordenes_compra; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.ordenes_compra TO tenant_app;



--
-- Name: TABLE ordenes_compra_detalle; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.ordenes_compra_detalle TO tenant_app;



--
-- Name: TABLE ordenes_compra_pagos; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.ordenes_compra_pagos TO tenant_app;



--
-- Name: TABLE precios_socios; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.precios_socios TO tenant_app;



--
-- Name: TABLE recepciones; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.recepciones TO tenant_app;



--
-- Name: TABLE recepciones_detalle; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.recepciones_detalle TO tenant_app;



--
-- Name: TABLE socios; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.socios TO tenant_app;



--
-- Name: TABLE transportistas; Type: ACL; Schema: reciclaje; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE reciclaje.transportistas TO tenant_app;




-- ======================================================
-- OTHER
-- ======================================================

--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: reciclaje; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA reciclaje GRANT ALL ON FUNCTIONS  TO tenant_app;



--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: reciclaje; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA reciclaje GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO tenant_app;


--
-- PostgreSQL database dump complete
--

\unrestrict OEw3QvX7RxrJtsACu9vbXxTAy9erS3h51xPBMd42d44sdtcR5GHKnbxHp56B2tQ


--
-- Name: movimientos_stock movimientos_stock_deposito_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.movimientos_stock
    ADD CONSTRAINT movimientos_stock_deposito_fk FOREIGN KEY (deposito_id) REFERENCES reciclaje.depositos(id);



--
-- Name: movimientos_stock movimientos_stock_material_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.movimientos_stock
    ADD CONSTRAINT movimientos_stock_material_id_fkey FOREIGN KEY (material_id) REFERENCES reciclaje.materiales(id);



--
-- Name: movimientos_stock movimientos_stock_orden_compra_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.movimientos_stock
    ADD CONSTRAINT movimientos_stock_orden_compra_id_fkey FOREIGN KEY (orden_compra_id) REFERENCES reciclaje.ordenes_compra(id);



--
-- Name: movimientos_stock movimientos_stock_recepcion_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.movimientos_stock
    ADD CONSTRAINT movimientos_stock_recepcion_id_fkey FOREIGN KEY (recepcion_id) REFERENCES reciclaje.recepciones(id);



--
-- Name: movimientos_stock movimientos_stock_socio_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.movimientos_stock
    ADD CONSTRAINT movimientos_stock_socio_id_fkey FOREIGN KEY (socio_id) REFERENCES reciclaje.socios(id);



--
-- Name: movimientos_stock movimientos_stock_transportista_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.movimientos_stock
    ADD CONSTRAINT movimientos_stock_transportista_id_fkey FOREIGN KEY (transportista_id) REFERENCES reciclaje.transportistas(id);



--
-- Name: operaciones operaciones_deposito_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.operaciones
    ADD CONSTRAINT operaciones_deposito_fk FOREIGN KEY (deposito_id) REFERENCES reciclaje.depositos(id);



--
-- Name: operaciones operaciones_finanza_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.operaciones
    ADD CONSTRAINT operaciones_finanza_fk FOREIGN KEY (finanza_id) REFERENCES reciclaje.finanzas(id);



--
-- Name: operaciones operaciones_orden_compra_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.operaciones
    ADD CONSTRAINT operaciones_orden_compra_fk FOREIGN KEY (orden_compra_id) REFERENCES reciclaje.ordenes_compra(id);



--
-- Name: operaciones operaciones_recepcion_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.operaciones
    ADD CONSTRAINT operaciones_recepcion_fk FOREIGN KEY (recepcion_id) REFERENCES reciclaje.recepciones(id);



--
-- Name: operaciones operaciones_socio_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.operaciones
    ADD CONSTRAINT operaciones_socio_fk FOREIGN KEY (socio_id) REFERENCES reciclaje.socios(id);



--
-- Name: operaciones operaciones_transportista_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.operaciones
    ADD CONSTRAINT operaciones_transportista_fk FOREIGN KEY (transportista_id) REFERENCES reciclaje.transportistas(id);



--
-- Name: ordenes_compra ordenes_compra_socio_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra
    ADD CONSTRAINT ordenes_compra_socio_id_fkey FOREIGN KEY (socio_id) REFERENCES reciclaje.socios(id);



--
-- Name: ordenes_compra ordenes_compra_transportista_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra
    ADD CONSTRAINT ordenes_compra_transportista_id_fkey FOREIGN KEY (transportista_id) REFERENCES reciclaje.transportistas(id);



--
-- Name: ordenes_compra_detalle ordenes_compra_detalle_material_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra_detalle
    ADD CONSTRAINT ordenes_compra_detalle_material_id_fkey FOREIGN KEY (material_id) REFERENCES reciclaje.materiales(id);



--
-- Name: ordenes_compra_detalle ordenes_compra_detalle_orden_compra_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra_detalle
    ADD CONSTRAINT ordenes_compra_detalle_orden_compra_id_fkey FOREIGN KEY (orden_compra_id) REFERENCES reciclaje.ordenes_compra(id) ON DELETE CASCADE;



--
-- Name: ordenes_compra_pagos ordenes_compra_pagos_forma_pago_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra_pagos
    ADD CONSTRAINT ordenes_compra_pagos_forma_pago_id_fkey FOREIGN KEY (forma_pago_id) REFERENCES reciclaje.formas_pago(id);



--
-- Name: ordenes_compra_pagos ordenes_compra_pagos_moneda_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra_pagos
    ADD CONSTRAINT ordenes_compra_pagos_moneda_id_fkey FOREIGN KEY (moneda_id) REFERENCES reciclaje.monedas(id);



--
-- Name: ordenes_compra_pagos ordenes_compra_pagos_orden_compra_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.ordenes_compra_pagos
    ADD CONSTRAINT ordenes_compra_pagos_orden_compra_id_fkey FOREIGN KEY (orden_compra_id) REFERENCES reciclaje.ordenes_compra(id) ON DELETE CASCADE;



--
-- Name: precios_socios precios_socios_material_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.precios_socios
    ADD CONSTRAINT precios_socios_material_fk FOREIGN KEY (material_id) REFERENCES reciclaje.materiales(id) ON DELETE CASCADE;



--
-- Name: precios_socios precios_socios_socio_fk; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.precios_socios
    ADD CONSTRAINT precios_socios_socio_fk FOREIGN KEY (socio_id) REFERENCES reciclaje.socios(id) ON DELETE CASCADE;



--
-- Name: recepciones recepciones_deposito_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.recepciones
    ADD CONSTRAINT recepciones_deposito_id_fkey FOREIGN KEY (deposito_id) REFERENCES reciclaje.depositos(id);



--
-- Name: recepciones recepciones_orden_compra_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.recepciones
    ADD CONSTRAINT recepciones_orden_compra_id_fkey FOREIGN KEY (orden_compra_id) REFERENCES reciclaje.ordenes_compra(id);



--
-- Name: recepciones_detalle recepciones_detalle_material_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.recepciones_detalle
    ADD CONSTRAINT recepciones_detalle_material_id_fkey FOREIGN KEY (material_id) REFERENCES reciclaje.materiales(id);



--
-- Name: recepciones_detalle recepciones_detalle_recepcion_id_fkey; Type: FK CONSTRAINT; Schema: reciclaje; Owner: postgres
--

ALTER TABLE ONLY reciclaje.recepciones_detalle
    ADD CONSTRAINT recepciones_detalle_recepcion_id_fkey FOREIGN KEY (recepcion_id) REFERENCES reciclaje.recepciones(id) ON DELETE CASCADE;


