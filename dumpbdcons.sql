--
-- PostgreSQL database dump
--

\restrict jmGltIKL8xf0SxSFwo25521ItiNZO5QJguQIGhgDl2m20VBCfQSGXahAwUpfMqg

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

--
-- Name: constructora; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA constructora;


ALTER SCHEMA constructora OWNER TO postgres;

--
-- Name: actualizar_imagen_editada(uuid, text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.actualizar_imagen_editada(p_id uuid, p_url_nueva text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_url_anterior text;
    v_result jsonb;
BEGIN

    IF COALESCE(TRIM(p_url_nueva), '') = '' THEN
        RAISE EXCEPTION 'La nueva URL es obligatoria';
    END IF;

    SELECT url_editada
    INTO v_url_anterior
    FROM constructora.imagenes_pendientes
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Imagen no encontrada: %', p_id;
    END IF;

    UPDATE constructora.imagenes_pendientes
    SET url_editada = TRIM(p_url_nueva)
    WHERE id = p_id;

    SELECT jsonb_build_object(
        'id', ip.id,
        'proyecto_id', ip.proyecto_id,

        'url_original', ip.url_temporal,

        'url_editada', ip.url_editada,

        'url_editada_anterior', v_url_anterior,

        'estado', ip.estado
    )
    INTO v_result
    FROM constructora.imagenes_pendientes ip
    WHERE ip.id = p_id;

    RETURN v_result;

END;
$$;


ALTER FUNCTION constructora.actualizar_imagen_editada(p_id uuid, p_url_nueva text) OWNER TO postgres;

--
-- Name: actualizar_progreso_proyecto(); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.actualizar_progreso_proyecto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_proyecto_id uuid;
BEGIN

    -- ========================================================
    -- RECALCULAR PROYECTO ACTUAL
    -- ========================================================

    IF TG_OP <> 'DELETE' THEN

        UPDATE constructora.proyectos p
        SET
            progreso = COALESCE(
                (
                    SELECT ROUND(AVG(c.progreso))::smallint
                    FROM constructora.cronograma c
                    WHERE c.proyecto_id = NEW.proyecto_id
                ),
                0
            ),
            updated_at = now()
        WHERE p.id = NEW.proyecto_id;

    END IF;


    -- ========================================================
    -- RECALCULAR PROYECTO ANTERIOR
    -- DELETE o cambio de proyecto
    -- ========================================================

    IF TG_OP = 'DELETE'
       OR (
            TG_OP = 'UPDATE'
            AND OLD.proyecto_id IS DISTINCT FROM NEW.proyecto_id
       )
    THEN

        v_proyecto_id := OLD.proyecto_id;

        UPDATE constructora.proyectos p
        SET
            progreso = COALESCE(
                (
                    SELECT ROUND(AVG(c.progreso))::smallint
                    FROM constructora.cronograma c
                    WHERE c.proyecto_id = v_proyecto_id
                ),
                0
            ),
            updated_at = now()
        WHERE p.id = v_proyecto_id;

    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION constructora.actualizar_progreso_proyecto() OWNER TO postgres;

--
-- Name: aprobar_imagen(uuid, character varying, integer, uuid); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.aprobar_imagen(p_id uuid, p_destino character varying, p_orden integer DEFAULT 0, p_avance_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_imagen constructora.imagenes_pendientes%ROWTYPE;
    v_url text;
    v_publicacion_id uuid;
BEGIN

    -- ========================================================
    -- OBTENER IMAGEN DEL BANCO
    -- ========================================================

    SELECT *
    INTO v_imagen
    FROM constructora.imagenes_pendientes
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Imagen no encontrada: %', p_id;
    END IF;


    -- ========================================================
    -- ELEGIR VERSIÓN
    -- editada tiene prioridad sobre original
    -- ========================================================

    v_url := COALESCE(
        NULLIF(v_imagen.url_editada, ''),
        v_imagen.url_temporal
    );


    -- ========================================================
    -- VALIDAR DESTINO
    -- ========================================================

    IF p_destino NOT IN ('portada', 'galeria', 'avance') THEN
        RAISE EXCEPTION
            'Destino inválido. Use portada, galeria o avance';
    END IF;


    -- ========================================================
    -- PORTADA
    -- Una sola portada por proyecto
    -- ========================================================

    IF p_destino = 'portada' THEN

        -- Quitar solamente el uso como portada anterior.
        -- La imagen anterior sigue existiendo en el banco
        -- y puede seguir estando en galería/avances.
        DELETE FROM constructora.proyecto_imagenes
        WHERE proyecto_id = v_imagen.proyecto_id
          AND tipo = 'portada';


        INSERT INTO constructora.proyecto_imagenes (
            proyecto_id,
            imagen_origen_id,
            url,
            titulo,
            descripcion,
            tipo,
            orden,
            publicada
        )
        VALUES (
            v_imagen.proyecto_id,
            v_imagen.id,
            v_url,
            v_imagen.titulo,
            v_imagen.descripcion,
            'portada',
            0,
            true
        )
        RETURNING id INTO v_publicacion_id;


        -- Mantener acceso rápido a portada
        UPDATE constructora.proyectos
        SET
            imagen_portada = v_url,
            updated_at = now()
        WHERE id = v_imagen.proyecto_id;


    -- ========================================================
    -- GALERÍA
    -- Una imagen puede aparecer una vez en la galería
    -- ========================================================

    ELSIF p_destino = 'galeria' THEN

        SELECT id
        INTO v_publicacion_id
        FROM constructora.proyecto_imagenes
        WHERE proyecto_id = v_imagen.proyecto_id
          AND imagen_origen_id = v_imagen.id
          AND tipo = 'galeria'
        LIMIT 1;


        IF v_publicacion_id IS NULL THEN

            INSERT INTO constructora.proyecto_imagenes (
                proyecto_id,
                imagen_origen_id,
                url,
                titulo,
                descripcion,
                tipo,
                orden,
                publicada
            )
            VALUES (
                v_imagen.proyecto_id,
                v_imagen.id,
                v_url,
                v_imagen.titulo,
                v_imagen.descripcion,
                'galeria',
                COALESCE(p_orden, 0),
                true
            )
            RETURNING id INTO v_publicacion_id;

        ELSE

            -- Si ya estaba en galería actualizamos versión,
            -- orden y metadatos.
            UPDATE constructora.proyecto_imagenes
            SET
                url = v_url,
                titulo = v_imagen.titulo,
                descripcion = v_imagen.descripcion,
                orden = COALESCE(p_orden, orden),
                publicada = true
            WHERE id = v_publicacion_id;

        END IF;


    -- ========================================================
    -- AVANCE
    -- ========================================================

    ELSIF p_destino = 'avance' THEN

        IF p_avance_id IS NULL THEN
            RAISE EXCEPTION
                'avance_id es obligatorio para destino avance';
        END IF;


        -- El avance debe pertenecer al mismo proyecto.
        IF NOT EXISTS (
            SELECT 1
            FROM constructora.avances a
            WHERE a.id = p_avance_id
              AND a.proyecto_id = v_imagen.proyecto_id
        ) THEN
            RAISE EXCEPTION
                'El avance no existe o pertenece a otro proyecto';
        END IF;


        -- Buscar si ya está utilizada en este avance.
        SELECT id
        INTO v_publicacion_id
        FROM constructora.avance_imagenes
        WHERE avance_id = p_avance_id
          AND imagen_origen_id = v_imagen.id
        LIMIT 1;


        IF v_publicacion_id IS NULL THEN

            INSERT INTO constructora.avance_imagenes (
                avance_id,
                imagen_origen_id,
                url,
                descripcion,
                orden
            )
            VALUES (
                p_avance_id,
                v_imagen.id,
                v_url,
                v_imagen.descripcion,
                COALESCE(p_orden, 0)
            )
            RETURNING id INTO v_publicacion_id;

        ELSE

            UPDATE constructora.avance_imagenes
            SET
                url = v_url,
                descripcion = v_imagen.descripcion,
                orden = COALESCE(p_orden, orden)
            WHERE id = v_publicacion_id;

        END IF;

    END IF;


    -- ========================================================
    -- MARCAR COMO APROBADA
    -- ========================================================

    UPDATE constructora.imagenes_pendientes
    SET
        estado = 'aprobada',
        revisado_at = now()
    WHERE id = v_imagen.id;


    -- ========================================================
    -- RESPUESTA
    -- ========================================================

    RETURN jsonb_build_object(
        'ok', true,
        'imagen_id', v_imagen.id,
        'publicacion_id', v_publicacion_id,
        'proyecto_id', v_imagen.proyecto_id,
        'destino', p_destino,
        'avance_id', p_avance_id,
        'url_original', v_imagen.url_temporal,
        'url_editada', v_imagen.url_editada,
        'url_publicada', v_url
    );

END;
$$;


ALTER FUNCTION constructora.aprobar_imagen(p_id uuid, p_destino character varying, p_orden integer, p_avance_id uuid) OWNER TO postgres;

--
-- Name: contexto_secretaria(text, timestamp with time zone); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.contexto_secretaria(p_modo text DEFAULT 'micro'::text, p_desde timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'constructora', 'public'
    AS $$
DECLARE
    v_desde timestamptz;
    v_resultado jsonb;
BEGIN

    -- --------------------------------------------------------
    -- MICRO
    -- Últimas 10 conversaciones literales.
    -- Se seleccionan las 10 más recientes y se devuelven
    -- en orden cronológico para conservar el hilo.
    -- --------------------------------------------------------
    IF lower(btrim(p_modo)) = 'micro' THEN

        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', c.id,
                    'creado_at', c.creado_at,
                    'mensaje_jefe', c.mensaje_jefe,
                    'respuesta_secretaria', c.respuesta_secretaria
                )
                ORDER BY c.creado_at ASC
            ),
            '[]'::jsonb
        )
        INTO v_resultado
        FROM (
            SELECT
                id,
                creado_at,
                mensaje_jefe,
                respuesta_secretaria
            FROM constructora.conversacion_secretaria
            ORDER BY creado_at DESC
            LIMIT 10
        ) c;

        RETURN jsonb_build_object(
            'modo', 'micro',
            'limite_interacciones', 10,
            'interacciones', v_resultado
        );

    -- --------------------------------------------------------
    -- HISTORIAL LITERAL
    -- Se conserva la lógica existente.
    -- Gemini nunca puede atravesar el límite de 15 días.
    -- --------------------------------------------------------
    ELSIF lower(btrim(p_modo)) = 'historial' THEN

        v_desde := GREATEST(
            COALESCE(
                p_desde,
                now() - interval '15 days'
            ),
            now() - interval '15 days'
        );

        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', c.id,
                    'creado_at', c.creado_at,
                    'mensaje_jefe', c.mensaje_jefe,
                    'respuesta_secretaria', c.respuesta_secretaria
                )
                ORDER BY c.creado_at ASC
            ),
            '[]'::jsonb
        )
        INTO v_resultado
        FROM constructora.conversacion_secretaria c
        WHERE c.creado_at >= v_desde;

        RETURN jsonb_build_object(
            'modo', 'historial',
            'desde', v_desde,
            'hasta', now(),
            'interacciones', v_resultado
        );

    ELSE
        RAISE EXCEPTION
            'agenda_CONTEXTO_MODO_INVALIDO: use micro o historial';
    END IF;

END;
$$;


ALTER FUNCTION constructora.contexto_secretaria(p_modo text, p_desde timestamp with time zone) OWNER TO postgres;

