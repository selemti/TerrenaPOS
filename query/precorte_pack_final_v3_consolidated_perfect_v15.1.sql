-- Transacción 1: Verificaciones iniciales
DO $$
BEGIN
    -- Añadir user_id a transactions si no existe
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'transactions' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.transactions 
        ADD COLUMN user_id integer;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al añadir user_id a transactions: %', SQLERRM;
END $$;

DO $$
BEGIN
    -- Añadir modified_time a ticket si no existe
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'ticket' 
        AND column_name = 'modified_time'
    ) THEN
        ALTER TABLE public.ticket 
        ADD COLUMN modified_time timestamp with time zone;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al añadir modified_time a ticket: %', SQLERRM;
END $$;

DO $$
BEGIN
    -- Asegurar que terminal_id=9939 existe
    INSERT INTO public.terminal (id, name, location, active, has_cash_drawer, opening_balance)
    SELECT 9939, 'Terminal 9939', 'SelemTI', true, true, 0.00
    WHERE NOT EXISTS (SELECT 1 FROM public.terminal WHERE id = 9939);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al insertar terminal_id=9939: %', SQLERRM;
END $$;

-- Transacción 2: Crear tablas
BEGIN;
-- Configuración general
CREATE TABLE IF NOT EXISTS public.pc_cfg (
    key text PRIMARY KEY,
    value text NOT NULL,
    CONSTRAINT valid_payouts CHECK (key <> 'payouts_in_dpr' OR value IN ('0','1'))
);

-- Seed seguro para payouts_in_dpr (por defecto '0' = DPR bruto)
INSERT INTO public.pc_cfg (key, value)
SELECT 'payouts_in_dpr', '0'
WHERE NOT EXISTS (SELECT 1 FROM public.pc_cfg WHERE key = 'payouts_in_dpr');

-- Precorte (captura de conteo + declarados + estado)
CREATE TABLE IF NOT EXISTS public.pc_precorte (
    id bigserial PRIMARY KEY,
    terminal_id integer NOT NULL,
    terminal_location text,
    cashier_user_id integer NOT NULL,
    from_ts timestamptz NOT NULL,
    to_ts timestamptz NOT NULL,
    opening_cash numeric(12,2) DEFAULT 0,
    system_cash numeric(12,2) DEFAULT 0,
    system_credit numeric(12,2) DEFAULT 0,
    system_debit numeric(12,2) DEFAULT 0,
    system_custom numeric(12,2) DEFAULT 0,
    system_payouts numeric(12,2) DEFAULT 0,
    counted_cash numeric(12,2) DEFAULT 0,
    declared_credit numeric(12,2) DEFAULT 0,
    declared_debit numeric(12,2) DEFAULT 0,
    declared_custom numeric(12,2) DEFAULT 0,
    status text NOT NULL CHECK (status IN ('PENDING', 'SUBMITTED', 'RECONCILED', 'DISCREPANCY', 'CLOSED')),
    created_by integer NOT NULL,
    notes text,
    supervisor_id integer,
    dpr_id bigint,
    post_cut_status text DEFAULT 'PENDING' CHECK (post_cut_status IN ('PENDING', 'RECONCILED', 'DISCREPANCY')),
    post_cut_diffs jsonb,
    client_ip inet,
    CONSTRAINT non_negative_declared CHECK (
        counted_cash >= 0 AND declared_credit >= 0 AND
        declared_debit >= 0 AND declared_custom >= 0
    ),
    CONSTRAINT pc_precorte_dpr_fk FOREIGN KEY (dpr_id)
        REFERENCES public.drawer_pull_report(id)
        ON DELETE SET NULL DEFERRABLE INITIALLY IMMEDIATE
);

-- Índice único parcial para evitar precortes duplicados en estados activos
CREATE UNIQUE INDEX IF NOT EXISTS idx_pc_precorte_unique_active
    ON public.pc_precorte (terminal_id, cashier_user_id, to_ts)
    WHERE status IN ('PENDING', 'SUBMITTED');

-- Conteo rápido por denominación
CREATE TABLE IF NOT EXISTS public.pc_precorte_cash_count (
    precorte_id bigint NOT NULL,
    denom numeric(12,2) NOT NULL,
    qty integer NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    CONSTRAINT pc_precorte_cash_count_pk PRIMARY KEY (precorte_id, denom),
    CONSTRAINT pc_precorte_cash_count_precorte_id_fkey
        FOREIGN KEY (precorte_id) REFERENCES public.pc_precorte (id) ON DELETE CASCADE,
    CONSTRAINT valid_count CHECK (subtotal = denom * qty)
);

