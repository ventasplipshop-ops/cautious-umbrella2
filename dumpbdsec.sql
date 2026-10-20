--
-- PostgreSQL database dump
--

\restrict ilcjSwBSYwigH4py0oHNLXXKTfQ6DhciGf0nfQCsKagLibPRJANghY18OD4nlNS

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
-- Name: secretaria_ia; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA secretaria_ia;


ALTER SCHEMA secretaria_ia OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: casos; Type: TABLE; Schema: secretaria_ia; Owner: postgres
--

CREATE TABLE secretaria_ia.casos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    categoria text NOT NULL,
    titulo text NOT NULL,
    entrada jsonb NOT NULL,
    respuesta_esperada jsonb NOT NULL,
    dificultad text DEFAULT 'basico'::text NOT NULL,
    validado boolean DEFAULT false NOT NULL,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT casos_dificultad_check CHECK ((dificultad = ANY (ARRAY['basico'::text, 'intermedio'::text, 'avanzado'::text])))
);


ALTER TABLE secretaria_ia.casos OWNER TO postgres;

--
-- Name: correcciones; Type: TABLE; Schema: secretaria_ia; Owner: postgres
--

CREATE TABLE secretaria_ia.correcciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    resultado_id uuid NOT NULL,
    tipo_error text NOT NULL,
    explicacion text NOT NULL,
    respuesta_corregida jsonb NOT NULL,
    aprobada boolean DEFAULT false NOT NULL,
    creado_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE secretaria_ia.correcciones OWNER TO postgres;

--
-- Name: ejecuciones_whatsapp; Type: TABLE; Schema: secretaria_ia; Owner: postgres
--

CREATE TABLE secretaria_ia.ejecuciones_whatsapp (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entrenamiento_id uuid NOT NULL,
    version_reglas integer NOT NULL,
    reglas text NOT NULL,
    estado text DEFAULT 'pendiente'::text NOT NULL,
    progreso jsonb DEFAULT '{}'::jsonb NOT NULL,
    etapas jsonb DEFAULT '{}'::jsonb NOT NULL,
    informe jsonb,
    evaluacion jsonb,
    error text,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    terminado_at timestamp with time zone,
    CONSTRAINT ejecuciones_whatsapp_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'ejecutando'::text, 'completado'::text, 'error'::text])))
);


ALTER TABLE secretaria_ia.ejecuciones_whatsapp OWNER TO postgres;

--
-- Name: entrenamientos_whatsapp; Type: TABLE; Schema: secretaria_ia; Owner: postgres
--

CREATE TABLE secretaria_ia.entrenamientos_whatsapp (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    chat text NOT NULL,
    respuesta_ideal jsonb,
    creado_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE secretaria_ia.entrenamientos_whatsapp OWNER TO postgres;

--
-- Name: instrucciones; Type: TABLE; Schema: secretaria_ia; Owner: postgres
--

CREATE TABLE secretaria_ia.instrucciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    modelo text DEFAULT 'secretaria-whatsapp:latest'::text NOT NULL,
    instrucciones text NOT NULL,
    parametros jsonb DEFAULT '{"num_ctx": 8192, "temperature": 0.1}'::jsonb NOT NULL,
    activa boolean DEFAULT false NOT NULL,
    creado_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE secretaria_ia.instrucciones OWNER TO postgres;

--
-- Name: resultados; Type: TABLE; Schema: secretaria_ia; Owner: postgres
--

CREATE TABLE secretaria_ia.resultados (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sesion_id uuid NOT NULL,
    caso_id uuid NOT NULL,
    respuesta_modelo jsonb,
    evaluacion jsonb DEFAULT '{}'::jsonb NOT NULL,
    estado text DEFAULT 'pendiente'::text NOT NULL,
    duracion_ms bigint,
    tokens_entrada integer,
    tokens_salida integer,
    error_detalle text,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT resultados_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'correcto'::text, 'incorrecto'::text, 'revision'::text, 'error'::text])))
);


ALTER TABLE secretaria_ia.resultados OWNER TO postgres;

--
-- Name: sesiones; Type: TABLE; Schema: secretaria_ia; Owner: postgres
--

CREATE TABLE secretaria_ia.sesiones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    modelo text NOT NULL,
    instrucciones_id uuid,
    estado text DEFAULT 'pendiente'::text NOT NULL,
    configuracion jsonb DEFAULT '{}'::jsonb NOT NULL,
    iniciada_at timestamp with time zone,
    finalizada_at timestamp with time zone,
    creado_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sesiones_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'ejecutando'::text, 'finalizada'::text, 'detenida'::text, 'error'::text])))
);


ALTER TABLE secretaria_ia.sesiones OWNER TO postgres;

--
-- Name: casos casos_pkey; Type: CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.casos
    ADD CONSTRAINT casos_pkey PRIMARY KEY (id);


--
-- Name: correcciones correcciones_pkey; Type: CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.correcciones
    ADD CONSTRAINT correcciones_pkey PRIMARY KEY (id);


--
-- Name: ejecuciones_whatsapp ejecuciones_whatsapp_pkey; Type: CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.ejecuciones_whatsapp
    ADD CONSTRAINT ejecuciones_whatsapp_pkey PRIMARY KEY (id);


--
-- Name: entrenamientos_whatsapp entrenamientos_whatsapp_pkey; Type: CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.entrenamientos_whatsapp
    ADD CONSTRAINT entrenamientos_whatsapp_pkey PRIMARY KEY (id);