--
-- Name: eliminar_avance(uuid); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.eliminar_avance(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_proyecto_id uuid;
    v_cronograma_id uuid;
    v_titulo text;
BEGIN

    -- ========================================================
    -- OBTENER DATOS ANTES DE ELIMINAR
    -- ========================================================

    SELECT
        proyecto_id,
        cronograma_id,
        titulo
    INTO
        v_proyecto_id,
        v_cronograma_id,
        v_titulo
    FROM constructora.avances
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Avance no encontrado: %', p_id;
    END IF;


    -- ========================================================
    -- ELIMINAR AVANCE
    -- ========================================================
    -- Las imágenes asociadas deben eliminarse por la relación
    -- ON DELETE CASCADE existente.

    DELETE FROM constructora.avances
    WHERE id = p_id;


    -- ========================================================
    -- RECALCULAR ACTIVIDAD
    -- ========================================================
    -- El avance ya no existe, por lo que el denominador
    -- utilizado por recalcular_progreso_actividad() ya refleja
    -- correctamente la nueva cantidad de avances.

    PERFORM constructora.recalcular_progreso_actividad(
        v_cronograma_id
    );


    -- ========================================================
    -- RESPUESTA
    -- ========================================================

    RETURN jsonb_build_object(
        'ok', true,
        'id', p_id,
        'proyecto_id', v_proyecto_id,
        'cronograma_id', v_cronograma_id,
        'titulo', v_titulo
    );

END;
$$;


ALTER FUNCTION constructora.eliminar_avance(p_id uuid) OWNER TO postgres;

--
-- Name: eliminar_cronograma(uuid); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.eliminar_cronograma(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_nombre text;
    v_proyecto_id uuid;
BEGIN

    DELETE FROM constructora.cronograma
    WHERE id = p_id
    RETURNING nombre, proyecto_id
    INTO v_nombre, v_proyecto_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Actividad de cronograma no encontrada: %', p_id;
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'id', p_id,
        'proyecto_id', v_proyecto_id,
        'nombre', v_nombre
    );
END;
$$;


ALTER FUNCTION constructora.eliminar_cronograma(p_id uuid) OWNER TO postgres;

--
-- Name: eliminar_proyecto(uuid); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.eliminar_proyecto(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_titulo text;
    v_slug text;
BEGIN

    DELETE FROM constructora.proyectos
    WHERE id = p_id
    RETURNING titulo, slug
    INTO v_titulo, v_slug;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proyecto no encontrado: %', p_id;
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'id', p_id,
        'titulo', v_titulo,
        'slug', v_slug
    );
END;
$$;


ALTER FUNCTION constructora.eliminar_proyecto(p_id uuid) OWNER TO postgres;

--
-- Name: estado_plan_secretaria(uuid, text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.estado_plan_secretaria(p_id uuid, p_accion text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_actual text;
    v_estado_nuevo text;
    v_resultado jsonb;
BEGIN

    IF p_id IS NULL THEN

        RAISE EXCEPTION
            'agenda_REQUIERE_DATO|plan_id|Falta identificar el plan de Secretaría.';

    END IF;


    IF p_accion IS NULL
       OR btrim(p_accion) = '' THEN

        RAISE EXCEPTION
            'agenda_REQUIERE_DATO|accion|Falta indicar qué hacer con el plan de Secretaría.';

    END IF;


    SELECT estado
    INTO v_estado_actual
    FROM constructora.plan_secretaria
    WHERE id = p_id
    FOR UPDATE;


    IF NOT FOUND THEN

        RAISE EXCEPTION
            'agenda_OPERACION_NO_PERMITIDA|plan|El plan de Secretaría no existe.';

    END IF;


    CASE lower(btrim(p_accion))

        WHEN 'aprobar' THEN

            IF v_estado_actual <> 'consulta' THEN

                RAISE EXCEPTION
                    'agenda_OPERACION_NO_PERMITIDA|plan|Solo puede aprobarse un plan que esté en consulta.';

            END IF;

            v_estado_nuevo := 'aprobado';


        WHEN 'ejecutar' THEN

            IF v_estado_actual <> 'aprobado' THEN

                RAISE EXCEPTION
                    'agenda_OPERACION_NO_PERMITIDA|plan|Solo puede marcarse como ejecutado un plan previamente aprobado.';

            END IF;

            v_estado_nuevo := 'ejecutado';


        WHEN 'rechazar' THEN

            IF v_estado_actual <> 'consulta' THEN

                RAISE EXCEPTION
                    'agenda_OPERACION_NO_PERMITIDA|plan|Solo puede rechazarse un plan que esté en consulta.';

            END IF;

            v_estado_nuevo := 'rechazado';


        ELSE

            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|accion|Acción de plan no permitida.';

    END CASE;


    UPDATE constructora.plan_secretaria
    SET
        estado = v_estado_nuevo,
        actualizado_at = now()
    WHERE id = p_id;


    SELECT jsonb_build_object(
        'id', ps.id,
        'estado', ps.estado,
        'plan', ps.plan,
        'creado_at', ps.creado_at,
        'actualizado_at', ps.actualizado_at
    )
    INTO v_resultado
    FROM constructora.plan_secretaria ps
    WHERE ps.id = p_id;


    RETURN v_resultado;

END;
$$;


ALTER FUNCTION constructora.estado_plan_secretaria(p_id uuid, p_accion text) OWNER TO postgres;

--
-- Name: fn_contexto_actual(text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_contexto_actual(p_contexto text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'constructora', 'public'
    AS $$
DECLARE
    v_contexto text;
    v_actualizado_at timestamptz;
BEGIN

    v_contexto := btrim(
        COALESCE(p_contexto, '')
    );


    INSERT INTO constructora.contexto_actual_secretaria (
        id,
        contexto,
        actualizado_at
    )
    VALUES (
        true,
        v_contexto,
        now()
    )

    ON CONFLICT (id)
    DO UPDATE SET
        contexto = EXCLUDED.contexto,
        actualizado_at = now()

    RETURNING actualizado_at
    INTO v_actualizado_at;


    RETURN jsonb_build_object(
        'ok', true,
        'contexto', v_contexto,
        'actualizado_at', v_actualizado_at
    );

END;
$$;


ALTER FUNCTION constructora.fn_contexto_actual(p_contexto text) OWNER TO postgres;

--
-- Name: fn_fecha_recurrencia(timestamp with time zone, text, integer, bigint); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_fecha_recurrencia(p_fecha_ancla timestamp with time zone, p_frecuencia text, p_intervalo integer DEFAULT 1, p_posicion bigint DEFAULT 0) RETURNS timestamp with time zone
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v_frecuencia       text;

    v_meses            bigint;
    v_anios            bigint;

    v_anio_objetivo    integer;
    v_mes_objetivo     integer;
    v_dia_original     integer;
    v_ultimo_dia       integer;
    v_dia_objetivo     integer;

    v_hora             integer;
    v_minuto           integer;
    v_segundo           double precision;

    v_fecha_local      timestamp;
BEGIN

    ------------------------------------------------------------
    -- 1. VALIDACIONES GENERALES
    ------------------------------------------------------------

    IF p_fecha_ancla IS NULL THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_FECHA_ANCLA_REQUERIDA';
    END IF;

    IF p_frecuencia IS NULL
       OR btrim(p_frecuencia) = ''
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_FRECUENCIA_REQUERIDA';
    END IF;

    v_frecuencia := lower(btrim(p_frecuencia));

    IF v_frecuencia NOT IN (
        'diaria',
        'semanal',
        'mensual',
        'anual'
    )
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_FRECUENCIA_INVALIDA';
    END IF;

    IF p_intervalo IS NULL
       OR p_intervalo <= 0
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_INTERVALO_INVALIDO';
    END IF;

    IF p_posicion IS NULL
       OR p_posicion < 0
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_POSICION_INVALIDA';
    END IF;


    ------------------------------------------------------------
    -- 2. POSICIÓN 0
    --
    -- La primera ocurrencia es exactamente el ancla.
    ------------------------------------------------------------

    IF p_posicion = 0 THEN
        RETURN p_fecha_ancla;
    END IF;


    ------------------------------------------------------------
    -- 3. DIARIA
    ------------------------------------------------------------

    IF v_frecuencia = 'diaria' THEN

        RETURN p_fecha_ancla
             + make_interval(
                   days => (p_intervalo::bigint * p_posicion)::integer
               );

    END IF;


    ------------------------------------------------------------
    -- 4. SEMANAL
    --
    -- Una semana = 7 días.
    ------------------------------------------------------------

    IF v_frecuencia = 'semanal' THEN

        RETURN p_fecha_ancla
             + make_interval(
                   days => (
                       p_intervalo::bigint
                       * p_posicion
                       * 7
                   )::integer
               );

    END IF;


    ------------------------------------------------------------
    -- 5. DATOS DEL ANCLA PARA MES / AÑO
    ------------------------------------------------------------

    v_dia_original :=
        extract(day FROM p_fecha_ancla)::integer;

    v_hora :=
        extract(hour FROM p_fecha_ancla)::integer;

    v_minuto :=
        extract(minute FROM p_fecha_ancla)::integer;

    v_segundo :=
        extract(second FROM p_fecha_ancla);


    ------------------------------------------------------------
    -- 6. MENSUAL
    --
    -- Nos posicionamos matemáticamente en el mes/año objetivo.
    --
    -- Después:
    --
    -- día objetivo =
    -- min(día original, último día del mes objetivo)
    --
    -- Ejemplo ancla 31/01:
    --
    -- posición 1 → febrero → 28/29
    -- posición 2 → marzo   → 31
    -- posición 3 → abril   → 30
    --
    -- Nunca hacemos:
    -- 31 enero -> 28 febrero -> 28 marzo
    ------------------------------------------------------------

    IF v_frecuencia = 'mensual' THEN

        v_meses :=
            p_intervalo::bigint * p_posicion;

        v_fecha_local :=
            date_trunc('month', p_fecha_ancla)
            + make_interval(months => v_meses::integer);

        v_anio_objetivo :=
            extract(year FROM v_fecha_local)::integer;

        v_mes_objetivo :=
            extract(month FROM v_fecha_local)::integer;


        -- último día real del mes objetivo

        v_ultimo_dia :=
            extract(
                day FROM (
                    make_date(
                        v_anio_objetivo,
                        v_mes_objetivo,
                        1
                    )
                    + interval '1 month'
                    - interval '1 day'
                )
            )::integer;


        v_dia_objetivo :=
            least(
                v_dia_original,
                v_ultimo_dia
            );


        v_fecha_local :=
            make_date(
                v_anio_objetivo,
                v_mes_objetivo,
                v_dia_objetivo
            )::timestamp
            + make_interval(
                hours => v_hora,
                mins  => v_minuto,
                secs  => v_segundo
            );


        RETURN v_fecha_local AT TIME ZONE current_setting('TimeZone');

    END IF;


    ------------------------------------------------------------
    -- 7. ANUAL
    --
    -- Conserva mes/día originales.
    --
    -- Si el día no existe en ese año:
    -- usa el último día válido del mes.
    --
    -- Ejemplo:
    --
    -- 29/02/2028
    -- 28/02/2029
    -- 28/02/2030
    -- 28/02/2031
    -- 29/02/2032
    ------------------------------------------------------------

    IF v_frecuencia = 'anual' THEN

        v_anios :=
            p_intervalo::bigint * p_posicion;

        v_anio_objetivo :=
            extract(year FROM p_fecha_ancla)::integer
            + v_anios::integer;

        v_mes_objetivo :=
            extract(month FROM p_fecha_ancla)::integer;


        v_ultimo_dia :=
            extract(
                day FROM (
                    make_date(
                        v_anio_objetivo,
                        v_mes_objetivo,
                        1
                    )
                    + interval '1 month'
                    - interval '1 day'
                )
            )::integer;


        v_dia_objetivo :=
            least(
                v_dia_original,
                v_ultimo_dia
            );


        v_fecha_local :=
            make_date(
                v_anio_objetivo,
                v_mes_objetivo,
                v_dia_objetivo
            )::timestamp
            + make_interval(
                hours => v_hora,
                mins  => v_minuto,
                secs  => v_segundo
            );


        RETURN v_fecha_local AT TIME ZONE current_setting('TimeZone');

    END IF;


    ------------------------------------------------------------
    -- SEGURIDAD
    ------------------------------------------------------------

    RAISE EXCEPTION
        'agenda_RECURRENCIA_ERROR_INTERNO';

END;
$$;


ALTER FUNCTION constructora.fn_fecha_recurrencia(p_fecha_ancla timestamp with time zone, p_frecuencia text, p_intervalo integer, p_posicion bigint) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: items; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    titulo text,
    descripcion text,
    estado text DEFAULT 'activo'::text,
    prioridad text DEFAULT 'baja'::text,
    fecha_inicio timestamp with time zone,
    fecha_limite timestamp with time zone,
    todo_el_dia boolean DEFAULT false,
    recordatorio timestamp with time zone,
    recurrencia jsonb,
    participantes jsonb,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_at timestamp with time zone DEFAULT now() NOT NULL,
    oculto boolean DEFAULT false NOT NULL
);


ALTER TABLE constructora.items OWNER TO postgres;

--
-- Name: fn_item(jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_item(p_data jsonb) RETURNS constructora.items
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id              uuid;
    v_actual          constructora.items%ROWTYPE;
    v_resultado       constructora.items%ROWTYPE;

    v_titulo          text;
    v_descripcion     text;
    v_prioridad       text;
    v_fecha_inicio    timestamptz;
    v_fecha_limite    timestamptz;
    v_todo_el_dia     boolean;
    v_recordatorio    timestamptz;
    v_recurrencia     jsonb;
    v_participantes   jsonb;
BEGIN
    ------------------------------------------------------------
    -- 1. ENTRADA
    ------------------------------------------------------------

    IF p_data IS NULL
       OR jsonb_typeof(p_data) <> 'object'
    THEN
        RAISE EXCEPTION 'agenda_ITEM_DATOS_INVALIDOS';
    END IF;


    ------------------------------------------------------------
    -- 2. ID
    ------------------------------------------------------------

    IF p_data ? 'id'
       AND p_data -> 'id' <> 'null'::jsonb
    THEN
        BEGIN
            v_id := (p_data ->> 'id')::uuid;
        EXCEPTION
            WHEN invalid_text_representation THEN
                RAISE EXCEPTION 'agenda_ITEM_ID_INVALIDO';
        END;
    END IF;


    ------------------------------------------------------------
    -- 3. CREAR
    ------------------------------------------------------------

    IF v_id IS NULL THEN

        -- Un item nuevo siempre nace activo.
        IF p_data ? 'estado'
           AND COALESCE(p_data ->> 'estado', 'activo') <> 'activo'
        THEN
            RAISE EXCEPTION 'agenda_ITEM_NUEVO_DEBE_SER_ACTIVO';
        END IF;

        v_titulo := p_data ->> 'titulo';
        v_descripcion := p_data ->> 'descripcion';

        v_prioridad := COALESCE(
            p_data ->> 'prioridad',
            'baja'
        );

        BEGIN
            v_fecha_inicio :=
                (p_data ->> 'fecha_inicio')::timestamptz;

            v_fecha_limite :=
                (p_data ->> 'fecha_limite')::timestamptz;

            v_recordatorio :=
                (p_data ->> 'recordatorio')::timestamptz;
        EXCEPTION
            WHEN invalid_datetime_format
              OR datetime_field_overflow THEN
                RAISE EXCEPTION 'agenda_ITEM_FECHA_INVALIDA';
        END;

        BEGIN
            v_todo_el_dia := COALESCE(
                (p_data ->> 'todo_el_dia')::boolean,
                false
            );
        EXCEPTION
            WHEN invalid_text_representation THEN
                RAISE EXCEPTION 'agenda_ITEM_TODO_EL_DIA_INVALIDO';
        END;

        v_recurrencia :=
            NULLIF(p_data -> 'recurrencia', 'null'::jsonb);

        v_participantes :=
            NULLIF(p_data -> 'participantes', 'null'::jsonb);


    ------------------------------------------------------------
    -- 4. EDITAR
    ------------------------------------------------------------

    ELSE

        SELECT *
        INTO v_actual
        FROM constructora.items
        WHERE id = v_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'agenda_ITEM_NO_EXISTE';
        END IF;


        -- Estado se modifica únicamente mediante movimientos.
        IF p_data ? 'estado' THEN
            RAISE EXCEPTION
                'agenda_ITEM_ESTADO_NO_EDITABLE: use fn_observacion';
        END IF;


        --------------------------------------------------------
        -- PATCH:
        -- ausente      = conservar
        -- presente null = borrar
        -- presente valor = reemplazar
        --------------------------------------------------------

        IF p_data ? 'titulo' THEN
            v_titulo := p_data ->> 'titulo';
        ELSE
            v_titulo := v_actual.titulo;
        END IF;

        IF p_data ? 'descripcion' THEN
            v_descripcion := p_data ->> 'descripcion';
        ELSE
            v_descripcion := v_actual.descripcion;
        END IF;

        IF p_data ? 'prioridad' THEN
            v_prioridad := p_data ->> 'prioridad';
        ELSE
            v_prioridad := v_actual.prioridad;
        END IF;


        IF p_data ? 'fecha_inicio' THEN
            BEGIN
                v_fecha_inicio :=
                    (p_data ->> 'fecha_inicio')::timestamptz;
            EXCEPTION
                WHEN invalid_datetime_format
                  OR datetime_field_overflow THEN
                    RAISE EXCEPTION 'agenda_ITEM_FECHA_INVALIDA';
            END;
        ELSE
            v_fecha_inicio := v_actual.fecha_inicio;
        END IF;


        IF p_data ? 'fecha_limite' THEN
            BEGIN
                v_fecha_limite :=
                    (p_data ->> 'fecha_limite')::timestamptz;
            EXCEPTION
                WHEN invalid_datetime_format
                  OR datetime_field_overflow THEN
                    RAISE EXCEPTION 'agenda_ITEM_FECHA_INVALIDA';
            END;
        ELSE
            v_fecha_limite := v_actual.fecha_limite;
        END IF;


        IF p_data ? 'recordatorio' THEN
            BEGIN
                v_recordatorio :=
                    (p_data ->> 'recordatorio')::timestamptz;
            EXCEPTION
                WHEN invalid_datetime_format
                  OR datetime_field_overflow THEN
                    RAISE EXCEPTION 'agenda_ITEM_FECHA_INVALIDA';
            END;
        ELSE
            v_recordatorio := v_actual.recordatorio;
        END IF;


        IF p_data ? 'todo_el_dia' THEN
            BEGIN
                IF p_data -> 'todo_el_dia' = 'null'::jsonb THEN
                    v_todo_el_dia := NULL;
                ELSE
                    v_todo_el_dia :=
                        (p_data ->> 'todo_el_dia')::boolean;
                END IF;
            EXCEPTION
                WHEN invalid_text_representation THEN
                    RAISE EXCEPTION
                        'agenda_ITEM_TODO_EL_DIA_INVALIDO';
            END;
        ELSE
            v_todo_el_dia := v_actual.todo_el_dia;
        END IF;


        IF p_data ? 'recurrencia' THEN
            v_recurrencia :=
                NULLIF(p_data -> 'recurrencia', 'null'::jsonb);
        ELSE
            v_recurrencia := v_actual.recurrencia;
        END IF;


        IF p_data ? 'participantes' THEN
            v_participantes :=
                NULLIF(p_data -> 'participantes', 'null'::jsonb);
        ELSE
            v_participantes := v_actual.participantes;
        END IF;

    END IF;


    ------------------------------------------------------------
    -- 5. VALIDACIONES DEL RESULTADO FINAL
    ------------------------------------------------------------

    IF v_prioridad IS NULL
       OR v_prioridad NOT IN ('alta', 'baja')
    THEN
        RAISE EXCEPTION 'agenda_ITEM_PRIORIDAD_INVALIDA';
    END IF;


    IF v_fecha_inicio IS NOT NULL
       AND v_fecha_limite IS NOT NULL
       AND v_fecha_limite < v_fecha_inicio
    THEN
        RAISE EXCEPTION
            'agenda_ITEM_FECHA_LIMITE_ANTERIOR_INICIO';
    END IF;


    ------------------------------------------------------------
-- VALIDAR RECURRENCIA
--
-- Contrato:
--
-- {
--   "frecuencia": "diaria|semanal|mensual|anual",
--   "intervalo": 1
-- }
--
-- intervalo:
--   - puede omitirse
--   - puede ser null (equivale a 1)
--   - si existe debe ser entero >= 1
--
-- Una recurrencia necesita fecha_inicio porque esa fecha
-- funciona como ancla matemática de la serie.
------------------------------------------------------------

    IF v_recurrencia IS NOT NULL THEN

        -- Debe ser objeto.
        IF jsonb_typeof(v_recurrencia) <> 'object' THEN
            RAISE EXCEPTION
                'agenda_ITEM_RECURRENCIA_INVALIDA';
        END IF;


        -- Debe existir fecha_inicio.
        IF v_fecha_inicio IS NULL THEN
            RAISE EXCEPTION
                'agenda_ITEM_RECURRENCIA_REQUIERE_FECHA_INICIO';
        END IF;


        -- Frecuencia obligatoria.
        IF NOT (v_recurrencia ? 'frecuencia')
        OR v_recurrencia -> 'frecuencia' = 'null'::jsonb
        OR jsonb_typeof(v_recurrencia -> 'frecuencia') <> 'string'
        OR btrim(v_recurrencia ->> 'frecuencia') = ''
        THEN
            RAISE EXCEPTION
                'agenda_ITEM_RECURRENCIA_FRECUENCIA_REQUERIDA';
        END IF;


        -- Frecuencia válida.
        IF lower(btrim(v_recurrencia ->> 'frecuencia'))
        NOT IN (
            'diaria',
            'semanal',
            'mensual',
            'anual'
        )
        THEN
            RAISE EXCEPTION
                'agenda_ITEM_RECURRENCIA_FRECUENCIA_INVALIDA';
        END IF;


        -- Intervalo opcional.
        IF v_recurrencia ? 'intervalo'
        AND v_recurrencia -> 'intervalo' <> 'null'::jsonb
        THEN

            -- Tiene que ser un número JSON.
            IF jsonb_typeof(v_recurrencia -> 'intervalo') <> 'number' THEN
                RAISE EXCEPTION
                    'agenda_ITEM_RECURRENCIA_INTERVALO_INVALIDO';
            END IF;


            -- Debe ser entero positivo y entrar en integer.
            BEGIN

                IF (v_recurrencia ->> 'intervalo')::numeric < 1
                OR
                trunc(
                    (v_recurrencia ->> 'intervalo')::numeric
                ) <> (v_recurrencia ->> 'intervalo')::numeric
                OR
                (v_recurrencia ->> 'intervalo')::numeric > 2147483647
                THEN
                    RAISE EXCEPTION
                        'agenda_ITEM_RECURRENCIA_INTERVALO_INVALIDO';
                END IF;

            EXCEPTION
                WHEN invalid_text_representation
                OR numeric_value_out_of_range
                THEN
                    RAISE EXCEPTION
                        'agenda_ITEM_RECURRENCIA_INTERVALO_INVALIDO';
            END;

        END IF;

    END IF;


    IF v_participantes IS NOT NULL
       AND jsonb_typeof(v_participantes) <> 'array'
    THEN
        RAISE EXCEPTION
            'agenda_ITEM_PARTICIPANTES_INVALIDOS';
    END IF;


    ------------------------------------------------------------
    -- 6. INSERT
    ------------------------------------------------------------

    IF v_id IS NULL THEN

        INSERT INTO constructora.items (
            titulo,
            descripcion,
            estado,
            prioridad,
            fecha_inicio,
            fecha_limite,
            todo_el_dia,
            recordatorio,
            recurrencia,
            participantes
        )
        VALUES (
            v_titulo,
            v_descripcion,
            'activo',
            v_prioridad,
            v_fecha_inicio,
            v_fecha_limite,
            v_todo_el_dia,
            v_recordatorio,
            v_recurrencia,
            v_participantes
        )
        RETURNING *
        INTO v_resultado;


    ------------------------------------------------------------
    -- 7. UPDATE
    ------------------------------------------------------------

    ELSE

        UPDATE constructora.items
        SET
            titulo         = v_titulo,
            descripcion    = v_descripcion,
            prioridad      = v_prioridad,
            fecha_inicio   = v_fecha_inicio,
            fecha_limite   = v_fecha_limite,
            todo_el_dia    = v_todo_el_dia,
            recordatorio   = v_recordatorio,
            recurrencia    = v_recurrencia,
            participantes  = v_participantes,
            actualizado_at = now()
        WHERE id = v_id
        RETURNING *
        INTO v_resultado;

    END IF;


    RETURN v_resultado;
END;
$$;


ALTER FUNCTION constructora.fn_item(p_data jsonb) OWNER TO postgres;

--
-- Name: fn_listar_memoria_jefe(); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_listar_memoria_jefe() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'constructora', 'public'
    AS $$
    SELECT jsonb_build_object(

        'preferencias',
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', m.id,
                        'contenido', m.contenido
                    )
                    ORDER BY m.creado_at ASC
                )
                FROM constructora.memoria_jefe m
                WHERE m.tipo = 'preferencia'
            ),
            '[]'::jsonb
        ),

        'intereses',
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', m.id,
                        'contenido', m.contenido
                    )
                    ORDER BY m.creado_at ASC
                )
                FROM constructora.memoria_jefe m
                WHERE m.tipo = 'interes'
            ),
            '[]'::jsonb
        )

    );