-- Materialización diaria para dashboard
CREATE TABLE IF NOT EXISTS public.pc_post_corte_kpis_daily (
    precorte_id bigint PRIMARY KEY,
    terminal_id integer NOT NULL,
    cashier_user_id integer NOT NULL,
    from_ts timestamptz NOT NULL,
    to_ts timestamptz NOT NULL,
    dpr_id bigint,
    report_time timestamptz,
    minutes_to_cut numeric,
    cash_diff numeric,
    credit_diff numeric,
    debit_diff numeric,
    custom_diff numeric,
    voided_tickets_cnt integer,
    total_discounts numeric,
    supervisor_id integer,
    materialized_date date NOT NULL
);
COMMIT;

-- Transacción 3: Crear índices
BEGIN;
-- Transacciones: ventana por usuario/terminal/tiempo
CREATE INDEX IF NOT EXISTS idx_transactions_user_term_time
    ON public.transactions (user_id, terminal_id, transaction_time);

-- Transacciones no anuladas
CREATE INDEX IF NOT EXISTS idx_transactions_not_voided
    ON public.transactions (ticket_id, transaction_time)
    WHERE COALESCE(voided, false) = false;

-- Transacciones no anuladas por usuario/terminal/tiempo
CREATE INDEX IF NOT EXISTS idx_tx_user_term_time_not_voided
    ON public.transactions (user_id, terminal_id, transaction_time)
    WHERE COALESCE(voided, false) = false;

-- Tickets: usa paid en lugar de closed
CREATE INDEX IF NOT EXISTS idx_ticket_create_terminal_status
    ON public.ticket (create_date, terminal_id, paid);

-- Tickets abiertos (paid=false)
CREATE INDEX IF NOT EXISTS idx_ticket_open
    ON public.ticket (terminal_id, create_date)
    WHERE NOT COALESCE(paid, false);

-- Attendence history: ajustado a dump, elimina operation
CREATE INDEX IF NOT EXISTS idx_attendence_user_time
    ON public.attendence_history (user_id, clock_in_time DESC);

-- Precorte lookup para trigger
CREATE INDEX IF NOT EXISTS idx_pc_precorte_lookup
    ON public.pc_precorte (terminal_id, cashier_user_id, to_ts DESC);

-- Materialización diaria
CREATE INDEX IF NOT EXISTS idx_pc_kpis_daily_materialized_date
    ON public.pc_post_corte_kpis_daily (materialized_date);

-- Drawer pull report: acelerar trigger y reportes
CREATE INDEX IF NOT EXISTS idx_dpr_user_term_time
    ON public.drawer_pull_report (user_id, terminal_id, report_time DESC);
COMMIT;

-- Transacción 4: Crear funciones
BEGIN;
-- ===========================
-- FUNCIÓN: VENTANA DE TURNO
-- ===========================
CREATE OR REPLACE FUNCTION public._last_assign_window(
    _terminal_id integer,
    _user_id integer,
    _ref_time timestamptz
)
RETURNS TABLE (from_ts timestamptz, to_ts timestamptz)
LANGUAGE sql STABLE AS $$
    WITH last_assign AS (
        SELECT ah.clock_in_time AS assign_time
        FROM public.attendence_history ah
        WHERE ah.user_id = _user_id
            AND ah.clock_in_time < _ref_time::timestamp
        ORDER BY ah.clock_in_time DESC
        LIMIT 1
    ),
    base_window AS (
        SELECT
            COALESCE((SELECT assign_time FROM last_assign), _ref_time - interval '24 hours') AS from_ts,
            _ref_time AS to_ts
    ),
    by_tx AS (
        SELECT
            MIN(t.transaction_time) AS first_tx,
            MAX(t.transaction_time) AS last_tx
        FROM public.transactions t
        WHERE t.user_id = _user_id
            AND t.terminal_id = _terminal_id
            AND t.transaction_time >= (SELECT from_ts FROM base_window)::timestamp
            AND t.transaction_time < (SELECT to_ts FROM base_window)::timestamp
    )
    SELECT
        LEAST((SELECT from_ts FROM base_window),
              COALESCE((SELECT first_tx FROM by_tx), (SELECT from_ts FROM base_window))) AS from_ts,
        GREATEST((SELECT to_ts FROM base_window),
                 COALESCE((SELECT last_tx FROM by_tx), (SELECT to_ts FROM base_window))) AS to_ts;