--
-- Name: instrucciones instrucciones_nombre_version_key; Type: CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.instrucciones
    ADD CONSTRAINT instrucciones_nombre_version_key UNIQUE (nombre, version);


--
-- Name: instrucciones instrucciones_pkey; Type: CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.instrucciones
    ADD CONSTRAINT instrucciones_pkey PRIMARY KEY (id);


--
-- Name: resultados resultados_pkey; Type: CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.resultados
    ADD CONSTRAINT resultados_pkey PRIMARY KEY (id);


--
-- Name: sesiones sesiones_pkey; Type: CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.sesiones
    ADD CONSTRAINT sesiones_pkey PRIMARY KEY (id);


--
-- Name: ejecuciones_whatsapp_entrenamiento_idx; Type: INDEX; Schema: secretaria_ia; Owner: postgres
--

CREATE INDEX ejecuciones_whatsapp_entrenamiento_idx ON secretaria_ia.ejecuciones_whatsapp USING btree (entrenamiento_id, creado_at DESC);


--
-- Name: idx_secretaria_casos_categoria; Type: INDEX; Schema: secretaria_ia; Owner: postgres
--

CREATE INDEX idx_secretaria_casos_categoria ON secretaria_ia.casos USING btree (categoria);


--
-- Name: idx_secretaria_casos_validado; Type: INDEX; Schema: secretaria_ia; Owner: postgres
--

CREATE INDEX idx_secretaria_casos_validado ON secretaria_ia.casos USING btree (validado);


--
-- Name: idx_secretaria_instruccion_activa; Type: INDEX; Schema: secretaria_ia; Owner: postgres
--

CREATE UNIQUE INDEX idx_secretaria_instruccion_activa ON secretaria_ia.instrucciones USING btree (modelo) WHERE (activa = true);


--
-- Name: idx_secretaria_resultados_caso; Type: INDEX; Schema: secretaria_ia; Owner: postgres
--

CREATE INDEX idx_secretaria_resultados_caso ON secretaria_ia.resultados USING btree (caso_id);


--
-- Name: idx_secretaria_resultados_estado; Type: INDEX; Schema: secretaria_ia; Owner: postgres
--

CREATE INDEX idx_secretaria_resultados_estado ON secretaria_ia.resultados USING btree (estado);


--
-- Name: idx_secretaria_resultados_sesion; Type: INDEX; Schema: secretaria_ia; Owner: postgres
--

CREATE INDEX idx_secretaria_resultados_sesion ON secretaria_ia.resultados USING btree (sesion_id);


--
-- Name: correcciones correcciones_resultado_id_fkey; Type: FK CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.correcciones
    ADD CONSTRAINT correcciones_resultado_id_fkey FOREIGN KEY (resultado_id) REFERENCES secretaria_ia.resultados(id);


--
-- Name: ejecuciones_whatsapp ejecuciones_whatsapp_entrenamiento_id_fkey; Type: FK CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.ejecuciones_whatsapp
    ADD CONSTRAINT ejecuciones_whatsapp_entrenamiento_id_fkey FOREIGN KEY (entrenamiento_id) REFERENCES secretaria_ia.entrenamientos_whatsapp(id) ON DELETE CASCADE;


--
-- Name: resultados resultados_caso_id_fkey; Type: FK CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.resultados
    ADD CONSTRAINT resultados_caso_id_fkey FOREIGN KEY (caso_id) REFERENCES secretaria_ia.casos(id);


--
-- Name: resultados resultados_sesion_id_fkey; Type: FK CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.resultados
    ADD CONSTRAINT resultados_sesion_id_fkey FOREIGN KEY (sesion_id) REFERENCES secretaria_ia.sesiones(id);


--
-- Name: sesiones sesiones_instrucciones_id_fkey; Type: FK CONSTRAINT; Schema: secretaria_ia; Owner: postgres
--

ALTER TABLE ONLY secretaria_ia.sesiones
    ADD CONSTRAINT sesiones_instrucciones_id_fkey FOREIGN KEY (instrucciones_id) REFERENCES secretaria_ia.instrucciones(id);


--
-- Name: SCHEMA secretaria_ia; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA secretaria_ia TO tenant_app;


--
-- Name: TABLE casos; Type: ACL; Schema: secretaria_ia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE secretaria_ia.casos TO tenant_app;


--
-- Name: TABLE correcciones; Type: ACL; Schema: secretaria_ia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE secretaria_ia.correcciones TO tenant_app;


--
-- Name: TABLE ejecuciones_whatsapp; Type: ACL; Schema: secretaria_ia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE secretaria_ia.ejecuciones_whatsapp TO tenant_app;


--
-- Name: TABLE entrenamientos_whatsapp; Type: ACL; Schema: secretaria_ia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE secretaria_ia.entrenamientos_whatsapp TO tenant_app;


--
-- Name: TABLE instrucciones; Type: ACL; Schema: secretaria_ia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE secretaria_ia.instrucciones TO tenant_app;


--
-- Name: TABLE resultados; Type: ACL; Schema: secretaria_ia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE secretaria_ia.resultados TO tenant_app;


--
-- Name: TABLE sesiones; Type: ACL; Schema: secretaria_ia; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE secretaria_ia.sesiones TO tenant_app;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: secretaria_ia; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA secretaria_ia GRANT SELECT,USAGE ON SEQUENCES  TO tenant_app;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: secretaria_ia; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA secretaria_ia GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO tenant_app;


--
-- PostgreSQL database dump complete
--

\unrestrict ilcjSwBSYwigH4py0oHNLXXKTfQ6DhciGf0nfQCsKagLibPRJANghY18OD4nlNS

