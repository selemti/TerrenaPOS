📄 DB_SCHEMA.md — Terrena POS Admin (PostgreSQL)

Propósito: documentar el esquema auxiliar que usamos para precortes, cortes y postcortes sin modificar la lógica/operación estándar de Floreant POS.
Estas tablas y funciones leen de la BD del POS y persisten cálculos/decisiones propias en un espacio auxiliar.

🧱 Principios

No rompemos POS: no alteramos tablas críticas del POS; todo lo nuestro vive en un namespace auxiliar (por defecto, esquema public pero con prefijo pc_).

Idempotencia: scripts pensados para aplicarse varias veces (con IF NOT EXISTS cuando aplica).

Auditable: guardamos quién, cuándo y qué en cada registro clave (campos created_at, created_by, updated_at).

Business date: todo concilia por fecha de negocio (no solo timestamp real). Evitar cruces por zonas horarias.

📦 Archivos SQL (carpeta /query)

POS_structure_30_08_2025.sql → solo estructura de la BD POS (consulta/desarrollo rápido).

POS_Cortes_preview_30_08_2025.sql → dump con datos para pruebas.

precorte_pack_final_v3_consolidated_perfect_v15.1.sql → tablas auxiliares + funciones + trigger para precorte/corte/postcorte y KPIs.

Orden sugerido de carga:

POS_structure_30_08_2025.sql (o el dump completo POS_Cortes_preview_30_08_2025.sql)

precorte_pack_final_v3_consolidated_perfect_v15.1.sql

🗺️ Relación con tablas POS (resumen conceptual)
Floreant POS (solo lectura)                       Auxiliares Terrena (lectura/escritura)
---------------------------------------           ----------------------------------------
ticket, ticket_item, payments                     pc_precorte
drawer_pull_report (DPR) --------------------┐    pc_precorte_cash_count
users, shifts, terminals                      └--> pc_post_corte_kpis_daily
catalog (items, categories)                         pc_cfg


POS nos da ventas reales, tickets, pagos, DPRs y contexto (usuarios, terminales).

Auxiliares guardan declarados del cajero (precorte/corte), conteo por denominación, y KPIs materializados por día.

🧩 Tablas Auxiliares

Los nombres de columnas pueden variar ligeramente según la versión; abajo va la estructura canónica adoptada en el proyecto para los módulos UI.

1) pc_cfg

Configuración global para el módulo de caja / conciliación.

Columna	Tipo	Descripción
id	serial PK	
key	text	Nombre de la configuración (único)
value	text	Valor (string; parseo en app)
description	text	Ayuda / contexto
updated_at	timestamptz	Última actualización

Claves lógicas comunes

payouts_in_dpr → true/false si el drawer pull report ya descuenta payouts.

business_day_start_hour → hora corte de día de negocio, ej. 05 (5am).

2) pc_precorte

Encabezado del precorte/corte/postcorte para una terminal y fecha de negocio.

Columna	Tipo	Descripción
id	bigserial PK	
business_date	date	Día de negocio (no el timestamp real)
store_id	int	Sucursal (mapea a POS)
terminal_id	int	Terminal POS
user_id	int	Cajero (id POS)
opened_at	timestamptz	Apertura/arranque del turno (opcional)
closed_at	timestamptz	Momento de corte (si aplica)
stage	text	precorte | corte | postcorte
decl_cash	numeric(12,2)	Efectivo declarado por cajero
decl_card	numeric(12,2)	Tarjeta declarado
decl_transfer	numeric(12,2)	Transferencia declarado
sys_cash	numeric(12,2)	Efectivo según sistema (funciones POS)
sys_card	numeric(12,2)	Tarjeta según sistema
sys_transfer	numeric(12,2)	Transferencia según sistema
difference	numeric(12,2)	(decl_total - sys_total)
notes	text	Observaciones
status	text	open | pending | reconciled | closed
created_by	int	Usuario app
created_at	timestamptz	Alta
updated_at	timestamptz	Modificación

Índices sugeridos

idx_pc_precorte_bdate_store_term (business_date, store_id, terminal_id)

idx_pc_precorte_stage_status (stage, status)

3) pc_precorte_cash_count

Detalle de conteo rápido por denominación (solo efectivo).

Columna	Tipo	Descripción
id	bigserial PK	
precorte_id	bigint FK	→ pc_precorte.id
denomination	numeric(12,2)	Valor de la denominación (ej. 100.00)
qty	int	Piezas
amount	numeric(12,2)	denomination * qty
created_at	timestamptz	

Índices

idx_pc_precorte_cash_precorte (precorte_id)

Nota: la suma de amount debe igualar decl_cash del pc_precorte.

4) pc_post_corte_kpis_daily

Materialización de KPIs por fecha/sucursal/terminal para dashboards.

Columna	Tipo	Descripción
id	bigserial PK	
business_date	date	
store_id	int	
terminal_id	int	
sales_cash	numeric(12,2)	
sales_card	numeric(12,2)	
sales_transfer	numeric(12,2)	
tickets_count	int	
avg_ticket	numeric(12,2)	
top_sku_json	jsonb	Top N productos (para hidratar gráficos)
created_at	timestamptz	

Índices

idx_pc_kpis_bdate_store_term (business_date, store_id, terminal_id)

idx_pc_kpis_bdate (business_date)

🧠 Funciones auxiliares (SQL)

Incluidas dentro de precorte_pack_final_v3_consolidated_perfect_v15.1.sql.

fn_precorte_sistema(business_date date, store_id int, terminal_id int)

Retorna totales por forma de pago según POS para ese día/terminal.

Uso típico: hidratar sys_cash/card/transfer en pc_precorte.

fn_precorte_customs(business_date date, store_id int, terminal_id int)

