# 🔌 API — Terrena POS Admin (v1)

API REST para alimentar el frontend (Dashboard y módulos).  
Base URL: `/api/v1`

> Autenticación: **Bearer JWT** o **cookie de sesión** (a definir en `Core/Auth.php`).  
> Respuestas en JSON (`application/json; charset=utf-8`).

---

## Autenticación

### POST `/auth/login`
**Body**
```json
{ "username": "jperez", "password": "••••••" }


200

{ "token":"<jwt>", "user": { "id":1, "name":"Juan Pérez", "roles":["admin"] } }

POST /auth/logout

200

{ "ok": true }

Dashboard
GET /dashboard/kpis?bdate=YYYY-MM-DD

Response

{
  "sales": { "total": 8450.00, "tickets": 124, "var_vs_ayer_pct": 12.5 },
  "star_product": { "name":"Latte Vainilla", "amount": 350.25 },
  "products_sold": { "qty": 385, "var_vs_ayer_pct": 7.2 },
  "avg_ticket": 68.15,
  "alerts_count": 5
}

GET /dashboard/status-cajas?bdate=YYYY-MM-DD
[
  { "sucursal":"Principal", "terminal":1, "estatus":"Abierto", "vendido":3250.50 },
  { "sucursal":"NB",        "terminal":1, "estatus":"Cerrado", "vendido":0.00  }
]

GET /dashboard/ventas-semanal?from=YYYY-MM-DD&to=YYYY-MM-DD
[
  { "date":"2025-08-26", "cash":2450, "card":3120, "transfer":120 },
  ...
]

GET /dashboard/ventas-hora?bdate=YYYY-MM-DD
[
  { "hour":"08:00", "sucursal":"Principal", "total": 120.00 },
  { "hour":"08:00", "sucursal":"NB",        "total":  20.00 },
  ...
]

GET /dashboard/formas-pago?bdate=YYYY-MM-DD
[
  { "tipo":"Efectivo", "total": 650.25 },
  { "tipo":"Tarjeta",  "total": 920.50 },
  { "tipo":"Transferencia", "total": 80.00 }
]

GET /dashboard/ventas-por-sucursal?bdate=YYYY-MM-DD
[
  { "sucursal":"Principal", "cash":2100, "card":2600, "transfer":500 },
  { "sucursal":"NB",        "cash":1800, "card":1500, "transfer":300 }
]

GET /dashboard/top5?bdate=YYYY-MM-DD
[
  { "item":"Latte Vainilla", "Principal":350.25, "NB":40,  "Torre":30, "Terrena":10 },
  { "item":"Capuchino",      "Principal":290.10, "NB":35,  "Torre":25, "Terrena":12 }
]

GET /dashboard/ordenes-recientes?limit=5
[
  { "ticket":1543, "sucursal":"Principal", "hora":"13:42", "total":128.50 },
  ...
]

GET /dashboard/actividad-reciente?since=ISO&limit=5
[
  { "type":"precorte", "text":"Precorte capturado en Principal", "ts":"2025-09-01T13:20:00Z" },
  ...
]

GET /dashboard/alerts?limit=5
[
  { "type":"low", "text":"Inventario bajo: Leche (10L)", "minutesAgo":8 },
  { "type":"error", "text":"Diferencia en corte: Sucursal NB", "minutesAgo":18 }
]

Caja (Precorte / Corte / Postcorte)
GET /caja/abiertas?bdate=YYYY-MM-DD
[
  { "sucursal":"Principal", "terminal":1, "cajero":"Juan", "precorte_id": 15, "status": "open", "stage":"precorte" }
]

POST /caja/precorte
{ "bdate":"2025-09-01", "store_id":1, "terminal_id":1, "user_id": 9 }


201

{ "precorte_id": 42 }

POST /caja/precorte/:id/conteo
[
  { "den": 100, "qty": 2 },
  { "den":  50, "qty": 1 }
]


200

{ "ok": true, "decl_cash": 250.0 }

PUT /caja/precorte/:id/decl
{ "cash": 250.0, "card": 1200.0, "transfer": 150.0 }

GET /caja/precorte/:id/sistema?bdate=YYYY-MM-DD&store_id=1&terminal_id=1
{ "sys_cash":240.00, "sys_card":1200.00, "sys_transfer":150.00 }

PUT /caja/precorte/:id/conciliar
{ "sys_cash":240.00, "sys_card":1200.00, "sys_transfer":150.00 }


200

{ "difference": 10.0, "stage":"corte", "status":"pending" }

POST /caja/cerrar-tickets-cero
{ "bdate":"2025-09-01", "store_id":1, "terminal_id":1 }


200 { "closed": 3 }

PUT /caja/precorte/:id/cerrar

200 { "ok": true, "status":"closed" }

PUT /caja/precorte/:id/postcorte
{ "notes":"Validado por supervisor" }


200 { "ok": true, "stage":"postcorte" }

Inventario (MVP)

En esta fase solo endpoints de estructura; PR’s futuros conectarán UDM y conversiones.

GET /inventario/udm
[
  { "id":1, "name":"pieza" }, { "id":2, "name":"ml" }, { "id":3, "name":"kg" }
]

GET /inventario/conversiones/:item_id
{ "base_udm":"ml", "presentaciones":[ {"name":"Caja 12 x 1.5L","factor":18000}, {"name":"Tetra 200ml","factor":200} ] }

Respuestas de error

400 { "error":"Bad Request", "details":"..." }

401 { "error":"Unauthorized" }

403 { "error":"Forbidden" }

404 { "error":"Not Found" }

500 { "error":"Internal Error", "trace_id":"..." }