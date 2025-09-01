--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.0
-- Dumped by pg_dump version 9.5.0

-- Started on 2025-08-30 11:39:05

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 358 (class 3079 OID 12355)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 3302 (class 0 OID 0)
-- Dependencies: 358
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 372 (class 1255 OID 20144)
-- Name: assign_daily_folio(); Type: FUNCTION; Schema: public; Owner: floreant
--

CREATE FUNCTION assign_daily_folio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_branch   TEXT;
    v_date     DATE;
    v_next     INTEGER;
BEGIN
    IF NEW.terminal_id IS NULL THEN
        RAISE EXCEPTION 'No se puede crear ticket sin terminal_id';
    END IF;
    IF NEW.create_date IS NULL THEN
        NEW.create_date := NOW();
    END IF;
    v_date := (NEW.create_date AT TIME ZONE 'America/Mexico_City')::DATE;
    SELECT COALESCE(NULLIF(UPPER(BTRIM(t.location)), ''), 'DEFAULT') INTO v_branch
    FROM public.terminal t
    WHERE t.id = NEW.terminal_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Terminal % no existe en la base de datos', NEW.terminal_id;
    END IF;
    IF NEW.daily_folio IS NOT NULL AND NEW.folio_date IS NOT NULL AND NEW.branch_key IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.ticket
            WHERE folio_date = NEW.folio_date
            AND branch_key = NEW.branch_key
            AND daily_folio = NEW.daily_folio
            AND id != NEW.id
        ) THEN
            RAISE EXCEPTION 'Folio % ya existe para % en %', NEW.daily_folio, NEW.branch_key, NEW.folio_date;
        END IF;
        RETURN NEW;
    END IF;
    WITH up AS (
        INSERT INTO public.daily_folio_counter (folio_date, branch_key, last_value)
        VALUES (v_date, v_branch, 1)
        ON CONFLICT (folio_date, branch_key)
        DO UPDATE SET last_value = public.daily_folio_counter.last_value + 1
        RETURNING last_value
    )
    SELECT last_value INTO v_next FROM up;
    NEW.folio_date := v_date;
    NEW.branch_key := v_branch;
    NEW.daily_folio := v_next;
    RETURN NEW;
END
$$;


ALTER FUNCTION public.assign_daily_folio() OWNER TO floreant;

--
-- TOC entry 373 (class 1255 OID 20159)
-- Name: get_daily_stats(date); Type: FUNCTION; Schema: public; Owner: floreant
--

CREATE FUNCTION get_daily_stats(p_date date DEFAULT ('now'::text)::date) RETURNS TABLE(sucursal text, total_ordenes integer, total_ventas numeric, primer_orden time without time zone, ultima_orden time without time zone, promedio_por_hora numeric)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        tfc.branch_key,
        COUNT(*)::INTEGER AS total_ordenes,
        SUM(tfc.total_price)::NUMERIC AS total_ventas,
        MIN(tfc.create_date::TIME) AS primer_orden,
        MAX(tfc.create_date::TIME) AS ultima_orden,
        ROUND(
            (COUNT(*)::NUMERIC /
            GREATEST(EXTRACT(EPOCH FROM (MAX(tfc.create_date) - MIN(tfc.create_date))) / 3600.0, 1))::NUMERIC,
            2
        ) AS promedio_por_hora
    FROM public.ticket_folio_complete tfc
    WHERE tfc.folio_date = p_date
    AND tfc.status_simple != 'CANCELADO'
    GROUP BY tfc.branch_key
    ORDER BY tfc.branch_key;
$$;


ALTER FUNCTION public.get_daily_stats(p_date date) OWNER TO floreant;

--
-- TOC entry 374 (class 1255 OID 20158)
-- Name: get_ticket_folio_info(integer); Type: FUNCTION; Schema: public; Owner: floreant
--

CREATE FUNCTION get_ticket_folio_info(p_ticket_id integer) RETURNS TABLE(daily_folio integer, folio_date date, branch_key text, folio_date_txt text, folio_display text, sucursal_completa text, terminal_name text)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        t.daily_folio,
        t.folio_date,
        t.branch_key,
        TO_CHAR(t.folio_date, 'DD/MM/YYYY') AS folio_date_txt,
        LPAD(t.daily_folio::TEXT, 4, '0') AS folio_display,
        COALESCE(term.location, 'DEFAULT') AS sucursal_completa,
        term.name AS terminal_name
    FROM public.ticket t
    LEFT JOIN public.terminal term ON t.terminal_id = term.id
    WHERE t.id = p_ticket_id;
$$;


ALTER FUNCTION public.get_ticket_folio_info(p_ticket_id integer) OWNER TO floreant;

--
-- TOC entry 371 (class 1255 OID 20026)
-- Name: kds_notify(); Type: FUNCTION; Schema: public; Owner: floreant
--

CREATE FUNCTION kds_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_ticket_id   INT;
    v_pg_id       INT;
    v_item_id     INT;
    v_status      TEXT;
    v_total       INT;
    v_ready       INT;
    v_done        INT;
    v_type        TEXT;
    v_daily_folio INT;
    v_branch_key  TEXT;
    v_folio_fmt   TEXT;
