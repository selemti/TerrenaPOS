# 📚 QUERIES — Terrena POS Admin (PostgreSQL)

Este documento reúne consultas SQL para: **Dashboard**, **Alertas**, y el flujo
**Precorte → Corte → Postcorte** usando POS (solo lectura) y tablas auxiliares `pc_*`.

> Ajusta prefijos/nombres si tu POS difiere. Todas las consultas se pueden envolver en vistas.

---

## 🧭 Parámetros comunes

- `:bdate`      → `date` (business_date)
- `:store_id`   → `int`  (sucursal)
- `:terminal_id`→ `int`  (terminal POS)
- `:limit`      → `int`  (registros)
- `:since`      → `timestamp` (actividad reciente desde…)

---

## 🧊 Dashboard

### 1) Ventas del día (total, tickets y variación vs. ayer)
WITH t AS (
  SELECT business_date,
         SUM(sales_cash + sales_card + sales_transfer) AS total,
         SUM(tickets_count) AS tickets
  FROM pc_post_corte_kpis_daily
  WHERE business_date IN (CURRENT_DATE, CURRENT_DATE - INTERVAL '1 day')
  GROUP BY business_date
)
SELECT
  (SELECT total   FROM t WHERE business_date = CURRENT_DATE) AS total_hoy,
  (SELECT tickets FROM t WHERE business_date = CURRENT_DATE) AS tickets_hoy,
  CASE
    WHEN (SELECT total FROM t WHERE business_date = CURRENT_DATE - INTERVAL '1 day') IS NULL THEN NULL
    ELSE ROUND(
      ((SELECT total FROM t WHERE business_date = CURRENT_DATE) -
       (SELECT total FROM t WHERE business_date = CURRENT_DATE - INTERVAL '1 day'))
       * 100.0 /
      NULLIF((SELECT total FROM t WHERE business_date = CURRENT_DATE - INTERVAL '1 day'),0), 2)
  END AS var_vs_ayer_pct;

2) Producto estrella (por ventas $ hoy)
SELECT item_name, SUM(total_amount) AS ventas
FROM (
  -- Si materializas top_sku_json por terminal/sucursal: desnormaliza aquí
  SELECT (kv->>'name')::text AS item_name,
         (kv->>'amount')::numeric AS total_amount
  FROM pc_post_corte_kpis_daily,
       LATERAL jsonb_array_elements(top_sku_json) AS kv
  WHERE business_date = CURRENT_DATE
) x
GROUP BY item_name
ORDER BY ventas DESC
LIMIT 1;

3) KPI — Productos vendidos (unidades hoy y variación vs. ayer)
WITH u AS (
  SELECT business_date, SUM((kv->>'qty')::int) AS uds
  FROM pc_post_corte_kpis_daily,
       LATERAL jsonb_array_elements(top_sku_json) kv
  WHERE business_date IN (CURRENT_DATE, CURRENT_DATE - INTERVAL '1 day')
  GROUP BY business_date
)
SELECT
  (SELECT uds FROM u WHERE business_date=CURRENT_DATE) AS uds_hoy,
  ROUND(
    ( (SELECT uds FROM u WHERE business_date=CURRENT_DATE) -
      (SELECT uds FROM u WHERE business_date=CURRENT_DATE - INTERVAL '1 day') ) * 100.0
    / NULLIF((SELECT uds FROM u WHERE business_date=CURRENT_DATE - INTERVAL '1 day'),0)
  ,2) AS var_vs_ayer_pct;

4) KPI — Ticket promedio
SELECT
  ROUND( AVG(avg_ticket)::numeric , 2 ) AS ticket_promedio
FROM pc_post_corte_kpis_daily
WHERE business_date = CURRENT_DATE;

5) Estatus de cajas (para el widget “Ir a cortes”)
SELECT
  s.name        AS sucursal,
  t.terminal_id AS terminal,
  CASE WHEN p.status IN ('open','pending') THEN 'Abierto' ELSE 'Cerrado' END AS estatus,
  COALESCE(p.sys_cash + p.sys_card + p.sys_transfer, 0) AS vendido