$$;


ALTER FUNCTION constructora.fn_listar_memoria_jefe() OWNER TO postgres;

--
-- Name: fn_memoria_jefe(jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_memoria_jefe(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'constructora', 'public'
    AS $$
DECLARE
    v_accion text;
    v_id uuid;
    v_tipo text;
    v_contenido text;
    v_resultado constructora.memoria_jefe%ROWTYPE;
BEGIN

    IF p_data IS NULL
       OR jsonb_typeof(p_data) <> 'object' THEN
        RAISE EXCEPTION
            'secretaria_MEMORIA_DATOS_INVALIDOS';
    END IF;


    -- --------------------------------------------------------
    -- Resolver ID
    -- --------------------------------------------------------

    IF p_data ? 'id'
       AND NULLIF(btrim(p_data->>'id'), '') IS NOT NULL THEN

        BEGIN
            v_id := (p_data->>'id')::uuid;
        EXCEPTION
            WHEN invalid_text_representation THEN
                RAISE EXCEPTION
                    'secretaria_MEMORIA_ID_INVALIDO';
        END;

    END IF;


    -- --------------------------------------------------------
    -- Resolver acción
    -- --------------------------------------------------------

    v_accion := lower(
        btrim(
            COALESCE(p_data->>'accion', '')
        )
    );

    IF v_accion = '' THEN
        IF v_id IS NULL THEN
            v_accion := 'crear';
        ELSE
            v_accion := 'modificar';
        END IF;
    END IF;


    -- ========================================================
    -- CREAR
    -- ========================================================

    IF v_accion = 'crear' THEN

        v_tipo := lower(
            btrim(
                COALESCE(p_data->>'tipo', '')
            )
        );

        v_contenido := btrim(
            COALESCE(p_data->>'contenido', '')
        );


        IF v_tipo NOT IN ('preferencia', 'interes') THEN
            RAISE EXCEPTION
                'secretaria_MEMORIA_TIPO_INVALIDO';
        END IF;


        IF v_contenido = '' THEN
            RAISE EXCEPTION
                'secretaria_MEMORIA_CONTENIDO_REQUERIDO';
        END IF;


        INSERT INTO constructora.memoria_jefe (
            tipo,
            contenido
        )
        VALUES (
            v_tipo,
            v_contenido
        )
        RETURNING *
        INTO v_resultado;


        RETURN jsonb_build_object(
            'ok', true,
            'accion', 'crear',
            'memoria', to_jsonb(v_resultado)
        );


    -- ========================================================
    -- MODIFICAR
    -- ========================================================

    ELSIF v_accion = 'modificar' THEN

        IF v_id IS NULL THEN
            RAISE EXCEPTION
                'secretaria_MEMORIA_ID_REQUERIDO';
        END IF;


        SELECT *
        INTO v_resultado
        FROM constructora.memoria_jefe
        WHERE id = v_id
        FOR UPDATE;


        IF NOT FOUND THEN
            RAISE EXCEPTION
                'secretaria_MEMORIA_NO_EXISTE';
        END IF;


        -- Tipo: PATCH
        IF p_data ? 'tipo' THEN

            v_tipo := lower(
                btrim(
                    COALESCE(p_data->>'tipo', '')
                )
            );

            IF v_tipo NOT IN ('preferencia', 'interes') THEN
                RAISE EXCEPTION
                    'secretaria_MEMORIA_TIPO_INVALIDO';
            END IF;

        ELSE
            v_tipo := v_resultado.tipo;
        END IF;


        -- Contenido: PATCH
        IF p_data ? 'contenido' THEN

            v_contenido := btrim(
                COALESCE(p_data->>'contenido', '')
            );

            IF v_contenido = '' THEN
                RAISE EXCEPTION
                    'secretaria_MEMORIA_CONTENIDO_REQUERIDO';
            END IF;

        ELSE
            v_contenido := v_resultado.contenido;
        END IF;


        UPDATE constructora.memoria_jefe
        SET
            tipo = v_tipo,
            contenido = v_contenido,
            actualizado_at = now()
        WHERE id = v_id
        RETURNING *
        INTO v_resultado;


        RETURN jsonb_build_object(
            'ok', true,
            'accion', 'modificar',
            'memoria', to_jsonb(v_resultado)
        );


    -- ========================================================
    -- ELIMINAR
    -- ========================================================

    ELSIF v_accion = 'eliminar' THEN

        IF v_id IS NULL THEN
            RAISE EXCEPTION
                'secretaria_MEMORIA_ID_REQUERIDO';
        END IF;


        DELETE FROM constructora.memoria_jefe
        WHERE id = v_id
        RETURNING *
        INTO v_resultado;


        IF NOT FOUND THEN
            RAISE EXCEPTION
                'secretaria_MEMORIA_NO_EXISTE';
        END IF;


        RETURN jsonb_build_object(
            'ok', true,
            'accion', 'eliminar',
            'memoria', to_jsonb(v_resultado)
        );


    ELSE

        RAISE EXCEPTION
            'secretaria_MEMORIA_ACCION_INVALIDA: use crear, modificar o eliminar';

    END IF;

END;
$$;


ALTER FUNCTION constructora.fn_memoria_jefe(p_data jsonb) OWNER TO postgres;

--
-- Name: observaciones; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.observaciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agenda_item_id uuid NOT NULL,
    observacion text,
    estado_anterior text,
    estado_nuevo text,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    secuencia bigint NOT NULL
);


ALTER TABLE constructora.observaciones OWNER TO postgres;

--
-- Name: fn_observacion(uuid, text, text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_observacion(p_agenda_item_id uuid, p_observacion text, p_estado_nuevo text DEFAULT NULL::text) RETURNS constructora.observaciones
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_item          constructora.items%ROWTYPE;
    v_estado_nuevo  text;
    v_resultado     constructora.observaciones%ROWTYPE;
BEGIN

    ------------------------------------------------------------
    -- 1. VALIDAR ID
    ------------------------------------------------------------

    IF p_agenda_item_id IS NULL THEN
        RAISE EXCEPTION 'agenda_OBSERVACION_ITEM_ID_REQUERIDO';
    END IF;


    ------------------------------------------------------------
    -- 2. BLOQUEAR Y LEER EL ITEM REAL
    ------------------------------------------------------------

    SELECT *
    INTO v_item
    FROM constructora.items
    WHERE id = p_agenda_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'agenda_OBSERVACION_ITEM_NO_EXISTE';
    END IF;


    ------------------------------------------------------------
    -- 3. VALIDAR OBSERVACIÓN
    ------------------------------------------------------------

    IF p_observacion IS NULL
       OR btrim(p_observacion) = ''
    THEN
        RAISE EXCEPTION 'agenda_OBSERVACION_TEXTO_REQUERIDO';
    END IF;


    ------------------------------------------------------------
    -- 4. DETERMINAR ESTADO RESULTANTE
    --
    -- NULL o texto vacío:
    --     conserva el estado actual.
    --
    -- valor:
    --     solicita cambio de estado.
    ------------------------------------------------------------

    IF p_estado_nuevo IS NULL
       OR btrim(p_estado_nuevo) = ''
    THEN
        v_estado_nuevo := v_item.estado;
    ELSE
        v_estado_nuevo := btrim(p_estado_nuevo);
    END IF;


    ------------------------------------------------------------
    -- 5. VALIDAR ESTADO
    ------------------------------------------------------------

    IF v_estado_nuevo NOT IN (
        'activo',
        'completado',
        'cancelado'
    )
    THEN
        RAISE EXCEPTION 'agenda_OBSERVACION_ESTADO_INVALIDO';
    END IF;


    ------------------------------------------------------------
    -- 6. REGISTRAR OBSERVACIÓN
    --
    -- estado_anterior SIEMPRE proviene de la BD.
    -- estado_nuevo representa cómo queda el item después
    -- de esta observación.
    ------------------------------------------------------------

    INSERT INTO constructora.observaciones (
        agenda_item_id,
        observacion,
        estado_anterior,
        estado_nuevo
    )
    VALUES (
        v_item.id,
        p_observacion,
        v_item.estado,
        v_estado_nuevo
    )
    RETURNING *
    INTO v_resultado;


    ------------------------------------------------------------
    -- 7. ACTUALIZAR ITEM
    --
    -- Si cambia el estado, lo actualizamos.
    -- Incluso si no cambia, actualizado_at refleja que hubo
    -- actividad humana sobre el compromiso.
    ------------------------------------------------------------

    UPDATE constructora.items
    SET
        estado = v_estado_nuevo,
        actualizado_at = now()
    WHERE id = v_item.id;


    ------------------------------------------------------------
    -- 8. DEVOLVER OBSERVACIÓN CREADA
    ------------------------------------------------------------

    RETURN v_resultado;

END;
$$;


ALTER FUNCTION constructora.fn_observacion(p_agenda_item_id uuid, p_observacion text, p_estado_nuevo text) OWNER TO postgres;

--
-- Name: fn_obtener_contexto_actual(); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_obtener_contexto_actual() RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'constructora', 'public'
    AS $$
    SELECT jsonb_build_object(
        'contexto',
        COALESCE(
            (
                SELECT contexto
                FROM constructora.contexto_actual_secretaria
                WHERE id = true
            ),
            ''
        ),

        'actualizado_at',
        (
            SELECT actualizado_at
            FROM constructora.contexto_actual_secretaria
            WHERE id = true
        )
    );
$$;


ALTER FUNCTION constructora.fn_obtener_contexto_actual() OWNER TO postgres;

--
-- Name: fn_ocultar_eliminar_item(uuid, text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_ocultar_eliminar_item(p_agenda_item_id uuid, p_accion text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_item constructora.items%ROWTYPE;
    v_accion text;
BEGIN
    IF p_agenda_item_id IS NULL THEN
        RAISE EXCEPTION
            'agenda_REQUIERE_DATO|agenda_item_id|¿Qué elemento de la agenda querés modificar?';
    END IF;

    v_accion := lower(trim(coalesce(p_accion, '')));

    IF v_accion NOT IN ('ocultar', 'restaurar', 'eliminar') THEN
        RAISE EXCEPTION
            'agenda_OPERACION_NO_PERMITIDA|accion|La acción debe ser ocultar, restaurar o eliminar.';
    END IF;

    SELECT *
      INTO v_item
      FROM constructora.items
     WHERE id = p_agenda_item_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'agenda_OPERACION_NO_PERMITIDA|agenda_item_id|El elemento indicado no existe.';
    END IF;


    -- ========================================================
    -- OCULTAR
    -- ========================================================

    IF v_accion = 'ocultar' THEN

        UPDATE constructora.items
           SET oculto = true,
               actualizado_at = now()
         WHERE id = p_agenda_item_id
         RETURNING * INTO v_item;

        RETURN jsonb_build_object(
            'ok', true,
            'accion', 'ocultar',
            'item', to_jsonb(v_item)
        );

    END IF;


    -- ========================================================
    -- RESTAURAR
    -- ========================================================

    IF v_accion = 'restaurar' THEN

        UPDATE constructora.items
           SET oculto = false,
               actualizado_at = now()
         WHERE id = p_agenda_item_id
         RETURNING * INTO v_item;

        RETURN jsonb_build_object(
            'ok', true,
            'accion', 'restaurar',
            'item', to_jsonb(v_item)
        );

    END IF;


    -- ========================================================
    -- ELIMINAR DEFINITIVAMENTE
    -- ========================================================

    DELETE FROM constructora.historial_recurrencia
     WHERE agenda_item_id = p_agenda_item_id;

    DELETE FROM constructora.observaciones
     WHERE agenda_item_id = p_agenda_item_id;

    DELETE FROM constructora.items
     WHERE id = p_agenda_item_id;

    RETURN jsonb_build_object(
        'ok', true,
        'accion', 'eliminar',
        'item_id', p_agenda_item_id,
        'eliminado', true
    );

END;
$$;


ALTER FUNCTION constructora.fn_ocultar_eliminar_item(p_agenda_item_id uuid, p_accion text) OWNER TO postgres;

--
-- Name: FUNCTION fn_ocultar_eliminar_item(p_agenda_item_id uuid, p_accion text); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.fn_ocultar_eliminar_item(p_agenda_item_id uuid, p_accion text) IS 'Gestiona la visibilidad o eliminación definitiva de un elemento de Agenda. Acciones: ocultar, restaurar, eliminar.';


--
-- Name: fn_orquestador(text, jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_orquestador(p_operacion text, p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_op text;
    v_id uuid;
    v_obs text;
    v_item constructora.items%ROWTYPE;
    v_observacion constructora.observaciones%ROWTYPE;
    v_json jsonb;
BEGIN
    v_op := lower(btrim(coalesce(p_operacion,'')));

    IF v_op NOT IN (
        'evento.crear','evento.modificar',
        'evento.completar','evento.cancelar','evento.reabrir',
        'evento.ocultar','evento.restaurar','evento.eliminar',
        'tarea.crear','tarea.modificar',
        'tarea.completar','tarea.reabrir','tarea.eliminar'
    ) THEN
        RAISE EXCEPTION 'agenda_OPERACION_NO_PERMITIDA|operacion|La operación % no existe.', coalesce(v_op,'');
    END IF;

    IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
        RAISE EXCEPTION 'agenda_REQUIERE_DATO|data|Necesito los datos de la operación.';
    END IF;

    -- EVENTOS ---------------------------------------------------------------
    IF v_op='evento.crear' THEN
        IF p_data ? 'id' AND p_data->'id' <> 'null'::jsonb THEN
            RAISE EXCEPTION 'agenda_REQUIERE_ACLARACION|evento|Crear un evento no admite un id existente.';
        END IF;
        v_item := constructora.fn_item(p_data);
        RETURN jsonb_build_object('ok',true,'operacion',v_op,'evento',to_jsonb(v_item));
    END IF;

    IF v_op='evento.modificar' THEN
        IF NOT (p_data ? 'id') OR p_data->'id'='null'::jsonb THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|evento_id|¿Qué evento querés modificar?';
        END IF;
        v_item := constructora.fn_item(p_data);
        RETURN jsonb_build_object('ok',true,'operacion',v_op,'evento',to_jsonb(v_item));
    END IF;

    IF v_op IN ('evento.completar','evento.cancelar','evento.reabrir') THEN
        BEGIN
            v_id := (p_data->>'id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|evento_id|Necesito identificar el evento.';
        END;

        v_obs := nullif(btrim(p_data->>'observacion'),'');
        IF v_obs IS NULL THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|observacion|¿Qué querés dejar registrado sobre el cambio?';
        END IF;

        v_observacion := constructora.fn_observacion(
            v_id,
            v_obs,
            CASE v_op
                WHEN 'evento.completar' THEN 'completado'
                WHEN 'evento.cancelar' THEN 'cancelado'
                ELSE 'activo'
            END
        );

        RETURN jsonb_build_object('ok',true,'operacion',v_op,'observacion',to_jsonb(v_observacion));
    END IF;

    IF v_op IN ('evento.ocultar','evento.restaurar','evento.eliminar') THEN
        BEGIN
            v_id := (p_data->>'id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|evento_id|Necesito identificar el evento.';
        END;

        v_json := constructora.fn_ocultar_eliminar_item(
            v_id,
            CASE v_op
                WHEN 'evento.ocultar' THEN 'ocultar'
                WHEN 'evento.restaurar' THEN 'restaurar'
                ELSE 'eliminar'
            END
        );

        RETURN jsonb_build_object('ok',true,'operacion',v_op,'resultado',v_json);
    END IF;

    -- TAREAS ----------------------------------------------------------------
    IF v_op='tarea.crear' THEN
        v_json := constructora.fn_tarea(
            (p_data-'accion') || jsonb_build_object('accion','crear')
        );
    ELSIF v_op='tarea.modificar' THEN
        v_json := constructora.fn_tarea(
            (p_data-'accion') || jsonb_build_object('accion','modificar')
        );
    ELSIF v_op='tarea.completar' THEN
        v_json := constructora.fn_tarea(
            (p_data-'accion'-'completada') ||
            jsonb_build_object('accion','modificar','completada',true)
        );
    ELSIF v_op='tarea.reabrir' THEN
        v_json := constructora.fn_tarea(
            (p_data-'accion'-'completada') ||
            jsonb_build_object('accion','modificar','completada',false)
        );
    ELSIF v_op='tarea.eliminar' THEN
        v_json := constructora.fn_tarea(
            (p_data-'accion') || jsonb_build_object('accion','eliminar')
        );
    END IF;

    RETURN jsonb_build_object('ok',true,'operacion',v_op,'resultado',v_json);
END;
$$;


ALTER FUNCTION constructora.fn_orquestador(p_operacion text, p_data jsonb) OWNER TO postgres;

--
-- Name: FUNCTION fn_orquestador(p_operacion text, p_data jsonb); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.fn_orquestador(p_operacion text, p_data jsonb) IS 'Orquestador simplificado de Agenda. Reemplaza completamente R01-R35 por operaciones explícitas de evento y tarea.';


--
-- Name: fn_posicion_recurrencia(timestamp with time zone, text, integer, timestamp with time zone); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_posicion_recurrencia(p_fecha_ancla timestamp with time zone, p_frecuencia text, p_intervalo integer DEFAULT 1, p_fecha_referencia timestamp with time zone DEFAULT now()) RETURNS TABLE(posicion bigint, anterior timestamp with time zone, correspondiente timestamp with time zone, siguiente timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_frecuencia text;

    v_estimacion bigint;
    v_posicion   bigint;

    v_actual     timestamptz;
    v_anterior   timestamptz;
    v_siguiente  timestamptz;

    v_dias       double precision;
    v_meses      bigint;
    v_anios      bigint;
BEGIN

    ------------------------------------------------------------
    -- 1. VALIDACIONES
    ------------------------------------------------------------

    IF p_fecha_ancla IS NULL THEN
        RAISE EXCEPTION
            'agenda_POSICION_FECHA_ANCLA_REQUERIDA';
    END IF;

    IF p_fecha_referencia IS NULL THEN
        RAISE EXCEPTION
            'agenda_POSICION_FECHA_REFERENCIA_REQUERIDA';
    END IF;

    IF p_frecuencia IS NULL
       OR btrim(p_frecuencia) = ''
    THEN
        RAISE EXCEPTION
            'agenda_POSICION_FRECUENCIA_REQUERIDA';
    END IF;

    v_frecuencia := lower(btrim(p_frecuencia));

    IF v_frecuencia NOT IN (
        'diaria',
        'semanal',
        'mensual',
        'anual'
    )
    THEN
        RAISE EXCEPTION
            'agenda_POSICION_FRECUENCIA_INVALIDA';
    END IF;

    IF p_intervalo IS NULL
       OR p_intervalo <= 0
    THEN
        RAISE EXCEPTION
            'agenda_POSICION_INTERVALO_INVALIDO';
    END IF;


    ------------------------------------------------------------
    -- 2. REFERENCIA ANTERIOR O IGUAL AL ANCLA
    ------------------------------------------------------------

    IF p_fecha_referencia <= p_fecha_ancla THEN

        v_actual := p_fecha_ancla;

        v_siguiente :=
            constructora.fn_fecha_recurrencia(
                p_fecha_ancla,
                v_frecuencia,
                p_intervalo,
                1
            );

        RETURN QUERY
        SELECT
            0::bigint,
            NULL::timestamptz,
            v_actual,
            v_siguiente;

        RETURN;

    END IF;


    ------------------------------------------------------------
    -- 3. ESTIMAR POSICIÓN
    --
    -- La estimación evita recorrer desde posición 0.
    --
    -- Después verificamos/corregimos usando
    -- fn_fecha_recurrencia(), que sigue siendo la autoridad.
    ------------------------------------------------------------

    CASE v_frecuencia

        --------------------------------------------------------
        -- DIARIA
        --------------------------------------------------------

        WHEN 'diaria' THEN

            v_dias :=
                extract(
                    epoch FROM (
                        p_fecha_referencia - p_fecha_ancla
                    )
                ) / 86400.0;

            v_estimacion :=
                floor(
                    v_dias / p_intervalo
                )::bigint;


        --------------------------------------------------------
        -- SEMANAL
        --------------------------------------------------------

        WHEN 'semanal' THEN

            v_dias :=
                extract(
                    epoch FROM (
                        p_fecha_referencia - p_fecha_ancla
                    )
                ) / 86400.0;

            v_estimacion :=
                floor(
                    v_dias / (p_intervalo * 7.0)
                )::bigint;


        --------------------------------------------------------
        -- MENSUAL
        --------------------------------------------------------

        WHEN 'mensual' THEN

            v_meses :=
                (
                    extract(year FROM p_fecha_referencia)::bigint
                    -
                    extract(year FROM p_fecha_ancla)::bigint
                ) * 12
                +
                (
                    extract(month FROM p_fecha_referencia)::bigint
                    -
                    extract(month FROM p_fecha_ancla)::bigint
                );

            v_estimacion :=
                floor(
                    v_meses::numeric / p_intervalo
                )::bigint;


        --------------------------------------------------------
        -- ANUAL
        --------------------------------------------------------

        WHEN 'anual' THEN

            v_anios :=
                extract(year FROM p_fecha_referencia)::bigint
                -
                extract(year FROM p_fecha_ancla)::bigint;

            v_estimacion :=
                floor(
                    v_anios::numeric / p_intervalo
                )::bigint;

    END CASE;


    ------------------------------------------------------------
    -- Nunca permitimos estimación negativa aquí.
    ------------------------------------------------------------

    v_posicion :=
        greatest(v_estimacion, 0);


    ------------------------------------------------------------
    -- 4. CALCULAR FECHA ESTIMADA
    ------------------------------------------------------------

    v_actual :=
        constructora.fn_fecha_recurrencia(
            p_fecha_ancla,
            v_frecuencia,
            p_intervalo,
            v_posicion
        );


    ------------------------------------------------------------
    -- 5. CORREGIR HACIA ATRÁS
    --
    -- Si la estimación cayó después de la referencia,
    -- retrocedemos.
    ------------------------------------------------------------

    WHILE
        v_posicion > 0
        AND v_actual > p_fecha_referencia
    LOOP

        v_posicion := v_posicion - 1;

        v_actual :=
            constructora.fn_fecha_recurrencia(
                p_fecha_ancla,
                v_frecuencia,
                p_intervalo,
                v_posicion
            );

    END LOOP;


    ------------------------------------------------------------
    -- 6. BUSCAR PRIMERA OCURRENCIA >= REFERENCIA
    --
    -- En este punto v_actual normalmente es la ocurrencia
    -- anterior o exactamente la referencia.
    ------------------------------------------------------------

    IF v_actual < p_fecha_referencia THEN

        LOOP

            v_siguiente :=
                constructora.fn_fecha_recurrencia(
                    p_fecha_ancla,
                    v_frecuencia,
                    p_intervalo,
                    v_posicion + 1
                );

            EXIT WHEN v_siguiente >= p_fecha_referencia;

            v_posicion := v_posicion + 1;
            v_actual := v_siguiente;

        END LOOP;


        --------------------------------------------------------
        -- v_actual es ahora la anterior.
        -- v_siguiente es correspondiente.
        --------------------------------------------------------

        v_anterior := v_actual;

        v_posicion := v_posicion + 1;

        v_actual := v_siguiente;


    ELSE

        --------------------------------------------------------
        -- Coincidencia exacta.
        --
        -- Buscamos la ocurrencia anterior.
        --------------------------------------------------------

        IF v_posicion = 0 THEN

            v_anterior := NULL;

        ELSE

            v_anterior :=
                constructora.fn_fecha_recurrencia(
                    p_fecha_ancla,
                    v_frecuencia,
                    p_intervalo,
                    v_posicion - 1
                );

        END IF;

    END IF;


    ------------------------------------------------------------
    -- 7. SIGUIENTE
    ------------------------------------------------------------

    v_siguiente :=
        constructora.fn_fecha_recurrencia(
            p_fecha_ancla,
            v_frecuencia,
            p_intervalo,
            v_posicion + 1
        );


    ------------------------------------------------------------
    -- 8. RESULTADO
    ------------------------------------------------------------

    RETURN QUERY
    SELECT
        v_posicion,
        v_anterior,
        v_actual,
        v_siguiente;

END;
$$;


ALTER FUNCTION constructora.fn_posicion_recurrencia(p_fecha_ancla timestamp with time zone, p_frecuencia text, p_intervalo integer, p_fecha_referencia timestamp with time zone) OWNER TO postgres;

--
-- Name: historial_recurrencia; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.historial_recurrencia (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agenda_item_id uuid NOT NULL,
    fecha timestamp with time zone,
    estado text,
    creado_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE constructora.historial_recurrencia OWNER TO postgres;

--
-- Name: fn_registrar_recurrencia(uuid, bigint, text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_registrar_recurrencia(p_agenda_item_id uuid, p_posicion bigint, p_estado text) RETURNS constructora.historial_recurrencia
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_item          constructora.items%ROWTYPE;
    v_frecuencia    text;
    v_intervalo     integer;
    v_estado        text;
    v_fecha         timestamptz;

    v_existente     constructora.historial_recurrencia%ROWTYPE;
    v_resultado     constructora.historial_recurrencia%ROWTYPE;
BEGIN

    -- ========================================================
    -- 1. VALIDAR ID
    -- ========================================================

    IF p_agenda_item_id IS NULL THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_ITEM_ID_REQUERIDO';
    END IF;


    -- ========================================================
    -- 2. BLOQUEAR Y LEER ITEM
    --
    -- Esto evita que mientras registramos una ocurrencia
    -- otra transacción cambie fecha_inicio o recurrencia.
    -- ========================================================

    SELECT *
    INTO v_item
    FROM constructora.items
    WHERE id = p_agenda_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_ITEM_NO_EXISTE';
    END IF;


    -- ========================================================
    -- 3. VALIDAR QUE SEA RECURRENTE
    -- ========================================================

    IF v_item.recurrencia IS NULL THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_ITEM_NO_RECURRENTE';
    END IF;

    IF jsonb_typeof(v_item.recurrencia) <> 'object' THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_CONFIG_INVALIDA';
    END IF;


    -- ========================================================
    -- 4. NECESITAMOS FECHA DE ANCLA
    -- ========================================================

    IF v_item.fecha_inicio IS NULL THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_FECHA_INICIO_REQUERIDA';
    END IF;


    -- ========================================================
    -- 5. EXTRAER FRECUENCIA
    -- ========================================================

    v_frecuencia :=
        lower(
            btrim(
                v_item.recurrencia ->> 'frecuencia'
            )
        );

    IF v_frecuencia IS NULL
       OR v_frecuencia = ''
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_FRECUENCIA_REQUERIDA';
    END IF;

    IF v_frecuencia NOT IN (
        'diaria',
        'semanal',
        'mensual',
        'anual'
    )
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_FRECUENCIA_INVALIDA';
    END IF;


    -- ========================================================
    -- 6. EXTRAER INTERVALO
    --
    -- Si no viene:
    -- intervalo = 1
    --
    -- Por eso son equivalentes:
    --
    -- {"frecuencia":"mensual"}
    --
    -- y
    --
    -- {"frecuencia":"mensual","intervalo":1}
    -- ========================================================

    IF NOT (v_item.recurrencia ? 'intervalo')
       OR
       v_item.recurrencia -> 'intervalo' = 'null'::jsonb
    THEN

        v_intervalo := 1;

    ELSE

        BEGIN

            v_intervalo :=
                (v_item.recurrencia ->> 'intervalo')::integer;

        EXCEPTION
            WHEN invalid_text_representation
              OR numeric_value_out_of_range
            THEN
                RAISE EXCEPTION
                    'agenda_RECURRENCIA_INTERVALO_INVALIDO';
        END;

    END IF;


    IF v_intervalo <= 0 THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_INTERVALO_INVALIDO';
    END IF;


    -- ========================================================
    -- 7. VALIDAR POSICIÓN
    -- ========================================================

    IF p_posicion IS NULL
       OR p_posicion < 0
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_POSICION_INVALIDA';
    END IF;


    -- ========================================================
    -- 8. VALIDAR ESTADO DE LA OCURRENCIA
    -- ========================================================

    IF p_estado IS NULL
       OR btrim(p_estado) = ''
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_ESTADO_REQUERIDO';
    END IF;

    v_estado := lower(btrim(p_estado));

    IF v_estado NOT IN (
        'completado',
        'no_completado',
        'cancelado'
    )
    THEN
        RAISE EXCEPTION
            'agenda_RECURRENCIA_ESTADO_INVALIDO';
    END IF;


    -- ========================================================
    -- 9. CALCULAR FECHA REAL
    --
    -- EL CALLER NO DECIDE LA FECHA.
    --
    -- La fecha sale exclusivamente de:
    --
    --   fecha_inicio
    --   frecuencia
    --   intervalo
    --   posición
    -- ========================================================

    v_fecha :=
        constructora.fn_fecha_recurrencia(
            v_item.fecha_inicio,
            v_frecuencia,
            v_intervalo,
            p_posicion
        );


    -- ========================================================
    -- 10. BUSCAR SI ESA OCURRENCIA YA EXISTE
    --
    -- Mientras todavía no tengamos constraint UNIQUE,
    -- bloqueamos cualquier coincidencia existente.
    -- ========================================================

    SELECT *
    INTO v_existente
    FROM constructora.historial_recurrencia
    WHERE agenda_item_id = p_agenda_item_id
      AND fecha = v_fecha
    ORDER BY creado_at, id
    LIMIT 1
    FOR UPDATE;


    -- ========================================================
    -- 11A. YA EXISTE
    --
    -- Actualizamos estado.
    -- NO duplicamos la ocurrencia.
    -- ========================================================

    IF FOUND THEN

        UPDATE constructora.historial_recurrencia
        SET estado = v_estado
        WHERE id = v_existente.id
        RETURNING *
        INTO v_resultado;

        RETURN v_resultado;

    END IF;


    -- ========================================================
    -- 11B. NO EXISTE
    -- ========================================================

    INSERT INTO constructora.historial_recurrencia (
        agenda_item_id,
        fecha,
        estado
    )
    VALUES (
        p_agenda_item_id,
        v_fecha,
        v_estado
    )
    RETURNING *
    INTO v_resultado;


    -- ========================================================
    -- 12. RESULTADO
    -- ========================================================

    RETURN v_resultado;

END;
$$;


ALTER FUNCTION constructora.fn_registrar_recurrencia(p_agenda_item_id uuid, p_posicion bigint, p_estado text) OWNER TO postgres;

--
-- Name: fn_tarea(jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_tarea(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_accion text;
    v_id uuid;
    v_item_id uuid;
    v_descripcion text;
    v_completada boolean;
    v_actual constructora.tareas%ROWTYPE;
    v_resultado constructora.tareas%ROWTYPE;
BEGIN
    IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
        RAISE EXCEPTION 'agenda_REQUIERE_DATO|tarea|Necesito los datos de la tarea.';
    END IF;

    IF p_data ? 'id' AND p_data->'id' <> 'null'::jsonb THEN
        BEGIN
            v_id := (p_data->>'id')::uuid;
        EXCEPTION WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|tarea_id|El identificador de la tarea no es válido.';
        END;
    END IF;

    v_accion := lower(btrim(coalesce(p_data->>'accion','')));
    IF v_accion = '' THEN
        v_accion := CASE WHEN v_id IS NULL THEN 'crear' ELSE 'modificar' END;
    END IF;

    IF v_accion NOT IN ('crear','modificar','eliminar') THEN
        RAISE EXCEPTION 'agenda_OPERACION_NO_PERMITIDA|tarea.accion|La acción debe ser crear, modificar o eliminar.';
    END IF;

    IF v_accion = 'crear' THEN
        IF v_id IS NOT NULL THEN
            RAISE EXCEPTION 'agenda_REQUIERE_ACLARACION|tarea|Crear una tarea no admite un id existente.';
        END IF;

        BEGIN
            v_item_id := (p_data->>'agenda_item_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|agenda_item_id|¿A qué evento pertenece la tarea?';
        END;

        IF NOT EXISTS (SELECT 1 FROM constructora.items WHERE id=v_item_id) THEN
            RAISE EXCEPTION 'agenda_REQUIERE_ACLARACION|agenda_item_id|El evento indicado no existe.';
        END IF;

        v_descripcion := nullif(btrim(p_data->>'descripcion'),'');
        IF v_descripcion IS NULL THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|descripcion|¿Cuál es la tarea?';
        END IF;

        IF p_data ? 'completada' AND p_data->'completada' <> 'null'::jsonb THEN
            BEGIN
                v_completada := (p_data->>'completada')::boolean;
            EXCEPTION WHEN invalid_text_representation THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|completada|Debe ser verdadero o falso.';
            END;
        ELSE
            v_completada := false;
        END IF;

        INSERT INTO constructora.tareas(agenda_item_id,descripcion,completada)
        VALUES(v_item_id,v_descripcion,v_completada)
        RETURNING * INTO v_resultado;

        RETURN jsonb_build_object('ok',true,'accion','crear','tarea',to_jsonb(v_resultado));
    END IF;

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'agenda_REQUIERE_DATO|tarea_id|Necesito identificar la tarea.';
    END IF;

    SELECT * INTO v_actual
    FROM constructora.tareas
    WHERE id=v_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'agenda_REQUIERE_ACLARACION|tarea|La tarea indicada no existe.';
    END IF;

    IF v_accion = 'eliminar' THEN
        DELETE FROM constructora.tareas WHERE id=v_id;
        RETURN jsonb_build_object('ok',true,'accion','eliminar','tarea_id',v_id,'eliminada',true);
    END IF;

    -- Una tarea no se mueve entre eventos.
    IF p_data ? 'agenda_item_id' THEN
        RAISE EXCEPTION 'agenda_OPERACION_NO_PERMITIDA|agenda_item_id|Una tarea no puede moverse a otro evento.';
    END IF;

    IF p_data ? 'descripcion' THEN
        v_descripcion := nullif(btrim(p_data->>'descripcion'),'');
        IF v_descripcion IS NULL THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|descripcion|La descripción no puede quedar vacía.';
        END IF;
    ELSE
        v_descripcion := v_actual.descripcion;
    END IF;

    IF p_data ? 'completada' THEN
        IF p_data->'completada' = 'null'::jsonb THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|completada|Debe ser verdadero o falso.';
        END IF;
        BEGIN
            v_completada := (p_data->>'completada')::boolean;
        EXCEPTION WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'agenda_REQUIERE_DATO|completada|Debe ser verdadero o falso.';
        END;
    ELSE
        v_completada := v_actual.completada;
    END IF;

    UPDATE constructora.tareas
       SET descripcion=v_descripcion,
           completada=v_completada
     WHERE id=v_id
     RETURNING * INTO v_resultado;

    RETURN jsonb_build_object('ok',true,'accion','modificar','tarea',to_jsonb(v_resultado));
END;
$$;


ALTER FUNCTION constructora.fn_tarea(p_data jsonb) OWNER TO postgres;

--
-- Name: FUNCTION fn_tarea(p_data jsonb); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.fn_tarea(p_data jsonb) IS 'Primitiva única de tareas: crea, modifica o elimina. Completar/reabrir modifica completada.';


--
-- Name: fn_whatsapp_analisis_delete(uuid); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_whatsapp_analisis_delete(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_row constructora.whatsapp_analisis%ROWTYPE;
BEGIN
    IF p_id IS NULL THEN
        RAISE EXCEPTION 'Se requiere el id del análisis.' USING ERRCODE = '22023';
    END IF;

    DELETE FROM constructora.whatsapp_analisis
    WHERE id = p_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el análisis con id %.', p_id USING ERRCODE = 'P0002';
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'accion', 'eliminado',
        'id', v_row.id,
        'nombre_conversacion', v_row.nombre_conversacion,
        'nombre_archivo', v_row.nombre_archivo,
        'fecha_analisis', v_row.fecha_analisis
    );
END;
$$;


ALTER FUNCTION constructora.fn_whatsapp_analisis_delete(p_id uuid) OWNER TO postgres;

--
-- Name: FUNCTION fn_whatsapp_analisis_delete(p_id uuid); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.fn_whatsapp_analisis_delete(p_id uuid) IS 'Elimina definitivamente un informe de análisis por UUID; no afecta otros informes ni mensajes.';


--
-- Name: fn_whatsapp_analisis_listar(text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_whatsapp_analisis_listar(p_nombre_conversacion text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_resultado jsonb;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            to_jsonb(a)
            ORDER BY a.fecha_analisis DESC, a.id
        ),
        '[]'::jsonb
    )
    INTO v_resultado
    FROM constructora.whatsapp_analisis a
    WHERE p_nombre_conversacion IS NULL
       OR a.nombre_conversacion = btrim(p_nombre_conversacion);

    RETURN jsonb_build_object(
        'ok', true,
        'total', jsonb_array_length(v_resultado),
        'analisis', v_resultado
    );
END;
$$;


ALTER FUNCTION constructora.fn_whatsapp_analisis_listar(p_nombre_conversacion text) OWNER TO postgres;

--
-- Name: FUNCTION fn_whatsapp_analisis_listar(p_nombre_conversacion text); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.fn_whatsapp_analisis_listar(p_nombre_conversacion text) IS 'Lista informes de WhatsApp o recupera el informe vigente de una conversación por nombre.';


--
-- Name: fn_whatsapp_analisis_upsert(jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.fn_whatsapp_analisis_upsert(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_row constructora.whatsapp_analisis%ROWTYPE;
    v_insertado boolean;
    v_nombre text;
    v_archivo text;
    v_informe text;
    v_resultado jsonb;
    v_fecha date;
BEGIN
    IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
        RAISE EXCEPTION 'Se requiere un objeto JSON valido.' USING ERRCODE = '22023';
    END IF;

    v_nombre := nullif(btrim(p_data->>'nombre_conversacion'), '');
    v_informe := nullif(btrim(p_data->>'informe_texto'), '');
    v_resultado := p_data->'resultado';
    v_archivo := nullif(btrim(p_data->>'nombre_archivo'), '');
    v_fecha := COALESCE(NULLIF(p_data->>'fecha_referencia', '')::date, CURRENT_DATE);

    IF v_nombre IS NULL OR v_informe IS NULL OR
       v_resultado IS NULL OR jsonb_typeof(v_resultado) <> 'object' THEN
        RAISE EXCEPTION 'Se requieren nombre_conversacion, informe_texto y resultado (objeto JSON).'
            USING ERRCODE = '22023';
    END IF;

    -- Si no se proporciona nombre_archivo, se conserva el previo en UPDATE.
    -- En INSERT se usa el nombre de conversacion como identificador legible.
    INSERT INTO constructora.whatsapp_analisis AS a
        (nombre_conversacion, nombre_archivo, fecha_referencia, resultado, informe_texto)
    VALUES
        (v_nombre, COALESCE(v_archivo, v_nombre), v_fecha, v_resultado, v_informe)
    ON CONFLICT (nombre_conversacion) DO UPDATE SET
        nombre_archivo = COALESCE(v_archivo, a.nombre_archivo),
        fecha_referencia = EXCLUDED.fecha_referencia,
        fecha_analisis = now(),
        resultado = EXCLUDED.resultado,
        informe_texto = EXCLUDED.informe_texto
    RETURNING * INTO v_row;

    -- El resultado es el informe vigente; no se conserva historial.
    RETURN jsonb_build_object('ok', true, 'analisis', to_jsonb(v_row));
END;
$$;


ALTER FUNCTION constructora.fn_whatsapp_analisis_upsert(p_data jsonb) OWNER TO postgres;

--
-- Name: FUNCTION fn_whatsapp_analisis_upsert(p_data jsonb); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.fn_whatsapp_analisis_upsert(p_data jsonb) IS 'Inserta o reemplaza el informe vigente identificado por nombre_conversacion; no requiere UUID. Conserva recomendaciones dentro de resultado e informe_texto.';


--
-- Name: contexto_voz; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.contexto_voz (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transcripcion text NOT NULL,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    expira_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval) NOT NULL,
    CONSTRAINT contexto_voz_expiracion_valida CHECK ((expira_at >= creado_at)),
    CONSTRAINT contexto_voz_texto_no_vacio CHECK ((btrim(transcripcion) <> ''::text))
);


ALTER TABLE constructora.contexto_voz OWNER TO postgres;

--
-- Name: TABLE contexto_voz; Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON TABLE constructora.contexto_voz IS 'Transcripciones temporales utilizadas como contexto conversacional. Dejan de estar activas automáticamente al superar expira_at.';


--
-- Name: guardar_contexto_voz(text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.guardar_contexto_voz(p_transcripcion text) RETURNS constructora.contexto_voz
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_resultado constructora.contexto_voz;
BEGIN

    IF p_transcripcion IS NULL
       OR btrim(p_transcripcion) = '' THEN

        RAISE EXCEPTION
            'agenda_REQUIERE_DATO|transcripcion|La transcripción no puede estar vacía.';
    END IF;


    INSERT INTO constructora.contexto_voz (
        transcripcion
    )
    VALUES (
        btrim(p_transcripcion)
    )
    RETURNING *
    INTO v_resultado;


    RETURN v_resultado;

END;
$$;


ALTER FUNCTION constructora.guardar_contexto_voz(p_transcripcion text) OWNER TO postgres;

--
-- Name: FUNCTION guardar_contexto_voz(p_transcripcion text); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.guardar_contexto_voz(p_transcripcion text) IS 'Guarda una transcripción como contexto conversacional temporal durante 24 horas.';


--
-- Name: guardar_plan_secretaria(uuid, jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.guardar_plan_secretaria(p_id uuid, p_plan jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id uuid;
    v_estado text;
    v_resultado jsonb;
BEGIN

    IF p_plan IS NULL
       OR jsonb_typeof(p_plan) <> 'object' THEN

        RAISE EXCEPTION
            'agenda_OPERACION_NO_PERMITIDA|plan|El plan de Secretaría debe ser un objeto JSON.';

    END IF;


    -- ========================================================
    -- CREAR
    -- ========================================================

    IF p_id IS NULL THEN

        INSERT INTO constructora.plan_secretaria (
            estado,
            plan
        )
        VALUES (
            'consulta',
            p_plan
        )
        RETURNING id
        INTO v_id;


    -- ========================================================
    -- ACTUALIZAR
    -- ========================================================

    ELSE

        SELECT estado
        INTO v_estado
        FROM constructora.plan_secretaria
        WHERE id = p_id
        FOR UPDATE;


        IF NOT FOUND THEN

            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|plan|El plan de Secretaría no existe.';

        END IF;


        IF v_estado <> 'consulta' THEN

            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|plan|Solo puede modificarse un plan que esté en consulta.';

        END IF;


        UPDATE constructora.plan_secretaria
        SET
            plan = p_plan,
            actualizado_at = now()
        WHERE id = p_id;

        v_id := p_id;

    END IF;


    SELECT jsonb_build_object(
        'id', ps.id,
        'estado', ps.estado,
        'plan', ps.plan,
        'creado_at', ps.creado_at,
        'actualizado_at', ps.actualizado_at
    )
    INTO v_resultado
    FROM constructora.plan_secretaria ps
    WHERE ps.id = v_id;


    RETURN v_resultado;

END;
$$;


ALTER FUNCTION constructora.guardar_plan_secretaria(p_id uuid, p_plan jsonb) OWNER TO postgres;

--
-- Name: transcripciones; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.transcripciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    titulo text,
    transcripcion text NOT NULL,
    nombre_archivo text,
    tipo_mime text,
    duracion_segundos integer,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_at timestamp with time zone DEFAULT now() NOT NULL,
    archivo_audio text,
    CONSTRAINT transcripciones_duracion_valida CHECK (((duracion_segundos IS NULL) OR (duracion_segundos >= 0))),
    CONSTRAINT transcripciones_texto_no_vacio CHECK ((btrim(transcripcion) <> ''::text))
);


ALTER TABLE constructora.transcripciones OWNER TO postgres;

--
-- Name: TABLE transcripciones; Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON TABLE constructora.transcripciones IS 'Transcripciones permanentes de reuniones, notas de voz y audios que el dueño desea conservar.';


--
-- Name: guardar_transcripcion(text, text, text, text, integer, text); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.guardar_transcripcion(p_transcripcion text, p_titulo text DEFAULT NULL::text, p_nombre_archivo text DEFAULT NULL::text, p_tipo_mime text DEFAULT NULL::text, p_duracion_segundos integer DEFAULT NULL::integer, p_archivo_audio text DEFAULT NULL::text) RETURNS constructora.transcripciones
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_resultado constructora.transcripciones;
BEGIN

    IF p_transcripcion IS NULL
       OR btrim(p_transcripcion) = '' THEN

        RAISE EXCEPTION
            'agenda_REQUIERE_DATO|transcripcion|La transcripción no puede estar vacía.';
    END IF;

    IF p_duracion_segundos IS NOT NULL
       AND p_duracion_segundos < 0 THEN

        RAISE EXCEPTION
            'agenda_OPERACION_NO_PERMITIDA|duracion_segundos|La duración del audio no puede ser negativa.';
    END IF;

    INSERT INTO constructora.transcripciones (
        titulo,
        transcripcion,
        nombre_archivo,
        tipo_mime,
        duracion_segundos,
        archivo_audio
    )
    VALUES (
        NULLIF(btrim(p_titulo), ''),
        btrim(p_transcripcion),
        NULLIF(btrim(p_nombre_archivo), ''),
        NULLIF(btrim(p_tipo_mime), ''),
        p_duracion_segundos,
        NULLIF(btrim(p_archivo_audio), '')
    )
    RETURNING *
    INTO v_resultado;

    RETURN v_resultado;
END;
$$;


ALTER FUNCTION constructora.guardar_transcripcion(p_transcripcion text, p_titulo text, p_nombre_archivo text, p_tipo_mime text, p_duracion_segundos integer, p_archivo_audio text) OWNER TO postgres;

--
-- Name: listar_agenda(integer, boolean); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.listar_agenda(p_dias_historial integer DEFAULT 30, p_incluir_ocultos boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_resultado jsonb;
BEGIN
    IF p_dias_historial IS NOT NULL AND p_dias_historial < 0 THEN
        RAISE EXCEPTION 'agenda_OPERACION_NO_PERMITIDA|dias_historial|Los días de historial no pueden ser negativos.';
    END IF;

    SELECT jsonb_build_object(
        'items',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id',i.id,
                    'titulo',i.titulo,
                    'descripcion',i.descripcion,
                    'estado',i.estado,
                    'prioridad',i.prioridad,
                    'oculto',i.oculto,
                    'fecha_inicio',i.fecha_inicio,
                    'fecha_limite',i.fecha_limite,
                    'todo_el_dia',i.todo_el_dia,
                    'recordatorio',i.recordatorio,
                    'participantes',i.participantes,
                    'recurrencia',i.recurrencia,

                    'situacion_recurrencia',
                    CASE WHEN i.recurrencia IS NULL THEN NULL
                    ELSE (
                        SELECT jsonb_build_object(
                            'posicion',r.posicion,
                            'anterior',r.anterior,
                            'correspondiente',r.correspondiente,
                            'siguiente',r.siguiente
                        )
                        FROM constructora.fn_posicion_recurrencia(
                            i.fecha_inicio,
                            i.recurrencia->>'frecuencia',
                            COALESCE((i.recurrencia->>'intervalo')::integer,1),
                            now()
                        ) r
                    ) END,

                    'tareas',
                    COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id',t.id,
                                'descripcion',t.descripcion,
                                'completada',t.completada
                            )
                            ORDER BY t.creado_at,t.id
                        )
                        FROM constructora.tareas t
                        WHERE t.agenda_item_id=i.id
                    ),'[]'::jsonb),

                    'observaciones',
                    COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id',o.id,
                                'observacion',o.observacion,
                                'estado_anterior',o.estado_anterior,
                                'estado_nuevo',o.estado_nuevo,
                                'creado_at',o.creado_at,
                                'secuencia',o.secuencia
                            )
                            ORDER BY o.secuencia
                        )
                        FROM constructora.observaciones o
                        WHERE o.agenda_item_id=i.id
                    ),'[]'::jsonb),

                    'historial_recurrencia',
                    COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id',h.id,
                                'fecha',h.fecha,
                                'estado',h.estado,
                                'creado_at',h.creado_at
                            )
                            ORDER BY h.fecha
                        )
                        FROM constructora.historial_recurrencia h
                        WHERE h.agenda_item_id=i.id
                    ),'[]'::jsonb),

                    'creado_at',i.creado_at,
                    'actualizado_at',i.actualizado_at
                )
                ORDER BY
                    CASE WHEN i.estado='activo' THEN 0 ELSE 1 END,
                    CASE WHEN i.prioridad='alta' THEN 0 ELSE 1 END,
                    i.fecha_inicio ASC NULLS LAST,
                    i.actualizado_at DESC
            ),
            '[]'::jsonb
        )
    )
    INTO v_resultado
    FROM constructora.items i
    WHERE
        (p_incluir_ocultos=true OR i.oculto=false)
        AND (
            i.estado='activo'
            OR p_dias_historial IS NULL
            OR (
                i.estado IN ('completado','cancelado')
                AND i.actualizado_at >= now()-make_interval(days=>p_dias_historial)
            )
        );

    RETURN v_resultado;
END;
$$;


ALTER FUNCTION constructora.listar_agenda(p_dias_historial integer, p_incluir_ocultos boolean) OWNER TO postgres;

--
-- Name: FUNCTION listar_agenda(p_dias_historial integer, p_incluir_ocultos boolean); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.listar_agenda(p_dias_historial integer, p_incluir_ocultos boolean) IS 'Lista Agenda con eventos, tareas, observaciones, historial y situación de recurrencia.';


--
-- Name: listar_contexto_voz_activo(); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.listar_contexto_voz_activo() RETURNS SETOF constructora.contexto_voz
    LANGUAGE sql STABLE
    AS $$
    SELECT *
    FROM constructora.contexto_voz
    WHERE expira_at > now()
    ORDER BY creado_at ASC;
$$;


ALTER FUNCTION constructora.listar_contexto_voz_activo() OWNER TO postgres;

--
-- Name: FUNCTION listar_contexto_voz_activo(); Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON FUNCTION constructora.listar_contexto_voz_activo() IS 'Devuelve únicamente contexto de voz cuya ventana temporal todavía está activa.';


--
-- Name: listar_proyectos(); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.listar_proyectos() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_result jsonb;
BEGIN

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(

                -- ============================================
                -- PROYECTO
                -- ============================================

                'id', p.id,
                'titulo', p.titulo,
                'slug', p.slug,
                'descripcion', p.descripcion,
                'descripcion_corta', p.descripcion_corta,
                'ubicacion', p.ubicacion,
                'estado', p.estado,

                'fecha_inicio', p.fecha_inicio,
                'fecha_fin', p.fecha_fin,

                'progreso', p.progreso,

                'imagen_portada', p.imagen_portada,

                'destacado', p.destacado,
                'publicado', p.publicado,
                'orden', p.orden,

                'detalles', p.detalles,

                'created_at', p.created_at,
                'updated_at', p.updated_at,


                -- ============================================
                -- CRONOGRAMA / ACTIVIDADES
                -- ============================================

                'cronograma',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                            jsonb_build_object(

                                'id', c.id,
                                'nombre', c.nombre,
                                'descripcion', c.descripcion,
                                'fecha_inicio', c.fecha_inicio,
                                'fecha_fin', c.fecha_fin,
                                'progreso', c.progreso,
                                'orden', c.orden,
                                'detalles', c.detalles,
                                'created_at', c.created_at,
                                'updated_at', c.updated_at,


                                -- ====================================
                                -- AVANCES DE ESTA ACTIVIDAD
                                -- ====================================

                                'avances',
                                COALESCE(
                                    (
                                        SELECT jsonb_agg(
                                            jsonb_build_object(

                                                'id', a.id,
                                                'proyecto_id', a.proyecto_id,
                                                'cronograma_id', a.cronograma_id,
                                                'titulo', a.titulo,
                                                'descripcion', a.descripcion,
                                                'fecha', a.fecha,
                                                'publicado', a.publicado,
                                                'created_at', a.created_at,
                                                'updated_at', a.updated_at,


                                                -- ====================
                                                -- IMÁGENES DEL AVANCE
                                                -- ====================

                                                'imagenes',
                                                COALESCE(
                                                    (
                                                        SELECT jsonb_agg(
                                                            jsonb_build_object(
                                                                'id', ai.id,
                                                                'imagen_origen_id', ai.imagen_origen_id,
                                                                'url', ai.url,
                                                                'descripcion', ai.descripcion,
                                                                'orden', ai.orden,
                                                                'created_at', ai.created_at
                                                            )
                                                            ORDER BY
                                                                ai.orden,
                                                                ai.created_at
                                                        )
                                                        FROM constructora.avance_imagenes ai
                                                        WHERE ai.avance_id = a.id
                                                    ),
                                                    '[]'::jsonb
                                                )

                                            )
                                            ORDER BY
                                                a.fecha DESC,
                                                a.created_at DESC
                                        )
                                        FROM constructora.avances a
                                        WHERE a.cronograma_id = c.id
                                    ),
                                    '[]'::jsonb
                                )

                            )
                            ORDER BY
                                c.orden,
                                c.fecha_inicio
                        )
                        FROM constructora.cronograma c
                        WHERE c.proyecto_id = p.id
                    ),
                    '[]'::jsonb
                ),


                -- ============================================
                -- GALERÍA
                -- ============================================

                'imagenes',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', i.id,
                                'url', i.url,
                                'titulo', i.titulo,
                                'descripcion', i.descripcion,
                                'tipo', i.tipo,
                                'orden', i.orden,
                                'publicada', i.publicada,
                                'created_at', i.created_at
                            )
                            ORDER BY
                                i.orden,
                                i.created_at
                        )
                        FROM constructora.proyecto_imagenes i
                        WHERE i.proyecto_id = p.id
                    ),
                    '[]'::jsonb
                ),


                -- ============================================
                -- IMÁGENES PENDIENTES
                -- ============================================

                'imagenes_pendientes',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', ip.id,
                                'archivo', ip.archivo,
                                'url_temporal', ip.url_temporal,
                                'url_editada', ip.url_editada,
                                'titulo', ip.titulo,
                                'descripcion', ip.descripcion,
                                'estado', ip.estado,
                                'created_at', ip.created_at,
                                'revisado_at', ip.revisado_at
                            )
                            ORDER BY ip.created_at DESC
                        )
                        FROM constructora.imagenes_pendientes ip
                        WHERE ip.proyecto_id = p.id
                    ),
                    '[]'::jsonb
                )

            )
            ORDER BY
                p.orden,
                p.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_result

    FROM constructora.proyectos p;

    RETURN v_result;