$$;

-- ===========================
-- SRF: MONTOS DEL SISTEMA
-- ===========================
CREATE OR REPLACE FUNCTION public.fn_precorte_sistema(
    _from timestamptz,
    _to timestamptz,
    _terminal_id integer,
    _user_id integer
)
RETURNS TABLE (
    sys_cash numeric(12,2),
    sys_credit numeric(12,2),
    sys_debit numeric(12,2),
    sys_custom numeric(12,2),
    sys_payouts numeric(12,2),
    branch_key text
)
LANGUAGE sql STABLE AS $$
    SELECT
        COALESCE(SUM(CASE WHEN LOWER(t.payment_type) = 'cash' AND NOT COALESCE(t.voided, false) AND t.payout_reason_id IS NULL THEN t.amount ELSE 0 END), 0)::numeric(12,2),
        COALESCE(SUM(CASE WHEN LOWER(t.payment_type) = 'credit_card' AND NOT COALESCE(t.voided, false) THEN t.amount ELSE 0 END), 0)::numeric(12,2),
        COALESCE(SUM(CASE WHEN LOWER(t.payment_type) = 'debit_card' AND NOT COALESCE(t.voided, false) THEN t.amount ELSE 0 END), 0)::numeric(12,2),
        COALESCE(SUM(CASE WHEN COALESCE(NULLIF(t.custom_payment_name, ''), '') <> '' AND NOT COALESCE(t.voided, false) THEN t.amount ELSE 0 END), 0)::numeric(12,2),
        COALESCE(SUM(CASE WHEN t.payout_reason_id IS NOT NULL AND NOT COALESCE(t.voided, false) THEN t.amount ELSE 0 END), 0)::numeric(12,2),
        COALESCE((SELECT location FROM public.terminal WHERE id = _terminal_id), 'N/A')
    FROM public.transactions t
    WHERE t.transaction_time >= _from::timestamp
        AND t.transaction_time < _to::timestamp
        AND t.terminal_id = _terminal_id
        AND t.user_id = _user_id;
$$;

-- ===========================
-- SRF: DETALLE DE CUSTOM PAYMENTS
-- ===========================
CREATE OR REPLACE FUNCTION public.fn_precorte_customs(
    _from timestamptz,
    _to timestamptz,
    _terminal_id integer,
    _user_id integer
)
RETURNS TABLE (
    custom_name text,
    custom_ref text,
    total numeric(12,2),
    transactions bigint
)
LANGUAGE sql STABLE AS $$
    SELECT
        COALESCE(NULLIF(t.custom_payment_name, ''), 'N/A') AS custom_name,
        COALESCE(t.custom_payment_ref, 'N/A') AS custom_ref,
        COALESCE(SUM(t.amount), 0)::numeric(12,2) AS total,
        COUNT(*) AS transactions
    FROM public.transactions t
    WHERE t.terminal_id = _terminal_id
        AND t.user_id = _user_id
        AND t.transaction_time >= _from::timestamp
        AND t.transaction_time < _to::timestamp
        AND NOT COALESCE(t.voided, false)
        AND COALESCE(NULLIF(t.custom_payment_name, ''), '') <> ''
    GROUP BY COALESCE(NULLIF(t.custom_payment_name, ''), 'N/A'),
             COALESCE(t.custom_payment_ref, 'N/A');
$$;

-- ===========================
-- CIERRE DE TICKETS $0
-- ===========================
CREATE OR REPLACE FUNCTION public.close_zero_tickets(
    _from timestamptz,
    _to timestamptz,
    _terminal_id integer,
    _user_id integer
)
RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    _count bigint;
    _ticket_ids bigint[];
