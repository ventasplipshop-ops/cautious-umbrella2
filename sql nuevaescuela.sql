BEGIN;

-- ============================================================
-- 1. ITEMS
-- Compromisos pertenecientes al dueño.
-- ============================================================

CREATE TABLE constructora.items (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    titulo          text,
    descripcion     text,

    estado          text DEFAULT 'activo',
    prioridad       text DEFAULT 'baja',

    fecha_inicio    timestamptz,
    fecha_limite    timestamptz,
    todo_el_dia     boolean DEFAULT false,
    recordatorio    timestamptz,

    recurrencia     jsonb,
    participantes   jsonb,

    creado_at       timestamptz NOT NULL DEFAULT now(),
    actualizado_at  timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- 2. OBSERVACIONES
-- Historial humano de lo ocurrido con un compromiso.
-- ============================================================

CREATE TABLE constructora.observaciones (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    agenda_item_id      uuid NOT NULL,

    observacion         text,

    estado_anterior     text,
    estado_nuevo        text,

    creado_at           timestamptz NOT NULL DEFAULT now(),

    -- Orden determinista de los movimientos.
    secuencia           bigint GENERATED ALWAYS AS IDENTITY NOT NULL,

    CONSTRAINT observaciones_agenda_item_id_fkey
        FOREIGN KEY (agenda_item_id)
        REFERENCES constructora.items(id)
);


-- ============================================================
-- 3. HISTORIAL DE RECURRENCIA
-- Registra el resultado de cada ocurrencia de un item recurrente.
-- No crea nuevos items.
-- ============================================================

CREATE TABLE constructora.historial_recurrencia (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    agenda_item_id      uuid NOT NULL,

    fecha               timestamptz,
    estado              text,

    creado_at           timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT historial_recurrencia_agenda_item_id_fkey
        FOREIGN KEY (agenda_item_id)
        REFERENCES constructora.items(id)
);


-- ============================================================
-- ÍNDICES BÁSICOS
-- ============================================================

CREATE INDEX idx_agenda_items_estado
    ON constructora.items (estado);

CREATE INDEX idx_agenda_items_fecha_inicio
    ON constructora.items (fecha_inicio);

CREATE INDEX idx_agenda_items_fecha_limite
    ON constructora.items (fecha_limite);

CREATE INDEX idx_agenda_items_recordatorio
    ON constructora.items (recordatorio);

CREATE INDEX idx_agenda_observaciones_item_secuencia
    ON constructora.observaciones (agenda_item_id, secuencia);

CREATE INDEX idx_agenda_historial_recurrencia_item_fecha
    ON constructora.historial_recurrencia (agenda_item_id, fecha);








CREATE OR REPLACE FUNCTION constructora.fn_item(
    p_data jsonb
)
RETURNS constructora.items
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



CREATE OR REPLACE FUNCTION constructora.fn_observacion(
    p_agenda_item_id uuid,
    p_observacion text,
    p_estado_nuevo text DEFAULT NULL
)
RETURNS constructora.observaciones
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




-- ============================================================
-- MOTOR BASE DE RECURRENCIA
--
-- p_fecha_ancla:
--   fecha/hora original desde donde nace la serie
--
-- p_frecuencia:
--   diaria | semanal | mensual | anual
--
-- p_intervalo:
--   cada cuántas unidades ocurre
--
-- p_posicion:
--   posición matemática desde el ancla
--
-- Ejemplos:
--   posicion 0 = propia fecha ancla
--   posicion 1 = siguiente ocurrencia
--   posicion 2 = segunda ocurrencia
--
-- IMPORTANTE:
-- mensual/anual SIEMPRE calculan desde el ancla original.
-- Nunca desde la ocurrencia anterior.
-- ============================================================

CREATE OR REPLACE FUNCTION constructora.fn_fecha_recurrencia(
    p_fecha_ancla timestamptz,
    p_frecuencia text,
    p_intervalo integer DEFAULT 1,
    p_posicion bigint DEFAULT 0
)
RETURNS timestamptz
LANGUAGE plpgsql
IMMUTABLE
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



-- ============================================================
-- DETERMINAR POSICIÓN DENTRO DE UNA RECURRENCIA
--
-- Usa constructora.fn_fecha_recurrencia() como motor matemático.
--
-- EJEMPLO
--
-- ancla       = 2026-01-31
-- frecuencia  = mensual
-- referencia  = 2026-04-15
--
-- devuelve:
--
-- anterior        = 2026-03-31
-- correspondiente = 2026-04-30
-- siguiente       = 2026-05-31
-- posicion         = 3
--
-- Si referencia = 2026-04-30:
--
-- anterior        = 2026-03-31
-- correspondiente = 2026-04-30
-- siguiente       = 2026-05-31
-- posicion         = 3
--
-- Si referencia es anterior al ancla:
--
-- anterior        = NULL
-- correspondiente = ancla
-- siguiente       = primera recurrencia posterior
-- posicion         = 0
-- ============================================================

CREATE OR REPLACE FUNCTION constructora.fn_posicion_recurrencia(
    p_fecha_ancla timestamptz,
    p_frecuencia text,
    p_intervalo integer DEFAULT 1,
    p_fecha_referencia timestamptz DEFAULT now()
)
RETURNS TABLE (
    posicion bigint,
    anterior timestamptz,
    correspondiente timestamptz,
    siguiente timestamptz
)
LANGUAGE plpgsql
STABLE
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




-- ============================================================
-- REGISTRAR RESULTADO DE UNA OCURRENCIA RECURRENTE
--
-- Responsabilidad:
--
--   item recurrente
--        ↓
--   posición matemática
--        ↓
--   fn_fecha_recurrencia()
--        ↓
--   fecha exacta de esa ocurrencia
--        ↓
--   historial_recurrencia
--
-- NO:
--   - cambia constructora.items.estado
--   - crea observaciones
--   - modifica fecha_inicio
--   - modifica recurrencia
--   - inventa fechas
--   - genera ocurrencias futuras
--
-- Estados de una ocurrencia:
--
--   completado
--   no_completado
--   cancelado
--
-- Si la misma ocurrencia ya fue registrada,
-- actualiza su estado en vez de duplicarla.
-- ============================================================

CREATE OR REPLACE FUNCTION constructora.fn_registrar_recurrencia(
    p_agenda_item_id uuid,
    p_posicion bigint,
    p_estado text
)
RETURNS constructora.historial_recurrencia
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


CREATE OR REPLACE FUNCTION constructora.fn_orquestador(
    p_regla text,
    p_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_regla             text;
    v_data              jsonb;

    v_item_id           uuid;
    v_item_data         jsonb;
    v_patch             jsonb;
    v_item              constructora.items%ROWTYPE;
    v_item_result       constructora.items%ROWTYPE;

    v_obs               text;
    v_estado            text;
    v_obs_result        constructora.observaciones%ROWTYPE;

    v_posicion          bigint;
    v_fecha_ref         timestamptz;
    v_fecha             timestamptz;
    v_frecuencia        text;
    v_intervalo         integer;
    v_hist_result       constructora.historial_recurrencia%ROWTYPE;

    v_pos               record;

    v_resultados        jsonb := '[]'::jsonb;
    v_tmp               jsonb;
    v_elem              jsonb;
    v_idx               integer;

    v_plan              jsonb;
    v_step              jsonb;
    v_tipo              text;
BEGIN
    -- --------------------------------------------------------
    -- 0. Entrada común
    -- --------------------------------------------------------
    IF p_regla IS NULL OR btrim(p_regla) = '' THEN
        RAISE EXCEPTION
            'agenda_REQUIERE_DATO|regla|¿Qué regla R01–R35 debe ejecutar constructora?';
    END IF;

    v_regla := upper(btrim(p_regla));

    IF v_regla !~ '^R(0[1-9]|[12][0-9]|3[0-5])$' THEN
        RAISE EXCEPTION
            'agenda_OPERACION_NO_PERMITIDA|regla|La regla % no existe. Use R01 a R35.',
            v_regla;
    END IF;

    IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
        RAISE EXCEPTION
            'agenda_REQUIERE_DATO|data|Necesito un objeto JSON con los datos necesarios para ejecutar %.',
            v_regla;
    END IF;

    v_data := p_data;

    -- ========================================================
    -- R01 — Crear item
    -- ========================================================
    IF v_regla = 'R01' THEN
        v_item_data := v_data -> 'item';

        IF v_item_data IS NULL OR jsonb_typeof(v_item_data) <> 'object' THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|item|¿Qué compromiso querés crear? Enviá sus datos en data.item.';
        END IF;

        IF v_item_data ? 'id' AND v_item_data -> 'id' <> 'null'::jsonb THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_ACLARACION|crear_o_modificar|R01 crea un compromiso nuevo, pero recibí un id. ¿Querés crear uno nuevo o modificar el existente?';
        END IF;

        v_item_result := constructora.fn_item(v_item_data);

        RETURN jsonb_build_object(
            'ok', true,
            'regla', v_regla,
            'resultado', jsonb_build_object('item', to_jsonb(v_item_result))
        );

    -- ========================================================
    -- R02 — Crear item + observación inicial
    -- ========================================================
    ELSIF v_regla = 'R02' THEN
        v_item_data := v_data -> 'item';
        v_obs := nullif(btrim(v_data ->> 'observacion'), '');

        IF v_item_data IS NULL OR jsonb_typeof(v_item_data) <> 'object' THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|item|¿Qué compromiso querés crear?';
        END IF;
        IF v_item_data ? 'id' AND v_item_data -> 'id' <> 'null'::jsonb THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_ACLARACION|crear_o_modificar|R02 crea un compromiso nuevo, pero recibí un id.';
        END IF;
        IF v_obs IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|observacion|¿Qué hecho querés dejar registrado al crear el compromiso?';
        END IF;

        v_item_result := constructora.fn_item(v_item_data);
        v_obs_result := constructora.fn_observacion(v_item_result.id, v_obs, NULL);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'item', to_jsonb(v_item_result),
                'observacion', to_jsonb(v_obs_result)
            )
        );

    -- ========================================================
    -- R03 / R09 / R32 — PATCH puro
    -- ========================================================
    ELSIF v_regla IN ('R03','R09','R32') THEN
        v_patch := COALESCE(v_data -> 'patch', v_data -> 'item');

        IF v_patch IS NULL OR jsonb_typeof(v_patch) <> 'object' THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|patch|¿Qué querés cambiar del compromiso?';
        END IF;

        IF NOT (v_patch ? 'id') OR v_patch -> 'id' = 'null'::jsonb THEN
            IF v_data ? 'item_id' THEN
                v_patch := jsonb_set(v_patch, '{id}', to_jsonb(v_data ->> 'item_id'));
            ELSE
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|item_id|¿Sobre qué compromiso querés hacer el cambio?';
            END IF;
        END IF;

        IF v_regla = 'R09' AND NOT (v_patch ? 'recurrencia') THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|recurrencia|¿Cómo querés cambiar la recurrencia?';
        END IF;

        v_item_result := constructora.fn_item(v_patch);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object('item', to_jsonb(v_item_result))
        );

    -- ========================================================
    -- R04 / R10 / R33 — PATCH + observación
    -- ========================================================
    ELSIF v_regla IN ('R04','R10','R33') THEN
        v_patch := COALESCE(v_data -> 'patch', v_data -> 'item');
        v_obs := nullif(btrim(v_data ->> 'observacion'), '');

        IF v_patch IS NULL OR jsonb_typeof(v_patch) <> 'object' THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|patch|¿Qué querés modificar del compromiso?';
        END IF;
        IF NOT (v_patch ? 'id') OR v_patch -> 'id' = 'null'::jsonb THEN
            IF v_data ? 'item_id' THEN
                v_patch := jsonb_set(v_patch, '{id}', to_jsonb(v_data ->> 'item_id'));
            ELSE
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|item_id|¿Sobre qué compromiso querés hacer el cambio?';
            END IF;
        END IF;
        IF v_regla = 'R10' AND NOT (v_patch ? 'recurrencia') THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|recurrencia|¿Cómo querés cambiar la recurrencia?';
        END IF;
        IF v_obs IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|observacion|¿Qué hecho o motivo querés dejar registrado junto con el cambio?';
        END IF;

        v_item_result := constructora.fn_item(v_patch);
        v_obs_result := constructora.fn_observacion(v_item_result.id, v_obs, NULL);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'item', to_jsonb(v_item_result),
                'observacion', to_jsonb(v_obs_result)
            )
        );

    -- ========================================================
    -- R05 — Observación
    -- R06 — Completar
    -- R07 — Cancelar
    -- R08 — Reabrir
    -- ========================================================
    ELSIF v_regla IN ('R05','R06','R07','R08') THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|item_id|Necesito identificar exactamente el compromiso.';
        END;

        v_obs := nullif(btrim(v_data ->> 'observacion'), '');
        IF v_obs IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|observacion|¿Qué querés dejar registrado sobre este compromiso?';
        END IF;

        v_estado := CASE v_regla
            WHEN 'R05' THEN NULL
            WHEN 'R06' THEN 'completado'
            WHEN 'R07' THEN 'cancelado'
            WHEN 'R08' THEN 'activo'
        END;

        v_obs_result := constructora.fn_observacion(v_item_id, v_obs, v_estado);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object('observacion', to_jsonb(v_obs_result))
        );

    -- ========================================================
    -- R11 — Calcular fecha por posición
    -- Puede trabajar con item_id o configuración explícita.
    -- ========================================================
    ELSIF v_regla = 'R11' THEN
        IF v_data ? 'item_id' THEN
            BEGIN
                v_item_id := (v_data ->> 'item_id')::uuid;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|item_id|El compromiso indicado no tiene un identificador válido.';
            END;

            SELECT * INTO v_item FROM constructora.items WHERE id = v_item_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_ACLARACION|item|No encuentro el compromiso indicado. ¿Podés identificarlo nuevamente?';
            END IF;
            IF v_item.recurrencia IS NULL THEN
                RAISE EXCEPTION
                    'agenda_OPERACION_NO_PERMITIDA|recurrencia|Este compromiso no es recurrente.';
            END IF;

            v_frecuencia := v_item.recurrencia ->> 'frecuencia';
            v_intervalo := COALESCE((v_item.recurrencia ->> 'intervalo')::integer, 1);
        ELSE
            BEGIN
                v_item.fecha_inicio := (v_data ->> 'fecha_ancla')::timestamptz;
                v_frecuencia := v_data ->> 'frecuencia';
                v_intervalo := COALESCE((v_data ->> 'intervalo')::integer, 1);
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|recurrencia|Necesito una fecha de ancla, frecuencia e intervalo válidos.';
            END;
        END IF;

        IF NOT (v_data ? 'posicion') THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|posicion|¿Qué posición de la recurrencia querés calcular?';
        END IF;
        BEGIN
            v_posicion := (v_data ->> 'posicion')::bigint;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|posicion|La posición debe ser un número entero.';
        END;

        v_fecha := constructora.fn_fecha_recurrencia(
            v_item.fecha_inicio, v_frecuencia, v_intervalo, v_posicion
        );

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'posicion', v_posicion,
                'fecha', v_fecha
            )
        );

    -- ========================================================
    -- R12 — Localizar ocurrencia
    -- ========================================================
    ELSIF v_regla = 'R12' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|item_id|¿De qué compromiso recurrente querés localizar una ocurrencia?';
        END;

        SELECT * INTO v_item FROM constructora.items WHERE id = v_item_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_ACLARACION|item|No encuentro el compromiso recurrente indicado.';
        END IF;
        IF v_item.recurrencia IS NULL THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|recurrencia|Este compromiso no es recurrente.';
        END IF;

        IF v_data ? 'fecha_referencia' AND v_data -> 'fecha_referencia' <> 'null'::jsonb THEN
            BEGIN
                v_fecha_ref := (v_data ->> 'fecha_referencia')::timestamptz;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|fecha_referencia|Necesito una fecha de referencia válida para localizar la ocurrencia.';
            END;
        ELSE
            v_fecha_ref := now();
        END IF;

        SELECT * INTO v_pos
        FROM constructora.fn_posicion_recurrencia(
            v_item.fecha_inicio,
            v_item.recurrencia ->> 'frecuencia',
            COALESCE((v_item.recurrencia ->> 'intervalo')::integer, 1),
            v_fecha_ref
        );

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', to_jsonb(v_pos)
        );

    -- ========================================================
    -- R13 / R14 / R15 / R16 — Registrar/corregir por posición
    -- ========================================================
    ELSIF v_regla IN ('R13','R14','R15','R16') THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
            v_posicion := (v_data ->> 'posicion')::bigint;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|ocurrencia|Necesito item_id y posición para identificar exactamente la ocurrencia.';
        END;

        v_estado := CASE v_regla
            WHEN 'R13' THEN 'completado'
            WHEN 'R14' THEN 'no_completado'
            WHEN 'R15' THEN 'cancelado'
            ELSE nullif(btrim(v_data ->> 'estado'), '')
        END;

        IF v_estado IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|estado|¿Cuál es el resultado correcto de esta ocurrencia: completado, no_completado o cancelado?';
        END IF;

        v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_posicion, v_estado);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object('ocurrencia', to_jsonb(v_hist_result))
        );

    -- ========================================================
    -- R17 — Localizar + registrar ocurrencia
    -- ========================================================
    ELSIF v_regla = 'R17' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
            v_fecha_ref := (v_data ->> 'fecha_referencia')::timestamptz;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|ocurrencia|Necesito el compromiso y una fecha de referencia concreta para saber qué ocurrencia querés afectar.';
        END;
        v_estado := nullif(btrim(v_data ->> 'estado'), '');
        IF v_estado IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|estado|¿La ocurrencia quedó completada, no_completada o cancelada?';
        END IF;

        SELECT * INTO v_item FROM constructora.items WHERE id = v_item_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_ACLARACION|item|No encuentro el compromiso indicado.';
        END IF;
        IF v_item.recurrencia IS NULL THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|recurrencia|La orden habla de una ocurrencia, pero este compromiso no es recurrente.';
        END IF;

        SELECT * INTO v_pos
        FROM constructora.fn_posicion_recurrencia(
            v_item.fecha_inicio,
            v_item.recurrencia ->> 'frecuencia',
            COALESCE((v_item.recurrencia ->> 'intervalo')::integer, 1),
            v_fecha_ref
        );

        v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_pos.posicion, v_estado);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'localizacion', to_jsonb(v_pos),
                'ocurrencia', to_jsonb(v_hist_result)
            )
        );

    -- ========================================================
    -- R18 — Calcular fecha + registrar resultado
    -- ========================================================
    ELSIF v_regla = 'R18' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
            v_posicion := (v_data ->> 'posicion')::bigint;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|ocurrencia|Necesito item_id y posición.';
        END;
        v_estado := nullif(btrim(v_data ->> 'estado'), '');
        IF v_estado IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|estado|¿Qué resultado querés registrar para esa ocurrencia?';
        END IF;

        SELECT * INTO v_item FROM constructora.items WHERE id = v_item_id;
        IF NOT FOUND OR v_item.recurrencia IS NULL THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|recurrencia|Necesito un compromiso recurrente válido.';
        END IF;

        v_fecha := constructora.fn_fecha_recurrencia(
            v_item.fecha_inicio,
            v_item.recurrencia ->> 'frecuencia',
            COALESCE((v_item.recurrencia ->> 'intervalo')::integer, 1),
            v_posicion
        );
        v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_posicion, v_estado);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'fecha', v_fecha,
                'ocurrencia', to_jsonb(v_hist_result)
            )
        );

    -- ========================================================
    -- R19 / R20 — localizar + registrar + observación/estado general
    -- ========================================================
    ELSIF v_regla IN ('R19','R20') THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
            v_fecha_ref := (v_data ->> 'fecha_referencia')::timestamptz;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|ocurrencia|Necesito identificar el compromiso y la ocurrencia.';
        END;

        v_estado := nullif(btrim(v_data ->> 'estado_ocurrencia'), '');
        v_obs := nullif(btrim(v_data ->> 'observacion'), '');

        IF v_estado IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|estado_ocurrencia|¿Qué pasó con esa ocurrencia?';
        END IF;
        IF v_obs IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|observacion|¿Qué hecho querés dejar registrado a nivel general?';
        END IF;

        SELECT * INTO v_item FROM constructora.items WHERE id = v_item_id;
        IF NOT FOUND OR v_item.recurrencia IS NULL THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|recurrencia|Necesito un compromiso recurrente válido.';
        END IF;

        SELECT * INTO v_pos
        FROM constructora.fn_posicion_recurrencia(
            v_item.fecha_inicio,
            v_item.recurrencia ->> 'frecuencia',
            COALESCE((v_item.recurrencia ->> 'intervalo')::integer, 1),
            v_fecha_ref
        );

        v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_pos.posicion, v_estado);

        IF v_regla = 'R20' THEN
            v_estado := nullif(btrim(v_data ->> 'estado_general'), '');
            IF v_estado IS NULL THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|estado_general|¿Querés dejar el compromiso activo, completado o cancelado?';
            END IF;
        ELSE
            v_estado := NULL;
        END IF;

        v_obs_result := constructora.fn_observacion(v_item_id, v_obs, v_estado);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'localizacion', to_jsonb(v_pos),
                'ocurrencia', to_jsonb(v_hist_result),
                'observacion', to_jsonb(v_obs_result)
            )
        );

    -- ========================================================
    -- R21 / R22 — PATCH + estado, con orden diferente
    -- ========================================================
    ELSIF v_regla IN ('R21','R22') THEN
        v_patch := COALESCE(v_data -> 'patch', v_data -> 'item');
        v_obs := nullif(btrim(v_data ->> 'observacion'), '');
        v_estado := nullif(btrim(v_data ->> 'estado_general'), '');

        IF v_patch IS NULL OR jsonb_typeof(v_patch) <> 'object' THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|patch|¿Qué querés modificar además del estado?';
        END IF;
        IF v_obs IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|observacion|¿Qué querés dejar registrado sobre el cambio de estado?';
        END IF;
        IF v_estado IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|estado_general|¿El compromiso queda activo, completado o cancelado?';
        END IF;

        IF NOT (v_patch ? 'id') OR v_patch -> 'id' = 'null'::jsonb THEN
            IF v_data ? 'item_id' THEN
                v_patch := jsonb_set(v_patch, '{id}', to_jsonb(v_data ->> 'item_id'));
            ELSE
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|item_id|¿Qué compromiso querés modificar?';
            END IF;
        END IF;

        BEGIN
            v_item_id := (v_patch ->> 'id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|item_id|El identificador del compromiso no es válido.';
        END;

        IF v_regla = 'R21' THEN
            v_item_result := constructora.fn_item(v_patch);
            v_obs_result := constructora.fn_observacion(v_item_id, v_obs, v_estado);
        ELSE
            v_obs_result := constructora.fn_observacion(v_item_id, v_obs, v_estado);
            v_item_result := constructora.fn_item(v_patch);
        END IF;

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'item', to_jsonb(v_item_result),
                'observacion', to_jsonb(v_obs_result)
            )
        );

    -- ========================================================
    -- R23 — modificar recurrencia + localizar
    -- ========================================================
    ELSIF v_regla = 'R23' THEN
        v_patch := COALESCE(v_data -> 'patch', v_data -> 'item');
        IF v_patch IS NULL OR jsonb_typeof(v_patch) <> 'object' OR NOT (v_patch ? 'id') THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|patch|Necesito el id y la nueva configuración recurrente.';
        END IF;
        IF NOT (v_patch ? 'recurrencia') THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|recurrencia|¿Cómo querés cambiar la recurrencia?';
        END IF;

        v_item_result := constructora.fn_item(v_patch);
        IF v_item_result.recurrencia IS NULL THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|recurrencia|Después del cambio el item no es recurrente, por lo que no hay una ocurrencia que localizar.';
        END IF;

        IF v_data ? 'fecha_referencia' AND v_data -> 'fecha_referencia' <> 'null'::jsonb THEN
            BEGIN
                v_fecha_ref := (v_data ->> 'fecha_referencia')::timestamptz;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|fecha_referencia|Necesito una fecha de referencia válida.';
            END;
        ELSE
            v_fecha_ref := now();
        END IF;

        SELECT * INTO v_pos FROM constructora.fn_posicion_recurrencia(
            v_item_result.fecha_inicio,
            v_item_result.recurrencia ->> 'frecuencia',
            COALESCE((v_item_result.recurrencia ->> 'intervalo')::integer, 1),
            v_fecha_ref
        );

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'item', to_jsonb(v_item_result),
                'localizacion', to_jsonb(v_pos)
            )
        );

    -- ========================================================
    -- R24 — modificar recurrencia + localizar + registrar
    -- ========================================================
    ELSIF v_regla = 'R24' THEN
        v_patch := COALESCE(v_data -> 'patch', v_data -> 'item');
        v_estado := nullif(btrim(v_data ->> 'estado_ocurrencia'), '');

        IF v_patch IS NULL OR jsonb_typeof(v_patch) <> 'object' OR NOT (v_patch ? 'id') THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|patch|Necesito el item y la nueva recurrencia.';
        END IF;
        IF NOT (v_patch ? 'recurrencia') THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|recurrencia|¿Cuál es la nueva recurrencia?';
        END IF;
        IF v_estado IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|estado_ocurrencia|¿Qué resultado querés registrar en la ocurrencia?';
        END IF;
        BEGIN
            v_fecha_ref := (v_data ->> 'fecha_referencia')::timestamptz;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|fecha_referencia|¿A qué fecha u ocurrencia te referís después del cambio?';
        END;

        v_item_result := constructora.fn_item(v_patch);
        IF v_item_result.recurrencia IS NULL THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|recurrencia|La nueva definición no es recurrente.';
        END IF;

        SELECT * INTO v_pos FROM constructora.fn_posicion_recurrencia(
            v_item_result.fecha_inicio,
            v_item_result.recurrencia ->> 'frecuencia',
            COALESCE((v_item_result.recurrencia ->> 'intervalo')::integer, 1),
            v_fecha_ref
        );
        v_hist_result := constructora.fn_registrar_recurrencia(v_item_result.id, v_pos.posicion, v_estado);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'item', to_jsonb(v_item_result),
                'localizacion', to_jsonb(v_pos),
                'ocurrencia', to_jsonb(v_hist_result)
            )
        );

    -- ========================================================
    -- R25 — registrar + localizar continuación
    -- ========================================================
    ELSIF v_regla = 'R25' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
            v_posicion := (v_data ->> 'posicion')::bigint;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|ocurrencia|Necesito item_id y posición de la ocurrencia que querés registrar.';
        END;
        v_estado := nullif(btrim(v_data ->> 'estado'), '');
        IF v_estado IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|estado|¿Qué resultado tuvo la ocurrencia?';
        END IF;

        v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_posicion, v_estado);

        SELECT * INTO v_item FROM constructora.items WHERE id = v_item_id;
        v_fecha_ref := COALESCE(
            (v_data ->> 'fecha_referencia')::timestamptz,
            v_hist_result.fecha + interval '1 microsecond'
        );

        SELECT * INTO v_pos FROM constructora.fn_posicion_recurrencia(
            v_item.fecha_inicio,
            v_item.recurrencia ->> 'frecuencia',
            COALESCE((v_item.recurrencia ->> 'intervalo')::integer, 1),
            v_fecha_ref
        );

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'ocurrencia', to_jsonb(v_hist_result),
                'continuacion', to_jsonb(v_pos)
            )
        );

    -- ========================================================
    -- R26 — registrar resultado + modificar definición
    -- ========================================================
    ELSIF v_regla = 'R26' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
            v_posicion := (v_data ->> 'posicion')::bigint;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|ocurrencia|Necesito item_id y posición.';
        END;
        v_estado := nullif(btrim(v_data ->> 'estado_ocurrencia'), '');
        v_patch := v_data -> 'patch';

        IF v_estado IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|estado_ocurrencia|¿Qué resultado tuvo la ocurrencia?';
        END IF;
        IF v_patch IS NULL OR jsonb_typeof(v_patch) <> 'object' THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|patch|¿Qué querés cambiar para las próximas veces?';
        END IF;

        v_patch := jsonb_set(v_patch, '{id}', to_jsonb(v_item_id::text));
        v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_posicion, v_estado);
        v_item_result := constructora.fn_item(v_patch);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'ocurrencia', to_jsonb(v_hist_result),
                'item', to_jsonb(v_item_result)
            )
        );

    -- ========================================================
    -- R27 — resultado + modificación + observación
    -- ========================================================
    ELSIF v_regla = 'R27' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
            v_posicion := (v_data ->> 'posicion')::bigint;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|ocurrencia|Necesito identificar la ocurrencia.';
        END;
        v_estado := nullif(btrim(v_data ->> 'estado_ocurrencia'), '');
        v_patch := v_data -> 'patch';
        v_obs := nullif(btrim(v_data ->> 'observacion'), '');

        IF v_estado IS NULL OR v_patch IS NULL OR jsonb_typeof(v_patch) <> 'object' OR v_obs IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|orden_compuesta|Necesito el resultado de la ocurrencia, el cambio del item y la observación que explica el cambio.';
        END IF;

        v_patch := jsonb_set(v_patch, '{id}', to_jsonb(v_item_id::text));
        v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_posicion, v_estado);
        v_item_result := constructora.fn_item(v_patch);
        v_obs_result := constructora.fn_observacion(v_item_id, v_obs, NULL);

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'ocurrencia', to_jsonb(v_hist_result),
                'item', to_jsonb(v_item_result),
                'observacion', to_jsonb(v_obs_result)
            )
        );

    -- ========================================================
    -- R28 / R29 — crear recurrente + observar + localizar/[registrar]
    -- ========================================================
    ELSIF v_regla IN ('R28','R29') THEN
        v_item_data := v_data -> 'item';
        v_obs := nullif(btrim(v_data ->> 'observacion'), '');

        IF v_item_data IS NULL OR jsonb_typeof(v_item_data) <> 'object' THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|item|¿Qué compromiso recurrente querés crear?';
        END IF;
        IF v_obs IS NULL THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|observacion|¿Qué hecho querés registrar al crear la serie?';
        END IF;

        v_item_result := constructora.fn_item(v_item_data);
        IF v_item_result.recurrencia IS NULL THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|recurrencia|Esta regla necesita crear un compromiso recurrente.';
        END IF;
        v_obs_result := constructora.fn_observacion(v_item_result.id, v_obs, NULL);

        IF v_data ? 'fecha_referencia' AND v_data -> 'fecha_referencia' <> 'null'::jsonb THEN
            BEGIN
                v_fecha_ref := (v_data ->> 'fecha_referencia')::timestamptz;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|fecha_referencia|Necesito una fecha de referencia válida.';
            END;
        ELSE
            v_fecha_ref := v_item_result.fecha_inicio;
        END IF;

        SELECT * INTO v_pos FROM constructora.fn_posicion_recurrencia(
            v_item_result.fecha_inicio,
            v_item_result.recurrencia ->> 'frecuencia',
            COALESCE((v_item_result.recurrencia ->> 'intervalo')::integer, 1),
            v_fecha_ref
        );

        IF v_regla = 'R29' THEN
            v_estado := nullif(btrim(v_data ->> 'estado_ocurrencia'), '');
            IF v_estado IS NULL THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|estado_ocurrencia|¿Qué resultado querés registrar para esa ocurrencia?';
            END IF;
            v_hist_result := constructora.fn_registrar_recurrencia(
                v_item_result.id, v_pos.posicion, v_estado
            );
        END IF;

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_strip_nulls(jsonb_build_object(
                'item', to_jsonb(v_item_result),
                'observacion', to_jsonb(v_obs_result),
                'localizacion', to_jsonb(v_pos),
                'ocurrencia', CASE WHEN v_regla = 'R29' THEN to_jsonb(v_hist_result) ELSE NULL END
            ))
        );

    -- ========================================================
    -- R30 — varias observaciones
    -- data.observaciones = ["...", "..."] o
    -- [{"texto":"...","estado_nuevo":null}, ...]
    -- ========================================================
    ELSIF v_regla = 'R30' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|item_id|¿Sobre qué compromiso querés registrar las observaciones?';
        END;

        IF jsonb_typeof(v_data -> 'observaciones') <> 'array'
           OR jsonb_array_length(v_data -> 'observaciones') = 0 THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|observaciones|Necesito una lista ordenada de observaciones.';
        END IF;

        FOR v_elem IN SELECT value FROM jsonb_array_elements(v_data -> 'observaciones')
        LOOP
            IF jsonb_typeof(v_elem) = 'string' THEN
                v_obs := nullif(btrim(v_elem #>> '{}'), '');
                v_estado := NULL;
            ELSIF jsonb_typeof(v_elem) = 'object' THEN
                v_obs := nullif(btrim(COALESCE(v_elem ->> 'texto', v_elem ->> 'observacion')), '');
                v_estado := nullif(btrim(v_elem ->> 'estado_nuevo'), '');
            ELSE
                RAISE EXCEPTION
                    'agenda_REQUIERE_ACLARACION|observaciones|Cada observación debe ser texto o un objeto con texto.';
            END IF;

            IF v_obs IS NULL THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|observacion|Encontré una observación vacía. ¿Qué hecho querés registrar?';
            END IF;

            v_obs_result := constructora.fn_observacion(v_item_id, v_obs, v_estado);
            v_resultados := v_resultados || jsonb_build_array(to_jsonb(v_obs_result));
        END LOOP;

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object('observaciones', v_resultados)
        );

    -- ========================================================
    -- R31 — varias ocurrencias
    -- Cada entrada: {"posicion":N,"estado":"..."}
    -- ========================================================
    ELSIF v_regla = 'R31' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|item_id|¿De qué serie querés registrar varias ocurrencias?';
        END;

        IF jsonb_typeof(v_data -> 'ocurrencias') <> 'array'
           OR jsonb_array_length(v_data -> 'ocurrencias') = 0 THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|ocurrencias|Necesito una lista de ocurrencias con posición y estado.';
        END IF;

        FOR v_elem IN SELECT value FROM jsonb_array_elements(v_data -> 'ocurrencias')
        LOOP
            BEGIN
                v_posicion := (v_elem ->> 'posicion')::bigint;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|posicion|Cada ocurrencia necesita una posición entera.';
            END;
            v_estado := nullif(btrim(v_elem ->> 'estado'), '');
            IF v_estado IS NULL THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_DATO|estado|Cada ocurrencia necesita un resultado.';
            END IF;

            v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_posicion, v_estado);
            v_resultados := v_resultados || jsonb_build_array(to_jsonb(v_hist_result));
        END LOOP;

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object('ocurrencias', v_resultados)
        );

    -- ========================================================
    -- R34 — localizar + calcular otra fecha
    -- data.desplazamiento: posiciones desde la correspondiente
    -- ========================================================
    ELSIF v_regla = 'R34' THEN
        BEGIN
            v_item_id := (v_data ->> 'item_id')::uuid;
            v_fecha_ref := (v_data ->> 'fecha_referencia')::timestamptz;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|referencia|Necesito el compromiso y una fecha de referencia.';
        END;

        IF NOT (v_data ? 'desplazamiento') THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|desplazamiento|¿Cuántas posiciones querés moverte desde la ocurrencia localizada?';
        END IF;
        BEGIN
            v_idx := (v_data ->> 'desplazamiento')::integer;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|desplazamiento|El desplazamiento debe ser un número entero.';
        END;

        SELECT * INTO v_item FROM constructora.items WHERE id = v_item_id;
        IF NOT FOUND OR v_item.recurrencia IS NULL THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|recurrencia|Necesito un compromiso recurrente válido.';
        END IF;

        SELECT * INTO v_pos FROM constructora.fn_posicion_recurrencia(
            v_item.fecha_inicio,
            v_item.recurrencia ->> 'frecuencia',
            COALESCE((v_item.recurrencia ->> 'intervalo')::integer, 1),
            v_fecha_ref
        );

        v_posicion := v_pos.posicion + v_idx;
        IF v_posicion < 0 THEN
            RAISE EXCEPTION
                'agenda_OPERACION_NO_PERMITIDA|posicion|El desplazamiento lleva a una posición anterior al inicio de la serie.';
        END IF;

        v_fecha := constructora.fn_fecha_recurrencia(
            v_item.fecha_inicio,
            v_item.recurrencia ->> 'frecuencia',
            COALESCE((v_item.recurrencia ->> 'intervalo')::integer, 1),
            v_posicion
        );

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object(
                'localizacion', to_jsonb(v_pos),
                'posicion_objetivo', v_posicion,
                'fecha_objetivo', v_fecha
            )
        );

    -- ========================================================
    -- R35 — composición transaccional variable
    --
    -- NO ejecuta SQL arbitrario.
    -- Acepta un plan explícito de primitivas:
    -- ITEM, OBSERVACION, FECHA_RECURRENCIA,
    -- POSICION_RECURRENCIA, REGISTRAR_RECURRENCIA.
    --
    -- Es deliberadamente estricto: no resuelve referencias
    -- entre pasos mágicamente. Para dependencias complejas deben
    -- usarse R01-R34 o ampliar este contrato de forma explícita.
    -- ========================================================
    ELSIF v_regla = 'R35' THEN
        v_plan := v_data -> 'plan';

        IF jsonb_typeof(v_plan) <> 'array' OR jsonb_array_length(v_plan) = 0 THEN
            RAISE EXCEPTION
                'agenda_REQUIERE_DATO|plan|R35 necesita un plan explícito y ordenado de operaciones.';
        END IF;

        FOR v_step IN SELECT value FROM jsonb_array_elements(v_plan)
        LOOP
            IF jsonb_typeof(v_step) <> 'object' THEN
                RAISE EXCEPTION
                    'agenda_REQUIERE_ACLARACION|plan|Cada paso de R35 debe ser un objeto.';
            END IF;

            v_tipo := upper(btrim(v_step ->> 'tipo'));

            IF v_tipo = 'ITEM' THEN
                IF jsonb_typeof(v_step -> 'data') <> 'object' THEN
                    RAISE EXCEPTION
                        'agenda_REQUIERE_DATO|plan.item|El paso ITEM necesita data.';
                END IF;
                v_item_result := constructora.fn_item(v_step -> 'data');
                v_resultados := v_resultados || jsonb_build_array(
                    jsonb_build_object('tipo','ITEM','resultado',to_jsonb(v_item_result))
                );

            ELSIF v_tipo = 'OBSERVACION' THEN
                BEGIN
                    v_item_id := (v_step ->> 'item_id')::uuid;
                EXCEPTION WHEN OTHERS THEN
                    RAISE EXCEPTION
                        'agenda_REQUIERE_DATO|plan.item_id|El paso OBSERVACION necesita item_id explícito.';
                END;
                v_obs := nullif(btrim(v_step ->> 'observacion'), '');
                v_estado := nullif(btrim(v_step ->> 'estado_nuevo'), '');
                IF v_obs IS NULL THEN
                    RAISE EXCEPTION
                        'agenda_REQUIERE_DATO|plan.observacion|El paso OBSERVACION necesita texto.';
                END IF;
                v_obs_result := constructora.fn_observacion(v_item_id, v_obs, v_estado);
                v_resultados := v_resultados || jsonb_build_array(
                    jsonb_build_object('tipo','OBSERVACION','resultado',to_jsonb(v_obs_result))
                );

            ELSIF v_tipo = 'FECHA_RECURRENCIA' THEN
                BEGIN
                    v_fecha := constructora.fn_fecha_recurrencia(
                        (v_step ->> 'fecha_ancla')::timestamptz,
                        v_step ->> 'frecuencia',
                        COALESCE((v_step ->> 'intervalo')::integer, 1),
                        COALESCE((v_step ->> 'posicion')::bigint, 0)
                    );
                EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow THEN
                    RAISE EXCEPTION
                        'agenda_REQUIERE_DATO|plan.recurrencia|El paso FECHA_RECURRENCIA contiene datos inválidos.';
                END;
                v_resultados := v_resultados || jsonb_build_array(
                    jsonb_build_object('tipo','FECHA_RECURRENCIA','resultado',jsonb_build_object('fecha',v_fecha))
                );

            ELSIF v_tipo = 'POSICION_RECURRENCIA' THEN
                BEGIN
                    SELECT * INTO v_pos FROM constructora.fn_posicion_recurrencia(
                        (v_step ->> 'fecha_ancla')::timestamptz,
                        v_step ->> 'frecuencia',
                        COALESCE((v_step ->> 'intervalo')::integer, 1),
                        COALESCE((v_step ->> 'fecha_referencia')::timestamptz, now())
                    );
                EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow THEN
                    RAISE EXCEPTION
                        'agenda_REQUIERE_DATO|plan.recurrencia|El paso POSICION_RECURRENCIA contiene datos inválidos.';
                END;
                v_resultados := v_resultados || jsonb_build_array(
                    jsonb_build_object('tipo','POSICION_RECURRENCIA','resultado',to_jsonb(v_pos))
                );

            ELSIF v_tipo = 'REGISTRAR_RECURRENCIA' THEN
                BEGIN
                    v_item_id := (v_step ->> 'item_id')::uuid;
                    v_posicion := (v_step ->> 'posicion')::bigint;
                EXCEPTION WHEN OTHERS THEN
                    RAISE EXCEPTION
                        'agenda_REQUIERE_DATO|plan.ocurrencia|REGISTRAR_RECURRENCIA necesita item_id y posición.';
                END;
                v_estado := nullif(btrim(v_step ->> 'estado'), '');
                IF v_estado IS NULL THEN
                    RAISE EXCEPTION
                        'agenda_REQUIERE_DATO|plan.estado|REGISTRAR_RECURRENCIA necesita estado.';
                END IF;
                v_hist_result := constructora.fn_registrar_recurrencia(v_item_id, v_posicion, v_estado);
                v_resultados := v_resultados || jsonb_build_array(
                    jsonb_build_object('tipo','REGISTRAR_RECURRENCIA','resultado',to_jsonb(v_hist_result))
                );

            ELSE
                RAISE EXCEPTION
                    'agenda_OPERACION_NO_PERMITIDA|plan|El tipo de paso % no está permitido en R35.',
                    COALESCE(v_tipo, '<vacío>');
            END IF;
        END LOOP;

        RETURN jsonb_build_object(
            'ok', true, 'regla', v_regla,
            'resultado', jsonb_build_object('pasos', v_resultados)
        );

    ELSE
        RAISE EXCEPTION
            'agenda_OPERACION_NO_PERMITIDA|regla|La regla % todavía no tiene construcción ejecutable.',
            v_regla;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Si el propio orquestador ya produjo un mensaje semántico,
        -- se conserva exactamente para que la capa superior pueda guiar.
        IF SQLERRM LIKE 'agenda_REQUIERE_DATO|%'
           OR SQLERRM LIKE 'agenda_REQUIERE_ACLARACION|%'
           OR SQLERRM LIKE 'agenda_OPERACION_NO_PERMITIDA|%'
        THEN
            RAISE;
        END IF;

        -- Traducción amigable de errores conocidos de las cinco bases.
        CASE SQLERRM
            WHEN 'agenda_ITEM_DATOS_INVALIDOS' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|item|Necesito datos válidos del compromiso.';
            WHEN 'agenda_ITEM_ID_INVALIDO' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|item_id|El identificador del compromiso no es válido.';
            WHEN 'agenda_ITEM_NUEVO_DEBE_SER_ACTIVO' THEN
                RAISE EXCEPTION 'agenda_OPERACION_NO_PERMITIDA|estado|Un compromiso nuevo nace activo. Si querés cerrarlo o cancelarlo, primero hay que crearlo y después registrar ese movimiento.';
            WHEN 'agenda_ITEM_FECHA_INVALIDA' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|fecha|La fecha indicada no es válida. Necesito una fecha y hora que pueda interpretar sin ambigüedad.';
            WHEN 'agenda_ITEM_TODO_EL_DIA_INVALIDO' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|todo_el_dia|Necesito saber si el compromiso es de todo el día: true o false.';
            WHEN 'agenda_ITEM_ESTADO_NO_EDITABLE: use fn_observacion' THEN
                RAISE EXCEPTION 'agenda_OPERACION_NO_PERMITIDA|estado|El estado no se edita como un campo. Usá una regla de movimiento: completar, cancelar o reabrir.';
            WHEN 'agenda_OBSERVACION_ITEM_ID_REQUERIDO' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|item_id|¿Sobre qué compromiso querés registrar el movimiento?';
            WHEN 'agenda_OBSERVACION_ITEM_NO_EXISTE' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_ACLARACION|item|No encuentro ese compromiso. ¿Podés identificarlo nuevamente?';
            WHEN 'agenda_OBSERVACION_TEXTO_REQUERIDO' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|observacion|¿Qué hecho querés dejar registrado?';
            WHEN 'agenda_OBSERVACION_ESTADO_INVALIDO' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|estado_general|El estado general debe ser activo, completado o cancelado.';
            WHEN 'agenda_RECURRENCIA_ITEM_ID_REQUERIDO' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|item_id|¿De qué compromiso recurrente estamos hablando?';
            WHEN 'agenda_RECURRENCIA_ITEM_NO_EXISTE' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_ACLARACION|item|No encuentro el compromiso recurrente indicado.';
            WHEN 'agenda_RECURRENCIA_ITEM_NO_RECURRENTE' THEN
                RAISE EXCEPTION 'agenda_OPERACION_NO_PERMITIDA|recurrencia|Ese compromiso no es recurrente. Primero habría que definir su recurrencia.';
            WHEN 'agenda_RECURRENCIA_FECHA_INICIO_REQUERIDA' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|fecha_inicio|La serie necesita una fecha de inicio que funcione como ancla.';
            WHEN 'agenda_RECURRENCIA_FRECUENCIA_REQUERIDA' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|frecuencia|¿La recurrencia es diaria, semanal, mensual o anual?';
            WHEN 'agenda_RECURRENCIA_FRECUENCIA_INVALIDA' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|frecuencia|La frecuencia debe ser diaria, semanal, mensual o anual.';
            WHEN 'agenda_RECURRENCIA_INTERVALO_INVALIDO' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|intervalo|El intervalo debe ser un entero mayor o igual a 1.';
            WHEN 'agenda_POSICION_FECHA_ANCLA_REQUERIDA' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|fecha_inicio|Necesito la fecha de inicio de la serie para localizar una ocurrencia.';
            WHEN 'agenda_POSICION_FECHA_REFERENCIA_REQUERIDA' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|fecha_referencia|¿Respecto de qué fecha querés localizar la ocurrencia?';
            WHEN 'agenda_POSICION_FRECUENCIA_REQUERIDA' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|frecuencia|Necesito la frecuencia de la serie.';
            WHEN 'agenda_POSICION_FRECUENCIA_INVALIDA' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|frecuencia|La frecuencia debe ser diaria, semanal, mensual o anual.';
            WHEN 'agenda_POSICION_INTERVALO_INVALIDO' THEN
                RAISE EXCEPTION 'agenda_REQUIERE_DATO|intervalo|El intervalo de recurrencia debe ser un entero mayor o igual a 1.';
            ELSE
                -- Error no catalogado: no se oculta. Esto es deliberado
                -- para que durante desarrollo podamos encontrar bugs reales.
                RAISE;
        END CASE;
END;
$$;

COMMENT ON FUNCTION constructora.fn_orquestador(text,jsonb) IS
'Orquestador transaccional de Agenda ELECCON. Ejecuta R01-R35 sobre las cinco funciones base y emite errores semánticos amigables y guiados.';


COMMIT;