END;
$$;


ALTER FUNCTION constructora.listar_proyectos() OWNER TO postgres;

--
-- Name: listar_proyectos_publicos(); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.listar_proyectos_publicos() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
    v_result jsonb;
BEGIN

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(

                -- ============================================
                -- PROYECTO
                -- ============================================

                'id', p.id,
                'titulo', p.titulo,
                'slug', p.slug,
                'descripcion', p.descripcion,
                'descripcion_corta', p.descripcion_corta,
                'ubicacion', p.ubicacion,
                'estado', p.estado,

                'fecha_inicio', p.fecha_inicio,
                'fecha_fin', p.fecha_fin,

                'progreso', p.progreso,

                'imagen_portada', p.imagen_portada,

                'destacado', p.destacado,
                'orden', p.orden,

                'detalles', p.detalles,


                -- ============================================
                -- CRONOGRAMA / ACTIVIDADES
                -- ============================================

                'cronograma',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                            jsonb_build_object(

                                'id', c.id,
                                'nombre', c.nombre,
                                'descripcion', c.descripcion,
                                'fecha_inicio', c.fecha_inicio,
                                'fecha_fin', c.fecha_fin,
                                'progreso', c.progreso,
                                'orden', c.orden,
                                'detalles', c.detalles,


                                -- ====================================
                                -- AVANCES PUBLICADOS DE LA ACTIVIDAD
                                -- ====================================

                                'avances',
                                COALESCE(
                                    (
                                        SELECT jsonb_agg(
                                            jsonb_build_object(

                                                'id', a.id,
                                                'titulo', a.titulo,
                                                'descripcion', a.descripcion,
                                                'fecha', a.fecha,

                                                -- ====================
                                                -- IMÁGENES DEL AVANCE
                                                -- ====================

                                                'imagenes',
                                                COALESCE(
                                                    (
                                                        SELECT jsonb_agg(
                                                            jsonb_build_object(
                                                                'id', ai.id,
                                                                'url', ai.url,
                                                                'descripcion', ai.descripcion,
                                                                'orden', ai.orden
                                                            )
                                                            ORDER BY
                                                                ai.orden,
                                                                ai.created_at
                                                        )
                                                        FROM constructora.avance_imagenes ai
                                                        WHERE ai.avance_id = a.id
                                                    ),
                                                    '[]'::jsonb
                                                )

                                            )
                                            ORDER BY
                                                a.fecha DESC,
                                                a.created_at DESC
                                        )
                                        FROM constructora.avances a
                                        WHERE a.cronograma_id = c.id
                                          AND a.publicado = true
                                    ),
                                    '[]'::jsonb
                                )

                            )
                            ORDER BY
                                c.orden,
                                c.fecha_inicio
                        )
                        FROM constructora.cronograma c
                        WHERE c.proyecto_id = p.id
                    ),
                    '[]'::jsonb
                ),


                -- ============================================
                -- GALERÍA / PORTADA
                -- ============================================

                'imagenes',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', i.id,
                                'url', i.url,
                                'titulo', i.titulo,
                                'descripcion', i.descripcion,
                                'tipo', i.tipo,
                                'orden', i.orden
                            )
                            ORDER BY
                                CASE
                                    WHEN i.tipo = 'portada' THEN 0
                                    ELSE 1
                                END,
                                i.orden,
                                i.created_at
                        )
                        FROM constructora.proyecto_imagenes i
                        WHERE i.proyecto_id = p.id
                          AND i.publicada = true
                    ),
                    '[]'::jsonb
                )

            )
            ORDER BY
                p.destacado DESC,
                p.orden,
                p.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_result

    FROM constructora.proyectos p

    WHERE p.publicado = true;


    RETURN v_result;