BEGIN
    IF TG_TABLE_NAME = 'kitchen_ticket_item' THEN
        IF NEW.ticket_item_id IS NULL THEN
            RAISE EXCEPTION 'ticket_item_id no puede ser NULL en kitchen_ticket_item';
        END IF;
        v_item_id := NEW.ticket_item_id;
        SELECT ti.ticket_id, ti.pg_id INTO v_ticket_id, v_pg_id
        FROM ticket_item ti WHERE ti.id = v_item_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ticket_item % no existe', v_item_id;
        END IF;
        SELECT daily_folio, branch_key INTO v_daily_folio, v_branch_key
        FROM ticket WHERE id = v_ticket_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ticket % no existe', v_ticket_id;
        END IF;
        v_folio_fmt := LPAD(COALESCE(v_daily_folio, 0)::TEXT, 4, '0');
        v_status := UPPER(COALESCE(NEW.status, ''));
        v_type := CASE WHEN TG_OP = 'INSERT' THEN 'item_upsert' ELSE 'item_status' END;
        PERFORM pg_notify(
            'kds_event',
            json_build_object(
                'type',        v_type,
                'ticket_id',   v_ticket_id,
                'pg',          v_pg_id,
                'item_id',     v_item_id,
                'status',      v_status,
                'daily_folio', v_daily_folio,
                'branch_key',  v_branch_key,
                'folio_fmt',   v_folio_fmt,
                'ts',          NOW()
            )::TEXT
        );
    ELSIF TG_TABLE_NAME = 'ticket_item' THEN
        v_item_id := NEW.id;
        v_ticket_id := NEW.ticket_id;
        v_pg_id := NEW.pg_id;
        IF v_ticket_id IS NULL THEN
            RAISE EXCEPTION 'ticket_id no puede ser NULL en ticket_item';
        END IF;
        SELECT daily_folio, branch_key INTO v_daily_folio, v_branch_key
        FROM ticket WHERE id = v_ticket_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ticket % no existe', v_ticket_id;
        END IF;
        v_folio_fmt := LPAD(COALESCE(v_daily_folio, 0)::TEXT, 4, '0');
        v_status := UPPER(COALESCE(NEW.status, ''));
        v_type := CASE WHEN TG_OP = 'INSERT' THEN 'item_insert' ELSE 'item_status' END;
        PERFORM pg_notify(
            'kds_event',
            json_build_object(
                'type',        v_type,
                'ticket_id',   v_ticket_id,
                'pg',          v_pg_id,
                'item_id',     v_item_id,
                'status',      v_status,
                'daily_folio', v_daily_folio,
                'branch_key',  v_branch_key,
                'folio_fmt',   v_folio_fmt,
                'ts',          NOW()
            )::TEXT
        );
    END IF;
    IF v_ticket_id IS NOT NULL AND v_pg_id IS NOT NULL THEN
        WITH s AS (
            SELECT
                ti.id AS item_id,
                UPPER(COALESCE(kti.status, ti.status, '')) AS st
            FROM ticket_item ti
            LEFT JOIN kitchen_ticket_item kti ON kti.ticket_item_id = ti.id
            WHERE ti.ticket_id = v_ticket_id AND ti.pg_id = v_pg_id
            GROUP BY ti.id, st
        )
        SELECT
            COUNT(DISTINCT item_id) AS total,
            COUNT(DISTINCT item_id) FILTER (WHERE st IN ('READY', 'DONE')) AS ready,
            COUNT(DISTINCT item_id) FILTER (WHERE st = 'DONE') AS done
        INTO v_total, v_ready, v_done
        FROM s;
        IF v_total > 0 AND v_total = v_ready THEN
            PERFORM pg_notify(
                'kds_event',
                json_build_object(
                    'type',        'ticket_all_ready',
                    'ticket_id',   v_ticket_id,
                    'pg',          v_pg_id,
                    'daily_folio', v_daily_folio,
                    'branch_key',  v_branch_key,
                    'folio_fmt',   v_folio_fmt,
                    'ts',          NOW()
                )::TEXT
            );
        END IF;
        IF v_total > 0 AND v_total = v_done THEN
            PERFORM pg_notify(
                'kds_event',
                json_build_object(
                    'type',        'ticket_all_done',
                    'ticket_id',   v_ticket_id,
                    'pg',          v_pg_id,
                    'daily_folio', v_daily_folio,
                    'branch_key',  v_branch_key,
                    'folio_fmt',   v_folio_fmt,
                    'ts',          NOW()
                )::TEXT
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.kds_notify() OWNER TO floreant;

--
-- TOC entry 375 (class 1255 OID 20160)
-- Name: reset_daily_folio_smart(text); Type: FUNCTION; Schema: public; Owner: floreant
--

CREATE FUNCTION reset_daily_folio_smart(p_branch text DEFAULT NULL::text) RETURNS TABLE(branch_reset text, tickets_affected integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_current_date DATE := CURRENT_DATE;
    v_branch TEXT;
    v_has_rows BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.daily_folio_counter
        WHERE folio_date = v_current_date
        AND (p_branch IS NULL OR branch_key = UPPER(BTRIM(p_branch)))
    ) INTO v_has_rows;
    IF NOT v_has_rows THEN
        branch_reset := 'none';
        tickets_affected := 0;
        RETURN NEXT;
        RETURN;
    END IF;
    FOR v_branch IN
        SELECT DISTINCT
            CASE
                WHEN p_branch IS NULL THEN dfc.branch_key
                ELSE UPPER(BTRIM(p_branch))
            END
        FROM public.daily_folio_counter dfc
        WHERE dfc.folio_date = v_current_date
        AND (p_branch IS NULL OR dfc.branch_key = UPPER(BTRIM(p_branch)))
    LOOP
        IF EXISTS (
            SELECT 1 FROM public.ticket
            WHERE branch_key = v_branch
            AND folio_date = v_current_date
        ) THEN
            RAISE NOTICE 'ADVERTENCIA: Sucursal % ya tiene % tickets hoy - NO reseteable',
                v_branch,
                (SELECT COUNT(*) FROM public.ticket WHERE branch_key = v_branch AND folio_date = v_current_date);
            CONTINUE;
        END IF;
        DELETE FROM public.daily_folio_counter
        WHERE branch_key = v_branch AND folio_date = v_current_date;
        branch_reset := v_branch;
        tickets_affected := 0;
        RETURN NEXT;
    END LOOP;
    RETURN;
END
$$;


ALTER FUNCTION public.reset_daily_folio_smart(p_branch text) OWNER TO floreant;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 180 (class 1259 OID 18591)
-- Name: action_history; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE action_history (
    id integer NOT NULL,
    action_time timestamp without time zone,
    action_name character varying(255),
    description character varying(255),
    user_id integer
);


ALTER TABLE action_history OWNER TO floreant;

--
-- TOC entry 181 (class 1259 OID 18597)
-- Name: action_history_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE action_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE action_history_id_seq OWNER TO floreant;

--
-- TOC entry 3307 (class 0 OID 0)
-- Dependencies: 181
-- Name: action_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE action_history_id_seq OWNED BY action_history.id;


--
-- TOC entry 182 (class 1259 OID 18599)
-- Name: attendence_history; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE attendence_history (
    id integer NOT NULL,
    clock_in_time timestamp without time zone,
    clock_out_time timestamp without time zone,
    clock_in_hour smallint,
    clock_out_hour smallint,
    clocked_out boolean,
    user_id integer,
    shift_id integer,
    terminal_id integer
);


ALTER TABLE attendence_history OWNER TO floreant;

--
-- TOC entry 183 (class 1259 OID 18602)
-- Name: attendence_history_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE attendence_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendence_history_id_seq OWNER TO floreant;

--
-- TOC entry 3308 (class 0 OID 0)
-- Dependencies: 183
-- Name: attendence_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE attendence_history_id_seq OWNED BY attendence_history.id;


--
-- TOC entry 184 (class 1259 OID 18604)
-- Name: cash_drawer; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE cash_drawer (
    id integer NOT NULL,
    terminal_id integer
);


ALTER TABLE cash_drawer OWNER TO floreant;

--
-- TOC entry 185 (class 1259 OID 18607)
-- Name: cash_drawer_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE cash_drawer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cash_drawer_id_seq OWNER TO floreant;

--
-- TOC entry 3309 (class 0 OID 0)
-- Dependencies: 185
-- Name: cash_drawer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE cash_drawer_id_seq OWNED BY cash_drawer.id;


--
-- TOC entry 186 (class 1259 OID 18609)
-- Name: cash_drawer_reset_history; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE cash_drawer_reset_history (
    id integer NOT NULL,
    reset_time timestamp without time zone,
    user_id integer
);


ALTER TABLE cash_drawer_reset_history OWNER TO floreant;

--
-- TOC entry 187 (class 1259 OID 18612)
-- Name: cash_drawer_reset_history_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE cash_drawer_reset_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cash_drawer_reset_history_id_seq OWNER TO floreant;

--
-- TOC entry 3310 (class 0 OID 0)
-- Dependencies: 187
-- Name: cash_drawer_reset_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE cash_drawer_reset_history_id_seq OWNED BY cash_drawer_reset_history.id;


--
-- TOC entry 188 (class 1259 OID 18614)
-- Name: cooking_instruction; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE cooking_instruction (
    id integer NOT NULL,
    description character varying(60)
);


ALTER TABLE cooking_instruction OWNER TO floreant;

--
-- TOC entry 189 (class 1259 OID 18617)
-- Name: cooking_instruction_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE cooking_instruction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cooking_instruction_id_seq OWNER TO floreant;

--
-- TOC entry 3311 (class 0 OID 0)
-- Dependencies: 189
-- Name: cooking_instruction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE cooking_instruction_id_seq OWNED BY cooking_instruction.id;


--
-- TOC entry 190 (class 1259 OID 18619)
-- Name: coupon_and_discount; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE coupon_and_discount (
    id integer NOT NULL,
    name character varying(120),
    type integer,
    barcode character varying(120),
    qualification_type integer,
    apply_to_all boolean,
    minimum_buy integer,
    maximum_off integer,
    value double precision,
    expiry_date timestamp without time zone,
    enabled boolean,
    auto_apply boolean,
    modifiable boolean,
    never_expire boolean,
    uuid character varying(36)
);


ALTER TABLE coupon_and_discount OWNER TO floreant;

--
-- TOC entry 191 (class 1259 OID 18622)
-- Name: coupon_and_discount_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE coupon_and_discount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE coupon_and_discount_id_seq OWNER TO floreant;

--
-- TOC entry 3312 (class 0 OID 0)
-- Dependencies: 191
-- Name: coupon_and_discount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE coupon_and_discount_id_seq OWNED BY coupon_and_discount.id;


--
-- TOC entry 192 (class 1259 OID 18624)
-- Name: currency; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE currency (
    id integer NOT NULL,
    code character varying(20),
    name character varying(30),
    symbol character varying(10),
    exchange_rate double precision,
    decimal_places integer,
    tolerance double precision,
    buy_price double precision,
    sales_price double precision,
    main boolean
);


ALTER TABLE currency OWNER TO floreant;

--
-- TOC entry 193 (class 1259 OID 18627)
-- Name: currency_balance; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE currency_balance (
    id integer NOT NULL,
    balance double precision,
    currency_id integer,
    cash_drawer_id integer,
    dpr_id integer
);


ALTER TABLE currency_balance OWNER TO floreant;

--
-- TOC entry 194 (class 1259 OID 18630)
-- Name: currency_balance_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE currency_balance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE currency_balance_id_seq OWNER TO floreant;

--
-- TOC entry 3313 (class 0 OID 0)
-- Dependencies: 194
-- Name: currency_balance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE currency_balance_id_seq OWNED BY currency_balance.id;


--
-- TOC entry 195 (class 1259 OID 18632)
-- Name: currency_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE currency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE currency_id_seq OWNER TO floreant;

--
-- TOC entry 3314 (class 0 OID 0)
-- Dependencies: 195
-- Name: currency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE currency_id_seq OWNED BY currency.id;


--
-- TOC entry 196 (class 1259 OID 18634)
-- Name: custom_payment; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE custom_payment (
    id integer NOT NULL,
    name character varying(60),
    required_ref_number boolean,
    ref_number_field_name character varying(60)
);


ALTER TABLE custom_payment OWNER TO floreant;

--
-- TOC entry 197 (class 1259 OID 18637)
-- Name: custom_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE custom_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE custom_payment_id_seq OWNER TO floreant;

--
-- TOC entry 3315 (class 0 OID 0)
-- Dependencies: 197
-- Name: custom_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE custom_payment_id_seq OWNED BY custom_payment.id;


--
-- TOC entry 198 (class 1259 OID 18639)
-- Name: customer; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE customer (
    auto_id integer NOT NULL,
    loyalty_no character varying(30),
    loyalty_point integer,
    social_security_number character varying(60),
    picture bytea,
    homephone_no character varying(30),
    mobile_no character varying(30),
    workphone_no character varying(30),
    email character varying(40),
    salutation character varying(60),
    first_name character varying(60),
    last_name character varying(60),
    name character varying(120),
    dob character varying(16),
    ssn character varying(30),
    address character varying(220),
    city character varying(30),
    state character varying(30),
    zip_code character varying(10),
    country character varying(30),
    vip boolean,
    credit_limit double precision,
    credit_spent double precision,
    credit_card_no character varying(30),
    note character varying(255)
);


ALTER TABLE customer OWNER TO floreant;

--
-- TOC entry 199 (class 1259 OID 18645)
-- Name: customer_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE customer_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE customer_auto_id_seq OWNER TO floreant;

--
-- TOC entry 3316 (class 0 OID 0)
-- Dependencies: 199
-- Name: customer_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE customer_auto_id_seq OWNED BY customer.auto_id;


--
-- TOC entry 200 (class 1259 OID 18647)
-- Name: customer_properties; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE customer_properties (
    id integer NOT NULL,
    property_value character varying(255),
    property_name character varying(255) NOT NULL
);


ALTER TABLE customer_properties OWNER TO floreant;

--
-- TOC entry 355 (class 1259 OID 20130)
-- Name: daily_folio_counter; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE daily_folio_counter (
    folio_date date NOT NULL,
    branch_key text NOT NULL,
    last_value integer DEFAULT 0 NOT NULL
);


ALTER TABLE daily_folio_counter OWNER TO floreant;

--
-- TOC entry 201 (class 1259 OID 18653)
-- Name: data_update_info; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE data_update_info (
    id integer NOT NULL,
    last_update_time timestamp without time zone
);


ALTER TABLE data_update_info OWNER TO floreant;

--
-- TOC entry 202 (class 1259 OID 18656)
-- Name: data_update_info_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE data_update_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE data_update_info_id_seq OWNER TO floreant;

--
-- TOC entry 3318 (class 0 OID 0)
-- Dependencies: 202
-- Name: data_update_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE data_update_info_id_seq OWNED BY data_update_info.id;


--
-- TOC entry 203 (class 1259 OID 18658)
-- Name: delivery_address; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE delivery_address (
    id integer NOT NULL,
    address character varying(320),
    phone_extension character varying(10),
    room_no character varying(30),
    distance double precision,
    customer_id integer
);


ALTER TABLE delivery_address OWNER TO floreant;

--
-- TOC entry 204 (class 1259 OID 18661)
-- Name: delivery_address_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE delivery_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery_address_id_seq OWNER TO floreant;

--
-- TOC entry 3319 (class 0 OID 0)
-- Dependencies: 204
-- Name: delivery_address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE delivery_address_id_seq OWNED BY delivery_address.id;


--
-- TOC entry 205 (class 1259 OID 18663)
-- Name: delivery_charge; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE delivery_charge (
    id integer NOT NULL,
    name character varying(220),
    zip_code character varying(20),
    start_range double precision,
    end_range double precision,
    charge_amount double precision
);


ALTER TABLE delivery_charge OWNER TO floreant;

--
-- TOC entry 206 (class 1259 OID 18666)
-- Name: delivery_charge_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE delivery_charge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery_charge_id_seq OWNER TO floreant;

--
-- TOC entry 3320 (class 0 OID 0)
-- Dependencies: 206
-- Name: delivery_charge_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE delivery_charge_id_seq OWNED BY delivery_charge.id;


--
-- TOC entry 207 (class 1259 OID 18668)
-- Name: delivery_configuration; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE delivery_configuration (
    id integer NOT NULL,
    unit_name character varying(20),
    unit_symbol character varying(8),
    charge_by_zip_code boolean
);


ALTER TABLE delivery_configuration OWNER TO floreant;

--
-- TOC entry 208 (class 1259 OID 18671)
-- Name: delivery_configuration_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE delivery_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery_configuration_id_seq OWNER TO floreant;

--
-- TOC entry 3321 (class 0 OID 0)
-- Dependencies: 208
-- Name: delivery_configuration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE delivery_configuration_id_seq OWNED BY delivery_configuration.id;


--
-- TOC entry 209 (class 1259 OID 18673)
-- Name: delivery_instruction; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE delivery_instruction (
    id integer NOT NULL,
    notes character varying(220),
    customer_no integer
);


ALTER TABLE delivery_instruction OWNER TO floreant;

--
-- TOC entry 210 (class 1259 OID 18676)
-- Name: delivery_instruction_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE delivery_instruction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE delivery_instruction_id_seq OWNER TO floreant;

--
-- TOC entry 3322 (class 0 OID 0)
-- Dependencies: 210
-- Name: delivery_instruction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE delivery_instruction_id_seq OWNED BY delivery_instruction.id;


--
-- TOC entry 211 (class 1259 OID 18678)
-- Name: drawer_assigned_history; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE drawer_assigned_history (
    id integer NOT NULL,
    "time" timestamp without time zone,
    operation character varying(60),
    a_user integer
);


ALTER TABLE drawer_assigned_history OWNER TO floreant;

--
-- TOC entry 212 (class 1259 OID 18681)
-- Name: drawer_assigned_history_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE drawer_assigned_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE drawer_assigned_history_id_seq OWNER TO floreant;

--
-- TOC entry 3323 (class 0 OID 0)
-- Dependencies: 212
-- Name: drawer_assigned_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE drawer_assigned_history_id_seq OWNED BY drawer_assigned_history.id;


--
-- TOC entry 213 (class 1259 OID 18683)
-- Name: drawer_pull_report; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE drawer_pull_report (
    id integer NOT NULL,
    report_time timestamp without time zone,
    reg character varying(15),
    ticket_count integer,
    begin_cash double precision,
    net_sales double precision,
    sales_tax double precision,
    cash_tax double precision,
    total_revenue double precision,
    gross_receipts double precision,
    giftcertreturncount integer,
    giftcertreturnamount double precision,
    giftcertchangeamount double precision,
    cash_receipt_no integer,
    cash_receipt_amount double precision,
    credit_card_receipt_no integer,
    credit_card_receipt_amount double precision,
    debit_card_receipt_no integer,
    debit_card_receipt_amount double precision,
    refund_receipt_count integer,
    refund_amount double precision,
    receipt_differential double precision,
    cash_back double precision,
    cash_tips double precision,
    charged_tips double precision,
    tips_paid double precision,
    tips_differential double precision,
    pay_out_no integer,
    pay_out_amount double precision,
    drawer_bleed_no integer,
    drawer_bleed_amount double precision,
    drawer_accountable double precision,
    cash_to_deposit double precision,
    variance double precision,
    delivery_charge double precision,
    totalvoidwst double precision,
    totalvoid double precision,
    totaldiscountcount integer,
    totaldiscountamount double precision,
    totaldiscountsales double precision,
    totaldiscountguest integer,
    totaldiscountpartysize integer,
    totaldiscountchecksize integer,
    totaldiscountpercentage double precision,
    totaldiscountratio double precision,
    user_id integer,
    terminal_id integer
);


ALTER TABLE drawer_pull_report OWNER TO floreant;

--
-- TOC entry 214 (class 1259 OID 18686)
-- Name: drawer_pull_report_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE drawer_pull_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE drawer_pull_report_id_seq OWNER TO floreant;

--
-- TOC entry 3324 (class 0 OID 0)
-- Dependencies: 214
-- Name: drawer_pull_report_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE drawer_pull_report_id_seq OWNED BY drawer_pull_report.id;


--
-- TOC entry 215 (class 1259 OID 18688)
-- Name: drawer_pull_report_voidtickets; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE drawer_pull_report_voidtickets (
    dpreport_id integer NOT NULL,
    code integer,
    reason character varying(255),
    hast character varying(255),
    quantity integer,
    amount double precision
);


ALTER TABLE drawer_pull_report_voidtickets OWNER TO floreant;

--
-- TOC entry 216 (class 1259 OID 18694)
-- Name: employee_in_out_history; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE employee_in_out_history (
    id integer NOT NULL,
    out_time timestamp without time zone,
    in_time timestamp without time zone,
    out_hour smallint,
    in_hour smallint,
    clock_out boolean,
    user_id integer,
    shift_id integer,
    terminal_id integer
);


ALTER TABLE employee_in_out_history OWNER TO floreant;

--
-- TOC entry 217 (class 1259 OID 18697)
-- Name: employee_in_out_history_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE employee_in_out_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE employee_in_out_history_id_seq OWNER TO floreant;

--
-- TOC entry 3325 (class 0 OID 0)
-- Dependencies: 217
-- Name: employee_in_out_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE employee_in_out_history_id_seq OWNED BY employee_in_out_history.id;


--
-- TOC entry 218 (class 1259 OID 18699)
-- Name: global_config; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE global_config (
    id integer NOT NULL,
    pos_key character varying(60),
    pos_value character varying(220)
);


ALTER TABLE global_config OWNER TO floreant;

--
-- TOC entry 219 (class 1259 OID 18702)
-- Name: global_config_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE global_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE global_config_id_seq OWNER TO floreant;

--
-- TOC entry 3326 (class 0 OID 0)
-- Dependencies: 219
-- Name: global_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE global_config_id_seq OWNED BY global_config.id;


--
-- TOC entry 220 (class 1259 OID 18704)
-- Name: gratuity; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE gratuity (
    id integer NOT NULL,
    amount double precision,
    paid boolean,
    refunded boolean,
    ticket_id integer,
    owner_id integer,
    terminal_id integer
);


ALTER TABLE gratuity OWNER TO floreant;

--
-- TOC entry 221 (class 1259 OID 18707)
-- Name: gratuity_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE gratuity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gratuity_id_seq OWNER TO floreant;

--
-- TOC entry 3327 (class 0 OID 0)
-- Dependencies: 221
-- Name: gratuity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE gratuity_id_seq OWNED BY gratuity.id;


--
-- TOC entry 222 (class 1259 OID 18709)
-- Name: group_taxes; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE group_taxes (
    group_id character varying(128) NOT NULL,
    elt integer NOT NULL
);


ALTER TABLE group_taxes OWNER TO floreant;

--
-- TOC entry 223 (class 1259 OID 18712)
-- Name: guest_check_print; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE guest_check_print (
    id integer NOT NULL,
    ticket_id integer,
    table_no character varying(255),
    ticket_total double precision,
    print_time timestamp without time zone,
    user_id integer
);


ALTER TABLE guest_check_print OWNER TO floreant;

--
-- TOC entry 224 (class 1259 OID 18715)
-- Name: guest_check_print_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE guest_check_print_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE guest_check_print_id_seq OWNER TO floreant;

--
-- TOC entry 3328 (class 0 OID 0)
-- Dependencies: 224
-- Name: guest_check_print_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE guest_check_print_id_seq OWNED BY guest_check_print.id;


--
-- TOC entry 225 (class 1259 OID 18717)
-- Name: inventory_group; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE inventory_group (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    visible boolean
);


ALTER TABLE inventory_group OWNER TO floreant;

--
-- TOC entry 226 (class 1259 OID 18720)
-- Name: inventory_group_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE inventory_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inventory_group_id_seq OWNER TO floreant;

--
-- TOC entry 3329 (class 0 OID 0)
-- Dependencies: 226
-- Name: inventory_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE inventory_group_id_seq OWNED BY inventory_group.id;


--
-- TOC entry 227 (class 1259 OID 18722)
-- Name: inventory_item; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE inventory_item (
    id integer NOT NULL,
    create_time timestamp without time zone,
    last_update_date timestamp without time zone,
    name character varying(60),
    package_barcode character varying(30),
    unit_barcode character varying(30),
    unit_per_package double precision,
    sort_order integer,
    package_reorder_level integer,
    package_replenish_level integer,
    description character varying(255),
    average_package_price double precision,
    total_unit_packages double precision,
    total_recepie_units double precision,
    unit_purchase_price double precision,
    unit_selling_price double precision,
    visible boolean,
    punit_id integer,
    recipe_unit_id integer,
    item_group_id integer,
    item_location_id integer,
    item_vendor_id integer,
    total_packages integer
);


ALTER TABLE inventory_item OWNER TO floreant;

--
-- TOC entry 228 (class 1259 OID 18725)
-- Name: inventory_item_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE inventory_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inventory_item_id_seq OWNER TO floreant;

--
-- TOC entry 3330 (class 0 OID 0)
-- Dependencies: 228
-- Name: inventory_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE inventory_item_id_seq OWNED BY inventory_item.id;


--
-- TOC entry 229 (class 1259 OID 18727)
-- Name: inventory_location; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE inventory_location (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    sort_order integer,
    visible boolean,
    warehouse_id integer
);


ALTER TABLE inventory_location OWNER TO floreant;

--
-- TOC entry 230 (class 1259 OID 18730)
-- Name: inventory_location_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE inventory_location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inventory_location_id_seq OWNER TO floreant;

--
-- TOC entry 3331 (class 0 OID 0)
-- Dependencies: 230
-- Name: inventory_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE inventory_location_id_seq OWNED BY inventory_location.id;


--
-- TOC entry 231 (class 1259 OID 18732)
-- Name: inventory_meta_code; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE inventory_meta_code (
    id integer NOT NULL,
    type character varying(255),
    code_text character varying(255),
    code_no integer,
    description character varying(255)
);


ALTER TABLE inventory_meta_code OWNER TO floreant;

--
-- TOC entry 232 (class 1259 OID 18738)
-- Name: inventory_meta_code_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE inventory_meta_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inventory_meta_code_id_seq OWNER TO floreant;

--
-- TOC entry 3332 (class 0 OID 0)
-- Dependencies: 232
-- Name: inventory_meta_code_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE inventory_meta_code_id_seq OWNED BY inventory_meta_code.id;


--
-- TOC entry 233 (class 1259 OID 18740)
-- Name: inventory_transaction; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE inventory_transaction (
    id integer NOT NULL,
    transaction_date timestamp without time zone,
    unit_quantity double precision,
    unit_price double precision,
    remark character varying(255),
    tran_type integer,
    reference_id integer,
    item_id integer,
    vendor_id integer,
    from_warehouse_id integer,
    to_warehouse_id integer,
    quantity integer
);


ALTER TABLE inventory_transaction OWNER TO floreant;

--
-- TOC entry 234 (class 1259 OID 18743)
-- Name: inventory_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE inventory_transaction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inventory_transaction_id_seq OWNER TO floreant;

--
-- TOC entry 3333 (class 0 OID 0)
-- Dependencies: 234
-- Name: inventory_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE inventory_transaction_id_seq OWNED BY inventory_transaction.id;


--
-- TOC entry 235 (class 1259 OID 18745)
-- Name: inventory_unit; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE inventory_unit (
    id integer NOT NULL,
    short_name character varying(255),
    long_name character varying(255),
    alt_name character varying(255),
    conv_factor1 character varying(255),
    conv_factor2 character varying(255),
    conv_factor3 character varying(255)
);


ALTER TABLE inventory_unit OWNER TO floreant;

--
-- TOC entry 236 (class 1259 OID 18751)
-- Name: inventory_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE inventory_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inventory_unit_id_seq OWNER TO floreant;

--
-- TOC entry 3334 (class 0 OID 0)
-- Dependencies: 236
-- Name: inventory_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE inventory_unit_id_seq OWNED BY inventory_unit.id;


--
-- TOC entry 237 (class 1259 OID 18753)
-- Name: inventory_vendor; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE inventory_vendor (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    visible boolean,
    address character varying(120) NOT NULL,
    city character varying(60) NOT NULL,
    state character varying(60) NOT NULL,
    zip character varying(60) NOT NULL,
    country character varying(60) NOT NULL,
    email character varying(60) NOT NULL,
    phone character varying(60) NOT NULL,
    fax character varying(60)
);


ALTER TABLE inventory_vendor OWNER TO floreant;

--
-- TOC entry 238 (class 1259 OID 18759)
-- Name: inventory_vendor_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE inventory_vendor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inventory_vendor_id_seq OWNER TO floreant;

--
-- TOC entry 3335 (class 0 OID 0)
-- Dependencies: 238
-- Name: inventory_vendor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE inventory_vendor_id_seq OWNED BY inventory_vendor.id;


--
-- TOC entry 239 (class 1259 OID 18761)
-- Name: inventory_warehouse; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE inventory_warehouse (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    visible boolean
);


ALTER TABLE inventory_warehouse OWNER TO floreant;

--
-- TOC entry 240 (class 1259 OID 18764)
-- Name: inventory_warehouse_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE inventory_warehouse_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inventory_warehouse_id_seq OWNER TO floreant;

--
-- TOC entry 3336 (class 0 OID 0)
-- Dependencies: 240
-- Name: inventory_warehouse_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE inventory_warehouse_id_seq OWNED BY inventory_warehouse.id;


--
-- TOC entry 241 (class 1259 OID 18766)
-- Name: item_order_type; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE item_order_type (
    menu_item_id integer NOT NULL,
    order_type_id integer NOT NULL
);


ALTER TABLE item_order_type OWNER TO floreant;

--
-- TOC entry 244 (class 1259 OID 18776)
-- Name: kitchen_ticket; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE kitchen_ticket (
    id integer NOT NULL,
    ticket_id integer,
    create_date timestamp without time zone,
    close_date timestamp without time zone,
    voided boolean,
    sequence_number integer,
    status character varying(30),
    server_name character varying(30),
    ticket_type character varying(20),
    pg_id integer
);


ALTER TABLE kitchen_ticket OWNER TO floreant;

--
-- TOC entry 320 (class 1259 OID 18991)
-- Name: terminal; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE terminal (
    id integer NOT NULL,
    name character varying(60),
    terminal_key character varying(120),
    opening_balance double precision,
    current_balance double precision,
    has_cash_drawer boolean,
    in_use boolean,
    active boolean,
    location character varying(320),
    floor_id integer,
    assigned_user integer
);


ALTER TABLE terminal OWNER TO floreant;

--
-- TOC entry 324 (class 1259 OID 19008)
-- Name: ticket; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket (
    id integer NOT NULL,
    global_id character varying(16),
    create_date timestamp without time zone,
    closing_date timestamp without time zone,
    active_date timestamp without time zone,
    deliveery_date timestamp without time zone,
    creation_hour integer,
    paid boolean,
    voided boolean,
    void_reason character varying(255),
    wasted boolean,
    refunded boolean,
    settled boolean,
    drawer_resetted boolean,
    sub_total double precision,
    total_discount double precision,
    total_tax double precision,
    total_price double precision,
    paid_amount double precision,
    due_amount double precision,
    advance_amount double precision,
    adjustment_amount double precision,
    number_of_guests integer,
    status character varying(30),
    bar_tab boolean,
    is_tax_exempt boolean,
    is_re_opened boolean,
    service_charge double precision,
    delivery_charge double precision,
    customer_id integer,
    delivery_address character varying(120),
    customer_pickeup boolean,
    delivery_extra_info character varying(255),
    ticket_type character varying(20),
    shift_id integer,
    owner_id integer,
    driver_id integer,
    gratuity_id integer,
    void_by_user integer,
    terminal_id integer,
    folio_date date,
    branch_key text,
    daily_folio integer,
    CONSTRAINT ck_ticket_daily_folio_positive CHECK (((daily_folio IS NULL) OR (daily_folio > 0)))
);


ALTER TABLE ticket OWNER TO floreant;

--
-- TOC entry 356 (class 1259 OID 20148)
-- Name: kds_orders_enhanced; Type: VIEW; Schema: public; Owner: floreant
--

CREATE VIEW kds_orders_enhanced AS
 SELECT kt.id AS kitchen_ticket_id,
    kt.ticket_id,
    kt.create_date AS kds_created_at,
    kt.sequence_number,
    t.daily_folio,
    t.folio_date,
    t.branch_key,
    lpad((t.daily_folio)::text, 4, '0'::text) AS folio_display,
    t.number_of_guests,
    t.ticket_type,
    term.name AS terminal_name,
        CASE
            WHEN ((t.daily_folio >= 1) AND (t.daily_folio <= 20)) THEN 'PRIORITARIO'::text
            WHEN ((t.daily_folio >= 21) AND (t.daily_folio <= 50)) THEN 'NORMAL'::text
            ELSE 'ALTO_VOLUMEN'::text
        END AS prioridad_voceo
   FROM ((kitchen_ticket kt
     JOIN ticket t ON ((t.id = kt.ticket_id)))
     LEFT JOIN terminal term ON ((t.terminal_id = term.id)));


ALTER TABLE kds_orders_enhanced OWNER TO floreant;

--
-- TOC entry 242 (class 1259 OID 18769)
-- Name: kds_ready_log; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE kds_ready_log (
    ticket_id integer NOT NULL,
    notified_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE kds_ready_log OWNER TO floreant;

--
-- TOC entry 243 (class 1259 OID 18773)
-- Name: kit_ticket_table_num; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE kit_ticket_table_num (
    kit_ticket_id integer NOT NULL,
    table_id integer
);


ALTER TABLE kit_ticket_table_num OWNER TO floreant;

--
-- TOC entry 245 (class 1259 OID 18779)
-- Name: kitchen_ticket_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE kitchen_ticket_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE kitchen_ticket_id_seq OWNER TO floreant;

--
-- TOC entry 3338 (class 0 OID 0)
-- Dependencies: 245
-- Name: kitchen_ticket_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE kitchen_ticket_id_seq OWNED BY kitchen_ticket.id;


--
-- TOC entry 246 (class 1259 OID 18781)
-- Name: kitchen_ticket_item; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE kitchen_ticket_item (
    id integer NOT NULL,
    cookable boolean,
    ticket_item_id integer NOT NULL,
    ticket_item_modifier_id integer,
    menu_item_code character varying(255),
    menu_item_name character varying(120),
    menu_item_group_id integer,
    menu_item_group_name character varying(120),
    quantity integer,
    fractional_quantity double precision,
    fractional_unit boolean,
    unit_name character varying(20),
    sort_order integer,
    voided boolean,
    status character varying(30),
    kithen_ticket_id integer,
    item_order integer
);


ALTER TABLE kitchen_ticket_item OWNER TO floreant;

--
-- TOC entry 247 (class 1259 OID 18787)
-- Name: kitchen_ticket_item_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE kitchen_ticket_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE kitchen_ticket_item_id_seq OWNER TO floreant;

--
-- TOC entry 3339 (class 0 OID 0)
-- Dependencies: 247
-- Name: kitchen_ticket_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE kitchen_ticket_item_id_seq OWNED BY kitchen_ticket_item.id;


--
-- TOC entry 248 (class 1259 OID 18789)
-- Name: menu_category; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_category (
    id integer NOT NULL,
    name character varying(120) NOT NULL,
    translated_name character varying(120),
    visible boolean,
    beverage boolean,
    sort_order integer,
    btn_color integer,
    text_color integer
);


ALTER TABLE menu_category OWNER TO floreant;

--
-- TOC entry 249 (class 1259 OID 18792)
-- Name: menu_category_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE menu_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menu_category_id_seq OWNER TO floreant;

--
-- TOC entry 3340 (class 0 OID 0)
-- Dependencies: 249
-- Name: menu_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE menu_category_id_seq OWNED BY menu_category.id;


--
-- TOC entry 250 (class 1259 OID 18794)
-- Name: menu_group; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_group (
    id integer NOT NULL,
    name character varying(120) NOT NULL,
    translated_name character varying(120),
    visible boolean,
    sort_order integer,
    btn_color integer,
    text_color integer,
    category_id integer
);


ALTER TABLE menu_group OWNER TO floreant;

--
-- TOC entry 251 (class 1259 OID 18797)
-- Name: menu_group_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE menu_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menu_group_id_seq OWNER TO floreant;

--
-- TOC entry 3341 (class 0 OID 0)
-- Dependencies: 251
-- Name: menu_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE menu_group_id_seq OWNED BY menu_group.id;


--
-- TOC entry 252 (class 1259 OID 18799)
-- Name: menu_item; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_item (
    id integer NOT NULL,
    name character varying(120) NOT NULL,
    description character varying(255),
    unit_name character varying(20),
    translated_name character varying(120),
    barcode character varying(120),
    buy_price double precision NOT NULL,
    stock_amount double precision,
    price double precision NOT NULL,
    discount_rate double precision,
    visible boolean,
    disable_when_stock_amount_is_zero boolean,
    sort_order integer,
    btn_color integer,
    text_color integer,
    image bytea,
    show_image_only boolean,
    fractional_unit boolean,
    pizza_type boolean,
    default_sell_portion integer,
    group_id integer,
    tax_group_id character varying(128),
    recepie integer,
    pg_id integer,
    tax_id integer
);


ALTER TABLE menu_item OWNER TO floreant;

--
-- TOC entry 253 (class 1259 OID 18805)
-- Name: menu_item_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE menu_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menu_item_id_seq OWNER TO floreant;

--
-- TOC entry 3342 (class 0 OID 0)
-- Dependencies: 253
-- Name: menu_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE menu_item_id_seq OWNED BY menu_item.id;


--
-- TOC entry 254 (class 1259 OID 18807)
-- Name: menu_item_properties; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_item_properties (
    menu_item_id integer NOT NULL,
    property_value character varying(100),
    property_name character varying(255) NOT NULL
);


ALTER TABLE menu_item_properties OWNER TO floreant;

--
-- TOC entry 255 (class 1259 OID 18810)
-- Name: menu_item_size; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_item_size (
    id integer NOT NULL,
    name character varying(60),
    translated_name character varying(60),
    description character varying(120),
    sort_order integer,
    size_in_inch double precision,
    default_size boolean
);


ALTER TABLE menu_item_size OWNER TO floreant;

--
-- TOC entry 256 (class 1259 OID 18813)
-- Name: menu_item_size_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE menu_item_size_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menu_item_size_id_seq OWNER TO floreant;

--
-- TOC entry 3343 (class 0 OID 0)
-- Dependencies: 256
-- Name: menu_item_size_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE menu_item_size_id_seq OWNED BY menu_item_size.id;


--
-- TOC entry 257 (class 1259 OID 18815)
-- Name: menu_item_terminal_ref; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_item_terminal_ref (
    menu_item_id integer NOT NULL,
    terminal_id integer NOT NULL
);


ALTER TABLE menu_item_terminal_ref OWNER TO floreant;

--
-- TOC entry 258 (class 1259 OID 18818)
-- Name: menu_modifier; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_modifier (
    id integer NOT NULL,
    name character varying(120),
    translated_name character varying(120),
    price double precision,
    extra_price double precision,
    sort_order integer,
    btn_color integer,
    text_color integer,
    enable boolean,
    fixed_price boolean,
    print_to_kitchen boolean,
    section_wise_pricing boolean,
    pizza_modifier boolean,
    group_id integer,
    tax_id integer
);


ALTER TABLE menu_modifier OWNER TO floreant;

--
-- TOC entry 259 (class 1259 OID 18821)
-- Name: menu_modifier_group; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_modifier_group (
    id integer NOT NULL,
    name character varying(60),
    translated_name character varying(60),
    enabled boolean,
    exclusived boolean,
    required boolean
);


ALTER TABLE menu_modifier_group OWNER TO floreant;

--
-- TOC entry 260 (class 1259 OID 18824)
-- Name: menu_modifier_group_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE menu_modifier_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menu_modifier_group_id_seq OWNER TO floreant;

--
-- TOC entry 3344 (class 0 OID 0)
-- Dependencies: 260
-- Name: menu_modifier_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE menu_modifier_group_id_seq OWNED BY menu_modifier_group.id;


--
-- TOC entry 261 (class 1259 OID 18826)
-- Name: menu_modifier_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE menu_modifier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menu_modifier_id_seq OWNER TO floreant;

--
-- TOC entry 3345 (class 0 OID 0)
-- Dependencies: 261
-- Name: menu_modifier_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE menu_modifier_id_seq OWNED BY menu_modifier.id;


--
-- TOC entry 262 (class 1259 OID 18828)
-- Name: menu_modifier_properties; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menu_modifier_properties (
    menu_modifier_id integer NOT NULL,
    property_value character varying(100),
    property_name character varying(255) NOT NULL
);


ALTER TABLE menu_modifier_properties OWNER TO floreant;

--
-- TOC entry 263 (class 1259 OID 18831)
-- Name: menucategory_discount; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menucategory_discount (
    discount_id integer NOT NULL,
    menucategory_id integer NOT NULL
);


ALTER TABLE menucategory_discount OWNER TO floreant;

--
-- TOC entry 264 (class 1259 OID 18834)
-- Name: menugroup_discount; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menugroup_discount (
    discount_id integer NOT NULL,
    menugroup_id integer NOT NULL
);


ALTER TABLE menugroup_discount OWNER TO floreant;

--
-- TOC entry 265 (class 1259 OID 18837)
-- Name: menuitem_discount; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menuitem_discount (
    discount_id integer NOT NULL,
    menuitem_id integer NOT NULL
);


ALTER TABLE menuitem_discount OWNER TO floreant;

--
-- TOC entry 266 (class 1259 OID 18840)
-- Name: menuitem_modifiergroup; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menuitem_modifiergroup (
    id integer NOT NULL,
    min_quantity integer,
    max_quantity integer,
    sort_order integer,
    modifier_group integer,
    menuitem_modifiergroup_id integer
);


ALTER TABLE menuitem_modifiergroup OWNER TO floreant;

--
-- TOC entry 267 (class 1259 OID 18843)
-- Name: menuitem_modifiergroup_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE menuitem_modifiergroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menuitem_modifiergroup_id_seq OWNER TO floreant;

--
-- TOC entry 3346 (class 0 OID 0)
-- Dependencies: 267
-- Name: menuitem_modifiergroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE menuitem_modifiergroup_id_seq OWNED BY menuitem_modifiergroup.id;


--
-- TOC entry 268 (class 1259 OID 18845)
-- Name: menuitem_pizzapirce; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menuitem_pizzapirce (
    menu_item_id integer NOT NULL,
    pizza_price_id integer NOT NULL
);


ALTER TABLE menuitem_pizzapirce OWNER TO floreant;

--
-- TOC entry 269 (class 1259 OID 18848)
-- Name: menuitem_shift; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menuitem_shift (
    id integer NOT NULL,
    shift_price double precision,
    shift_id integer,
    menuitem_id integer
);


ALTER TABLE menuitem_shift OWNER TO floreant;

--
-- TOC entry 270 (class 1259 OID 18851)
-- Name: menuitem_shift_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE menuitem_shift_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menuitem_shift_id_seq OWNER TO floreant;

--
-- TOC entry 3347 (class 0 OID 0)
-- Dependencies: 270
-- Name: menuitem_shift_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE menuitem_shift_id_seq OWNED BY menuitem_shift.id;


--
-- TOC entry 271 (class 1259 OID 18853)
-- Name: menumodifier_pizzamodifierprice; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE menumodifier_pizzamodifierprice (
    menumodifier_id integer NOT NULL,
    pizzamodifierprice_id integer NOT NULL
);


ALTER TABLE menumodifier_pizzamodifierprice OWNER TO floreant;

--
-- TOC entry 272 (class 1259 OID 18856)
-- Name: modifier_multiplier_price; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE modifier_multiplier_price (
    id integer NOT NULL,
    price double precision,
    multiplier_id character varying(20),
    menumodifier_id integer,
    pizza_modifier_price_id integer
);


ALTER TABLE modifier_multiplier_price OWNER TO floreant;

--
-- TOC entry 273 (class 1259 OID 18859)
-- Name: modifier_multiplier_price_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE modifier_multiplier_price_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE modifier_multiplier_price_id_seq OWNER TO floreant;

--
-- TOC entry 3348 (class 0 OID 0)
-- Dependencies: 273
-- Name: modifier_multiplier_price_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE modifier_multiplier_price_id_seq OWNED BY modifier_multiplier_price.id;


--
-- TOC entry 274 (class 1259 OID 18861)
-- Name: multiplier; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE multiplier (
    name character varying(20) NOT NULL,
    ticket_prefix character varying(20),
    rate double precision,
    sort_order integer,
    default_multiplier boolean,
    main boolean,
    btn_color integer,
    text_color integer
);


ALTER TABLE multiplier OWNER TO floreant;

--
-- TOC entry 275 (class 1259 OID 18864)
-- Name: order_type; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE order_type (
    id integer NOT NULL,
    name character varying(120) NOT NULL,
    enabled boolean,
    show_table_selection boolean,
    show_guest_selection boolean,
    should_print_to_kitchen boolean,
    prepaid boolean,
    close_on_paid boolean,
    required_customer_data boolean,
    delivery boolean,
    show_item_barcode boolean,
    show_in_login_screen boolean,
    consolidate_tiems_in_receipt boolean,
    allow_seat_based_order boolean,
    hide_item_with_empty_inventory boolean,
    has_forhere_and_togo boolean,
    pre_auth_credit_card boolean,
    bar_tab boolean,
    retail_order boolean,
    show_price_on_button boolean,
    show_stock_count_on_button boolean,
    show_unit_price_in_ticket_grid boolean,
    properties text
);


ALTER TABLE order_type OWNER TO floreant;

--
-- TOC entry 276 (class 1259 OID 18870)
-- Name: order_type_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE order_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE order_type_id_seq OWNER TO floreant;

--
-- TOC entry 3349 (class 0 OID 0)
-- Dependencies: 276
-- Name: order_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE order_type_id_seq OWNED BY order_type.id;


--
-- TOC entry 277 (class 1259 OID 18872)
-- Name: packaging_unit; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE packaging_unit (
    id integer NOT NULL,
    name character varying(30),
    short_name character varying(10),
    factor double precision,
    baseunit boolean,
    dimension character varying(30)
);


ALTER TABLE packaging_unit OWNER TO floreant;

--
-- TOC entry 278 (class 1259 OID 18875)
-- Name: packaging_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE packaging_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE packaging_unit_id_seq OWNER TO floreant;

--
-- TOC entry 3350 (class 0 OID 0)
-- Dependencies: 278
-- Name: packaging_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE packaging_unit_id_seq OWNED BY packaging_unit.id;


--
-- TOC entry 279 (class 1259 OID 18877)
-- Name: payout_reasons; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE payout_reasons (
    id integer NOT NULL,
    reason character varying(255)
);


ALTER TABLE payout_reasons OWNER TO floreant;

--
-- TOC entry 280 (class 1259 OID 18880)
-- Name: payout_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE payout_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payout_reasons_id_seq OWNER TO floreant;

--
-- TOC entry 3351 (class 0 OID 0)
-- Dependencies: 280
-- Name: payout_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE payout_reasons_id_seq OWNED BY payout_reasons.id;


--
-- TOC entry 281 (class 1259 OID 18882)
-- Name: payout_recepients; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE payout_recepients (
    id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE payout_recepients OWNER TO floreant;

--
-- TOC entry 282 (class 1259 OID 18885)
-- Name: payout_recepients_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE payout_recepients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payout_recepients_id_seq OWNER TO floreant;

--
-- TOC entry 3352 (class 0 OID 0)
-- Dependencies: 282
-- Name: payout_recepients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE payout_recepients_id_seq OWNED BY payout_recepients.id;


--
-- TOC entry 283 (class 1259 OID 18887)
-- Name: pizza_crust; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE pizza_crust (
    id integer NOT NULL,
    name character varying(60),
    translated_name character varying(60),
    description character varying(120),
    sort_order integer,
    default_crust boolean
);


ALTER TABLE pizza_crust OWNER TO floreant;

--
-- TOC entry 284 (class 1259 OID 18890)
-- Name: pizza_crust_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE pizza_crust_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pizza_crust_id_seq OWNER TO floreant;

--
-- TOC entry 3353 (class 0 OID 0)
-- Dependencies: 284
-- Name: pizza_crust_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE pizza_crust_id_seq OWNED BY pizza_crust.id;


--
-- TOC entry 285 (class 1259 OID 18892)
-- Name: pizza_modifier_price; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE pizza_modifier_price (
    id integer NOT NULL,
    item_size integer
);


ALTER TABLE pizza_modifier_price OWNER TO floreant;

--
-- TOC entry 286 (class 1259 OID 18895)
-- Name: pizza_modifier_price_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE pizza_modifier_price_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pizza_modifier_price_id_seq OWNER TO floreant;

--
-- TOC entry 3354 (class 0 OID 0)
-- Dependencies: 286
-- Name: pizza_modifier_price_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE pizza_modifier_price_id_seq OWNED BY pizza_modifier_price.id;


--
-- TOC entry 287 (class 1259 OID 18897)
-- Name: pizza_price; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE pizza_price (
    id integer NOT NULL,
    price double precision,
    menu_item_size integer,
    crust integer,
    order_type integer
);


ALTER TABLE pizza_price OWNER TO floreant;

--
-- TOC entry 288 (class 1259 OID 18900)
-- Name: pizza_price_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE pizza_price_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pizza_price_id_seq OWNER TO floreant;

--
-- TOC entry 3355 (class 0 OID 0)
-- Dependencies: 288
-- Name: pizza_price_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE pizza_price_id_seq OWNED BY pizza_price.id;


--
-- TOC entry 289 (class 1259 OID 18902)
-- Name: printer_configuration; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE printer_configuration (
    id integer NOT NULL,
    receipt_printer character varying(255),
    kitchen_printer character varying(255),
    prwts boolean,
    prwtp boolean,
    pkwts boolean,
    pkwtp boolean,
    unpft boolean,
    unpfk boolean
);


ALTER TABLE printer_configuration OWNER TO floreant;

--
-- TOC entry 290 (class 1259 OID 18908)
-- Name: printer_group; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE printer_group (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    is_default boolean
);


ALTER TABLE printer_group OWNER TO floreant;

--
-- TOC entry 291 (class 1259 OID 18911)
-- Name: printer_group_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE printer_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE printer_group_id_seq OWNER TO floreant;

--
-- TOC entry 3356 (class 0 OID 0)
-- Dependencies: 291
-- Name: printer_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE printer_group_id_seq OWNED BY printer_group.id;


--
-- TOC entry 292 (class 1259 OID 18913)
-- Name: printer_group_printers; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE printer_group_printers (
    printer_id integer NOT NULL,
    printer_name character varying(255)
);


ALTER TABLE printer_group_printers OWNER TO floreant;

--
-- TOC entry 293 (class 1259 OID 18916)
-- Name: purchase_order; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE purchase_order (
    id integer NOT NULL,
    order_id character varying(30),
    name character varying(30)
);


ALTER TABLE purchase_order OWNER TO floreant;

--
-- TOC entry 294 (class 1259 OID 18919)
-- Name: purchase_order_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE purchase_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE purchase_order_id_seq OWNER TO floreant;

--
-- TOC entry 3357 (class 0 OID 0)
-- Dependencies: 294
-- Name: purchase_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE purchase_order_id_seq OWNED BY purchase_order.id;


--
-- TOC entry 295 (class 1259 OID 18921)
-- Name: recepie; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE recepie (
    id integer NOT NULL,
    menu_item integer
);


ALTER TABLE recepie OWNER TO floreant;

--
-- TOC entry 296 (class 1259 OID 18924)
-- Name: recepie_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE recepie_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recepie_id_seq OWNER TO floreant;

--
-- TOC entry 3358 (class 0 OID 0)
-- Dependencies: 296
-- Name: recepie_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE recepie_id_seq OWNED BY recepie.id;


--
-- TOC entry 297 (class 1259 OID 18926)
-- Name: recepie_item; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE recepie_item (
    id integer NOT NULL,
    percentage double precision,
    inventory_deductable boolean,
    inventory_item integer,
    recepie_id integer
);


ALTER TABLE recepie_item OWNER TO floreant;

--
-- TOC entry 298 (class 1259 OID 18929)
-- Name: recepie_item_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE recepie_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recepie_item_id_seq OWNER TO floreant;

--
-- TOC entry 3359 (class 0 OID 0)
-- Dependencies: 298
-- Name: recepie_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE recepie_item_id_seq OWNED BY recepie_item.id;


--
-- TOC entry 299 (class 1259 OID 18931)
-- Name: restaurant; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE restaurant (
    id integer NOT NULL,
    unique_id integer,
    name character varying(120),
    address_line1 character varying(60),
    address_line2 character varying(60),
    address_line3 character varying(60),
    zip_code character varying(10),
    telephone character varying(16),
    capacity integer,
    tables integer,
    cname character varying(20),
    csymbol character varying(10),
    sc_percentage double precision,
    gratuity_percentage double precision,
    ticket_footer character varying(60),
    price_includes_tax boolean,
    allow_modifier_max_exceed boolean
);


ALTER TABLE restaurant OWNER TO floreant;

--
-- TOC entry 300 (class 1259 OID 18934)
-- Name: restaurant_properties; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE restaurant_properties (
    id integer NOT NULL,
    property_value character varying(1000),
    property_name character varying(255) NOT NULL
);


ALTER TABLE restaurant_properties OWNER TO floreant;

--
-- TOC entry 301 (class 1259 OID 18940)
-- Name: shift; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE shift (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    shift_len bigint
);


ALTER TABLE shift OWNER TO floreant;

--
-- TOC entry 302 (class 1259 OID 18943)
-- Name: shift_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE shift_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shift_id_seq OWNER TO floreant;

--
-- TOC entry 3360 (class 0 OID 0)
-- Dependencies: 302
-- Name: shift_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE shift_id_seq OWNED BY shift.id;


--
-- TOC entry 303 (class 1259 OID 18945)
-- Name: shop_floor; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE shop_floor (
    id integer NOT NULL,
    name character varying(60),
    occupied boolean,
    image oid
);


ALTER TABLE shop_floor OWNER TO floreant;

--
-- TOC entry 304 (class 1259 OID 18948)
-- Name: shop_floor_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE shop_floor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shop_floor_id_seq OWNER TO floreant;

--
-- TOC entry 3361 (class 0 OID 0)
-- Dependencies: 304
-- Name: shop_floor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE shop_floor_id_seq OWNED BY shop_floor.id;


--
-- TOC entry 305 (class 1259 OID 18950)
-- Name: shop_floor_template; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE shop_floor_template (
    id integer NOT NULL,
    name character varying(60),
    default_floor boolean,
    main boolean,
    floor_id integer
);


ALTER TABLE shop_floor_template OWNER TO floreant;

--
-- TOC entry 306 (class 1259 OID 18953)
-- Name: shop_floor_template_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE shop_floor_template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shop_floor_template_id_seq OWNER TO floreant;

--
-- TOC entry 3362 (class 0 OID 0)
-- Dependencies: 306
-- Name: shop_floor_template_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE shop_floor_template_id_seq OWNED BY shop_floor_template.id;


--
-- TOC entry 307 (class 1259 OID 18955)
-- Name: shop_floor_template_properties; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE shop_floor_template_properties (
    id integer NOT NULL,
    property_value character varying(60),
    property_name character varying(255) NOT NULL
);


ALTER TABLE shop_floor_template_properties OWNER TO floreant;

--
-- TOC entry 308 (class 1259 OID 18958)
-- Name: shop_table; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE shop_table (
    id integer NOT NULL,
    name character varying(20),
    description character varying(60),
    capacity integer,
    x integer,
    y integer,
    floor_id integer,
    free boolean,
    serving boolean,
    booked boolean,
    dirty boolean,
    disable boolean
);


ALTER TABLE shop_table OWNER TO floreant;

--
-- TOC entry 309 (class 1259 OID 18961)
-- Name: shop_table_status; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE shop_table_status (
    id integer NOT NULL,
    table_status integer
);


ALTER TABLE shop_table_status OWNER TO floreant;

--
-- TOC entry 310 (class 1259 OID 18964)
-- Name: shop_table_type; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE shop_table_type (
    id integer NOT NULL,
    description character varying(120),
    name character varying(40)
);


ALTER TABLE shop_table_type OWNER TO floreant;

--
-- TOC entry 311 (class 1259 OID 18967)
-- Name: shop_table_type_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE shop_table_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE shop_table_type_id_seq OWNER TO floreant;

--
-- TOC entry 3363 (class 0 OID 0)
-- Dependencies: 311
-- Name: shop_table_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE shop_table_type_id_seq OWNED BY shop_table_type.id;


--
-- TOC entry 312 (class 1259 OID 18969)
-- Name: table_booking_info; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE table_booking_info (
    id integer NOT NULL,
    from_date timestamp without time zone,
    to_date timestamp without time zone,
    guest_count integer,
    status character varying(30),
    payment_status character varying(30),
    booking_confirm character varying(30),
    booking_charge double precision,
    remaining_balance double precision,
    paid_amount double precision,
    booking_id character varying(30),
    booking_type character varying(30),
    user_id integer,
    customer_id integer
);


ALTER TABLE table_booking_info OWNER TO floreant;

--
-- TOC entry 313 (class 1259 OID 18972)
-- Name: table_booking_info_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE table_booking_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE table_booking_info_id_seq OWNER TO floreant;

--
-- TOC entry 3364 (class 0 OID 0)
-- Dependencies: 313
-- Name: table_booking_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE table_booking_info_id_seq OWNED BY table_booking_info.id;


--
-- TOC entry 314 (class 1259 OID 18974)
-- Name: table_booking_mapping; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE table_booking_mapping (
    booking_id integer NOT NULL,
    table_id integer NOT NULL
);


ALTER TABLE table_booking_mapping OWNER TO floreant;

--
-- TOC entry 315 (class 1259 OID 18977)
-- Name: table_ticket_num; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE table_ticket_num (
    shop_table_status_id integer NOT NULL,
    ticket_id integer,
    user_id integer,
    user_name character varying(30)
);


ALTER TABLE table_ticket_num OWNER TO floreant;

--
-- TOC entry 316 (class 1259 OID 18980)
-- Name: table_type_relation; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE table_type_relation (
    table_id integer NOT NULL,
    type_id integer NOT NULL
);


ALTER TABLE table_type_relation OWNER TO floreant;

--
-- TOC entry 317 (class 1259 OID 18983)
-- Name: tax; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE tax (
    id integer NOT NULL,
    name character varying(20) NOT NULL,
    rate double precision
);


ALTER TABLE tax OWNER TO floreant;

--
-- TOC entry 318 (class 1259 OID 18986)
-- Name: tax_group; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE tax_group (
    id character varying(128) NOT NULL,
    name character varying(20) NOT NULL
);


ALTER TABLE tax_group OWNER TO floreant;

--
-- TOC entry 319 (class 1259 OID 18989)
-- Name: tax_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE tax_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tax_id_seq OWNER TO floreant;

--
-- TOC entry 3365 (class 0 OID 0)
-- Dependencies: 319
-- Name: tax_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE tax_id_seq OWNED BY tax.id;


--
-- TOC entry 321 (class 1259 OID 18997)
-- Name: terminal_printers; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE terminal_printers (
    id integer NOT NULL,
    terminal_id integer,
    printer_name character varying(60),
    virtual_printer_id integer
);


ALTER TABLE terminal_printers OWNER TO floreant;

--
-- TOC entry 322 (class 1259 OID 19000)
-- Name: terminal_printers_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE terminal_printers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE terminal_printers_id_seq OWNER TO floreant;

--
-- TOC entry 3366 (class 0 OID 0)
-- Dependencies: 322
-- Name: terminal_printers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE terminal_printers_id_seq OWNED BY terminal_printers.id;


--
-- TOC entry 323 (class 1259 OID 19002)
-- Name: terminal_properties; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE terminal_properties (
    id integer NOT NULL,
    property_value character varying(255),
    property_name character varying(255) NOT NULL
);


ALTER TABLE terminal_properties OWNER TO floreant;

--
-- TOC entry 325 (class 1259 OID 19014)
-- Name: ticket_discount; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_discount (
    id integer NOT NULL,
    discount_id integer,
    name character varying(30),
    type integer,
    auto_apply boolean,
    minimum_amount integer,
    value double precision,
    ticket_id integer
);


ALTER TABLE ticket_discount OWNER TO floreant;

--
-- TOC entry 326 (class 1259 OID 19017)
-- Name: ticket_discount_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE ticket_discount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ticket_discount_id_seq OWNER TO floreant;

--
-- TOC entry 3367 (class 0 OID 0)
-- Dependencies: 326
-- Name: ticket_discount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE ticket_discount_id_seq OWNED BY ticket_discount.id;


--
-- TOC entry 357 (class 1259 OID 20153)
-- Name: ticket_folio_complete; Type: VIEW; Schema: public; Owner: floreant
--

CREATE VIEW ticket_folio_complete AS
 SELECT t.id,
    t.daily_folio,
    t.folio_date,
    t.branch_key,
    t.total_price,
    t.paid_amount,
    t.create_date,
    to_char((t.folio_date)::timestamp with time zone, 'DD/MM/YYYY'::text) AS folio_date_txt,
    lpad((t.daily_folio)::text, 4, '0'::text) AS folio_display,
    COALESCE(term.location, 'DEFAULT'::character varying) AS sucursal_completa,
    term.name AS terminal_name,
    to_char((t.folio_date)::timestamp with time zone, 'YYYY-MM'::text) AS periodo_mes,
    date_part('hour'::text, t.create_date) AS hora_venta,
    date_part('dow'::text, t.folio_date) AS dia_semana,
        CASE
            WHEN t.voided THEN 'CANCELADO'::text
            WHEN (t.paid_amount > (0)::double precision) THEN 'PAGADO'::text
            ELSE 'PENDIENTE'::text
        END AS status_simple
   FROM (ticket t
     LEFT JOIN terminal term ON ((t.terminal_id = term.id)));


ALTER TABLE ticket_folio_complete OWNER TO floreant;

--
-- TOC entry 327 (class 1259 OID 19019)
-- Name: ticket_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE ticket_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ticket_id_seq OWNER TO floreant;

--
-- TOC entry 3369 (class 0 OID 0)
-- Dependencies: 327
-- Name: ticket_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE ticket_id_seq OWNED BY ticket.id;


--
-- TOC entry 328 (class 1259 OID 19021)
-- Name: ticket_item; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_item (
    id integer NOT NULL,
    item_id integer,
    item_count integer,
    item_quantity double precision,
    item_name character varying(120),
    item_unit_name character varying(20),
    group_name character varying(120),
    category_name character varying(120),
    item_price double precision,
    item_tax_rate double precision,
    sub_total double precision,
    sub_total_without_modifiers double precision,
    discount double precision,
    tax_amount double precision,
    tax_amount_without_modifiers double precision,
    total_price double precision,
    total_price_without_modifiers double precision,
    beverage boolean,
    inventory_handled boolean,
    print_to_kitchen boolean,
    treat_as_seat boolean,
    seat_number integer,
    fractional_unit boolean,
    has_modiiers boolean,
    printed_to_kitchen boolean,
    status character varying(255),
    stock_amount_adjusted boolean,
    pizza_type boolean,
    size_modifier_id integer,
    ticket_id integer,
    pg_id integer,
    pizza_section_mode integer
);


ALTER TABLE ticket_item OWNER TO floreant;

--
-- TOC entry 329 (class 1259 OID 19027)
-- Name: ticket_item_addon_relation; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_item_addon_relation (
    ticket_item_id integer NOT NULL,
    modifier_id integer NOT NULL,
    list_order integer NOT NULL
);


ALTER TABLE ticket_item_addon_relation OWNER TO floreant;

--
-- TOC entry 330 (class 1259 OID 19030)
-- Name: ticket_item_cooking_instruction; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_item_cooking_instruction (
    ticket_item_id integer NOT NULL,
    description character varying(60),
    printedtokitchen boolean,
    item_order integer NOT NULL
);


ALTER TABLE ticket_item_cooking_instruction OWNER TO floreant;

--
-- TOC entry 331 (class 1259 OID 19033)
-- Name: ticket_item_discount; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_item_discount (
    id integer NOT NULL,
    discount_id integer,
    name character varying(30),
    type integer,
    auto_apply boolean,
    minimum_quantity integer,
    value double precision,
    amount double precision,
    ticket_itemid integer
);


ALTER TABLE ticket_item_discount OWNER TO floreant;

--
-- TOC entry 332 (class 1259 OID 19036)
-- Name: ticket_item_discount_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE ticket_item_discount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ticket_item_discount_id_seq OWNER TO floreant;

--
-- TOC entry 3370 (class 0 OID 0)
-- Dependencies: 332
-- Name: ticket_item_discount_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE ticket_item_discount_id_seq OWNED BY ticket_item_discount.id;


--
-- TOC entry 333 (class 1259 OID 19038)
-- Name: ticket_item_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE ticket_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ticket_item_id_seq OWNER TO floreant;

--
-- TOC entry 3371 (class 0 OID 0)
-- Dependencies: 333
-- Name: ticket_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE ticket_item_id_seq OWNED BY ticket_item.id;


--
-- TOC entry 334 (class 1259 OID 19040)
-- Name: ticket_item_modifier; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_item_modifier (
    id integer NOT NULL,
    item_id integer,
    group_id integer,
    item_count integer,
    modifier_name character varying(120),
    modifier_price double precision,
    modifier_tax_rate double precision,
    modifier_type integer,
    subtotal_price double precision,
    total_price double precision,
    tax_amount double precision,
    info_only boolean,
    section_name character varying(20),
    multiplier_name character varying(20),
    print_to_kitchen boolean,
    section_wise_pricing boolean,
    status character varying(10),
    printed_to_kitchen boolean,
    ticket_item_id integer
);


ALTER TABLE ticket_item_modifier OWNER TO floreant;

--
-- TOC entry 335 (class 1259 OID 19043)
-- Name: ticket_item_modifier_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE ticket_item_modifier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ticket_item_modifier_id_seq OWNER TO floreant;

--
-- TOC entry 3372 (class 0 OID 0)
-- Dependencies: 335
-- Name: ticket_item_modifier_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE ticket_item_modifier_id_seq OWNED BY ticket_item_modifier.id;


--
-- TOC entry 336 (class 1259 OID 19045)
-- Name: ticket_item_modifier_relation; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_item_modifier_relation (
    ticket_item_id integer NOT NULL,
    modifier_id integer NOT NULL,
    list_order integer NOT NULL
);


ALTER TABLE ticket_item_modifier_relation OWNER TO floreant;

--
-- TOC entry 337 (class 1259 OID 19048)
-- Name: ticket_properties; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_properties (
    id integer NOT NULL,
    property_value character varying(1000),
    property_name character varying(255) NOT NULL
);


ALTER TABLE ticket_properties OWNER TO floreant;

--
-- TOC entry 338 (class 1259 OID 19054)
-- Name: ticket_table_num; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE ticket_table_num (
    ticket_id integer NOT NULL,
    table_id integer
);


ALTER TABLE ticket_table_num OWNER TO floreant;

--
-- TOC entry 339 (class 1259 OID 19057)
-- Name: transaction_properties; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE transaction_properties (
    id integer NOT NULL,
    property_value character varying(255),
    property_name character varying(255) NOT NULL
);


ALTER TABLE transaction_properties OWNER TO floreant;

--
-- TOC entry 340 (class 1259 OID 19063)
-- Name: transactions; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE transactions (
    id integer NOT NULL,
    payment_type character varying(30) NOT NULL,
    global_id character varying(16),
    transaction_time timestamp without time zone,
    amount double precision,
    tips_amount double precision,
    tips_exceed_amount double precision,
    tender_amount double precision,
    transaction_type character varying(30) NOT NULL,
    custom_payment_name character varying(60),
    custom_payment_ref character varying(120),
    custom_payment_field_name character varying(60),
    payment_sub_type character varying(40) NOT NULL,
    captured boolean,
    voided boolean,
    authorizable boolean,
    card_holder_name character varying(60),
    card_number character varying(40),
    card_auth_code character varying(30),
    card_type character varying(20),
    card_transaction_id character varying(255),
    card_merchant_gateway character varying(60),
    card_reader character varying(30),
    card_aid character varying(120),
    card_arqc character varying(120),
    card_ext_data character varying(255),
    gift_cert_number character varying(64),
    gift_cert_face_value double precision,
    gift_cert_paid_amount double precision,
    gift_cert_cash_back_amount double precision,
    drawer_resetted boolean,
    note character varying(255),
    terminal_id integer,
    ticket_id integer,
    user_id integer,
    payout_reason_id integer,
    payout_recepient_id integer
);


ALTER TABLE transactions OWNER TO floreant;

--
-- TOC entry 341 (class 1259 OID 19069)
-- Name: transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE transactions_id_seq OWNER TO floreant;

--
-- TOC entry 3373 (class 0 OID 0)
-- Dependencies: 341
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE transactions_id_seq OWNED BY transactions.id;


--
-- TOC entry 342 (class 1259 OID 19071)
-- Name: user_permission; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE user_permission (
    name character varying(40) NOT NULL
);


ALTER TABLE user_permission OWNER TO floreant;

--
-- TOC entry 343 (class 1259 OID 19074)
-- Name: user_type; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE user_type (
    id integer NOT NULL,
    p_name character varying(60)
);


ALTER TABLE user_type OWNER TO floreant;

--
-- TOC entry 344 (class 1259 OID 19077)
-- Name: user_type_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE user_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE user_type_id_seq OWNER TO floreant;

--
-- TOC entry 3374 (class 0 OID 0)
-- Dependencies: 344
-- Name: user_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE user_type_id_seq OWNED BY user_type.id;


--
-- TOC entry 345 (class 1259 OID 19079)
-- Name: user_user_permission; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE user_user_permission (
    permissionid integer NOT NULL,
    elt character varying(40) NOT NULL
);


ALTER TABLE user_user_permission OWNER TO floreant;

--
-- TOC entry 346 (class 1259 OID 19082)
-- Name: users; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE users (
    auto_id integer NOT NULL,
    user_id integer,
    user_pass character varying(16) NOT NULL,
    first_name character varying(30),
    last_name character varying(30),
    ssn character varying(30),
    cost_per_hour double precision,
    clocked_in boolean,
    last_clock_in_time timestamp without time zone,
    last_clock_out_time timestamp without time zone,
    phone_no character varying(20),
    is_driver boolean,
    available_for_delivery boolean,
    active boolean,
    shift_id integer,
    currentterminal integer,
    n_user_type integer
);


ALTER TABLE users OWNER TO floreant;

--
-- TOC entry 347 (class 1259 OID 19085)
-- Name: users_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE users_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_auto_id_seq OWNER TO floreant;

--
-- TOC entry 3375 (class 0 OID 0)
-- Dependencies: 347
-- Name: users_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE users_auto_id_seq OWNED BY users.auto_id;


--
-- TOC entry 348 (class 1259 OID 19087)
-- Name: virtual_printer; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE virtual_printer (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    type integer,
    priority integer,
    enabled boolean
);


ALTER TABLE virtual_printer OWNER TO floreant;

--
-- TOC entry 349 (class 1259 OID 19090)
-- Name: virtual_printer_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE virtual_printer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE virtual_printer_id_seq OWNER TO floreant;

--
-- TOC entry 3376 (class 0 OID 0)
-- Dependencies: 349
-- Name: virtual_printer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE virtual_printer_id_seq OWNED BY virtual_printer.id;


--
-- TOC entry 350 (class 1259 OID 19092)
-- Name: virtualprinter_order_type; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE virtualprinter_order_type (
    printer_id integer NOT NULL,
    order_type character varying(255)
);


ALTER TABLE virtualprinter_order_type OWNER TO floreant;

--
-- TOC entry 351 (class 1259 OID 19095)
-- Name: void_reasons; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE void_reasons (
    id integer NOT NULL,
    reason_text character varying(255)
);


ALTER TABLE void_reasons OWNER TO floreant;

--
-- TOC entry 352 (class 1259 OID 19098)
-- Name: void_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE void_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE void_reasons_id_seq OWNER TO floreant;

--
-- TOC entry 3377 (class 0 OID 0)
-- Dependencies: 352
-- Name: void_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE void_reasons_id_seq OWNED BY void_reasons.id;


--
-- TOC entry 353 (class 1259 OID 19100)
-- Name: zip_code_vs_delivery_charge; Type: TABLE; Schema: public; Owner: floreant
--

CREATE TABLE zip_code_vs_delivery_charge (
    auto_id integer NOT NULL,
    zip_code character varying(10) NOT NULL,
    delivery_charge double precision NOT NULL
);


ALTER TABLE zip_code_vs_delivery_charge OWNER TO floreant;

--
-- TOC entry 354 (class 1259 OID 19103)
-- Name: zip_code_vs_delivery_charge_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: floreant
--

CREATE SEQUENCE zip_code_vs_delivery_charge_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE zip_code_vs_delivery_charge_auto_id_seq OWNER TO floreant;

--
-- TOC entry 3378 (class 0 OID 0)
-- Dependencies: 354
-- Name: zip_code_vs_delivery_charge_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: floreant
--

ALTER SEQUENCE zip_code_vs_delivery_charge_auto_id_seq OWNED BY zip_code_vs_delivery_charge.auto_id;


--
-- TOC entry 2574 (class 2604 OID 19105)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY action_history ALTER COLUMN id SET DEFAULT nextval('action_history_id_seq'::regclass);


--
-- TOC entry 2575 (class 2604 OID 19106)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY attendence_history ALTER COLUMN id SET DEFAULT nextval('attendence_history_id_seq'::regclass);


--
-- TOC entry 2576 (class 2604 OID 19107)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY cash_drawer ALTER COLUMN id SET DEFAULT nextval('cash_drawer_id_seq'::regclass);


--
-- TOC entry 2577 (class 2604 OID 19108)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY cash_drawer_reset_history ALTER COLUMN id SET DEFAULT nextval('cash_drawer_reset_history_id_seq'::regclass);


--
-- TOC entry 2578 (class 2604 OID 19109)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY cooking_instruction ALTER COLUMN id SET DEFAULT nextval('cooking_instruction_id_seq'::regclass);


--
-- TOC entry 2579 (class 2604 OID 19110)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY coupon_and_discount ALTER COLUMN id SET DEFAULT nextval('coupon_and_discount_id_seq'::regclass);


--
-- TOC entry 2580 (class 2604 OID 19111)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY currency ALTER COLUMN id SET DEFAULT nextval('currency_id_seq'::regclass);


--
-- TOC entry 2581 (class 2604 OID 19112)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY currency_balance ALTER COLUMN id SET DEFAULT nextval('currency_balance_id_seq'::regclass);


--
-- TOC entry 2582 (class 2604 OID 19113)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY custom_payment ALTER COLUMN id SET DEFAULT nextval('custom_payment_id_seq'::regclass);


--
-- TOC entry 2583 (class 2604 OID 19114)
-- Name: auto_id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY customer ALTER COLUMN auto_id SET DEFAULT nextval('customer_auto_id_seq'::regclass);


--
-- TOC entry 2584 (class 2604 OID 19115)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY data_update_info ALTER COLUMN id SET DEFAULT nextval('data_update_info_id_seq'::regclass);


--
-- TOC entry 2585 (class 2604 OID 19116)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY delivery_address ALTER COLUMN id SET DEFAULT nextval('delivery_address_id_seq'::regclass);


--
-- TOC entry 2586 (class 2604 OID 19117)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY delivery_charge ALTER COLUMN id SET DEFAULT nextval('delivery_charge_id_seq'::regclass);


--
-- TOC entry 2587 (class 2604 OID 19118)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY delivery_configuration ALTER COLUMN id SET DEFAULT nextval('delivery_configuration_id_seq'::regclass);


--
-- TOC entry 2588 (class 2604 OID 19119)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY delivery_instruction ALTER COLUMN id SET DEFAULT nextval('delivery_instruction_id_seq'::regclass);


--
-- TOC entry 2589 (class 2604 OID 19120)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY drawer_assigned_history ALTER COLUMN id SET DEFAULT nextval('drawer_assigned_history_id_seq'::regclass);


--
-- TOC entry 2590 (class 2604 OID 19121)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY drawer_pull_report ALTER COLUMN id SET DEFAULT nextval('drawer_pull_report_id_seq'::regclass);


--
-- TOC entry 2591 (class 2604 OID 19122)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY employee_in_out_history ALTER COLUMN id SET DEFAULT nextval('employee_in_out_history_id_seq'::regclass);


--
-- TOC entry 2592 (class 2604 OID 19123)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY global_config ALTER COLUMN id SET DEFAULT nextval('global_config_id_seq'::regclass);


--
-- TOC entry 2593 (class 2604 OID 19124)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY gratuity ALTER COLUMN id SET DEFAULT nextval('gratuity_id_seq'::regclass);


--
-- TOC entry 2594 (class 2604 OID 19125)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY guest_check_print ALTER COLUMN id SET DEFAULT nextval('guest_check_print_id_seq'::regclass);


--
-- TOC entry 2595 (class 2604 OID 19126)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY inventory_group ALTER COLUMN id SET DEFAULT nextval('inventory_group_id_seq'::regclass);


--
-- TOC entry 2596 (class 2604 OID 19127)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY inventory_item ALTER COLUMN id SET DEFAULT nextval('inventory_item_id_seq'::regclass);


--
-- TOC entry 2597 (class 2604 OID 19128)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY inventory_location ALTER COLUMN id SET DEFAULT nextval('inventory_location_id_seq'::regclass);


--
-- TOC entry 2598 (class 2604 OID 19129)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY inventory_meta_code ALTER COLUMN id SET DEFAULT nextval('inventory_meta_code_id_seq'::regclass);


--
-- TOC entry 2599 (class 2604 OID 19130)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY inventory_transaction ALTER COLUMN id SET DEFAULT nextval('inventory_transaction_id_seq'::regclass);


--
-- TOC entry 2600 (class 2604 OID 19131)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY inventory_unit ALTER COLUMN id SET DEFAULT nextval('inventory_unit_id_seq'::regclass);


--
-- TOC entry 2601 (class 2604 OID 19132)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY inventory_vendor ALTER COLUMN id SET DEFAULT nextval('inventory_vendor_id_seq'::regclass);


--
-- TOC entry 2602 (class 2604 OID 19133)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY inventory_warehouse ALTER COLUMN id SET DEFAULT nextval('inventory_warehouse_id_seq'::regclass);


--
-- TOC entry 2604 (class 2604 OID 19134)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY kitchen_ticket ALTER COLUMN id SET DEFAULT nextval('kitchen_ticket_id_seq'::regclass);


--
-- TOC entry 2605 (class 2604 OID 19135)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY kitchen_ticket_item ALTER COLUMN id SET DEFAULT nextval('kitchen_ticket_item_id_seq'::regclass);


--
-- TOC entry 2606 (class 2604 OID 19136)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY menu_category ALTER COLUMN id SET DEFAULT nextval('menu_category_id_seq'::regclass);


--
-- TOC entry 2607 (class 2604 OID 19137)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY menu_group ALTER COLUMN id SET DEFAULT nextval('menu_group_id_seq'::regclass);


--
-- TOC entry 2608 (class 2604 OID 19138)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY menu_item ALTER COLUMN id SET DEFAULT nextval('menu_item_id_seq'::regclass);


--
-- TOC entry 2609 (class 2604 OID 19139)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY menu_item_size ALTER COLUMN id SET DEFAULT nextval('menu_item_size_id_seq'::regclass);


--
-- TOC entry 2610 (class 2604 OID 19140)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY menu_modifier ALTER COLUMN id SET DEFAULT nextval('menu_modifier_id_seq'::regclass);


--
-- TOC entry 2611 (class 2604 OID 19141)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY menu_modifier_group ALTER COLUMN id SET DEFAULT nextval('menu_modifier_group_id_seq'::regclass);


--
-- TOC entry 2612 (class 2604 OID 19142)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY menuitem_modifiergroup ALTER COLUMN id SET DEFAULT nextval('menuitem_modifiergroup_id_seq'::regclass);


--
-- TOC entry 2613 (class 2604 OID 19143)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY menuitem_shift ALTER COLUMN id SET DEFAULT nextval('menuitem_shift_id_seq'::regclass);


--
-- TOC entry 2614 (class 2604 OID 19144)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY modifier_multiplier_price ALTER COLUMN id SET DEFAULT nextval('modifier_multiplier_price_id_seq'::regclass);


--
-- TOC entry 2615 (class 2604 OID 19145)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY order_type ALTER COLUMN id SET DEFAULT nextval('order_type_id_seq'::regclass);


--
-- TOC entry 2616 (class 2604 OID 19146)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY packaging_unit ALTER COLUMN id SET DEFAULT nextval('packaging_unit_id_seq'::regclass);


--
-- TOC entry 2617 (class 2604 OID 19147)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY payout_reasons ALTER COLUMN id SET DEFAULT nextval('payout_reasons_id_seq'::regclass);


--
-- TOC entry 2618 (class 2604 OID 19148)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY payout_recepients ALTER COLUMN id SET DEFAULT nextval('payout_recepients_id_seq'::regclass);


--
-- TOC entry 2619 (class 2604 OID 19149)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY pizza_crust ALTER COLUMN id SET DEFAULT nextval('pizza_crust_id_seq'::regclass);


--
-- TOC entry 2620 (class 2604 OID 19150)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY pizza_modifier_price ALTER COLUMN id SET DEFAULT nextval('pizza_modifier_price_id_seq'::regclass);


--
-- TOC entry 2621 (class 2604 OID 19151)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY pizza_price ALTER COLUMN id SET DEFAULT nextval('pizza_price_id_seq'::regclass);


--
-- TOC entry 2622 (class 2604 OID 19152)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY printer_group ALTER COLUMN id SET DEFAULT nextval('printer_group_id_seq'::regclass);


--
-- TOC entry 2623 (class 2604 OID 19153)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY purchase_order ALTER COLUMN id SET DEFAULT nextval('purchase_order_id_seq'::regclass);


--
-- TOC entry 2624 (class 2604 OID 19154)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY recepie ALTER COLUMN id SET DEFAULT nextval('recepie_id_seq'::regclass);


--
-- TOC entry 2625 (class 2604 OID 19155)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY recepie_item ALTER COLUMN id SET DEFAULT nextval('recepie_item_id_seq'::regclass);


--
-- TOC entry 2626 (class 2604 OID 19156)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY shift ALTER COLUMN id SET DEFAULT nextval('shift_id_seq'::regclass);


--
-- TOC entry 2627 (class 2604 OID 19157)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY shop_floor ALTER COLUMN id SET DEFAULT nextval('shop_floor_id_seq'::regclass);


--
-- TOC entry 2628 (class 2604 OID 19158)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY shop_floor_template ALTER COLUMN id SET DEFAULT nextval('shop_floor_template_id_seq'::regclass);


--
-- TOC entry 2629 (class 2604 OID 19159)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY shop_table_type ALTER COLUMN id SET DEFAULT nextval('shop_table_type_id_seq'::regclass);


--
-- TOC entry 2630 (class 2604 OID 19160)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY table_booking_info ALTER COLUMN id SET DEFAULT nextval('table_booking_info_id_seq'::regclass);


--
-- TOC entry 2631 (class 2604 OID 19161)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY tax ALTER COLUMN id SET DEFAULT nextval('tax_id_seq'::regclass);


--
-- TOC entry 2632 (class 2604 OID 19162)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY terminal_printers ALTER COLUMN id SET DEFAULT nextval('terminal_printers_id_seq'::regclass);


--
-- TOC entry 2633 (class 2604 OID 19163)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY ticket ALTER COLUMN id SET DEFAULT nextval('ticket_id_seq'::regclass);


--
-- TOC entry 2635 (class 2604 OID 19164)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY ticket_discount ALTER COLUMN id SET DEFAULT nextval('ticket_discount_id_seq'::regclass);


--
-- TOC entry 2636 (class 2604 OID 19165)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY ticket_item ALTER COLUMN id SET DEFAULT nextval('ticket_item_id_seq'::regclass);


--
-- TOC entry 2637 (class 2604 OID 19166)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY ticket_item_discount ALTER COLUMN id SET DEFAULT nextval('ticket_item_discount_id_seq'::regclass);


--
-- TOC entry 2638 (class 2604 OID 19167)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY ticket_item_modifier ALTER COLUMN id SET DEFAULT nextval('ticket_item_modifier_id_seq'::regclass);


--
-- TOC entry 2639 (class 2604 OID 19168)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY transactions ALTER COLUMN id SET DEFAULT nextval('transactions_id_seq'::regclass);


--
-- TOC entry 2640 (class 2604 OID 19169)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY user_type ALTER COLUMN id SET DEFAULT nextval('user_type_id_seq'::regclass);


--
-- TOC entry 2641 (class 2604 OID 19170)
-- Name: auto_id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY users ALTER COLUMN auto_id SET DEFAULT nextval('users_auto_id_seq'::regclass);


--
-- TOC entry 2642 (class 2604 OID 19171)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY virtual_printer ALTER COLUMN id SET DEFAULT nextval('virtual_printer_id_seq'::regclass);


--
-- TOC entry 2643 (class 2604 OID 19172)
-- Name: id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY void_reasons ALTER COLUMN id SET DEFAULT nextval('void_reasons_id_seq'::regclass);


--
-- TOC entry 2644 (class 2604 OID 19173)
-- Name: auto_id; Type: DEFAULT; Schema: public; Owner: floreant
--

ALTER TABLE ONLY zip_code_vs_delivery_charge ALTER COLUMN auto_id SET DEFAULT nextval('zip_code_vs_delivery_charge_auto_id_seq'::regclass);


--
-- TOC entry 3301 (class 0 OID 0)
-- Dependencies: 6
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- TOC entry 3303 (class 0 OID 0)
-- Dependencies: 372
-- Name: assign_daily_folio(); Type: ACL; Schema: public; Owner: floreant
--

REVOKE ALL ON FUNCTION assign_daily_folio() FROM PUBLIC;
REVOKE ALL ON FUNCTION assign_daily_folio() FROM floreant;
GRANT ALL ON FUNCTION assign_daily_folio() TO floreant;
GRANT ALL ON FUNCTION assign_daily_folio() TO PUBLIC;


--
-- TOC entry 3304 (class 0 OID 0)
-- Dependencies: 373
-- Name: get_daily_stats(date); Type: ACL; Schema: public; Owner: floreant
--

REVOKE ALL ON FUNCTION get_daily_stats(p_date date) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_daily_stats(p_date date) FROM floreant;
GRANT ALL ON FUNCTION get_daily_stats(p_date date) TO floreant;
GRANT ALL ON FUNCTION get_daily_stats(p_date date) TO PUBLIC;


--
-- TOC entry 3305 (class 0 OID 0)
-- Dependencies: 374
-- Name: get_ticket_folio_info(integer); Type: ACL; Schema: public; Owner: floreant
--

REVOKE ALL ON FUNCTION get_ticket_folio_info(p_ticket_id integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_ticket_folio_info(p_ticket_id integer) FROM floreant;
GRANT ALL ON FUNCTION get_ticket_folio_info(p_ticket_id integer) TO floreant;
GRANT ALL ON FUNCTION get_ticket_folio_info(p_ticket_id integer) TO PUBLIC;


--
-- TOC entry 3306 (class 0 OID 0)
-- Dependencies: 375
-- Name: reset_daily_folio_smart(text); Type: ACL; Schema: public; Owner: floreant
--

REVOKE ALL ON FUNCTION reset_daily_folio_smart(p_branch text) FROM PUBLIC;
REVOKE ALL ON FUNCTION reset_daily_folio_smart(p_branch text) FROM floreant;
GRANT ALL ON FUNCTION reset_daily_folio_smart(p_branch text) TO floreant;
GRANT ALL ON FUNCTION reset_daily_folio_smart(p_branch text) TO PUBLIC;


--
-- TOC entry 3317 (class 0 OID 0)
-- Dependencies: 355
-- Name: daily_folio_counter; Type: ACL; Schema: public; Owner: floreant
--

REVOKE ALL ON TABLE daily_folio_counter FROM PUBLIC;
REVOKE ALL ON TABLE daily_folio_counter FROM floreant;
GRANT ALL ON TABLE daily_folio_counter TO floreant;


--
-- TOC entry 3337 (class 0 OID 0)
-- Dependencies: 356
-- Name: kds_orders_enhanced; Type: ACL; Schema: public; Owner: floreant
--

REVOKE ALL ON TABLE kds_orders_enhanced FROM PUBLIC;
REVOKE ALL ON TABLE kds_orders_enhanced FROM floreant;
GRANT ALL ON TABLE kds_orders_enhanced TO floreant;


--
-- TOC entry 3368 (class 0 OID 0)
-- Dependencies: 357
-- Name: ticket_folio_complete; Type: ACL; Schema: public; Owner: floreant
--

REVOKE ALL ON TABLE ticket_folio_complete FROM PUBLIC;
REVOKE ALL ON TABLE ticket_folio_complete FROM floreant;
GRANT ALL ON TABLE ticket_folio_complete TO floreant;


-- Completed on 2025-08-30 11:39:05

--
-- PostgreSQL database dump complete
--