BEGIN
    WITH tk AS (
        SELECT t.id
        FROM public.ticket t
        WHERE (COALESCE(t.total_price, 0) - COALESCE(t.total_discount, 0)) <= 0
            AND t.create_date >= _from::timestamp
            AND t.create_date < _to::timestamp
            AND t.terminal_id = _terminal_id
            AND NOT COALESCE(t.paid, false)
            AND NOT COALESCE(t.voided, false)
    )
    SELECT COUNT(*), array_agg(id) INTO _count, _ticket_ids
    FROM tk;

    IF _count > 0 THEN
        UPDATE public.ticket
        SET paid = true,
            modified_time = now()
        WHERE id = ANY(_ticket_ids);

        INSERT INTO public.action_history (
            action_time, action_name, description, user_id
        )
        VALUES (
            now(),
            'AUTO_CLOSE_ZERO',
            jsonb_build_object('ticket_ids', _ticket_ids, 'count', _count)::text,
            _user_id
        );
    END IF;

    RETURN _count;
END;
$$;

-- ===========================
-- MATERIALIZACIÓN DIARIA KPIs
-- ===========================
CREATE OR REPLACE FUNCTION public.materialize_kpis_daily(
    _from_date date DEFAULT date_trunc('day', now()) - INTERVAL '1 day',
    _to_date date DEFAULT date_trunc('day', now())
)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.pc_post_corte_kpis_daily (
        precorte_id, terminal_id, cashier_user_id, from_ts, to_ts,
        dpr_id, report_time, minutes_to_cut, cash_diff, credit_diff,
        debit_diff, custom_diff, voided_tickets_cnt, total_discounts,
        supervisor_id, materialized_date
    )
    SELECT
        pc.id AS precorte_id,
        pc.terminal_id,
        pc.cashier_user_id,
        pc.from_ts,
        pc.to_ts,
        pc.dpr_id,
        dpr.report_time,
        EXTRACT(EPOCH FROM (dpr.report_time - pc.to_ts))/60 AS minutes_to_cut,
        COALESCE((pc.post_cut_diffs->>'cash_diff')::numeric, 0) AS cash_diff,
        COALESCE((pc.post_cut_diffs->>'credit_diff')::numeric, 0) AS credit_diff,
        COALESCE((pc.post_cut_diffs->>'debit_diff')::numeric, 0) AS debit_diff,
        COALESCE((pc.post_cut_diffs->>'custom_diff')::numeric, 0) AS custom_diff,
        (SELECT COUNT(*) FROM public.ticket t WHERE t.terminal_id = pc.terminal_id AND t.create_date >= pc.from_ts AND t.create_date < pc.to_ts AND COALESCE(t.voided, false)) AS voided_tickets_cnt,
        (SELECT COALESCE(SUM(t.total_discount), 0)::numeric FROM public.ticket t WHERE t.terminal_id = pc.terminal_id AND t.create_date >= pc.from_ts AND t.create_date < pc.to_ts) AS total_discounts,
        pc.supervisor_id,
        date_trunc('day', pc.to_ts) AS materialized_date
    FROM public.pc_precorte pc
    LEFT JOIN public.drawer_pull_report dpr ON pc.dpr_id = dpr.id
    WHERE pc.to_ts::date BETWEEN _from_date AND _to_date
        AND pc.post_cut_status IN ('RECONCILED', 'DISCREPANCY')
    ON CONFLICT (precorte_id) DO NOTHING;
END;
$$;
COMMIT;

-- Transacción 5: Crear trigger
BEGIN;
CREATE OR REPLACE FUNCTION public.reconcile_precorte_on_dpr()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_from timestamptz;
    v_to timestamptz;
    v_sys_cash numeric(12,2) := 0;
    v_sys_credit numeric(12,2) := 0;
    v_sys_debit numeric(12,2) := 0;
    v_sys_custom numeric(12,2) := 0;
    v_sys_payouts numeric(12,2) := 0;
    v_pc_id bigint;
    v_diffs jsonb;
    v_counted_cash numeric(12,2) := 0;
    v_expected_cash numeric(12,2);
    v_payouts_in_dpr smallint;
    v_custom_breakdown jsonb;