Ajustes/customs no contemplados directamente por POS (descuentos especiales, etc.).

_last_assign_window(user_id int, terminal_id int)

Determina ventana (inicio/fin) del turno asignado a un cajero/terminal.

close_zero_tickets(business_date date, store_id int, terminal_id int)

Cierra tickets de importe $0 aún abiertos.

materialize_kpis_daily(business_date date)

Calcula y persist en pc_post_corte_kpis_daily los KPIs de ese día.

🔔 Trigger (reconciliación automática)

reconcile_precorte_on_dpr

Evento: AFTER INSERT en drawer_pull_report (tabla POS).

Acción: reconcilia pc_precorte pendientes para esa terminal y business_date:

actualiza sys_* llamando a fn_precorte_sistema.

calcula difference.

marca status como reconciled/closed según regla.

invoca materialize_kpis_daily para refrescar KPIs.

Beneficio: el POS “dispara” la conciliación cuando se hace el DPR; el admin solo lee resultados en UI.

🔍 Consultas de ejemplo
1) Estatus de Cajas (dashboard, widget)
SELECT
  s.name        AS sucursal,
  t.terminal_id AS terminal,
  CASE
    WHEN p.status IN ('open','pending') THEN 'Abierto'
    ELSE 'Cerrado'
  END AS estatus,
  COALESCE(p.sys_cash + p.sys_card + p.sys_transfer, 0) AS vendido
FROM terminals t
JOIN stores s ON s.id = t.store_id
LEFT JOIN pc_precorte p
  ON p.business_date = CURRENT_DATE
 AND p.store_id      = t.store_id
 AND p.terminal_id   = t.terminal_id
ORDER BY s.name, t.terminal_id;

2) Conteo rápido (detalle efectivo)
SELECT denomination, qty, amount
FROM pc_precorte_cash_count
WHERE precorte_id = :precorte_id
ORDER BY denomination DESC;

3) Precortes abiertos hoy
SELECT p.*
FROM pc_precorte p
WHERE p.business_date = CURRENT_DATE
  AND p.status IN ('open','pending');

4) KPIs para gráficas (últimos 7 días)
SELECT business_date,
       SUM(sales_cash)      AS cash,
       SUM(sales_card)      AS card,
       SUM(sales_transfer)  AS transfer,
       SUM(tickets_count)   AS tickets,
       ROUND(AVG(avg_ticket)::numeric, 2) AS avg_ticket
FROM pc_post_corte_kpis_daily
WHERE business_date >= CURRENT_DATE - INTERVAL '7 day'
GROUP BY business_date
ORDER BY business_date;

5) Top N productos del día (usando jsonb materializado)
SELECT business_date, top_sku_json
FROM pc_post_corte_kpis_daily
WHERE business_date = CURRENT_DATE
ORDER BY store_id, terminal_id;

🧭 Reglas de negocio clave

Una barra por hora / producto apilada por sucursal: para Ventas por hora y Top 5 productos en Chart.js, preferimos sumar por store_id y mandar datasets por sucursal.

Fecha de negocio ≠ timestamp real: uses siempre business_date (con business_day_start_hour de pc_cfg para calcular el corte).

Cierre automático de tickets $0 antes de conciliar: usar close_zero_tickets en el flujo.

🔒 Permisos recomendados

Rol terrena_app con SELECT sobre tablas POS relevantes (ticket, payments, drawer_pull_report, terminals, users, stores…), y ALL PRIVILEGES sobre pc_*.

Deshabilitar DELETE en POS desde la app (solo lectura).

Backups programados de pc_* + POS.

🧪 Seeds / Fixtures

Usa POS_Cortes_preview_30_08_2025.sql para levantar datos demo.

Ejecuta materialize_kpis_daily(CURRENT_DATE) para hidratar el dashboard.

🔗 Integración en PHP (snippets)

Cargar KPIs dashboard (PDO, ejemplo):

$sql = "SELECT business_date,
               SUM(sales_cash) AS cash,
               SUM(sales_card) AS card,
               SUM(sales_transfer) AS transfer
        FROM pc_post_corte_kpis_daily
        WHERE business_date >= CURRENT_DATE - INTERVAL '7 day'
        GROUP BY business_date
        ORDER BY business_date";
$stmt = $pdo->query($sql);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);


Estatus de cajas (widget):

$sql = "SELECT s.name AS sucursal,
               CASE WHEN p.status IN ('open','pending') THEN 'Abierto' ELSE 'Cerrado' END AS estatus,
               COALESCE(p.sys_cash + p.sys_card + p.sys_transfer, 0) AS vendido
        FROM terminals t
        JOIN stores s ON s.id = t.store_id
        LEFT JOIN pc_precorte p
          ON p.business_date = CURRENT_DATE
         AND p.store_id = t.store_id
         AND p.terminal_id = t.terminal_id
        ORDER BY s.name";
$rows = $pdo->query($sql)->fetchAll(PDO::FETCH_ASSOC);

⚠️ Pitfalls / Buenas prácticas

Zonas horarias: fijar TZ del servidor y de PHP a MX/UTC coherente; usar business_date para cortes.

Re-ejecución de materialize_kpis_daily: es seguro; sobreescribe/actualiza KPIs del día.

Nulls: coalesce en consultas para evitar NULL en SUM.

Índices: si crece el volumen, agregar índices por fecha y sucursal en pc_*.

📌 ToDo (BD)

 Documentar todas las columnas efectivas post–deploy (añadir diff si cambian).

 Agregar vista vw_status_cajas para el widget (performance y limpieza de consultas).

 Añadir constraints check (ej. decl_cash = SUM(pc_precorte_cash_count.amount)).

Contacto / Créditos
Terrena Café / SelemTI
Basado en Floreant POS + extensión auxiliar de caja.