END;
$$;


ALTER FUNCTION constructora.listar_proyectos_publicos() OWNER TO postgres;

--
-- Name: obtener_plan_secretaria(); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.obtener_plan_secretaria() RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_resultado jsonb;
BEGIN

    SELECT jsonb_build_object(
        'id', ps.id,
        'estado', ps.estado,
        'plan', ps.plan,
        'creado_at', ps.creado_at,
        'actualizado_at', ps.actualizado_at
    )
    INTO v_resultado
    FROM constructora.plan_secretaria ps
    WHERE ps.estado = 'consulta'
    ORDER BY ps.actualizado_at DESC
    LIMIT 1;


    RETURN v_resultado;

END;
$$;


ALTER FUNCTION constructora.obtener_plan_secretaria() OWNER TO postgres;

--
-- Name: recalcular_progreso_actividad(uuid); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.recalcular_progreso_actividad(p_cronograma_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_total_avances integer;
    v_avances_con_imagen integer;
    v_progreso integer;
BEGIN

    -- Total de avances definidos para esta actividad
    SELECT COUNT(*)
    INTO v_total_avances
    FROM constructora.avances a
    WHERE a.cronograma_id = p_cronograma_id;


    -- Avances que tienen AL MENOS una imagen
    SELECT COUNT(*)
    INTO v_avances_con_imagen
    FROM constructora.avances a
    WHERE a.cronograma_id = p_cronograma_id
      AND EXISTS (
          SELECT 1
          FROM constructora.avance_imagenes ai
          WHERE ai.avance_id = a.id
      );


    -- Si todavía no existen avances, progreso = 0
    IF v_total_avances = 0 THEN
        v_progreso := 0;
    ELSE
        v_progreso := ROUND(
            (v_avances_con_imagen::numeric / v_total_avances::numeric) * 100
        )::integer;
    END IF;


    -- Actualizar actividad
    UPDATE constructora.cronograma
    SET
        progreso = v_progreso,
        updated_at = now()
    WHERE id = p_cronograma_id;

END;
$$;


ALTER FUNCTION constructora.recalcular_progreso_actividad(p_cronograma_id uuid) OWNER TO postgres;

--
-- Name: registrar_conversacion_secretaria(text, text, jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.registrar_conversacion_secretaria(p_mensaje_jefe text, p_respuesta_secretaria text, p_memoria_semantica jsonb DEFAULT '[]'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'constructora', 'public'
    AS $$
DECLARE
    v_id uuid;
    v_creado_at timestamptz;
BEGIN
    IF p_mensaje_jefe IS NULL
       OR btrim(p_mensaje_jefe) = '' THEN
        RAISE EXCEPTION
            'agenda_CONVERSACION_MENSAJE_REQUERIDO';
    END IF;

    IF p_respuesta_secretaria IS NULL
       OR btrim(p_respuesta_secretaria) = '' THEN
        RAISE EXCEPTION
            'agenda_CONVERSACION_RESPUESTA_REQUERIDA';
    END IF;

    IF p_memoria_semantica IS NULL THEN
        p_memoria_semantica := '[]'::jsonb;
    END IF;

    IF jsonb_typeof(p_memoria_semantica) <> 'array' THEN
        RAISE EXCEPTION
            'agenda_CONVERSACION_MEMORIA_DEBE_SER_ARRAY';
    END IF;

    INSERT INTO constructora.conversacion_secretaria (
        mensaje_jefe,
        respuesta_secretaria,
        memoria_semantica
    )
    VALUES (
        btrim(p_mensaje_jefe),
        btrim(p_respuesta_secretaria),
        p_memoria_semantica
    )
    RETURNING id, creado_at
    INTO v_id, v_creado_at;

    RETURN jsonb_build_object(
        'ok', true,
        'id', v_id,
        'creado_at', v_creado_at
    );
END;
$$;


ALTER FUNCTION constructora.registrar_conversacion_secretaria(p_mensaje_jefe text, p_respuesta_secretaria text, p_memoria_semantica jsonb) OWNER TO postgres;

--
-- Name: retroceder_avance(uuid); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.retroceder_avance(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_result jsonb;
BEGIN

    UPDATE constructora.avances
    SET
        publicado = false,
        updated_at = now()
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Avance no encontrado: %', p_id;
    END IF;

    SELECT jsonb_build_object(
        'id', a.id,
        'proyecto_id', a.proyecto_id,
        'titulo', a.titulo,
        'descripcion', a.descripcion,
        'fecha', a.fecha,
        'publicado', a.publicado,
        'created_at', a.created_at,
        'updated_at', a.updated_at
    )
    INTO v_result
    FROM constructora.avances a
    WHERE a.id = p_id;

    RETURN v_result;

END;
$$;


ALTER FUNCTION constructora.retroceder_avance(p_id uuid) OWNER TO postgres;

--
-- Name: trigger_recalcular_progreso_actividad(); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.trigger_recalcular_progreso_actividad() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_cronograma_id uuid;
BEGIN

    -- --------------------------------------------------------
    -- DELETE
    -- --------------------------------------------------------

    IF TG_OP = 'DELETE' THEN

        SELECT cronograma_id
        INTO v_cronograma_id
        FROM constructora.avances
        WHERE id = OLD.avance_id;

        IF v_cronograma_id IS NOT NULL THEN
            PERFORM constructora.recalcular_progreso_actividad(
                v_cronograma_id
            );
        END IF;

        RETURN OLD;

    END IF;


    -- --------------------------------------------------------
    -- INSERT
    -- --------------------------------------------------------

    IF TG_OP = 'INSERT' THEN

        SELECT cronograma_id
        INTO v_cronograma_id
        FROM constructora.avances
        WHERE id = NEW.avance_id;

        IF v_cronograma_id IS NOT NULL THEN
            PERFORM constructora.recalcular_progreso_actividad(
                v_cronograma_id
            );
        END IF;

        RETURN NEW;

    END IF;


    -- --------------------------------------------------------
    -- UPDATE
    -- --------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN

        -- Si una imagen cambia de avance,
        -- recalculamos primero el avance anterior.

        IF OLD.avance_id IS DISTINCT FROM NEW.avance_id THEN

            SELECT cronograma_id
            INTO v_cronograma_id
            FROM constructora.avances
            WHERE id = OLD.avance_id;

            IF v_cronograma_id IS NOT NULL THEN
                PERFORM constructora.recalcular_progreso_actividad(
                    v_cronograma_id
                );
            END IF;

        END IF;


        -- Recalcular actividad actual

        SELECT cronograma_id
        INTO v_cronograma_id
        FROM constructora.avances
        WHERE id = NEW.avance_id;

        IF v_cronograma_id IS NOT NULL THEN
            PERFORM constructora.recalcular_progreso_actividad(
                v_cronograma_id
            );
        END IF;

        RETURN NEW;

    END IF;


    RETURN NULL;

END;
$$;


ALTER FUNCTION constructora.trigger_recalcular_progreso_actividad() OWNER TO postgres;

--
-- Name: upsert_avance(jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.upsert_avance(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_id uuid;
    v_proyecto_id uuid;
    v_cronograma_id uuid;
    v_cronograma_anterior_id uuid;
    v_result jsonb;
BEGIN

    -- ========================================================
    -- UPDATE
    -- ========================================================

    IF NULLIF(p_data->>'id', '') IS NOT NULL THEN

        v_id := (p_data->>'id')::uuid;

        -- Obtener estado actual
        SELECT
            proyecto_id,
            cronograma_id
        INTO
            v_proyecto_id,
            v_cronograma_anterior_id
        FROM constructora.avances
        WHERE id = v_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Avance no encontrado: %', v_id;
        END IF;

        -- Por defecto conserva su actividad actual
        v_cronograma_id := v_cronograma_anterior_id;


        -- ====================================================
        -- CAMBIO DE ACTIVIDAD
        -- ====================================================

        IF p_data ? 'cronograma_id' THEN

            v_cronograma_id :=
                NULLIF(p_data->>'cronograma_id', '')::uuid;

            IF v_cronograma_id IS NULL THEN
                RAISE EXCEPTION 'cronograma_id es obligatorio';
            END IF;

            -- La actividad debe pertenecer al mismo proyecto
            IF NOT EXISTS (
                SELECT 1
                FROM constructora.cronograma c
                WHERE c.id = v_cronograma_id
                  AND c.proyecto_id = v_proyecto_id
            ) THEN
                RAISE EXCEPTION
                    'La actividad no existe o pertenece a otro proyecto';
            END IF;

        END IF;


        -- ====================================================
        -- ACTUALIZAR AVANCE
        -- ====================================================

        UPDATE constructora.avances
        SET
            cronograma_id = v_cronograma_id,

            titulo = CASE
                WHEN p_data ? 'titulo'
                    THEN NULLIF(TRIM(p_data->>'titulo'), '')
                ELSE titulo
            END,

            descripcion = CASE
                WHEN p_data ? 'descripcion'
                    THEN NULLIF(p_data->>'descripcion', '')
                ELSE descripcion
            END,

            fecha = CASE
                WHEN p_data ? 'fecha'
                    THEN NULLIF(p_data->>'fecha', '')::date
                ELSE fecha
            END,

            publicado = CASE
                WHEN p_data ? 'publicado'
                    THEN (p_data->>'publicado')::boolean
                ELSE publicado
            END,

            updated_at = now()

        WHERE id = v_id;


        -- ====================================================
        -- RECALCULAR SI CAMBIÓ DE ACTIVIDAD
        -- ====================================================

        IF v_cronograma_anterior_id
            IS DISTINCT FROM v_cronograma_id
        THEN

            -- Actividad de donde salió
            PERFORM constructora.recalcular_progreso_actividad(
                v_cronograma_anterior_id
            );

            -- Actividad a donde llegó
            PERFORM constructora.recalcular_progreso_actividad(
                v_cronograma_id
            );

        END IF;


    -- ========================================================
    -- INSERT
    -- ========================================================

    ELSE

        IF NULLIF(p_data->>'proyecto_id', '') IS NULL THEN
            RAISE EXCEPTION 'proyecto_id es obligatorio';
        END IF;

        IF NULLIF(p_data->>'cronograma_id', '') IS NULL THEN
            RAISE EXCEPTION 'cronograma_id es obligatorio';
        END IF;


        v_proyecto_id :=
            (p_data->>'proyecto_id')::uuid;

        v_cronograma_id :=
            (p_data->>'cronograma_id')::uuid;


        -- Verificar proyecto
        IF NOT EXISTS (
            SELECT 1
            FROM constructora.proyectos
            WHERE id = v_proyecto_id
        ) THEN
            RAISE EXCEPTION 'Proyecto no encontrado';
        END IF;


        -- Verificar actividad y pertenencia
        IF NOT EXISTS (
            SELECT 1
            FROM constructora.cronograma c
            WHERE c.id = v_cronograma_id
              AND c.proyecto_id = v_proyecto_id
        ) THEN
            RAISE EXCEPTION
                'La actividad no existe o pertenece a otro proyecto';
        END IF;


        INSERT INTO constructora.avances (
            proyecto_id,
            cronograma_id,
            titulo,
            descripcion,
            fecha,
            publicado
        )
        VALUES (
            v_proyecto_id,
            v_cronograma_id,

            NULLIF(
                TRIM(p_data->>'titulo'),
                ''
            ),

            NULLIF(
                p_data->>'descripcion',
                ''
            ),

            COALESCE(
                NULLIF(p_data->>'fecha', '')::date,
                CURRENT_DATE
            ),

            COALESCE(
                (p_data->>'publicado')::boolean,
                true
            )
        )
        RETURNING id INTO v_id;


        -- ====================================================
        -- NUEVO AVANCE = CAMBIÓ EL DENOMINADOR
        -- ====================================================

        PERFORM constructora.recalcular_progreso_actividad(
            v_cronograma_id
        );

    END IF;


    -- ========================================================
    -- RESPUESTA COMPLETA
    -- ========================================================

    SELECT jsonb_build_object(
        'id', a.id,
        'proyecto_id', a.proyecto_id,
        'cronograma_id', a.cronograma_id,
        'titulo', a.titulo,
        'descripcion', a.descripcion,
        'fecha', a.fecha,
        'publicado', a.publicado,
        'created_at', a.created_at,
        'updated_at', a.updated_at,

        'imagenes',
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', ai.id,
                        'imagen_origen_id', ai.imagen_origen_id,
                        'url', ai.url,
                        'descripcion', ai.descripcion,
                        'orden', ai.orden,
                        'created_at', ai.created_at
                    )
                    ORDER BY ai.orden, ai.created_at
                )
                FROM constructora.avance_imagenes ai
                WHERE ai.avance_id = a.id
            ),
            '[]'::jsonb
        )
    )
    INTO v_result
    FROM constructora.avances a
    WHERE a.id = v_id;


    RETURN v_result;

END;
$$;


ALTER FUNCTION constructora.upsert_avance(p_data jsonb) OWNER TO postgres;

--
-- Name: upsert_cronograma(jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.upsert_cronograma(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_id uuid;
    v_proyecto_id uuid;
    v_result jsonb;
BEGIN

    -- ========================================================
    -- UPDATE
    -- ========================================================

    IF NULLIF(p_data->>'id', '') IS NOT NULL THEN

        v_id := (p_data->>'id')::uuid;

        -- Verificar existencia
        SELECT proyecto_id
        INTO v_proyecto_id
        FROM constructora.cronograma
        WHERE id = v_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Actividad de cronograma no encontrada: %', v_id;
        END IF;


        UPDATE constructora.cronograma
        SET
            nombre = CASE
                WHEN p_data ? 'nombre'
                    THEN NULLIF(TRIM(p_data->>'nombre'), '')
                ELSE nombre
            END,

            descripcion = CASE
                WHEN p_data ? 'descripcion'
                    THEN NULLIF(p_data->>'descripcion', '')
                ELSE descripcion
            END,

            fecha_inicio = CASE
                WHEN p_data ? 'fecha_inicio'
                    THEN NULLIF(p_data->>'fecha_inicio', '')::date
                ELSE fecha_inicio
            END,

            fecha_fin = CASE
                WHEN p_data ? 'fecha_fin'
                    THEN NULLIF(p_data->>'fecha_fin', '')::date
                ELSE fecha_fin
            END,

            -- progreso NO se modifica manualmente

            orden = CASE
                WHEN p_data ? 'orden'
                    THEN (p_data->>'orden')::integer
                ELSE orden
            END,

            detalles = CASE
                WHEN p_data ? 'detalles'
                    THEN COALESCE(
                        p_data->'detalles',
                        '{}'::jsonb
                    )
                ELSE detalles
            END,

            updated_at = now()

        WHERE id = v_id;


    -- ========================================================
    -- INSERT
    -- ========================================================

    ELSE

        IF NULLIF(p_data->>'proyecto_id', '') IS NULL THEN
            RAISE EXCEPTION 'proyecto_id es obligatorio';
        END IF;

        v_proyecto_id :=
            (p_data->>'proyecto_id')::uuid;


        IF COALESCE(TRIM(p_data->>'nombre'), '') = '' THEN
            RAISE EXCEPTION
                'El nombre de la actividad es obligatorio';
        END IF;


        IF NULLIF(p_data->>'fecha_inicio', '') IS NULL THEN
            RAISE EXCEPTION 'fecha_inicio es obligatoria';
        END IF;


        IF NULLIF(p_data->>'fecha_fin', '') IS NULL THEN
            RAISE EXCEPTION 'fecha_fin es obligatoria';
        END IF;


        INSERT INTO constructora.cronograma (
            proyecto_id,
            nombre,
            descripcion,
            fecha_inicio,
            fecha_fin,
            progreso,
            orden,
            detalles
        )
        VALUES (
            v_proyecto_id,
            TRIM(p_data->>'nombre'),
            NULLIF(p_data->>'descripcion', ''),
            (p_data->>'fecha_inicio')::date,
            (p_data->>'fecha_fin')::date,

            -- Una actividad siempre nace en 0
            0,

            COALESCE(
                (p_data->>'orden')::integer,
                0
            ),

            COALESCE(
                p_data->'detalles',
                '{}'::jsonb
            )
        )
        RETURNING id INTO v_id;

    END IF;


    -- ========================================================
    -- RESPUESTA
    -- ========================================================

    SELECT to_jsonb(c)
    INTO v_result
    FROM constructora.cronograma c
    WHERE c.id = v_id;

    RETURN v_result;

END;
$$;


ALTER FUNCTION constructora.upsert_cronograma(p_data jsonb) OWNER TO postgres;

--
-- Name: upsert_imagen_pendiente(jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.upsert_imagen_pendiente(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_id uuid;
    v_result jsonb;
BEGIN

    -- ========================================================
    -- UPDATE
    -- ========================================================

    IF NULLIF(p_data->>'id', '') IS NOT NULL THEN

        v_id := (p_data->>'id')::uuid;

        UPDATE constructora.imagenes_pendientes
        SET
            proyecto_id = CASE
                WHEN p_data ? 'proyecto_id'
                    THEN NULLIF(p_data->>'proyecto_id', '')::uuid
                ELSE proyecto_id
            END,

            archivo = CASE
                WHEN p_data ? 'archivo'
                    THEN NULLIF(TRIM(p_data->>'archivo'), '')
                ELSE archivo
            END,

            url_temporal = CASE
                WHEN p_data ? 'url_temporal'
                    THEN NULLIF(TRIM(p_data->>'url_temporal'), '')
                ELSE url_temporal
            END,

            titulo = CASE
                WHEN p_data ? 'titulo'
                    THEN NULLIF(TRIM(p_data->>'titulo'), '')
                ELSE titulo
            END,

            descripcion = CASE
                WHEN p_data ? 'descripcion'
                    THEN NULLIF(p_data->>'descripcion', '')
                ELSE descripcion
            END

        WHERE id = v_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Imagen pendiente no encontrada: %', v_id;
        END IF;


    -- ========================================================
    -- INSERT
    -- ========================================================

    ELSE

        -- proyecto obligatorio
        IF NULLIF(p_data->>'proyecto_id', '') IS NULL THEN
            RAISE EXCEPTION 'proyecto_id es obligatorio';
        END IF;

        -- archivo obligatorio
        IF COALESCE(TRIM(p_data->>'archivo'), '') = '' THEN
            RAISE EXCEPTION 'archivo es obligatorio';
        END IF;

        -- URL temporal obligatoria
        IF COALESCE(TRIM(p_data->>'url_temporal'), '') = '' THEN
            RAISE EXCEPTION 'url_temporal es obligatoria';
        END IF;


        INSERT INTO constructora.imagenes_pendientes (
            proyecto_id,
            archivo,
            url_temporal,
            titulo,
            descripcion,
            estado
        )
        VALUES (
            (p_data->>'proyecto_id')::uuid,
            TRIM(p_data->>'archivo'),
            TRIM(p_data->>'url_temporal'),
            NULLIF(TRIM(p_data->>'titulo'), ''),
            NULLIF(p_data->>'descripcion', ''),
            'pendiente'
        )
        RETURNING id INTO v_id;

    END IF;


    -- ========================================================
    -- RESPUESTA
    -- ========================================================

    SELECT to_jsonb(ip)
    INTO v_result
    FROM constructora.imagenes_pendientes ip
    WHERE ip.id = v_id;

    RETURN v_result;

END;
$$;


ALTER FUNCTION constructora.upsert_imagen_pendiente(p_data jsonb) OWNER TO postgres;

--
-- Name: upsert_proyecto(jsonb); Type: FUNCTION; Schema: constructora; Owner: postgres
--

CREATE FUNCTION constructora.upsert_proyecto(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_id uuid;
    v_result jsonb;
BEGIN

    -- ========================================================
    -- UPDATE
    -- ========================================================

    IF NULLIF(p_data->>'id', '') IS NOT NULL THEN

        v_id := (p_data->>'id')::uuid;

        UPDATE constructora.proyectos
        SET
            titulo = CASE
                WHEN p_data ? 'titulo'
                    THEN COALESCE(NULLIF(TRIM(p_data->>'titulo'), ''), titulo)
                ELSE titulo
            END,

            slug = CASE
                WHEN p_data ? 'slug'
                    THEN COALESCE(NULLIF(TRIM(p_data->>'slug'), ''), slug)
                ELSE slug
            END,

            descripcion = CASE
                WHEN p_data ? 'descripcion'
                    THEN NULLIF(p_data->>'descripcion', '')
                ELSE descripcion
            END,

            descripcion_corta = CASE
                WHEN p_data ? 'descripcion_corta'
                    THEN NULLIF(p_data->>'descripcion_corta', '')
                ELSE descripcion_corta
            END,

            ubicacion = CASE
                WHEN p_data ? 'ubicacion'
                    THEN NULLIF(p_data->>'ubicacion', '')
                ELSE ubicacion
            END,

            estado = CASE
                WHEN p_data ? 'estado'
                    THEN COALESCE(NULLIF(p_data->>'estado', ''), estado)
                ELSE estado
            END,

            fecha_inicio = CASE
                WHEN p_data ? 'fecha_inicio'
                    THEN NULLIF(p_data->>'fecha_inicio', '')::date
                ELSE fecha_inicio
            END,

            fecha_fin = CASE
                WHEN p_data ? 'fecha_fin'
                    THEN NULLIF(p_data->>'fecha_fin', '')::date
                ELSE fecha_fin
            END,

            imagen_portada = CASE
                WHEN p_data ? 'imagen_portada'
                    THEN NULLIF(p_data->>'imagen_portada', '')
                ELSE imagen_portada
            END,

            destacado = CASE
                WHEN p_data ? 'destacado'
                    THEN (p_data->>'destacado')::boolean
                ELSE destacado
            END,

            publicado = CASE
                WHEN p_data ? 'publicado'
                    THEN (p_data->>'publicado')::boolean
                ELSE publicado
            END,

            orden = CASE
                WHEN p_data ? 'orden'
                    THEN (p_data->>'orden')::integer
                ELSE orden
            END,

            detalles = CASE
                WHEN p_data ? 'detalles'
                    THEN COALESCE(p_data->'detalles', '{}'::jsonb)
                ELSE detalles
            END,

            updated_at = now()

        WHERE id = v_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Proyecto no encontrado: %', v_id;
        END IF;


    -- ========================================================
    -- INSERT
    -- ========================================================

    ELSE

        -- Solo al crear son obligatorios
        IF COALESCE(TRIM(p_data->>'titulo'), '') = '' THEN
            RAISE EXCEPTION 'El titulo es obligatorio';
        END IF;

        IF COALESCE(TRIM(p_data->>'slug'), '') = '' THEN
            RAISE EXCEPTION 'El slug es obligatorio';
        END IF;


        INSERT INTO constructora.proyectos (
            titulo,
            slug,
            descripcion,
            descripcion_corta,
            ubicacion,
            estado,
            fecha_inicio,
            fecha_fin,
            imagen_portada,
            destacado,
            publicado,
            orden,
            detalles
        )
        VALUES (
            TRIM(p_data->>'titulo'),
            TRIM(p_data->>'slug'),
            NULLIF(p_data->>'descripcion', ''),
            NULLIF(p_data->>'descripcion_corta', ''),
            NULLIF(p_data->>'ubicacion', ''),

            COALESCE(
                NULLIF(p_data->>'estado', ''),
                'en_construccion'
            ),

            NULLIF(p_data->>'fecha_inicio', '')::date,
            NULLIF(p_data->>'fecha_fin', '')::date,
            NULLIF(p_data->>'imagen_portada', ''),

            COALESCE(
                (p_data->>'destacado')::boolean,
                false
            ),

            COALESCE(
                (p_data->>'publicado')::boolean,
                false
            ),

            COALESCE(
                (p_data->>'orden')::integer,
                0
            ),

            COALESCE(
                p_data->'detalles',
                '{}'::jsonb
            )
        )

        RETURNING id INTO v_id;

    END IF;


    -- ========================================================
    -- RESPUESTA
    -- ========================================================

    SELECT to_jsonb(p)
    INTO v_result
    FROM constructora.proyectos p
    WHERE p.id = v_id;

    RETURN v_result;

END;
$$;


ALTER FUNCTION constructora.upsert_proyecto(p_data jsonb) OWNER TO postgres;

--
-- Name: avance_imagenes; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.avance_imagenes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    avance_id uuid NOT NULL,
    url text NOT NULL,
    descripcion text,
    orden integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    imagen_origen_id uuid
);


ALTER TABLE constructora.avance_imagenes OWNER TO postgres;

--
-- Name: avances; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.avances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    proyecto_id uuid NOT NULL,
    titulo character varying(200),
    descripcion text,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    publicado boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    cronograma_id uuid
);


ALTER TABLE constructora.avances OWNER TO postgres;

--
-- Name: contexto_actual_secretaria; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.contexto_actual_secretaria (
    id boolean DEFAULT true NOT NULL,
    contexto text DEFAULT ''::text NOT NULL,
    actualizado_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contexto_actual_secretaria_unica_fila_chk CHECK ((id = true))
);


ALTER TABLE constructora.contexto_actual_secretaria OWNER TO postgres;

--
-- Name: conversacion_secretaria; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.conversacion_secretaria (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    mensaje_jefe text NOT NULL,
    respuesta_secretaria text NOT NULL,
    memoria_semantica jsonb DEFAULT '[]'::jsonb NOT NULL,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT conversacion_secretaria_memoria_chk CHECK ((jsonb_typeof(memoria_semantica) = 'array'::text)),
    CONSTRAINT conversacion_secretaria_mensaje_chk CHECK ((btrim(mensaje_jefe) <> ''::text)),
    CONSTRAINT conversacion_secretaria_respuesta_chk CHECK ((btrim(respuesta_secretaria) <> ''::text))
);


ALTER TABLE constructora.conversacion_secretaria OWNER TO postgres;

--
-- Name: cronograma; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.cronograma (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    proyecto_id uuid NOT NULL,
    nombre character varying(250) NOT NULL,
    descripcion text,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    progreso smallint DEFAULT 0 NOT NULL,
    orden integer DEFAULT 0 NOT NULL,
    detalles jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cronograma_check CHECK ((fecha_fin >= fecha_inicio)),
    CONSTRAINT cronograma_progreso_check CHECK (((progreso >= 0) AND (progreso <= 100)))
);


ALTER TABLE constructora.cronograma OWNER TO postgres;

--
-- Name: imagenes_pendientes; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.imagenes_pendientes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    proyecto_id uuid,
    archivo character varying(500) NOT NULL,
    url_temporal text NOT NULL,
    titulo character varying(200),
    descripcion text,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    revisado_at timestamp with time zone,
    url_editada text,
    CONSTRAINT imagenes_pendientes_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'aprobada'::character varying, 'rechazada'::character varying])::text[])))
);