BEGIN
    -- Obtener configuración de payouts
    SELECT COALESCE(value::smallint, 0) INTO v_payouts_in_dpr
    FROM public.pc_cfg
    WHERE key = 'payouts_in_dpr'
    LIMIT 1;

    -- Obtener ventana de turno
    SELECT from_ts, to_ts INTO v_from, v_to
    FROM public._last_assign_window(NEW.terminal_id, NEW.user_id, NEW.report_time);

    -- Calcular totales del sistema
    SELECT sys_cash, sys_credit, sys_debit, sys_custom, sys_payouts
    INTO v_sys_cash, v_sys_credit, v_sys_debit, v_sys_custom, v_sys_payouts
    FROM public.fn_precorte_sistema(v_from, v_to, NEW.terminal_id, NEW.user_id);

    -- Localizar precorte más cercano (≤ 1h)
    SELECT pc.id, COALESCE(cc.total_counted, pc.counted_cash)
    INTO v_pc_id, v_counted_cash
    FROM public.pc_precorte pc
    LEFT JOIN (
        SELECT precorte_id, SUM(subtotal) AS total_counted
        FROM public.pc_precorte_cash_count
        GROUP BY precorte_id
    ) cc ON cc.precorte_id = pc.id
    WHERE pc.terminal_id = NEW.terminal_id
        AND pc.cashier_user_id = NEW.user_id
        AND NEW.report_time >= pc.to_ts
        AND NEW.report_time < (pc.to_ts + INTERVAL '1 hour')
        AND pc.post_cut_status = 'PENDING'
    ORDER BY pc.to_ts DESC
    LIMIT 1;

    IF v_pc_id IS NOT NULL THEN
        -- Ajustar efectivo esperado
        v_expected_cash := COALESCE(v_counted_cash, 0);
        IF v_payouts_in_dpr = 0 THEN
            v_expected_cash := v_expected_cash - COALESCE(v_sys_payouts, 0);
        END IF;

        -- Breakdown de custom payments (top-5)
        SELECT jsonb_agg(jsonb_build_object(
            'custom_name', custom_name,
            'custom_ref', custom_ref,
            'total', total,
            'transactions', transactions
        ) ORDER BY total DESC)
        INTO v_custom_breakdown
        FROM public.fn_precorte_customs(v_from, v_to, NEW.terminal_id, NEW.user_id)
        WHERE total > 0
        LIMIT 5;

        -- Calcular diferencias
        SELECT jsonb_build_object(
            'cash_diff', v_expected_cash - COALESCE(NEW.cash_receipt_amount, 0),
            'credit_diff', COALESCE(pc.declared_credit, 0) - COALESCE(NEW.credit_card_receipt_amount, 0),
            'debit_diff', COALESCE(pc.declared_debit, 0) - COALESCE(NEW.debit_card_receipt_amount, 0),
            'custom_diff', COALESCE(pc.declared_custom, 0) - COALESCE(v_sys_custom, 0),
            'custom_breakdown', v_custom_breakdown
        ) INTO v_diffs
        FROM public.pc_precorte pc
        WHERE pc.id = v_pc_id;

        -- Actualizar precorte
        UPDATE public.pc_precorte
        SET system_cash = v_sys_cash,
            system_credit = v_sys_credit,
            system_debit = v_sys_debit,
            system_custom = v_sys_custom,
            system_payouts = v_sys_payouts,
            post_cut_status = CASE
                WHEN (v_diffs->>'cash_diff')::numeric != 0 OR
                     (v_diffs->>'credit_diff')::numeric != 0 OR
                     (v_diffs->>'debit_diff')::numeric != 0 OR
                     (v_diffs->>'custom_diff')::numeric != 0
                THEN 'DISCREPANCY'
                ELSE 'RECONCILED'
            END,
            post_cut_diffs = v_diffs,
            dpr_id = NEW.id
        WHERE id = v_pc_id;

        -- Notificar si hay discrepancias
        IF (v_diffs->>'cash_diff')::numeric != 0 OR
           (v_diffs->>'credit_diff')::numeric != 0 OR
           (v_diffs->>'debit_diff')::numeric != 0 OR
           (v_diffs->>'custom_diff')::numeric != 0 THEN
            PERFORM pg_notify('post_cut_alert',
                jsonb_build_object('precorte_id', v_pc_id, 'dpr_id', NEW.id, 'diffs', v_diffs)::text);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger PG 9.5: drop + create + execute procedure
DROP TRIGGER IF EXISTS reconcile_precorte_trigger ON public.drawer_pull_report;
CREATE TRIGGER reconcile_precorte_trigger
    AFTER INSERT ON public.drawer_pull_report
    FOR EACH ROW
    EXECUTE PROCEDURE public.reconcile_precorte_on_dpr();

COMMIT;