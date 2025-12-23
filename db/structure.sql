SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: timescaledb; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;


--
-- Name: EXTENSION timescaledb; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION timescaledb IS 'Enables scalable inserts and complex queries for time-series data (Community Edition)';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name text NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    environment text,
    service text,
    host text,
    properties jsonb DEFAULT '{}'::jsonb,
    tags jsonb DEFAULT '{}'::jsonb,
    user_id text,
    session_id text,
    request_id text,
    value numeric,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: aggregated_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aggregated_metrics (
    project_id uuid NOT NULL,
    metric_name text NOT NULL,
    bucket_size text NOT NULL,
    bucket_time timestamp with time zone NOT NULL,
    sum double precision,
    count double precision,
    avg double precision,
    min double precision,
    max double precision,
    p50 double precision,
    p95 double precision,
    p99 double precision,
    tags jsonb DEFAULT '{}'::jsonb
);


--
-- Name: anomalies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.anomalies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    source character varying NOT NULL,
    source_name character varying NOT NULL,
    anomaly_type character varying NOT NULL,
    severity character varying DEFAULT 'info'::character varying,
    expected_value double precision,
    actual_value double precision,
    deviation_percent double precision,
    detected_at timestamp(6) without time zone NOT NULL,
    started_at timestamp(6) without time zone,
    ended_at timestamp(6) without time zone,
    context jsonb DEFAULT '{}'::jsonb,
    acknowledged boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dashboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    description text,
    is_default boolean DEFAULT false,
    is_public boolean DEFAULT false,
    layout jsonb DEFAULT '{}'::jsonb,
    settings jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: metric_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metric_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name character varying NOT NULL,
    display_name character varying,
    description text,
    metric_type character varying NOT NULL,
    unit character varying,
    tags_schema jsonb DEFAULT '{}'::jsonb,
    aggregations jsonb DEFAULT '[]'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: metric_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metric_points (
    project_id uuid NOT NULL,
    metric_name text NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    value double precision,
    sum double precision,
    count double precision,
    min double precision,
    max double precision,
    p50 double precision,
    p95 double precision,
    p99 double precision,
    cardinality integer,
    hll_data bytea,
    tags jsonb DEFAULT '{}'::jsonb
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform_project_id character varying NOT NULL,
    name character varying,
    slug character varying,
    description text,
    environment character varying DEFAULT 'development'::character varying,
    api_key character varying,
    ingest_key character varying,
    events_count bigint DEFAULT 0,
    metrics_count bigint DEFAULT 0,
    retention_days integer DEFAULT 90,
    settings jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: widgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.widgets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dashboard_id uuid NOT NULL,
    title character varying,
    widget_type character varying NOT NULL,
    query jsonb DEFAULT '{}'::jsonb,
    display jsonb DEFAULT '{}'::jsonb,
    "position" jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: anomalies anomalies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anomalies
    ADD CONSTRAINT anomalies_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: dashboards dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT dashboards_pkey PRIMARY KEY (id);


--
-- Name: metric_definitions metric_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metric_definitions
    ADD CONSTRAINT metric_definitions_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: widgets widgets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.widgets
    ADD CONSTRAINT widgets_pkey PRIMARY KEY (id);


--
-- Name: aggregated_metrics_bucket_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX aggregated_metrics_bucket_time_idx ON public.aggregated_metrics USING btree (bucket_time DESC);


--
-- Name: events_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_timestamp_idx ON public.events USING btree ("timestamp" DESC);


--
-- Name: idx_aggregated_metrics_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aggregated_metrics_lookup ON public.aggregated_metrics USING btree (project_id, metric_name, bucket_size, bucket_time);


--
-- Name: idx_events_properties; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_properties ON public.events USING gin (properties jsonb_path_ops);


--
-- Name: idx_events_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_tags ON public.events USING gin (tags jsonb_path_ops);


--
-- Name: idx_metric_points_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_metric_points_tags ON public.metric_points USING gin (tags jsonb_path_ops);


--
-- Name: idx_on_project_id_metric_name_timestamp_d3ed18d27d; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_project_id_metric_name_timestamp_d3ed18d27d ON public.metric_points USING btree (project_id, metric_name, "timestamp");


--
-- Name: index_anomalies_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_anomalies_on_project_id ON public.anomalies USING btree (project_id);


--
-- Name: index_anomalies_on_project_id_and_acknowledged; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_anomalies_on_project_id_and_acknowledged ON public.anomalies USING btree (project_id, acknowledged);


--
-- Name: index_anomalies_on_project_id_and_detected_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_anomalies_on_project_id_and_detected_at ON public.anomalies USING btree (project_id, detected_at);


--
-- Name: index_anomalies_on_project_id_and_severity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_anomalies_on_project_id_and_severity ON public.anomalies USING btree (project_id, severity);


--
-- Name: index_anomalies_on_project_id_and_source_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_anomalies_on_project_id_and_source_name ON public.anomalies USING btree (project_id, source_name);


--
-- Name: index_dashboards_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dashboards_on_project_id ON public.dashboards USING btree (project_id);


--
-- Name: index_dashboards_on_project_id_and_is_default; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dashboards_on_project_id_and_is_default ON public.dashboards USING btree (project_id, is_default);


--
-- Name: index_dashboards_on_project_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dashboards_on_project_id_and_slug ON public.dashboards USING btree (project_id, slug);


--
-- Name: index_events_on_project_id_and_name_and_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_project_id_and_name_and_timestamp ON public.events USING btree (project_id, name, "timestamp");


--
-- Name: index_events_on_project_id_and_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_project_id_and_timestamp ON public.events USING btree (project_id, "timestamp");


--
-- Name: index_events_on_session_id_and_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_session_id_and_timestamp ON public.events USING btree (session_id, "timestamp");


--
-- Name: index_events_on_user_id_and_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_user_id_and_timestamp ON public.events USING btree (user_id, "timestamp");


--
-- Name: index_metric_definitions_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metric_definitions_on_project_id ON public.metric_definitions USING btree (project_id);


--
-- Name: index_metric_definitions_on_project_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_metric_definitions_on_project_id_and_name ON public.metric_definitions USING btree (project_id, name);


--
-- Name: index_projects_on_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_api_key ON public.projects USING btree (api_key);


--
-- Name: index_projects_on_ingest_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_ingest_key ON public.projects USING btree (ingest_key);


--
-- Name: index_projects_on_platform_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_platform_project_id ON public.projects USING btree (platform_project_id);


--
-- Name: index_projects_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_slug ON public.projects USING btree (slug);


--
-- Name: index_widgets_on_dashboard_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_widgets_on_dashboard_id ON public.widgets USING btree (dashboard_id);


--
-- Name: metric_points_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX metric_points_timestamp_idx ON public.metric_points USING btree ("timestamp" DESC);


--
-- Name: widgets fk_rails_1368d3db36; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.widgets
    ADD CONSTRAINT fk_rails_1368d3db36 FOREIGN KEY (dashboard_id) REFERENCES public.dashboards(id);


--
-- Name: metric_definitions fk_rails_228c3e7bc0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metric_definitions
    ADD CONSTRAINT fk_rails_228c3e7bc0 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: dashboards fk_rails_5ad01c40ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT fk_rails_5ad01c40ce FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: anomalies fk_rails_eb5145e922; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anomalies
    ADD CONSTRAINT fk_rails_eb5145e922 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

---
--- Drop ts_insert_blocker previously created by pg_dump to avoid pg errors, create_hypertable will re-create it again.
---

DROP TRIGGER IF EXISTS ts_insert_blocker ON public.events;