ALTER TABLE constructora.imagenes_pendientes OWNER TO postgres;

--
-- Name: memoria_jefe; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.memoria_jefe (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tipo text NOT NULL,
    contenido text NOT NULL,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT memoria_jefe_contenido_chk CHECK ((btrim(contenido) <> ''::text)),
    CONSTRAINT memoria_jefe_tipo_chk CHECK ((tipo = ANY (ARRAY['preferencia'::text, 'interes'::text])))
);


ALTER TABLE constructora.memoria_jefe OWNER TO postgres;

--
-- Name: observaciones_secuencia_seq; Type: SEQUENCE; Schema: constructora; Owner: postgres
--

ALTER TABLE constructora.observaciones ALTER COLUMN secuencia ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME constructora.observaciones_secuencia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: plan_secretaria; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.plan_secretaria (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    estado text DEFAULT 'consulta'::text NOT NULL,
    plan jsonb DEFAULT '{}'::jsonb NOT NULL,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT plan_secretaria_estado_check CHECK ((estado = ANY (ARRAY['consulta'::text, 'aprobado'::text, 'ejecutado'::text, 'rechazado'::text]))),
    CONSTRAINT plan_secretaria_plan_objeto_check CHECK ((jsonb_typeof(plan) = 'object'::text))
);