FROM terminals t
JOIN stores s ON s.id = t.store_id
LEFT JOIN pc_precorte p
  ON p.business_date = CURRENT_DATE
 AND p.store_id      = t.store_id
 AND p.terminal_id   = t.terminal_id
ORDER BY s.name, t.terminal_id;

6) Tendencia de ventas (últimos 7 días)
SELECT business_date,
       SUM(sales_cash)      AS cash,
       SUM(sales_card)      AS card,
       SUM(sales_transfer)  AS transfer
FROM pc_post_corte_kpis_daily
WHERE business_date >= CURRENT_DATE - INTERVAL '6 day'
GROUP BY business_date
ORDER BY business_date;

7) Ventas por hora — apiladas por sucursal (ejemplo con tickets POS)

Si no tienes tabla POS por hora materializada, aproxima usando ticket.created.

SELECT
  date_trunc('hour', tk.created)::time AS hora,
  s.name AS sucursal,
  SUM(tk.total_amount) AS total
FROM ticket tk
JOIN stores s ON s.id = tk.store_id
WHERE tk.created::date = :bdate
GROUP BY 1,2
ORDER BY 1,2;

8) Formas de pago (hoy)
SELECT
  'Efectivo'    AS tipo, SUM(sales_cash)     AS total FROM pc_post_corte_kpis_daily WHERE business_date=CURRENT_DATE
UNION ALL
SELECT 'Tarjeta',     SUM(sales_card)        FROM pc_post_corte_kpis_daily WHERE business_date=CURRENT_DATE
UNION ALL
SELECT 'Transferencia',SUM(sales_transfer)   FROM pc_post_corte_kpis_daily WHERE business_date=CURRENT_DATE;

9) Ventas por sucursal (por tipo de pago, hoy)
SELECT s.name AS sucursal,
       SUM(k.sales_cash)     AS cash,
       SUM(k.sales_card)     AS card,
       SUM(k.sales_transfer) AS transfer
FROM pc_post_corte_kpis_daily k
JOIN stores s ON s.id = k.store_id
WHERE k.business_date = CURRENT_DATE
GROUP BY s.name
ORDER BY s.name;

10) Top 5 productos (apilados por sucursal)
WITH sku AS (
  SELECT s.name AS sucursal,
         (kv->>'name')::text   AS item_name,
         (kv->>'amount')::numeric AS amount
  FROM pc_post_corte_kpis_daily k
  JOIN stores s ON s.id = k.store_id
  CROSS JOIN LATERAL jsonb_array_elements(k.top_sku_json) kv
  WHERE k.business_date = :bdate
)
SELECT item_name,
       SUM(CASE WHEN sucursal='Principal' THEN amount ELSE 0 END) AS principal,
       SUM(CASE WHEN sucursal='NB'        THEN amount ELSE 0 END) AS nb,
       SUM(CASE WHEN sucursal='Torre'     THEN amount ELSE 0 END) AS torre,
       SUM(CASE WHEN sucursal='Terrena'   THEN amount ELSE 0 END) AS terrena
FROM sku
GROUP BY item_name
ORDER BY (principal+nb+torre+terrena) DESC
LIMIT 5;

11) Órdenes recientes
SELECT tk.ticket_id, s.name AS sucursal, tk.created::time AS hora, tk.total_amount
FROM ticket tk
JOIN stores s ON s.id = tk.store_id
WHERE tk.created >= NOW() - INTERVAL '2 hour'
ORDER BY tk.created DESC
LIMIT :limit;

12) Actividad reciente (eventos auxiliares)

Si no tienes tabla de auditoría aún, puedes armar con lo que haya en pc_* + drawer_pull_report.

SELECT 'precorte' AS tipo, CONCAT('Precorte capturado en ', s.name) AS texto, p.created_at AS ts
FROM pc_precorte p JOIN stores s ON s.id = p.store_id
WHERE p.created_at >= :since
UNION ALL
SELECT 'dpr', CONCAT('Drawer Pull Report en ', s.name), dpr.created
FROM drawer_pull_report dpr JOIN stores s ON s.id = dpr.store_id
WHERE dpr.created >= :since
ORDER BY ts DESC
LIMIT :limit;

