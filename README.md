# ☕ Terrena POS Admin

Sistema web de **administración, control financiero e inventarios** para cafeterías y restaurantes,
integrado con **Floreant POS**.  
Desarrollado por **SelemTI / Terrena Café** como parte de la transformación digital
para sucursales **Principal, NB, Torre y Terrena**.

---

## 🚀 Objetivo

Centralizar la **operación administrativa** que Floreant POS no cubre:
- Control financiero avanzado (precortes, cortes, postcortes).
- Gestión de inventario y recetas con conversiones/unidades.
- Producción programada (ej. 20 tortas de pollo para mañana).
- Compras automáticas con base en stocks mínimos/máximos.
- Reporteo consolidado multi-sucursal con KPIs y dashboards modernos.
---

## 🏗️ Arquitectura y Tecnologías

- **Backend**: PHP 8 (XAMPP en desarrollo / Apache2 en Ubuntu Server productivo).
- **Base de Datos**: PostgreSQL 9.5 (con tablas extendidas de Floreant POS).
- **Frontend**: HTML5, CSS3, Bootstrap 5, JS (Chart.js).
- **Composer packages**:
  - [`mike42/escpos-php`](https://github.com/mike42/escpos-php) (impresoras térmicas).
  - `lib-curl-openssl` y otros según necesidad.
- **Integración Floreant POS**:
  - Reutilizamos tickets, terminales, usuarios.
  - Extensiones SQL (ej: `folio_diario_floreant_optimizado_final_v6_OK_txt.sql`) para folio diario y triggers de KDS/Voceo.
  - precorte_pack_final_v3_consolidated_perfect_v15.1.sql para menejo de cortes de cajas, precotes y conciliación de cortes.
  - Lectura de tickets, transacciones y usuarios desde BD original.
  - Uso de **tablas auxiliares** (`pc_precorte`, `pc_precorte_cash_count`, `pc_post_corte_kpis_daily`, `pc_cfg`) para cálculos propios.
  - Triggers y funciones que materializan KPIs diarios y reconcilian precortes tras cada `drawer_pull_report`.

---
🔑 Integración Precortes y Cortes de Caja

El sistema incluye precortes, cortes y postcortes totalmente integrados con Floreant POS sin alterar su operación nativa:

Se crearon tablas auxiliares en PostgreSQL (pc_precorte, pc_precorte_cash_count, pc_cfg, pc_post_corte_kpis_daily) que permiten capturar y reconciliar información sin modificar la lógica original del POS.

Se implementaron funciones SQL:

_last_assign_window() → detecta la ventana de turno real.

fn_precorte_sistema() → calcula montos del sistema en el rango del precorte.
fn_precorte_customs() → detalla pagos personalizados.
close_zero_tickets() → cierra automáticamente tickets en $0.
materialize_kpis_daily() → genera KPIs diarios consolidados para dashboard.

Se añadió un trigger reconcile_precorte_on_dpr sobre drawer_pull_report que reconcilia automáticamente los precortes con el cierre de caja, marcando estatus:
RECONCILED → si coincide.
DISCREPANCY → si hay diferencias en efectivo, crédito, débito o pagos personalizados.

👉 Esto garantiza que los precortes/cortes del sistema administrativo sean consistentes con POS, pero sin interferir en la operación de Floreant.

📂 Carpeta query/

El proyecto ahora incluye:
POS_Cortes_preview_30_08_2025.sql → respaldo con datos.
POS_strcuture_30_08_2025.sql → solo estructura (consultas rápidas).
precorte_pack_final_v3_consolidated_perfect_v15.1.sql → script final con todas las funciones, tablas y triggers de precortes.
-------

## 📂 Estructura del proyecto
Raíz del proyecto
│
├── config.php # Conexión a BD PostgreSQL
├── composer.json # Dependencias PHP
│
├── query/ # 📌 NUEVO: scripts SQL auxiliares
│ ├── POS_Cortes_preview_30_08_2025.sql # Dump con datos (demo)
│ ├── POS_structure_30_08_2025.sql # Solo estructura
│ └── precorte_pack_final_v3_consolidated_perfect_v15.1.sql
│ (tablas y triggers auxiliares de precortes/cortes)
│
├── assets/
│ ├── css/
│ │ └── terrena.css
│ ├── js/
│ │ └── terrena.js
│ ├── img/
│ │ ├── logo.svg
│ │ └── logo2.svg
│ └── font/
│
├── Core/ # Router y Auth base
├── Modules/ # Controladores por módulo
│ ├── Caja/ # Precorte, Corte, Postcorte
│ ├── Inventario/ # Control de stock, unidades, conversiones
│ ├── Compras/ # Órdenes de compra y proveedores
│ ├── Recetas/ # Recetario, costeo, mermas
│ ├── Produccion/ # Producción programada
│ ├── Reportes/ # KPIs, reportes exportables
│ ├── Admin/ # Configuración general, items, catálogos
│ └── Personal/ # Administración de usuarios y privilegios
│
└── Views/
├── layout.php
├── dashboard.php
├── caja/
├── inventario/
├── ...


---

## ⚙️ Instalación y ejecución

1. **Clonar el repositorio**  
   git clone https://github.com/tu-org/terrena-pos-admin.git
   cd terrena-pos-admin
2. **CConfigurar dependencias PHP**

composer install

3. **Configurar base de datos**
PostgreSQL 9.5+
Importar respaldo de Floreant POS:
	query/POS_Cortes_preview_30_08_2025.sql (con datos).
	o query/POS_structure_30_08_2025.sql (solo estructura para desarrollo rápido).

Aplicar script auxiliar:
	query/precorte_pack_final_v3_consolidated_perfect_v15.1.sql (crea tablas auxiliares, funciones y triggers).

4. **Configurar conexión en config.php**
define('DB_HOST','localhost');
define('DB_PORT','5432');
define('DB_NAME','floreant');
define('DB_USER','usuario');
define('DB_PASS','password');


5.**Entorno de desarrollo**

XAMPP: copiar en htdocs/terrena/Terrena/ y acceder a
http://localhost/terrena/Terrena/

6. **Producción**
Ubuntu Server con Apache2 + PHP8.
VirtualHost apuntando al directorio raíz.
---
📊 Precortes, Cortes y Postcortes

**Tablas auxiliares:**
pc_precorte: captura de conteo y declarados.
pc_precorte_cash_count: detalle por denominación.
pc_post_corte_kpis_daily: materialización de KPIs diarios.
pc_cfg: configuración general (ej. payouts_in_dpr).

**Funciones:**

_last_assign_window: ventana de turno por usuario/terminal.
fn_precorte_sistema: montos calculados del sistema.
fn_precorte_customs: desglose de pagos custom.
close_zero_tickets: cierre automático de tickets $0.
materialize_kpis_daily: consolidación diaria.

**Trigger:**
reconcile_precorte_on_dpr: al insertar un drawer_pull_report,
reconcilia precortes pendientes y marca discrepancias.

Con esto, el sistema puede mostrar precortes, cortes y postcortes sin afectar la lógica original de Floreant POS.

🔐 Privilegios y usuarios
Privilegios distintos a los del POS.
Control granular por módulo/submódulo.
Plan: interfaz para roles dinámicos.

## 📊 Dashboard actual

- **KPIs**:
  - Ventas del día (vs. día anterior).
  - Producto estrella.
  - Alertas (inventario bajo, diferencia de corte, descuentos, tickets abiertos, etc.).
  - Productos vendidos.
  - Ticket promedio.
- **Gráficas**:
  - Tendencia de ventas (últimos 7 días).
  - Ventas por hora (barras apiladas por sucursal).
  - Top 5 productos (horizontal apilada por sucursal).
  - Ventas por sucursal (efectivo, tarjeta, transferencia).
  - Formas de pago (dona).
- **Listas**:
  - Actividad reciente (últimas acciones del sistema).
  - Órdenes recientes (últimos tickets).

---

## ⚙️ Instalación y ejecución

1. **Clonar el repositorio**  
   git clone https://github.com/tu-org/terrena-pos-admin.git
   cd terrena-pos-admin
Configurar dependencias PHP

bash
Copiar código
composer install
Configurar base de datos

PostgreSQL 9.5+

Importar dump de Floreant POS (dump_19_08_2025_18_33.sql).

Aplicar extensión folio_diario_floreant_optimizado_final_v6_OK_txt.sql.

Configurar conexión en config.php

php
Copiar código
define('DB_HOST','localhost');
define('DB_PORT','5432');
define('DB_NAME','floreant');
define('DB_USER','usuario');
define('DB_PASS','password');
Entorno de desarrollo

XAMPP: copiar en htdocs/terrena/Terrena/ y acceder a
http://localhost/terrena/Terrena/

Producción

Ubuntu Server con Apache2 + PHP8.

VirtualHost apuntando al directorio raíz.

🔐 Privilegios y usuarios
Los privilegios en este sistema no son los mismos que en Floreant POS.

Se implementa un control de acceso a nivel de módulos y submódulos.

Próximos pasos: UI para roles y permisos.

📌 Próximos pasos / backlog
 Interfaz completa de Precorte/Corte/Postcorte en módulo Caja/.

 Dashboard: mostrar estatus de cajas usando tabla auxiliar.

 Conectar KPIs y gráficas con datos reales vía funciones SQL.

 Implementar Inventario → UDM + conversiones.

 Agregar privilegios dinámicos.


---

# 📄 ROADMAP.md (ampliado con Precortes y BD)

```markdown
# 🗺️ Roadmap de Terrena POS Admin

---

## ✅ Fase 1: Maquetación y estructura base (COMPLETADO)

- Layout general (sidebar, topbar, footer).
- Dashboard con KPIs dummy y gráficas Chart.js.
- Módulos creados (estructura carpetas).

---

## ✅ Fase 2: Base de datos y Precortes (COMPLETADO)

- [x] Creación de **tablas auxiliares** (`pc_precorte`, `pc_precorte_cash_count`, `pc_post_corte_kpis_daily`, `pc_cfg`).
- [x] Funciones SQL:
  - `_last_assign_window`
  - `fn_precorte_sistema`
  - `fn_precorte_customs`
  - `close_zero_tickets`
  - `materialize_kpis_daily`
- [x] Trigger `reconcile_precorte_on_dpr`.
- [x] Dumps de referencia en carpeta `query/`:
  - `POS_Cortes_preview_30_08_2025.sql` (con datos).
  - `POS_structure_30_08_2025.sql` (estructura).
  - `precorte_pack_final_v3_consolidated_perfect_v15.1.sql` (auxiliares).

---

## 🚧 Fase 3: Finanzas y Caja

- [ ] Interfaz de **Precorte**:
  - Conteo rápido por denominación.
  - Selección de caja abierta.
  - Tickets abiertos listados para cierre.
- [ ] Interfaz de **Corte**:
  - Conciliación de ventas vs declarados.
  - Arqueo y diferencias.
- [ ] Interfaz de **Postcorte**:
  - Ajustes y validación supervisor.
- [ ] Reportes exportables (PDF/Excel).
- [ ] Dashboard → tarjeta de **Estatus de Cajas** usando tabla `pc_precorte`.

---

## 🚧 Fase 4: Inventario y Compras

- [ ] CRUD de productos con UDM y conversiones.
- [ ] Control de stock mínimo/máximo.
- [ ] Alertas de inventario bajo.
- [ ] Órdenes de compra manuales y automáticas.
- [ ] Recepción de mercancía y conciliación.

---

## 🚧 Fase 5: Recetas y Producción

- [ ] Editor de recetas con costeo automático.
- [ ] Control de mermas.
- [ ] Producción programada.
- [ ] Descuento de inventario al producir.
- [ ] Generación automática de OC si falta stock.

---

## 🚧 Fase 6: Reportes y KPIs

- [ ] Reportes por sucursal, empleado y periodo.
- [ ] Exportación PDF/Excel.
- [ ] Dashboard dinámico (filtros + widgets configurables).

---

## 🚧 Fase 7: Administración y Seguridad

- [ ] CRUD de personal.
- [ ] Roles y privilegios granulares (independientes del POS).
- [ ] Auditoría de acciones.

---

## 🚧 Fase 8: Integraciones

- [ ] Sincronización continua con Floreant POS (lectura).
- [ ] KDS en sucursal Principal.
- [ ] API REST para apps móviles.

👥 Créditos
Desarrollo: SelemTI.
Diseño de interfaz y maquetación: inspirado en sistemas POS/KDS modernos.
POS base: Floreant POS.

no veo nada sobre lo que ya hicimos en la conversación de "Solución precortes caja POS" en estos archivos y es algo muy inportenta por que ya lo tenemos. tampoco veo de la base de datos de postgres ni que el sistema debe consumir la BD sin afectar las funcionabilidad de POS por lo que debemos usar tablas auxiliares adicionales, te comparto el script que usamos final. tambien  en el el proyecto añadire la carpeta de query, la base de datos del pos con datos (respaldo) es el archivo "POS_Cortes_preview_30_08_2025.sql" y solo la estrucutura para consultas más rápidas es "POS_strcuture_30_08_2025.sql" 