ALTER TABLE constructora.plan_secretaria OWNER TO postgres;

--
-- Name: proyecto_imagenes; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.proyecto_imagenes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    proyecto_id uuid NOT NULL,
    url text NOT NULL,
    titulo character varying(200),
    descripcion text,
    tipo character varying(30) DEFAULT 'galeria'::character varying NOT NULL,
    orden integer DEFAULT 0 NOT NULL,
    publicada boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    imagen_origen_id uuid,
    CONSTRAINT proyecto_imagenes_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['portada'::character varying, 'galeria'::character varying])::text[])))
);


ALTER TABLE constructora.proyecto_imagenes OWNER TO postgres;

--
-- Name: proyectos; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.proyectos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    titulo character varying(200) NOT NULL,
    slug character varying(220) NOT NULL,
    descripcion text,
    descripcion_corta character varying(500),
    ubicacion character varying(300),
    estado character varying(30) DEFAULT 'en_construccion'::character varying NOT NULL,
    fecha_inicio date,
    fecha_fin date,
    imagen_portada text,
    destacado boolean DEFAULT false NOT NULL,
    publicado boolean DEFAULT false NOT NULL,
    orden integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    detalles jsonb DEFAULT '{}'::jsonb NOT NULL,
    progreso smallint DEFAULT 0 NOT NULL,
    CONSTRAINT proyectos_estado_check CHECK (((estado)::text = ANY ((ARRAY['planificado'::character varying, 'en_construccion'::character varying, 'finalizado'::character varying, 'pausado'::character varying])::text[]))),
    CONSTRAINT proyectos_progreso_check CHECK (((progreso >= 0) AND (progreso <= 100)))
);


ALTER TABLE constructora.proyectos OWNER TO postgres;

--
-- Name: tareas; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.tareas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agenda_item_id uuid NOT NULL,
    descripcion text NOT NULL,
    completada boolean DEFAULT false NOT NULL,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tareas_descripcion_check CHECK ((btrim(descripcion) <> ''::text))
);


ALTER TABLE constructora.tareas OWNER TO postgres;

--
-- Name: TABLE tareas; Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON TABLE constructora.tareas IS 'Tareas mínimas necesarias para completar un evento. Son hijas del evento y no eventos independientes.';


--
-- Name: whatsapp_analisis; Type: TABLE; Schema: constructora; Owner: postgres
--

CREATE TABLE constructora.whatsapp_analisis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre_conversacion text NOT NULL,
    nombre_archivo text NOT NULL,
    fecha_analisis timestamp with time zone DEFAULT now() NOT NULL,
    fecha_referencia date NOT NULL,
    resultado jsonb NOT NULL,
    informe_texto text NOT NULL,
    CONSTRAINT whatsapp_analisis_informe_no_vacio CHECK ((length(btrim(informe_texto)) > 0)),
    CONSTRAINT whatsapp_analisis_nombre_archivo_no_vacio CHECK ((length(btrim(nombre_archivo)) > 0)),
    CONSTRAINT whatsapp_analisis_nombre_conversacion_no_vacio CHECK ((length(btrim(nombre_conversacion)) > 0)),
    CONSTRAINT whatsapp_analisis_resultado_objeto CHECK ((jsonb_typeof(resultado) = 'object'::text))
);


ALTER TABLE constructora.whatsapp_analisis OWNER TO postgres;

--
-- Name: TABLE whatsapp_analisis; Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON TABLE constructora.whatsapp_analisis IS 'Informes históricos de Gemini sobre exportaciones de WhatsApp; no almacena mensajes individuales.';


--
-- Name: COLUMN whatsapp_analisis.resultado; Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON COLUMN constructora.whatsapp_analisis.resultado IS 'JSONB estructurado con evaluaciones, tareas, fechas importantes, recomendaciones y asuntos por confirmar.';


--
-- Name: COLUMN whatsapp_analisis.informe_texto; Type: COMMENT; Schema: constructora; Owner: postgres
--

COMMENT ON COLUMN constructora.whatsapp_analisis.informe_texto IS 'Respuesta íntegra de Gemini, incluidas las recomendaciones.';


--
-- Name: avance_imagenes avance_imagenes_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.avance_imagenes
    ADD CONSTRAINT avance_imagenes_pkey PRIMARY KEY (id);


--
-- Name: avances avances_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.avances
    ADD CONSTRAINT avances_pkey PRIMARY KEY (id);


--
-- Name: contexto_actual_secretaria contexto_actual_secretaria_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.contexto_actual_secretaria
    ADD CONSTRAINT contexto_actual_secretaria_pkey PRIMARY KEY (id);


--
-- Name: contexto_voz contexto_voz_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.contexto_voz
    ADD CONSTRAINT contexto_voz_pkey PRIMARY KEY (id);


--
-- Name: conversacion_secretaria conversacion_secretaria_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.conversacion_secretaria
    ADD CONSTRAINT conversacion_secretaria_pkey PRIMARY KEY (id);


--
-- Name: cronograma cronograma_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.cronograma
    ADD CONSTRAINT cronograma_pkey PRIMARY KEY (id);