13) Alertas (conteo y detalle)

Bajo stock (placeholder si no hay inventario aún).

Diferencia en corte (pc_precorte.difference <> 0).

Descuentos altos (desde POS).

Tickets abiertos (POS).

-- Diferencias en corte hoy
SELECT s.name AS sucursal, p.terminal_id, p.difference
FROM pc_precorte p
JOIN stores s ON s.id=p.store_id
WHERE p.business_date=CURRENT_DATE
  AND p.stage IN ('corte','postcorte')
  AND COALESCE(p.difference,0) <> 0
ORDER BY ABS(p.difference) DESC
LIMIT 5;

💸 Precorte → Corte → Postcorte
A) Cajas abiertas hoy (precorte pendiente)
SELECT
  s.name AS sucursal, t.terminal_id, u.name AS cajero,
  p.id AS precorte_id, p.status, p.stage, p.business_date
FROM terminals t
JOIN stores s ON s.id=t.store_id
JOIN users u  ON u.id=t.user_id
LEFT JOIN pc_precorte p
  ON p.business_date=CURRENT_DATE
 AND p.store_id=t.store_id
 AND p.terminal_id=t.terminal_id
WHERE COALESCE(p.status,'open') IN ('open','pending')
ORDER BY s.name, t.terminal_id;

B) Iniciar precorte (header) — INSERT
INSERT INTO pc_precorte (
  business_date, store_id, terminal_id, user_id, stage, status, opened_at, created_by
) VALUES (
  :bdate, :store_id, :terminal_id, :user_id, 'precorte', 'open', NOW(), :user_app
)
RETURNING id;

C) Conteo rápido por denominación — INSERT detalle
INSERT INTO pc_precorte_cash_count (precorte_id, denomination, qty, amount, created_at)
VALUES (:precorte_id, :den, :qty, :den * :qty, NOW());

D) Declarados por forma de pago — UPDATE header
UPDATE pc_precorte
SET decl_cash=:cash, decl_card=:card, decl_transfer=:transfer, updated_at=NOW()
WHERE id=:precorte_id;

E) Montos del sistema (POS) — SELECT funciones auxiliares
-- Totales sistema (efectivo/tarjeta/transfer) calculados desde POS
SELECT * FROM fn_precorte_sistema(:bdate, :store_id, :terminal_id);

F) Conciliación (difference) — UPDATE
UPDATE pc_precorte
SET sys_cash=:sys_cash,
    sys_card=:sys_card,
    sys_transfer=:sys_transfer,
    difference = (:decl_cash + :decl_card + :decl_transfer) - (:sys_cash + :sys_card + :sys_transfer),
    stage='corte',
    status='pending',
    updated_at=NOW()
WHERE id=:precorte_id;

G) Cerrar tickets $0 (opcional pre-corte)
SELECT close_zero_tickets(:bdate, :store_id, :terminal_id);

H) Registrar corte (cerrar)
UPDATE pc_precorte
SET status='closed', closed_at=NOW(), updated_at=NOW()
WHERE id=:precorte_id;

I) Postcorte (ajustes y materialización KPIs)
UPDATE pc_precorte
SET stage='postcorte', notes=:notes, updated_at=NOW()
WHERE id=:precorte_id;

SELECT materialize_kpis_daily(:bdate);


El trigger reconcile_precorte_on_dpr hará parte del trabajo automáticamente cuando se inserte un drawer_pull_report (DPR) del POS.

🧾 Reportes útiles
Cortes por sucursal (últimos 7 días)
SELECT p.business_date, s.name AS sucursal,
       SUM(p.decl_cash + p.decl_card + p.decl_transfer) AS declarado,
       SUM(p.sys_cash + p.sys_card + p.sys_transfer) AS sistema,
       SUM(p.difference) AS diferencia
FROM pc_precorte p
JOIN stores s ON s.id=p.store_id
WHERE p.business_date >= CURRENT_DATE - INTERVAL '6 day'
  AND p.stage IN ('corte','postcorte')
GROUP BY p.business_date, s.name
ORDER BY p.business_date, s.name;


---