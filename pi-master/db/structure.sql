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
-- Name: pg_buffercache; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_buffercache WITH SCHEMA public;


--
-- Name: EXTENSION pg_buffercache; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_buffercache IS 'examine the shared buffer cache';


--
-- Name: pg_prewarm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_prewarm WITH SCHEMA public;


--
-- Name: EXTENSION pg_prewarm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_prewarm IS 'prewarm relation data';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track execution statistics of all SQL statements executed';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


--
-- Name: first_agg(anyelement, anyelement); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.first_agg(anyelement, anyelement) RETURNS anyelement
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
                SELECT $1;
        $_$;


--
-- Name: first(anyelement); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.first(anyelement) (
    SFUNC = public.first_agg,
    STYPE = anyelement
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_stats (
    id integer NOT NULL,
    account_id integer,
    calls_count bigint DEFAULT 0,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    identifier character varying,
    last_call_at timestamp without time zone,
    calls_count_offset integer DEFAULT 0 NOT NULL
);


--
-- Name: account_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_stats_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_stats_id_seq OWNED BY public.account_stats.id;


--
-- Name: account_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_users (
    id integer NOT NULL,
    account_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: account_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_users_id_seq OWNED BY public.account_users.id;


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id integer NOT NULL,
    name character varying(255),
    identifier character varying(255),
    pulse_insights_branding boolean DEFAULT true,
    max_submissions integer DEFAULT 500,
    max_submissions_per_month integer,
    cancelled_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    custom_data_enabled boolean DEFAULT false,
    custom_data_snippet text,
    oncomplete_callback_enabled boolean DEFAULT false,
    oncomplete_callback_code text,
    onanswer_callback_enabled boolean DEFAULT false,
    onanswer_callback_code text,
    enabled boolean DEFAULT true,
    ips_to_block text,
    frequency_cap_enabled boolean DEFAULT false,
    frequency_cap_limit integer,
    frequency_cap_duration integer,
    frequency_cap_type character varying,
    region character varying DEFAULT 'en-US'::character varying,
    ip_storage_policy integer DEFAULT 0,
    onclose_callback_enabled boolean DEFAULT false NOT NULL,
    onclose_callback_code text,
    use_new_spa_behaviour boolean DEFAULT true,
    onview_callback_enabled boolean DEFAULT false NOT NULL,
    onview_callback_code text,
    tag_automation_enabled boolean DEFAULT false NOT NULL,
    is_observed boolean DEFAULT false NOT NULL,
    custom_content_link_click_enabled boolean DEFAULT false NOT NULL,
    ai_summaries_enabled boolean DEFAULT false NOT NULL,
    domains_to_allow_for_redirection text[] DEFAULT '{}'::text[] NOT NULL,
    tag_js_version character varying DEFAULT '1.0.2'::character varying NOT NULL,
    onclick_callback_enabled boolean DEFAULT false NOT NULL,
    onclick_callback_code text,
    viewed_impressions_enabled_at timestamp with time zone,
    qrvey_enabled boolean DEFAULT true,
    survey_brief_agent_enabled boolean DEFAULT false,
    next_insights_agent_enabled boolean DEFAULT false NOT NULL
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: ai_outline_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_outline_jobs (
    id bigint NOT NULL,
    survey_id bigint NOT NULL,
    prompt_template_id bigint,
    prompt_text text,
    use_default_prompt boolean DEFAULT false NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    outline_content text,
    error_message text,
    filters jsonb DEFAULT '{}'::jsonb,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    gamma_generation_id character varying,
    gamma_url text,
    gamma_started_at timestamp(6) without time zone,
    gamma_completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_outline_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_outline_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_outline_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_outline_jobs_id_seq OWNED BY public.ai_outline_jobs.id;


--
-- Name: ai_summarization_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_summarization_jobs (
    id bigint NOT NULL,
    status integer DEFAULT 0,
    question_id bigint,
    summary text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_summarization_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_summarization_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_summarization_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_summarization_jobs_id_seq OWNED BY public.ai_summarization_jobs.id;


--
-- Name: answer_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.answer_images (
    id integer NOT NULL,
    image character varying,
    imageable_type character varying,
    imageable_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: answer_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.answer_images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: answer_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.answer_images_id_seq OWNED BY public.answer_images.id;


--
-- Name: answers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.answers (
    id integer NOT NULL,
    question_id integer,
    possible_answer_id integer,
    submission_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    text_answer text,
    analyzed boolean DEFAULT false,
    keyword_extraction jsonb,
    positive_sentiment double precision,
    negative_sentiment double precision,
    sentiment jsonb,
    entities jsonb,
    translated_answer character varying,
    question_type integer,
    CONSTRAINT answer_emptiness_check CHECK (((text_answer IS NOT NULL) OR (possible_answer_id IS NOT NULL)))
);
ALTER TABLE ONLY public.answers ALTER COLUMN submission_id SET STATISTICS 1000;
ALTER TABLE ONLY public.answers ALTER COLUMN created_at SET STATISTICS 1000;


--
-- Name: answers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.answers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.answers_id_seq OWNED BY public.answers.id;


--
-- Name: applied_survey_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applied_survey_tags (
    id integer NOT NULL,
    survey_id integer,
    survey_tag_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: applied_survey_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.applied_survey_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: applied_survey_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.applied_survey_tags_id_seq OWNED BY public.applied_survey_tags.id;


--
-- Name: applied_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applied_tags (
    id integer NOT NULL,
    tag_id integer,
    answer_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_good_automation boolean,
    tag_automation_job_id integer
);


--
-- Name: applied_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.applied_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: applied_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.applied_tags_id_seq OWNED BY public.applied_tags.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audits (
    id integer NOT NULL,
    auditable_id integer,
    auditable_type character varying,
    associated_id integer,
    associated_type character varying,
    user_id integer,
    user_type character varying,
    username character varying,
    action character varying,
    audited_changes jsonb,
    version integer DEFAULT 0,
    comment character varying,
    remote_address character varying,
    request_uuid character varying,
    created_at timestamp without time zone
);


--
-- Name: audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audits_id_seq OWNED BY public.audits.id;


--
-- Name: automation_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.automation_actions (
    id integer NOT NULL,
    automation_id integer,
    email character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    event_name character varying,
    event_properties jsonb
);


--
-- Name: automation_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.automation_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: automation_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.automation_actions_id_seq OWNED BY public.automation_actions.id;


--
-- Name: automation_conditions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.automation_conditions (
    id integer NOT NULL,
    automation_id integer,
    question_id integer,
    condition character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    url_matcher integer
);


--
-- Name: automation_conditions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.automation_conditions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: automation_conditions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.automation_conditions_id_seq OWNED BY public.automation_conditions.id;


--
-- Name: automations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.automations (
    id integer NOT NULL,
    account_id integer,
    times_triggered integer,
    name character varying,
    enabled boolean DEFAULT false,
    condition_type integer DEFAULT 0 NOT NULL,
    trigger_type integer,
    last_triggered_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    action_type integer DEFAULT 0 NOT NULL
);


--
-- Name: automations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.automations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: automations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.automations_id_seq OWNED BY public.automations.id;


--
-- Name: client_report_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_report_histories (
    id bigint NOT NULL,
    job_class character varying NOT NULL,
    data_start_time timestamp(6) without time zone NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: client_report_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_report_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_report_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_report_histories_id_seq OWNED BY public.client_report_histories.id;


--
-- Name: custom_content_link_clicks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_content_link_clicks (
    id bigint NOT NULL,
    submission_id bigint,
    custom_content_link_id bigint,
    client_key character varying,
    custom_data jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: custom_content_link_clicks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.custom_content_link_clicks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: custom_content_link_clicks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.custom_content_link_clicks_id_seq OWNED BY public.custom_content_link_clicks.id;


--
-- Name: custom_content_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_content_links (
    id bigint NOT NULL,
    question_id bigint NOT NULL,
    link_text character varying,
    link_url character varying NOT NULL,
    report_color character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    archived_at timestamp without time zone,
    link_identifier uuid NOT NULL
);


--
-- Name: custom_content_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.custom_content_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: custom_content_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.custom_content_links_id_seq OWNED BY public.custom_content_links.id;


--
-- Name: device_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.device_data (
    id integer NOT NULL,
    device_id integer,
    account_id integer,
    device_data jsonb,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: device_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.device_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.device_data_id_seq OWNED BY public.device_data.id;


--
-- Name: devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.devices (
    id integer NOT NULL,
    udid character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    client_key character varying
);


--
-- Name: devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.devices_id_seq OWNED BY public.devices.id;


--
-- Name: diagram_properties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diagram_properties (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    node_record_id bigint,
    node_type character varying,
    "position" integer[] DEFAULT '{0,0}'::integer[],
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: diagram_properties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.diagram_properties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: diagram_properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.diagram_properties_id_seq OWNED BY public.diagram_properties.id;


--
-- Name: invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitations (
    id integer NOT NULL,
    account_id integer,
    email character varying(255),
    token character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    level integer DEFAULT 0,
    expires_at timestamp without time zone
);


--
-- Name: invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invitations_id_seq OWNED BY public.invitations.id;


--
-- Name: locale_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locale_groups (
    id bigint NOT NULL,
    type character varying,
    name character varying,
    owner_record_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    report_color character varying
);


--
-- Name: locale_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.locale_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locale_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.locale_groups_id_seq OWNED BY public.locale_groups.id;


--
-- Name: locale_translation_caches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locale_translation_caches (
    id bigint NOT NULL,
    expected_language_code character varying,
    "column" character varying,
    translation character varying,
    original character varying,
    google_language_code character varying,
    record_id bigint NOT NULL,
    record_type character varying NOT NULL
);


--
-- Name: locale_translation_caches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.locale_translation_caches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locale_translation_caches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.locale_translation_caches_id_seq OWNED BY public.locale_translation_caches.id;


--
-- Name: metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metadata (
    id bigint NOT NULL,
    type character varying NOT NULL,
    name character varying NOT NULL,
    owner_record_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.metadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.metadata_id_seq OWNED BY public.metadata.id;


--
-- Name: page_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.page_events (
    id bigint NOT NULL,
    name character varying NOT NULL,
    properties jsonb,
    device_id bigint NOT NULL,
    account_id bigint NOT NULL,
    url character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: page_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.page_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: page_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.page_events_id_seq OWNED BY public.page_events.id;


--
-- Name: pdf_template_file_uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pdf_template_file_uploads (
    id bigint NOT NULL,
    type character varying NOT NULL,
    metadatum_id bigint NOT NULL,
    object_key character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    file_name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pdf_template_file_uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pdf_template_file_uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pdf_template_file_uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pdf_template_file_uploads_id_seq OWNED BY public.pdf_template_file_uploads.id;


--
-- Name: personal_data_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personal_data_settings (
    id bigint NOT NULL,
    masking_enabled boolean DEFAULT false NOT NULL,
    phone_number_masked boolean DEFAULT false NOT NULL,
    email_masked boolean DEFAULT false NOT NULL,
    account_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: personal_data_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.personal_data_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: personal_data_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.personal_data_settings_id_seq OWNED BY public.personal_data_settings.id;


--
-- Name: possible_answers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.possible_answers (
    id integer NOT NULL,
    question_id integer,
    content text,
    next_question_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    image_alt character varying,
    image_height character varying,
    image_width character varying,
    answer_image_id integer,
    image_position_cd integer,
    image_height_mobile character varying,
    image_width_mobile character varying,
    image_height_tablet character varying,
    image_width_tablet character varying,
    possible_answer_locale_group_id bigint,
    "position" integer NOT NULL,
    report_color character varying
);


--
-- Name: possible_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.possible_answers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: possible_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.possible_answers_id_seq OWNED BY public.possible_answers.id;


--
-- Name: prompt_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prompt_templates (
    id bigint NOT NULL,
    name character varying NOT NULL,
    content text NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: prompt_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.prompt_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: prompt_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.prompt_templates_id_seq OWNED BY public.prompt_templates.id;


--
-- Name: qrvey_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrvey_applications (
    id bigint NOT NULL,
    qrvey_user_id bigint,
    qrvey_application_id character varying,
    shared boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: qrvey_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.qrvey_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: qrvey_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.qrvey_applications_id_seq OWNED BY public.qrvey_applications.id;


--
-- Name: qrvey_dashboard_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrvey_dashboard_mappings (
    id bigint NOT NULL,
    qrvey_name character varying,
    pi_name character varying,
    "position" integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: qrvey_dashboard_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.qrvey_dashboard_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: qrvey_dashboard_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.qrvey_dashboard_mappings_id_seq OWNED BY public.qrvey_dashboard_mappings.id;


--
-- Name: qrvey_datasets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrvey_datasets (
    id bigint NOT NULL,
    qrvey_application_id bigint,
    qrvey_dataset_id character varying,
    qrvey_survey_id_column_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: qrvey_datasets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.qrvey_datasets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: qrvey_datasets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.qrvey_datasets_id_seq OWNED BY public.qrvey_datasets.id;


--
-- Name: qrvey_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrvey_users (
    id bigint NOT NULL,
    account_id bigint,
    qrvey_user_id character varying,
    password character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: qrvey_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.qrvey_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: qrvey_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.qrvey_users_id_seq OWNED BY public.qrvey_users.id;


--
-- Name: questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.questions (
    id integer NOT NULL,
    survey_id integer,
    content text,
    "position" integer NOT NULL,
    question_type integer DEFAULT 0,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    hint_text character varying(255),
    submit_label character varying(255) DEFAULT 'Submit'::character varying,
    height integer DEFAULT 1,
    max_length integer DEFAULT 141,
    free_text_next_question_id integer,
    keyword_extraction json,
    positive_sentiment double precision,
    negative_sentiment double precision,
    fullscreen boolean DEFAULT false,
    custom_content text,
    background_color character varying,
    opacity integer,
    autoclose_enabled boolean,
    autoclose_delay integer,
    autoredirect_enabled boolean,
    autoredirect_url character varying,
    autoredirect_delay integer,
    enable_maximum_selection boolean,
    maximum_selection integer,
    next_question_id integer,
    randomize integer,
    answers_per_row_desktop integer,
    answers_per_row_mobile integer,
    answers_alignment_desktop integer,
    button_type integer DEFAULT 1,
    desktop_width_type integer DEFAULT 0,
    optional boolean DEFAULT false,
    image_settings integer,
    mobile_width_type integer DEFAULT 0,
    answers_alignment_mobile integer,
    additional_text jsonb DEFAULT '{}'::jsonb,
    nps boolean DEFAULT false,
    error_text character varying(255),
    single_choice_default_label character varying,
    question_locale_group_id bigint,
    tag_automation_worker_enabled boolean DEFAULT false NOT NULL,
    additional_content text,
    show_additional_content boolean DEFAULT false,
    additional_content_position integer DEFAULT 0,
    empty_error_text character varying(255),
    slider_start_position integer,
    slider_submit_button_enabled boolean,
    maximum_selections_exceeded_error_text character varying,
    show_after_aao boolean DEFAULT false
);


--
-- Name: questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.questions_id_seq OWNED BY public.questions.id;


--
-- Name: report_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_jobs (
    id integer NOT NULL,
    user_id integer,
    survey_id integer,
    status integer DEFAULT 0,
    report_url character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    survey_locale_group_id bigint,
    sudo_from_id bigint,
    current_user_email character varying,
    filters jsonb DEFAULT '{}'::jsonb
);


--
-- Name: report_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.report_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.report_jobs_id_seq OWNED BY public.report_jobs.id;


--
-- Name: scheduled_report_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduled_report_emails (
    id integer NOT NULL,
    scheduled_report_id integer,
    email character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: scheduled_report_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scheduled_report_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduled_report_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scheduled_report_emails_id_seq OWNED BY public.scheduled_report_emails.id;


--
-- Name: scheduled_report_survey_locale_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduled_report_survey_locale_groups (
    id bigint NOT NULL,
    scheduled_report_id bigint NOT NULL,
    locale_group_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: scheduled_report_survey_locale_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scheduled_report_survey_locale_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduled_report_survey_locale_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scheduled_report_survey_locale_groups_id_seq OWNED BY public.scheduled_report_survey_locale_groups.id;


--
-- Name: scheduled_report_surveys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduled_report_surveys (
    id integer NOT NULL,
    scheduled_report_id integer,
    survey_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    scheduled_report_survey_locale_group_id bigint
);


--
-- Name: scheduled_report_surveys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scheduled_report_surveys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduled_report_surveys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scheduled_report_surveys_id_seq OWNED BY public.scheduled_report_surveys.id;


--
-- Name: scheduled_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduled_reports (
    id integer NOT NULL,
    account_id integer,
    name character varying,
    frequency integer,
    date_range integer,
    start_date timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    send_next_report_at timestamp without time zone,
    end_date timestamp without time zone,
    all_surveys boolean DEFAULT false,
    in_progress boolean DEFAULT false,
    last_attempt_at timestamp without time zone,
    send_no_results_email boolean DEFAULT false,
    paused boolean DEFAULT false
);


--
-- Name: scheduled_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scheduled_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduled_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scheduled_reports_id_seq OWNED BY public.scheduled_reports.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(255) NOT NULL
);

ALTER TABLE ONLY public.schema_migrations REPLICA IDENTITY FULL;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id integer NOT NULL,
    session_id character varying NOT NULL,
    data text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: signin_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signin_activities (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    sudoer_id bigint,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: signin_activities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.signin_activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: signin_activities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.signin_activities_id_seq OWNED BY public.signin_activities.id;


--
-- Name: submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.submissions (
    id integer NOT NULL,
    survey_id integer,
    device_id integer,
    url character varying(10000),
    ip_address character varying(255),
    user_agent character varying(10000),
    answers_count integer,
    custom_data json,
    created_at timestamp without time zone,
    closed_by_user boolean DEFAULT false,
    udid character varying,
    device_type character varying,
    pageview_count integer,
    visit_count integer,
    client_key character varying,
    created_date date,
    view_name character varying,
    mobile_launch_times integer,
    mobile_days_installed integer,
    pseudo_event character varying,
    mobile_type integer,
    viewed_at timestamp without time zone
);


--
-- Name: submissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.submissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: submissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.submissions_id_seq OWNED BY public.submissions.id;


--
-- Name: successful_mfa_signins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.successful_mfa_signins (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address inet,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: successful_mfa_signins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.successful_mfa_signins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: successful_mfa_signins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.successful_mfa_signins_id_seq OWNED BY public.successful_mfa_signins.id;


--
-- Name: survey_brief_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_brief_jobs (
    id bigint NOT NULL,
    status integer DEFAULT 0,
    survey_id bigint,
    input text,
    brief text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: survey_brief_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_brief_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_brief_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_brief_jobs_id_seq OWNED BY public.survey_brief_jobs.id;


--
-- Name: survey_overview_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_overview_documents (
    id bigint NOT NULL,
    survey_id bigint NOT NULL,
    status integer DEFAULT 0,
    failure_reason text,
    survey_editor_screenshot character varying,
    client_page_screenshots_desktop json,
    client_page_screenshots_mobile json,
    client_site_configuration jsonb DEFAULT '{}'::jsonb NOT NULL,
    google_presentation_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: survey_overview_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_overview_documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_overview_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_overview_documents_id_seq OWNED BY public.survey_overview_documents.id;


--
-- Name: survey_recommendations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_recommendations (
    id bigint NOT NULL,
    survey_id bigint NOT NULL,
    filters jsonb,
    content jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: survey_recommendations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_recommendations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_recommendations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_recommendations_id_seq OWNED BY public.survey_recommendations.id;


--
-- Name: survey_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_stats (
    id integer NOT NULL,
    survey_id integer,
    answers_count integer DEFAULT 0,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: survey_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_stats_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_stats_id_seq OWNED BY public.survey_stats.id;


--
-- Name: survey_submission_caches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_submission_caches (
    id bigint NOT NULL,
    survey_id bigint,
    applies_to_date date NOT NULL,
    submission_count integer DEFAULT 0 NOT NULL,
    impression_count integer DEFAULT 0 NOT NULL,
    last_impression_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    viewed_impression_count integer DEFAULT 0 NOT NULL,
    last_submission_at timestamp with time zone
);


--
-- Name: survey_submission_caches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_submission_caches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_submission_caches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_submission_caches_id_seq OWNED BY public.survey_submission_caches.id;


--
-- Name: survey_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_tags (
    id integer NOT NULL,
    account_id integer,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: survey_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_tags_id_seq OWNED BY public.survey_tags.id;


--
-- Name: surveys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.surveys (
    id integer NOT NULL,
    account_id integer,
    name character varying(255),
    status integer DEFAULT 0,
    goal integer DEFAULT 5000,
    first_call_at timestamp without time zone,
    starts_at timestamp without time zone,
    ends_at timestamp without time zone,
    live_at timestamp without time zone,
    sample_rate integer DEFAULT 100,
    survey_type integer DEFAULT 0,
    top_position character varying(255),
    bottom_position character varying(255),
    right_position character varying(255),
    left_position character varying(255),
    background_color character varying(255),
    text_color character varying(255),
    logo character varying(255),
    inline_target_selector text,
    width integer,
    custom_css text,
    invitation character varying(255),
    thank_you character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    desktop_enabled boolean DEFAULT true,
    tablet_enabled boolean DEFAULT true,
    mobile_enabled boolean DEFAULT true,
    pusher_enabled boolean DEFAULT false,
    answer_text_color character varying(255),
    stop_showing_without_answer boolean DEFAULT false,
    inline_target_position integer DEFAULT 0,
    mobile_inline_target_selector text,
    poll_enabled boolean,
    refire_time integer,
    refire_time_period character varying,
    refire_enabled boolean DEFAULT false,
    ios_enabled boolean DEFAULT false,
    android_enabled boolean DEFAULT false,
    theme_id integer,
    background character varying,
    remote_background character varying,
    display_all_questions boolean DEFAULT false,
    fullscreen_margin integer,
    invitation_button character varying,
    invitation_button_disabled boolean DEFAULT false,
    single_page boolean DEFAULT false,
    ignore_frequency_cap boolean DEFAULT false,
    randomize_question_order boolean DEFAULT false,
    sdk_inline_target_selector text,
    email_enabled boolean DEFAULT false NOT NULL,
    all_at_once_submit_label character varying,
    all_at_once_error_text character varying,
    survey_locale_group_id bigint,
    sdk_theme_id integer,
    language_code character varying,
    locale_code character varying,
    sdk_widget_height integer DEFAULT 0,
    all_at_once_empty_error_enabled boolean DEFAULT false
);


--
-- Name: surveys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.surveys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: surveys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.surveys_id_seq OWNED BY public.surveys.id;


--
-- Name: tag_automation_job_answers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_automation_job_answers (
    id bigint NOT NULL,
    tag_automation_job_id bigint NOT NULL,
    answer_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tag_automation_job_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_automation_job_answers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_automation_job_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_automation_job_answers_id_seq OWNED BY public.tag_automation_job_answers.id;


--
-- Name: tag_automation_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_automation_jobs (
    id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    question_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tag_automation_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_automation_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_automation_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_automation_jobs_id_seq OWNED BY public.tag_automation_jobs.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name character varying,
    color character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    question_id integer
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: themes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.themes (
    id integer NOT NULL,
    name character varying,
    css text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    theme_type integer DEFAULT 0 NOT NULL,
    native_content json,
    account_id bigint NOT NULL
);


--
-- Name: themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.themes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.themes_id_seq OWNED BY public.themes.id;


--
-- Name: triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.triggers (
    id integer NOT NULL,
    survey_id integer,
    url character varying(255),
    regexp character varying(255),
    excluded boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    device_data_key character varying,
    device_data_matcher character varying,
    device_data_value character varying,
    type_cd character varying,
    pageviews_count integer DEFAULT 0,
    visits_count integer DEFAULT 0,
    visitor_type integer DEFAULT 0,
    previous_answered_survey_id integer,
    previous_possible_answer_id integer,
    mobile_pageview character varying,
    mobile_regexp character varying,
    mobile_launch_times integer DEFAULT 0,
    mobile_days_installed integer DEFAULT 0,
    render_after_x_seconds integer,
    render_after_x_seconds_enabled boolean,
    render_after_x_percent_scroll integer,
    render_after_x_percent_scroll_enabled boolean,
    render_after_intent_exit_enabled boolean,
    render_after_element_clicked character varying,
    render_after_element_clicked_enabled boolean,
    render_after_element_visible character varying,
    render_after_element_visible_enabled boolean,
    text_on_page_enabled boolean,
    text_on_page_presence boolean,
    text_on_page_selector character varying,
    text_on_page_value character varying,
    geo_country character varying,
    geo_state_or_dma character varying,
    client_key_presence boolean DEFAULT false,
    url_matches character varying,
    pseudo_event character varying,
    device_data_mandatory boolean DEFAULT true NOT NULL
);


--
-- Name: triggers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.triggers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: triggers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.triggers_id_seq OWNED BY public.triggers.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    account_id integer,
    email character varying(255),
    first_name character varying(255),
    last_name character varying(255),
    encrypted_password character varying(255),
    admin boolean DEFAULT false,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    sign_in_count integer DEFAULT 0,
    last_sign_in_at timestamp without time zone,
    live_preview_url character varying(255),
    level integer DEFAULT 0,
    last_action_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_attempts integer DEFAULT 0,
    active boolean DEFAULT true,
    reset_email_token character varying,
    reset_email_sent_at timestamp without time zone,
    unlock_token character varying,
    otp_secret character varying,
    consumed_timestep integer,
    otp_required_for_login boolean DEFAULT false,
    otp_backup_codes character varying[]
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: worker_output_copies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.worker_output_copies (
    id bigint NOT NULL,
    worker_name character varying,
    file_name character varying,
    signed_url character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: worker_output_copies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.worker_output_copies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: worker_output_copies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.worker_output_copies_id_seq OWNED BY public.worker_output_copies.id;


--
-- Name: account_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_stats ALTER COLUMN id SET DEFAULT nextval('public.account_stats_id_seq'::regclass);


--
-- Name: account_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_users ALTER COLUMN id SET DEFAULT nextval('public.account_users_id_seq'::regclass);


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: ai_outline_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_outline_jobs ALTER COLUMN id SET DEFAULT nextval('public.ai_outline_jobs_id_seq'::regclass);


--
-- Name: ai_summarization_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_summarization_jobs ALTER COLUMN id SET DEFAULT nextval('public.ai_summarization_jobs_id_seq'::regclass);


--
-- Name: answer_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer_images ALTER COLUMN id SET DEFAULT nextval('public.answer_images_id_seq'::regclass);


--
-- Name: answers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answers ALTER COLUMN id SET DEFAULT nextval('public.answers_id_seq'::regclass);


--
-- Name: applied_survey_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_survey_tags ALTER COLUMN id SET DEFAULT nextval('public.applied_survey_tags_id_seq'::regclass);


--
-- Name: applied_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_tags ALTER COLUMN id SET DEFAULT nextval('public.applied_tags_id_seq'::regclass);


--
-- Name: audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audits ALTER COLUMN id SET DEFAULT nextval('public.audits_id_seq'::regclass);


--
-- Name: automation_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_actions ALTER COLUMN id SET DEFAULT nextval('public.automation_actions_id_seq'::regclass);


--
-- Name: automation_conditions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_conditions ALTER COLUMN id SET DEFAULT nextval('public.automation_conditions_id_seq'::regclass);


--
-- Name: automations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automations ALTER COLUMN id SET DEFAULT nextval('public.automations_id_seq'::regclass);


--
-- Name: client_report_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_report_histories ALTER COLUMN id SET DEFAULT nextval('public.client_report_histories_id_seq'::regclass);


--
-- Name: custom_content_link_clicks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_content_link_clicks ALTER COLUMN id SET DEFAULT nextval('public.custom_content_link_clicks_id_seq'::regclass);


--
-- Name: custom_content_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_content_links ALTER COLUMN id SET DEFAULT nextval('public.custom_content_links_id_seq'::regclass);


--
-- Name: device_data id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_data ALTER COLUMN id SET DEFAULT nextval('public.device_data_id_seq'::regclass);


--
-- Name: devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devices ALTER COLUMN id SET DEFAULT nextval('public.devices_id_seq'::regclass);


--
-- Name: diagram_properties id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diagram_properties ALTER COLUMN id SET DEFAULT nextval('public.diagram_properties_id_seq'::regclass);


--
-- Name: invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations ALTER COLUMN id SET DEFAULT nextval('public.invitations_id_seq'::regclass);


--
-- Name: locale_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locale_groups ALTER COLUMN id SET DEFAULT nextval('public.locale_groups_id_seq'::regclass);


--
-- Name: locale_translation_caches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locale_translation_caches ALTER COLUMN id SET DEFAULT nextval('public.locale_translation_caches_id_seq'::regclass);


--
-- Name: metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metadata ALTER COLUMN id SET DEFAULT nextval('public.metadata_id_seq'::regclass);


--
-- Name: page_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_events ALTER COLUMN id SET DEFAULT nextval('public.page_events_id_seq'::regclass);


--
-- Name: pdf_template_file_uploads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pdf_template_file_uploads ALTER COLUMN id SET DEFAULT nextval('public.pdf_template_file_uploads_id_seq'::regclass);


--
-- Name: personal_data_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_data_settings ALTER COLUMN id SET DEFAULT nextval('public.personal_data_settings_id_seq'::regclass);


--
-- Name: possible_answers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.possible_answers ALTER COLUMN id SET DEFAULT nextval('public.possible_answers_id_seq'::regclass);


--
-- Name: prompt_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prompt_templates ALTER COLUMN id SET DEFAULT nextval('public.prompt_templates_id_seq'::regclass);


--
-- Name: qrvey_applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrvey_applications ALTER COLUMN id SET DEFAULT nextval('public.qrvey_applications_id_seq'::regclass);


--
-- Name: qrvey_dashboard_mappings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrvey_dashboard_mappings ALTER COLUMN id SET DEFAULT nextval('public.qrvey_dashboard_mappings_id_seq'::regclass);


--
-- Name: qrvey_datasets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrvey_datasets ALTER COLUMN id SET DEFAULT nextval('public.qrvey_datasets_id_seq'::regclass);


--
-- Name: qrvey_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrvey_users ALTER COLUMN id SET DEFAULT nextval('public.qrvey_users_id_seq'::regclass);


--
-- Name: questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions ALTER COLUMN id SET DEFAULT nextval('public.questions_id_seq'::regclass);


--
-- Name: report_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_jobs ALTER COLUMN id SET DEFAULT nextval('public.report_jobs_id_seq'::regclass);


--
-- Name: scheduled_report_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_report_emails ALTER COLUMN id SET DEFAULT nextval('public.scheduled_report_emails_id_seq'::regclass);


--
-- Name: scheduled_report_survey_locale_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_report_survey_locale_groups ALTER COLUMN id SET DEFAULT nextval('public.scheduled_report_survey_locale_groups_id_seq'::regclass);


--
-- Name: scheduled_report_surveys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_report_surveys ALTER COLUMN id SET DEFAULT nextval('public.scheduled_report_surveys_id_seq'::regclass);


--
-- Name: scheduled_reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_reports ALTER COLUMN id SET DEFAULT nextval('public.scheduled_reports_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: signin_activities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signin_activities ALTER COLUMN id SET DEFAULT nextval('public.signin_activities_id_seq'::regclass);


--
-- Name: submissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions ALTER COLUMN id SET DEFAULT nextval('public.submissions_id_seq'::regclass);


--
-- Name: successful_mfa_signins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.successful_mfa_signins ALTER COLUMN id SET DEFAULT nextval('public.successful_mfa_signins_id_seq'::regclass);


--
-- Name: survey_brief_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_brief_jobs ALTER COLUMN id SET DEFAULT nextval('public.survey_brief_jobs_id_seq'::regclass);


--
-- Name: survey_overview_documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_overview_documents ALTER COLUMN id SET DEFAULT nextval('public.survey_overview_documents_id_seq'::regclass);


--
-- Name: survey_recommendations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_recommendations ALTER COLUMN id SET DEFAULT nextval('public.survey_recommendations_id_seq'::regclass);


--
-- Name: survey_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_stats ALTER COLUMN id SET DEFAULT nextval('public.survey_stats_id_seq'::regclass);


--
-- Name: survey_submission_caches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_submission_caches ALTER COLUMN id SET DEFAULT nextval('public.survey_submission_caches_id_seq'::regclass);


--
-- Name: survey_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_tags ALTER COLUMN id SET DEFAULT nextval('public.survey_tags_id_seq'::regclass);


--
-- Name: surveys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys ALTER COLUMN id SET DEFAULT nextval('public.surveys_id_seq'::regclass);


--
-- Name: tag_automation_job_answers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_automation_job_answers ALTER COLUMN id SET DEFAULT nextval('public.tag_automation_job_answers_id_seq'::regclass);


--
-- Name: tag_automation_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_automation_jobs ALTER COLUMN id SET DEFAULT nextval('public.tag_automation_jobs_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.themes ALTER COLUMN id SET DEFAULT nextval('public.themes_id_seq'::regclass);


--
-- Name: triggers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triggers ALTER COLUMN id SET DEFAULT nextval('public.triggers_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: worker_output_copies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.worker_output_copies ALTER COLUMN id SET DEFAULT nextval('public.worker_output_copies_id_seq'::regclass);


--
-- Name: account_stats account_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_stats
    ADD CONSTRAINT account_stats_pkey PRIMARY KEY (id);


--
-- Name: account_users account_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_users
    ADD CONSTRAINT account_users_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: ai_outline_jobs ai_outline_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_outline_jobs
    ADD CONSTRAINT ai_outline_jobs_pkey PRIMARY KEY (id);


--
-- Name: ai_summarization_jobs ai_summarization_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_summarization_jobs
    ADD CONSTRAINT ai_summarization_jobs_pkey PRIMARY KEY (id);


--
-- Name: answer_images answer_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer_images
    ADD CONSTRAINT answer_images_pkey PRIMARY KEY (id);


--
-- Name: answers answers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answers
    ADD CONSTRAINT answers_pkey PRIMARY KEY (id);


--
-- Name: applied_survey_tags applied_survey_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_survey_tags
    ADD CONSTRAINT applied_survey_tags_pkey PRIMARY KEY (id);


--
-- Name: applied_tags applied_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applied_tags
    ADD CONSTRAINT applied_tags_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audits audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audits
    ADD CONSTRAINT audits_pkey PRIMARY KEY (id);


--
-- Name: automation_actions automation_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_actions
    ADD CONSTRAINT automation_actions_pkey PRIMARY KEY (id);


--
-- Name: automation_conditions automation_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automation_conditions
    ADD CONSTRAINT automation_conditions_pkey PRIMARY KEY (id);


--
-- Name: automations automations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.automations
    ADD CONSTRAINT automations_pkey PRIMARY KEY (id);


--
-- Name: client_report_histories client_report_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_report_histories
    ADD CONSTRAINT client_report_histories_pkey PRIMARY KEY (id);


--
-- Name: custom_content_link_clicks custom_content_link_clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_content_link_clicks
    ADD CONSTRAINT custom_content_link_clicks_pkey PRIMARY KEY (id);


--
-- Name: custom_content_links custom_content_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_content_links
    ADD CONSTRAINT custom_content_links_pkey PRIMARY KEY (id);


--
-- Name: device_data device_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_data
    ADD CONSTRAINT device_data_pkey PRIMARY KEY (id);


--
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- Name: diagram_properties diagram_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diagram_properties
    ADD CONSTRAINT diagram_properties_pkey PRIMARY KEY (id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: locale_groups locale_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locale_groups
    ADD CONSTRAINT locale_groups_pkey PRIMARY KEY (id);


--
-- Name: locale_translation_caches locale_translation_caches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locale_translation_caches
    ADD CONSTRAINT locale_translation_caches_pkey PRIMARY KEY (id);


--
-- Name: metadata metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metadata
    ADD CONSTRAINT metadata_pkey PRIMARY KEY (id);


--
-- Name: page_events page_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_events
    ADD CONSTRAINT page_events_pkey PRIMARY KEY (id);


--
-- Name: pdf_template_file_uploads pdf_template_file_uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pdf_template_file_uploads
    ADD CONSTRAINT pdf_template_file_uploads_pkey PRIMARY KEY (id);


--
-- Name: personal_data_settings personal_data_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_data_settings
    ADD CONSTRAINT personal_data_settings_pkey PRIMARY KEY (id);


--
-- Name: possible_answers possible_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.possible_answers
    ADD CONSTRAINT possible_answers_pkey PRIMARY KEY (id);


--
-- Name: prompt_templates prompt_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prompt_templates
    ADD CONSTRAINT prompt_templates_pkey PRIMARY KEY (id);


--
-- Name: qrvey_applications qrvey_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrvey_applications
    ADD CONSTRAINT qrvey_applications_pkey PRIMARY KEY (id);


--
-- Name: qrvey_dashboard_mappings qrvey_dashboard_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrvey_dashboard_mappings
    ADD CONSTRAINT qrvey_dashboard_mappings_pkey PRIMARY KEY (id);


--
-- Name: qrvey_datasets qrvey_datasets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrvey_datasets
    ADD CONSTRAINT qrvey_datasets_pkey PRIMARY KEY (id);


--
-- Name: qrvey_users qrvey_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrvey_users
    ADD CONSTRAINT qrvey_users_pkey PRIMARY KEY (id);


--
-- Name: questions questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);


--
-- Name: report_jobs report_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_jobs
    ADD CONSTRAINT report_jobs_pkey PRIMARY KEY (id);


--
-- Name: scheduled_report_emails scheduled_report_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_report_emails
    ADD CONSTRAINT scheduled_report_emails_pkey PRIMARY KEY (id);


--
-- Name: scheduled_report_survey_locale_groups scheduled_report_survey_locale_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_report_survey_locale_groups
    ADD CONSTRAINT scheduled_report_survey_locale_groups_pkey PRIMARY KEY (id);


--
-- Name: scheduled_report_surveys scheduled_report_surveys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_report_surveys
    ADD CONSTRAINT scheduled_report_surveys_pkey PRIMARY KEY (id);


--
-- Name: scheduled_reports scheduled_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_reports
    ADD CONSTRAINT scheduled_reports_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: signin_activities signin_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signin_activities
    ADD CONSTRAINT signin_activities_pkey PRIMARY KEY (id);


--
-- Name: submissions submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_pkey PRIMARY KEY (id);


--
-- Name: successful_mfa_signins successful_mfa_signins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.successful_mfa_signins
    ADD CONSTRAINT successful_mfa_signins_pkey PRIMARY KEY (id);


--
-- Name: survey_brief_jobs survey_brief_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_brief_jobs
    ADD CONSTRAINT survey_brief_jobs_pkey PRIMARY KEY (id);


--
-- Name: survey_overview_documents survey_overview_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_overview_documents
    ADD CONSTRAINT survey_overview_documents_pkey PRIMARY KEY (id);


--
-- Name: survey_recommendations survey_recommendations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_recommendations
    ADD CONSTRAINT survey_recommendations_pkey PRIMARY KEY (id);


--
-- Name: survey_stats survey_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_stats
    ADD CONSTRAINT survey_stats_pkey PRIMARY KEY (id);


--
-- Name: survey_submission_caches survey_submission_caches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_submission_caches
    ADD CONSTRAINT survey_submission_caches_pkey PRIMARY KEY (id);


--
-- Name: survey_tags survey_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_tags
    ADD CONSTRAINT survey_tags_pkey PRIMARY KEY (id);


--
-- Name: surveys surveys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys
    ADD CONSTRAINT surveys_pkey PRIMARY KEY (id);


--
-- Name: tag_automation_job_answers tag_automation_job_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_automation_job_answers
    ADD CONSTRAINT tag_automation_job_answers_pkey PRIMARY KEY (id);


--
-- Name: tag_automation_jobs tag_automation_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_automation_jobs
    ADD CONSTRAINT tag_automation_jobs_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: themes themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_pkey PRIMARY KEY (id);


--
-- Name: triggers triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.triggers
    ADD CONSTRAINT triggers_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: worker_output_copies worker_output_copies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.worker_output_copies
    ADD CONSTRAINT worker_output_copies_pkey PRIMARY KEY (id);


--
-- Name: account_stats_identifier_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX account_stats_identifier_idx ON public.account_stats USING btree (identifier);


--
-- Name: associated_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX associated_index ON public.audits USING btree (associated_type, associated_id);


--
-- Name: auditable_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auditable_index ON public.audits USING btree (auditable_type, auditable_id, version);


--
-- Name: index_account_stats_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_stats_on_account_id ON public.account_stats USING btree (account_id);


--
-- Name: index_account_users_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_users_on_account_id ON public.account_users USING btree (account_id);


--
-- Name: index_account_users_on_account_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_account_users_on_account_id_and_user_id ON public.account_users USING btree (account_id, user_id);


--
-- Name: index_account_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_users_on_user_id ON public.account_users USING btree (user_id);


--
-- Name: index_accounts_on_cancelled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_cancelled_at ON public.accounts USING btree (cancelled_at);


--
-- Name: index_accounts_on_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_identifier ON public.accounts USING btree (identifier);


--
-- Name: index_accounts_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_name ON public.accounts USING btree (name);


--
-- Name: index_ai_outline_jobs_on_gamma_generation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_outline_jobs_on_gamma_generation_id ON public.ai_outline_jobs USING btree (gamma_generation_id);


--
-- Name: index_ai_outline_jobs_on_prompt_template_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_outline_jobs_on_prompt_template_id ON public.ai_outline_jobs USING btree (prompt_template_id);


--
-- Name: index_ai_outline_jobs_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_outline_jobs_on_status ON public.ai_outline_jobs USING btree (status);


--
-- Name: index_ai_outline_jobs_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_outline_jobs_on_survey_id ON public.ai_outline_jobs USING btree (survey_id);


--
-- Name: index_ai_outline_jobs_on_survey_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_outline_jobs_on_survey_id_and_created_at ON public.ai_outline_jobs USING btree (survey_id, created_at);


--
-- Name: index_ai_summarization_jobs_on_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_summarization_jobs_on_question_id ON public.ai_summarization_jobs USING btree (question_id);


--
-- Name: index_ai_summarization_jobs_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_summarization_jobs_on_status ON public.ai_summarization_jobs USING btree (status) WHERE (status = ANY (ARRAY[0, 1]));


--
-- Name: index_answer_images_on_imageable_type_and_imageable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_answer_images_on_imageable_type_and_imageable_id ON public.answer_images USING btree (imageable_type, imageable_id);


--
-- Name: index_answers_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_answers_on_created_at ON public.answers USING btree (created_at);


--
-- Name: index_answers_on_possible_answer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_answers_on_possible_answer_id ON public.answers USING btree (possible_answer_id);


--
-- Name: index_answers_on_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_answers_on_question_id ON public.answers USING btree (question_id);


--
-- Name: index_answers_on_sub_id_and_q_id_and_pa_id_and_null_text_answer; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_answers_on_sub_id_and_q_id_and_pa_id_and_null_text_answer ON public.answers USING btree (submission_id, question_id, possible_answer_id) WHERE (text_answer IS NULL);


--
-- Name: index_answers_on_sub_id_and_q_id_except_for_multi_choice; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_answers_on_sub_id_and_q_id_except_for_multi_choice ON public.answers USING btree (submission_id, question_id) WHERE (question_type <> 3);


--
-- Name: index_answers_on_submission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_answers_on_submission_id ON public.answers USING btree (submission_id);


--
-- Name: index_answers_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_answers_on_updated_at ON public.answers USING btree (updated_at);


--
-- Name: index_applied_survey_tags_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_survey_tags_on_survey_id ON public.applied_survey_tags USING btree (survey_id);


--
-- Name: index_applied_survey_tags_on_survey_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_survey_tags_on_survey_tag_id ON public.applied_survey_tags USING btree (survey_tag_id);


--
-- Name: index_applied_tags_on_answer_id_with_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applied_tags_on_answer_id_with_tag_id ON public.applied_tags USING btree (answer_id, tag_id);


--
-- Name: index_audits_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audits_on_created_at ON public.audits USING btree (created_at);


--
-- Name: index_audits_on_request_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audits_on_request_uuid ON public.audits USING btree (request_uuid);


--
-- Name: index_automation_actions_on_automation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_automation_actions_on_automation_id ON public.automation_actions USING btree (automation_id);


--
-- Name: index_automation_conditions_on_automation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_automation_conditions_on_automation_id ON public.automation_conditions USING btree (automation_id);


--
-- Name: index_automation_conditions_on_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_automation_conditions_on_question_id ON public.automation_conditions USING btree (question_id);


--
-- Name: index_automations_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_automations_on_account_id ON public.automations USING btree (account_id);


--
-- Name: index_client_report_histories_on_job_class; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_report_histories_on_job_class ON public.client_report_histories USING btree (job_class);


--
-- Name: index_client_report_histories_on_job_class_and_data_start_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_report_histories_on_job_class_and_data_start_time ON public.client_report_histories USING btree (job_class, data_start_time);


--
-- Name: index_custom_content_link_clicks_on_custom_content_link_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_custom_content_link_clicks_on_custom_content_link_id ON public.custom_content_link_clicks USING btree (custom_content_link_id);


--
-- Name: index_custom_content_link_clicks_on_submission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_custom_content_link_clicks_on_submission_id ON public.custom_content_link_clicks USING btree (submission_id);


--
-- Name: index_custom_content_links_on_question_id_and_link_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_custom_content_links_on_question_id_and_link_identifier ON public.custom_content_links USING btree (question_id, link_identifier);


--
-- Name: index_device_data_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_device_data_on_account_id ON public.device_data USING btree (account_id);


--
-- Name: index_device_data_on_account_id_and_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_device_data_on_account_id_and_device_id ON public.device_data USING btree (account_id, device_id);


--
-- Name: index_device_data_on_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_device_data_on_device_id ON public.device_data USING btree (device_id);


--
-- Name: index_devices_on_client_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_devices_on_client_key ON public.devices USING btree (client_key);


--
-- Name: index_devices_on_udid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_devices_on_udid ON public.devices USING btree (udid);


--
-- Name: index_diagram_props_on_user_id_and_node_record_id_and_node_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_diagram_props_on_user_id_and_node_record_id_and_node_type ON public.diagram_properties USING btree (user_id, node_record_id, node_type);


--
-- Name: index_invitations_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_account_id ON public.invitations USING btree (account_id);


--
-- Name: index_invitations_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_email ON public.invitations USING btree (email);


--
-- Name: index_invitations_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_token ON public.invitations USING btree (token);


--
-- Name: index_locale_groups_on_owner_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_locale_groups_on_owner_record_id ON public.locale_groups USING btree (owner_record_id);


--
-- Name: index_locale_groups_on_type_and_owner_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_locale_groups_on_type_and_owner_record_id ON public.locale_groups USING btree (type, owner_record_id);


--
-- Name: index_locale_groups_on_type_and_owner_record_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_locale_groups_on_type_and_owner_record_id_and_name ON public.locale_groups USING btree (type, owner_record_id, name);


--
-- Name: index_ltc_on_record_id_and_record_type_and_column; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ltc_on_record_id_and_record_type_and_column ON public.locale_translation_caches USING btree (record_id, record_type, "column");


--
-- Name: index_metadata_on_type_and_owner_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_metadata_on_type_and_owner_record_id ON public.metadata USING btree (type, owner_record_id);


--
-- Name: index_page_events_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_page_events_on_account_id ON public.page_events USING btree (account_id);


--
-- Name: index_page_events_on_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_page_events_on_device_id ON public.page_events USING btree (device_id);


--
-- Name: index_pdf_template_file_uploads_on_metadatum_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pdf_template_file_uploads_on_metadatum_id ON public.pdf_template_file_uploads USING btree (metadatum_id);


--
-- Name: index_pdf_template_file_uploads_on_object_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pdf_template_file_uploads_on_object_key ON public.pdf_template_file_uploads USING btree (object_key);


--
-- Name: index_personal_data_settings_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_personal_data_settings_on_account_id ON public.personal_data_settings USING btree (account_id);


--
-- Name: index_possible_answers_on_content; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_possible_answers_on_content ON public.possible_answers USING btree (content);


--
-- Name: index_possible_answers_on_next_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_possible_answers_on_next_question_id ON public.possible_answers USING btree (next_question_id);


--
-- Name: index_possible_answers_on_possible_answer_locale_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_possible_answers_on_possible_answer_locale_group_id ON public.possible_answers USING btree (possible_answer_locale_group_id);


--
-- Name: index_possible_answers_on_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_possible_answers_on_question_id ON public.possible_answers USING btree (question_id);


--
-- Name: index_prompt_templates_on_is_default; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_prompt_templates_on_is_default ON public.prompt_templates USING btree (is_default);


--
-- Name: index_prompt_templates_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_prompt_templates_on_name ON public.prompt_templates USING btree (name);


--
-- Name: index_q_datasets_on_q_dataset_id_and_q_survey_id_column_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_q_datasets_on_q_dataset_id_and_q_survey_id_column_id ON public.qrvey_datasets USING btree (qrvey_dataset_id, qrvey_survey_id_column_id);


--
-- Name: index_qrvey_applications_on_qrvey_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_qrvey_applications_on_qrvey_user_id ON public.qrvey_applications USING btree (qrvey_user_id);


--
-- Name: index_qrvey_dashboard_mappings_on_pi_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_qrvey_dashboard_mappings_on_pi_name ON public.qrvey_dashboard_mappings USING btree (pi_name);


--
-- Name: index_qrvey_dashboard_mappings_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_qrvey_dashboard_mappings_on_position ON public.qrvey_dashboard_mappings USING btree ("position");


--
-- Name: index_qrvey_dashboard_mappings_on_qrvey_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_qrvey_dashboard_mappings_on_qrvey_name ON public.qrvey_dashboard_mappings USING btree (qrvey_name);


--
-- Name: index_qrvey_datasets_on_qrvey_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_qrvey_datasets_on_qrvey_application_id ON public.qrvey_datasets USING btree (qrvey_application_id);


--
-- Name: index_qrvey_users_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_qrvey_users_on_account_id ON public.qrvey_users USING btree (account_id);


--
-- Name: index_questions_on_content; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_questions_on_content ON public.questions USING btree (content);


--
-- Name: index_questions_on_question_locale_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_questions_on_question_locale_group_id ON public.questions USING btree (question_locale_group_id);


--
-- Name: index_questions_on_question_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_questions_on_question_type ON public.questions USING btree (question_type);


--
-- Name: index_questions_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_questions_on_survey_id ON public.questions USING btree (survey_id);


--
-- Name: index_report_jobs_on_survey_locale_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_jobs_on_survey_locale_group_id ON public.report_jobs USING btree (survey_locale_group_id);


--
-- Name: index_scheduled_report_emails_on_email_and_scheduled_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scheduled_report_emails_on_email_and_scheduled_report_id ON public.scheduled_report_emails USING btree (email, scheduled_report_id);


--
-- Name: index_scheduled_report_emails_on_scheduled_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scheduled_report_emails_on_scheduled_report_id ON public.scheduled_report_emails USING btree (scheduled_report_id);


--
-- Name: index_scheduled_report_survey_locale_group_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scheduled_report_survey_locale_group_uniq ON public.scheduled_report_survey_locale_groups USING btree (scheduled_report_id, locale_group_id);


--
-- Name: index_scheduled_report_survey_on_locale_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scheduled_report_survey_on_locale_group_id ON public.scheduled_report_surveys USING btree (scheduled_report_survey_locale_group_id);


--
-- Name: index_scheduled_report_surveys_on_scheduled_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scheduled_report_surveys_on_scheduled_report_id ON public.scheduled_report_surveys USING btree (scheduled_report_id);


--
-- Name: index_sessions_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sessions_on_session_id ON public.sessions USING btree (session_id);


--
-- Name: index_sessions_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_updated_at ON public.sessions USING btree (updated_at);


--
-- Name: index_signin_activities_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_signin_activities_on_account_id ON public.signin_activities USING btree (account_id);


--
-- Name: index_signin_activities_on_sudoer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_signin_activities_on_sudoer_id ON public.signin_activities USING btree (sudoer_id);


--
-- Name: index_signin_activities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_signin_activities_on_user_id ON public.signin_activities USING btree (user_id);


--
-- Name: index_submissions_on_client_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_client_key ON public.submissions USING btree (client_key);


--
-- Name: index_submissions_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_created_at ON public.submissions USING btree (created_at);


--
-- Name: index_submissions_on_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_device_id ON public.submissions USING btree (device_id);


--
-- Name: index_submissions_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_survey_id ON public.submissions USING btree (survey_id);


--
-- Name: index_submissions_on_survey_id_with_answers; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_survey_id_with_answers ON public.submissions USING btree (survey_id, id) WHERE (answers_count > 0);


--
-- Name: index_submissions_on_survey_id_with_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_survey_id_with_created_at ON public.submissions USING btree (survey_id, created_at) WHERE (answers_count > 0);


--
-- Name: index_submissions_on_survey_id_with_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_survey_id_with_device_id ON public.submissions USING btree (survey_id, device_id);


--
-- Name: index_submissions_on_survey_id_with_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_survey_id_with_id ON public.submissions USING btree (survey_id, id);


--
-- Name: index_submissions_on_udid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_udid ON public.submissions USING btree (udid);


--
-- Name: index_submissions_on_viewed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_submissions_on_viewed_at ON public.submissions USING btree (viewed_at);


--
-- Name: index_successful_mfa_signins_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_successful_mfa_signins_on_user_id ON public.successful_mfa_signins USING btree (user_id);


--
-- Name: index_survey_brief_jobs_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_brief_jobs_on_survey_id ON public.survey_brief_jobs USING btree (survey_id);


--
-- Name: index_survey_overview_documents_on_client_site_configuration; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_overview_documents_on_client_site_configuration ON public.survey_overview_documents USING btree (client_site_configuration);


--
-- Name: index_survey_overview_documents_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_overview_documents_on_status ON public.survey_overview_documents USING btree (status);


--
-- Name: index_survey_overview_documents_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_overview_documents_on_survey_id ON public.survey_overview_documents USING btree (survey_id);


--
-- Name: index_survey_recommendations_on_survey_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_recommendations_on_survey_id_and_created_at ON public.survey_recommendations USING btree (survey_id, created_at);


--
-- Name: index_survey_stats_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_stats_on_survey_id ON public.survey_stats USING btree (survey_id);


--
-- Name: index_survey_submission_caches_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_submission_caches_on_survey_id ON public.survey_submission_caches USING btree (survey_id);


--
-- Name: index_survey_submission_caches_on_survey_id_and_applies_to_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_survey_submission_caches_on_survey_id_and_applies_to_date ON public.survey_submission_caches USING btree (survey_id, applies_to_date);


--
-- Name: index_survey_tags_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_tags_on_account_id ON public.survey_tags USING btree (account_id);


--
-- Name: index_surveys_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_account_id ON public.surveys USING btree (account_id);


--
-- Name: index_surveys_on_ends_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_ends_at ON public.surveys USING btree (ends_at);


--
-- Name: index_surveys_on_first_call_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_first_call_at ON public.surveys USING btree (first_call_at);


--
-- Name: index_surveys_on_goal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_goal ON public.surveys USING btree (goal);


--
-- Name: index_surveys_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_name ON public.surveys USING btree (name);


--
-- Name: index_surveys_on_sample_rate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_sample_rate ON public.surveys USING btree (sample_rate);


--
-- Name: index_surveys_on_sdk_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_sdk_theme_id ON public.surveys USING btree (sdk_theme_id);


--
-- Name: index_surveys_on_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_starts_at ON public.surveys USING btree (starts_at);


--
-- Name: index_surveys_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_status ON public.surveys USING btree (status);


--
-- Name: index_surveys_on_survey_locale_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_survey_locale_group_id ON public.surveys USING btree (survey_locale_group_id);


--
-- Name: index_surveys_on_survey_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_survey_type ON public.surveys USING btree (survey_type);


--
-- Name: index_surveys_on_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_theme_id ON public.surveys USING btree (theme_id);


--
-- Name: index_tag_automation_job_answers_on_answer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_automation_job_answers_on_answer_id ON public.tag_automation_job_answers USING btree (answer_id);


--
-- Name: index_tag_automation_job_answers_on_tag_automation_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_automation_job_answers_on_tag_automation_job_id ON public.tag_automation_job_answers USING btree (tag_automation_job_id);


--
-- Name: index_tag_automation_jobs_on_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_automation_jobs_on_question_id ON public.tag_automation_jobs USING btree (question_id);


--
-- Name: index_tags_on_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_question_id ON public.tags USING btree (question_id);


--
-- Name: index_tags_on_question_id_and_name_case_insensitive; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_question_id_and_name_case_insensitive ON public.tags USING btree (question_id, lower((name)::text));


--
-- Name: index_themes_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_themes_on_account_id ON public.themes USING btree (account_id);


--
-- Name: index_triggers_on_excluded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_triggers_on_excluded ON public.triggers USING btree (excluded);


--
-- Name: index_triggers_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_triggers_on_survey_id ON public.triggers USING btree (survey_id);


--
-- Name: index_users_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_account_id ON public.users USING btree (account_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_first_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_first_name ON public.users USING btree (first_name);


--
-- Name: index_users_on_last_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_last_name ON public.users USING btree (last_name);


--
-- Name: index_users_on_unlock_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_unlock_token ON public.users USING btree (unlock_token);


--
-- Name: page_events_account_id_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX page_events_account_id_name_idx ON public.page_events USING btree (account_id, name);


--
-- Name: submissions_survey_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX submissions_survey_id_created_at_idx ON public.submissions USING btree (survey_id, created_at);


--
-- Name: submissions_survey_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX submissions_survey_id_idx ON public.submissions USING btree (survey_id) WHERE (viewed_at IS NOT NULL);


--
-- Name: user_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_index ON public.audits USING btree (user_id, user_type);


--
-- Name: survey_overview_documents fk_rails_15d03583ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_overview_documents
    ADD CONSTRAINT fk_rails_15d03583ee FOREIGN KEY (survey_id) REFERENCES public.surveys(id);


--
-- Name: successful_mfa_signins fk_rails_8e96cb925b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.successful_mfa_signins
    ADD CONSTRAINT fk_rails_8e96cb925b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: ai_outline_jobs fk_rails_9e077c8efb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_outline_jobs
    ADD CONSTRAINT fk_rails_9e077c8efb FOREIGN KEY (prompt_template_id) REFERENCES public.prompt_templates(id);


--
-- Name: ai_outline_jobs fk_rails_c045b5fe8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_outline_jobs
    ADD CONSTRAINT fk_rails_c045b5fe8f FOREIGN KEY (survey_id) REFERENCES public.surveys(id);


--
-- Name: pi_production_publication; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION pi_production_publication FOR ALL TABLES WITH (publish = 'insert, update, delete, truncate');


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20250815191449'),
('20250819183210');