--
-- Name: historial_recurrencia historial_recurrencia_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.historial_recurrencia
    ADD CONSTRAINT historial_recurrencia_pkey PRIMARY KEY (id);


--
-- Name: imagenes_pendientes imagenes_pendientes_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.imagenes_pendientes
    ADD CONSTRAINT imagenes_pendientes_pkey PRIMARY KEY (id);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: memoria_jefe memoria_jefe_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.memoria_jefe
    ADD CONSTRAINT memoria_jefe_pkey PRIMARY KEY (id);


--
-- Name: observaciones observaciones_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.observaciones
    ADD CONSTRAINT observaciones_pkey PRIMARY KEY (id);


--
-- Name: plan_secretaria plan_secretaria_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.plan_secretaria
    ADD CONSTRAINT plan_secretaria_pkey PRIMARY KEY (id);


--
-- Name: proyecto_imagenes proyecto_imagenes_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.proyecto_imagenes
    ADD CONSTRAINT proyecto_imagenes_pkey PRIMARY KEY (id);


--
-- Name: proyectos proyectos_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.proyectos
    ADD CONSTRAINT proyectos_pkey PRIMARY KEY (id);


--
-- Name: proyectos proyectos_slug_key; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.proyectos
    ADD CONSTRAINT proyectos_slug_key UNIQUE (slug);


--
-- Name: tareas tareas_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.tareas
    ADD CONSTRAINT tareas_pkey PRIMARY KEY (id);


--
-- Name: transcripciones transcripciones_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.transcripciones
    ADD CONSTRAINT transcripciones_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_analisis whatsapp_analisis_pkey; Type: CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.whatsapp_analisis
    ADD CONSTRAINT whatsapp_analisis_pkey PRIMARY KEY (id);


--
-- Name: idx_agenda_historial_recurrencia_item_fecha; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_agenda_historial_recurrencia_item_fecha ON constructora.historial_recurrencia USING btree (agenda_item_id, fecha);


--
-- Name: idx_agenda_items_estado; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_agenda_items_estado ON constructora.items USING btree (estado);


--
-- Name: idx_agenda_items_fecha_inicio; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_agenda_items_fecha_inicio ON constructora.items USING btree (fecha_inicio);


--
-- Name: idx_agenda_items_fecha_limite; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_agenda_items_fecha_limite ON constructora.items USING btree (fecha_limite);


--
-- Name: idx_agenda_items_recordatorio; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_agenda_items_recordatorio ON constructora.items USING btree (recordatorio);


--
-- Name: idx_agenda_observaciones_item_secuencia; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_agenda_observaciones_item_secuencia ON constructora.observaciones USING btree (agenda_item_id, secuencia);


--
-- Name: idx_constructora_avance_imagenes; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_avance_imagenes ON constructora.avance_imagenes USING btree (avance_id);


--
-- Name: idx_constructora_avances_fecha; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_avances_fecha ON constructora.avances USING btree (fecha DESC);


--
-- Name: idx_constructora_avances_proyecto; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_avances_proyecto ON constructora.avances USING btree (proyecto_id);


--
-- Name: idx_constructora_cronograma_fechas; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_cronograma_fechas ON constructora.cronograma USING btree (proyecto_id, fecha_inicio, fecha_fin);


--
-- Name: idx_constructora_cronograma_proyecto; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_cronograma_proyecto ON constructora.cronograma USING btree (proyecto_id);


--
-- Name: idx_constructora_imagenes_pendientes_estado; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_imagenes_pendientes_estado ON constructora.imagenes_pendientes USING btree (estado);


--
-- Name: idx_constructora_imagenes_pendientes_proyecto; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_imagenes_pendientes_proyecto ON constructora.imagenes_pendientes USING btree (proyecto_id);


--
-- Name: idx_constructora_imagenes_proyecto; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_imagenes_proyecto ON constructora.proyecto_imagenes USING btree (proyecto_id);


--
-- Name: idx_constructora_proyectos_destacado; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_proyectos_destacado ON constructora.proyectos USING btree (destacado);


--
-- Name: idx_constructora_proyectos_estado; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_proyectos_estado ON constructora.proyectos USING btree (estado);


--
-- Name: idx_constructora_proyectos_publicado; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_constructora_proyectos_publicado ON constructora.proyectos USING btree (publicado);


--
-- Name: idx_contexto_voz_creado_at; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_contexto_voz_creado_at ON constructora.contexto_voz USING btree (creado_at DESC);


--
-- Name: idx_contexto_voz_expira_at; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_contexto_voz_expira_at ON constructora.contexto_voz USING btree (expira_at);


--
-- Name: idx_conversacion_secretaria_creado_at; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_conversacion_secretaria_creado_at ON constructora.conversacion_secretaria USING btree (creado_at DESC);


--
-- Name: idx_memoria_jefe_tipo; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_memoria_jefe_tipo ON constructora.memoria_jefe USING btree (tipo);


--
-- Name: idx_plan_secretaria_estado_actualizado; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_plan_secretaria_estado_actualizado ON constructora.plan_secretaria USING btree (estado, actualizado_at DESC);


--
-- Name: idx_tareas_agenda_item_id; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_tareas_agenda_item_id ON constructora.tareas USING btree (agenda_item_id);


--
-- Name: idx_transcripciones_creado_at; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_transcripciones_creado_at ON constructora.transcripciones USING btree (creado_at DESC);


--
-- Name: idx_whatsapp_analisis_conversacion_fecha; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_whatsapp_analisis_conversacion_fecha ON constructora.whatsapp_analisis USING btree (nombre_conversacion, fecha_analisis DESC);


--
-- Name: idx_whatsapp_analisis_fecha; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE INDEX idx_whatsapp_analisis_fecha ON constructora.whatsapp_analisis USING btree (fecha_analisis DESC);


--
-- Name: uq_whatsapp_analisis_nombre_conversacion; Type: INDEX; Schema: constructora; Owner: postgres
--

CREATE UNIQUE INDEX uq_whatsapp_analisis_nombre_conversacion ON constructora.whatsapp_analisis USING btree (nombre_conversacion);


--
-- Name: cronograma trg_actualizar_progreso_proyecto; Type: TRIGGER; Schema: constructora; Owner: postgres
--

CREATE TRIGGER trg_actualizar_progreso_proyecto AFTER INSERT OR DELETE OR UPDATE ON constructora.cronograma FOR EACH ROW EXECUTE FUNCTION constructora.actualizar_progreso_proyecto();


--
-- Name: avance_imagenes trg_recalcular_progreso_actividad; Type: TRIGGER; Schema: constructora; Owner: postgres
--

CREATE TRIGGER trg_recalcular_progreso_actividad AFTER INSERT OR DELETE OR UPDATE ON constructora.avance_imagenes FOR EACH ROW EXECUTE FUNCTION constructora.trigger_recalcular_progreso_actividad();


--
-- Name: avance_imagenes avance_imagenes_avance_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.avance_imagenes
    ADD CONSTRAINT avance_imagenes_avance_id_fkey FOREIGN KEY (avance_id) REFERENCES constructora.avances(id) ON DELETE CASCADE;


--
-- Name: avance_imagenes avance_imagenes_imagen_origen_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.avance_imagenes
    ADD CONSTRAINT avance_imagenes_imagen_origen_id_fkey FOREIGN KEY (imagen_origen_id) REFERENCES constructora.imagenes_pendientes(id) ON DELETE SET NULL;


--
-- Name: avances avances_cronograma_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.avances
    ADD CONSTRAINT avances_cronograma_id_fkey FOREIGN KEY (cronograma_id) REFERENCES constructora.cronograma(id) ON DELETE CASCADE;


--
-- Name: avances avances_proyecto_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.avances
    ADD CONSTRAINT avances_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES constructora.proyectos(id) ON DELETE CASCADE;


--
-- Name: cronograma cronograma_proyecto_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.cronograma
    ADD CONSTRAINT cronograma_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES constructora.proyectos(id) ON DELETE CASCADE;


--
-- Name: historial_recurrencia historial_recurrencia_agenda_item_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.historial_recurrencia
    ADD CONSTRAINT historial_recurrencia_agenda_item_id_fkey FOREIGN KEY (agenda_item_id) REFERENCES constructora.items(id);


--
-- Name: imagenes_pendientes imagenes_pendientes_proyecto_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.imagenes_pendientes
    ADD CONSTRAINT imagenes_pendientes_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES constructora.proyectos(id) ON DELETE CASCADE;


--
-- Name: observaciones observaciones_agenda_item_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.observaciones
    ADD CONSTRAINT observaciones_agenda_item_id_fkey FOREIGN KEY (agenda_item_id) REFERENCES constructora.items(id);


--
-- Name: proyecto_imagenes proyecto_imagenes_imagen_origen_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.proyecto_imagenes
    ADD CONSTRAINT proyecto_imagenes_imagen_origen_id_fkey FOREIGN KEY (imagen_origen_id) REFERENCES constructora.imagenes_pendientes(id) ON DELETE SET NULL;


--
-- Name: proyecto_imagenes proyecto_imagenes_proyecto_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.proyecto_imagenes
    ADD CONSTRAINT proyecto_imagenes_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES constructora.proyectos(id) ON DELETE CASCADE;


--
-- Name: tareas tareas_agenda_item_id_fkey; Type: FK CONSTRAINT; Schema: constructora; Owner: postgres
--

ALTER TABLE ONLY constructora.tareas
    ADD CONSTRAINT tareas_agenda_item_id_fkey FOREIGN KEY (agenda_item_id) REFERENCES constructora.items(id) ON DELETE CASCADE;


--
-- Name: SCHEMA constructora; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA constructora TO tenant_app;


--
-- Name: FUNCTION actualizar_imagen_editada(p_id uuid, p_url_nueva text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.actualizar_imagen_editada(p_id uuid, p_url_nueva text) TO tenant_app;


--
-- Name: FUNCTION actualizar_progreso_proyecto(); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.actualizar_progreso_proyecto() TO tenant_app;


--
-- Name: FUNCTION aprobar_imagen(p_id uuid, p_destino character varying, p_orden integer, p_avance_id uuid); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.aprobar_imagen(p_id uuid, p_destino character varying, p_orden integer, p_avance_id uuid) TO tenant_app;


--
-- Name: FUNCTION contexto_secretaria(p_modo text, p_desde timestamp with time zone); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.contexto_secretaria(p_modo text, p_desde timestamp with time zone) TO tenant_app;


--
-- Name: FUNCTION eliminar_avance(p_id uuid); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.eliminar_avance(p_id uuid) TO tenant_app;


--
-- Name: FUNCTION eliminar_cronograma(p_id uuid); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.eliminar_cronograma(p_id uuid) TO tenant_app;


--
-- Name: FUNCTION eliminar_proyecto(p_id uuid); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.eliminar_proyecto(p_id uuid) TO tenant_app;


--
-- Name: FUNCTION estado_plan_secretaria(p_id uuid, p_accion text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.estado_plan_secretaria(p_id uuid, p_accion text) TO tenant_app;


--
-- Name: FUNCTION fn_contexto_actual(p_contexto text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_contexto_actual(p_contexto text) TO tenant_app;


--
-- Name: FUNCTION fn_fecha_recurrencia(p_fecha_ancla timestamp with time zone, p_frecuencia text, p_intervalo integer, p_posicion bigint); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_fecha_recurrencia(p_fecha_ancla timestamp with time zone, p_frecuencia text, p_intervalo integer, p_posicion bigint) TO tenant_app;


--
-- Name: TABLE items; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.items TO tenant_app;


--
-- Name: FUNCTION fn_item(p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_item(p_data jsonb) TO tenant_app;


--
-- Name: FUNCTION fn_listar_memoria_jefe(); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_listar_memoria_jefe() TO tenant_app;


--
-- Name: FUNCTION fn_memoria_jefe(p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_memoria_jefe(p_data jsonb) TO tenant_app;


--
-- Name: TABLE observaciones; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.observaciones TO tenant_app;


--
-- Name: FUNCTION fn_observacion(p_agenda_item_id uuid, p_observacion text, p_estado_nuevo text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_observacion(p_agenda_item_id uuid, p_observacion text, p_estado_nuevo text) TO tenant_app;


--
-- Name: FUNCTION fn_obtener_contexto_actual(); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_obtener_contexto_actual() TO tenant_app;


--
-- Name: FUNCTION fn_ocultar_eliminar_item(p_agenda_item_id uuid, p_accion text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_ocultar_eliminar_item(p_agenda_item_id uuid, p_accion text) TO tenant_app;


--
-- Name: FUNCTION fn_orquestador(p_operacion text, p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_orquestador(p_operacion text, p_data jsonb) TO tenant_app;


--
-- Name: FUNCTION fn_posicion_recurrencia(p_fecha_ancla timestamp with time zone, p_frecuencia text, p_intervalo integer, p_fecha_referencia timestamp with time zone); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_posicion_recurrencia(p_fecha_ancla timestamp with time zone, p_frecuencia text, p_intervalo integer, p_fecha_referencia timestamp with time zone) TO tenant_app;


--
-- Name: TABLE historial_recurrencia; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.historial_recurrencia TO tenant_app;


--
-- Name: FUNCTION fn_registrar_recurrencia(p_agenda_item_id uuid, p_posicion bigint, p_estado text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_registrar_recurrencia(p_agenda_item_id uuid, p_posicion bigint, p_estado text) TO tenant_app;


--
-- Name: FUNCTION fn_tarea(p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_tarea(p_data jsonb) TO tenant_app;


--
-- Name: FUNCTION fn_whatsapp_analisis_delete(p_id uuid); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_whatsapp_analisis_delete(p_id uuid) TO tenant_app;


--
-- Name: FUNCTION fn_whatsapp_analisis_listar(p_nombre_conversacion text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_whatsapp_analisis_listar(p_nombre_conversacion text) TO tenant_app;


--
-- Name: FUNCTION fn_whatsapp_analisis_upsert(p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.fn_whatsapp_analisis_upsert(p_data jsonb) TO tenant_app;


--
-- Name: TABLE contexto_voz; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.contexto_voz TO tenant_app;


--
-- Name: FUNCTION guardar_contexto_voz(p_transcripcion text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.guardar_contexto_voz(p_transcripcion text) TO tenant_app;


--
-- Name: FUNCTION guardar_plan_secretaria(p_id uuid, p_plan jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.guardar_plan_secretaria(p_id uuid, p_plan jsonb) TO tenant_app;


--
-- Name: TABLE transcripciones; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.transcripciones TO tenant_app;


--
-- Name: FUNCTION guardar_transcripcion(p_transcripcion text, p_titulo text, p_nombre_archivo text, p_tipo_mime text, p_duracion_segundos integer, p_archivo_audio text); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.guardar_transcripcion(p_transcripcion text, p_titulo text, p_nombre_archivo text, p_tipo_mime text, p_duracion_segundos integer, p_archivo_audio text) TO tenant_app;


--
-- Name: FUNCTION listar_agenda(p_dias_historial integer, p_incluir_ocultos boolean); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.listar_agenda(p_dias_historial integer, p_incluir_ocultos boolean) TO tenant_app;


--
-- Name: FUNCTION listar_contexto_voz_activo(); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.listar_contexto_voz_activo() TO tenant_app;


--
-- Name: FUNCTION listar_proyectos(); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.listar_proyectos() TO tenant_app;


--
-- Name: FUNCTION listar_proyectos_publicos(); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.listar_proyectos_publicos() TO tenant_app;


--
-- Name: FUNCTION obtener_plan_secretaria(); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.obtener_plan_secretaria() TO tenant_app;


--
-- Name: FUNCTION recalcular_progreso_actividad(p_cronograma_id uuid); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.recalcular_progreso_actividad(p_cronograma_id uuid) TO tenant_app;


--
-- Name: FUNCTION registrar_conversacion_secretaria(p_mensaje_jefe text, p_respuesta_secretaria text, p_memoria_semantica jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.registrar_conversacion_secretaria(p_mensaje_jefe text, p_respuesta_secretaria text, p_memoria_semantica jsonb) TO tenant_app;


--
-- Name: FUNCTION retroceder_avance(p_id uuid); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.retroceder_avance(p_id uuid) TO tenant_app;


--
-- Name: FUNCTION trigger_recalcular_progreso_actividad(); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.trigger_recalcular_progreso_actividad() TO tenant_app;


--
-- Name: FUNCTION upsert_avance(p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.upsert_avance(p_data jsonb) TO tenant_app;


--
-- Name: FUNCTION upsert_cronograma(p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.upsert_cronograma(p_data jsonb) TO tenant_app;


--
-- Name: FUNCTION upsert_imagen_pendiente(p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.upsert_imagen_pendiente(p_data jsonb) TO tenant_app;


--
-- Name: FUNCTION upsert_proyecto(p_data jsonb); Type: ACL; Schema: constructora; Owner: postgres
--

GRANT ALL ON FUNCTION constructora.upsert_proyecto(p_data jsonb) TO tenant_app;


--
-- Name: TABLE avance_imagenes; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.avance_imagenes TO tenant_app;


--
-- Name: TABLE avances; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.avances TO tenant_app;


--
-- Name: TABLE contexto_actual_secretaria; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.contexto_actual_secretaria TO tenant_app;


--
-- Name: TABLE conversacion_secretaria; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.conversacion_secretaria TO tenant_app;


--
-- Name: TABLE cronograma; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.cronograma TO tenant_app;


--
-- Name: TABLE imagenes_pendientes; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.imagenes_pendientes TO tenant_app;


--
-- Name: TABLE memoria_jefe; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.memoria_jefe TO tenant_app;


--
-- Name: TABLE plan_secretaria; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.plan_secretaria TO tenant_app;


--
-- Name: TABLE proyecto_imagenes; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.proyecto_imagenes TO tenant_app;


--
-- Name: TABLE proyectos; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.proyectos TO tenant_app;


--
-- Name: TABLE tareas; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.tareas TO tenant_app;


--
-- Name: TABLE whatsapp_analisis; Type: ACL; Schema: constructora; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE constructora.whatsapp_analisis TO tenant_app;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: constructora; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA constructora GRANT ALL ON FUNCTIONS  TO tenant_app;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: constructora; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA constructora GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO tenant_app;


--
-- PostgreSQL database dump complete
--

\unrestrict jmGltIKL8xf0SxSFwo25521ItiNZO5QJguQIGhgDl2m20VBCfQSGXahAwUpfMqg

