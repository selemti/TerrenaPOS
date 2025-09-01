# 🗺️ Roadmap de Terrena POS Admin

Este documento organiza las fases de desarrollo del sistema de **administración y control financiero**
integrado con **Floreant POS**.

---

## ✅ Fase 1: Maquetación y estructura base (COMPLETADO)

- [x] **Layout general**
  - Sidebar con colapso y logo dinámico (logo.svg / logo2.svg).
  - Topbar con reloj, alertas y perfil de usuario.
  - Footer / barra de estado fijo.
- [x] **Dashboard inicial**
  - KPIs principales (ventas, producto estrella, alertas, productos vendidos, ticket promedio).
  - Gráficas de ventas por hora, top 5 productos, sucursales por tipo de pago, formas de pago.
  - Listas de alertas, actividad reciente y órdenes recientes.
- [x] **Módulos base creados** (estructura de carpetas y controladores vacíos).

---

## 🚧 Fase 2: Finanzas y Caja

### Cortes de Caja
- [ ] Implementar **Precorte** con conteo rápido de efectivo y tickets abiertos.
- [ ] Implementar **Corte** (turno/sucursal) con conciliación de ventas y arqueo.
- [ ] Implementar **Postcorte** con ajustes de diferencia.
- [ ] Reportes de cortes exportables (PDF/Excel).
- [ ] Alertas por diferencias detectadas.

### Flujo de Caja
- [ ] Registro de ingresos y egresos operativos.
- [ ] Conciliación con ventas POS.
- [ ] Reportes de flujo de efectivo diario/semanal/mensual.

---

## 🚧 Fase 3: Inventario y Compras

### Inventario
- [ ] CRUD de productos con **unidades de medida (UDM)**.
- [ ] Conversiones (ej: caja de 12 → piezas → ml).
- [ ] Control de stock mínimo/máximo.
- [ ] Alertas de bajo stock / caducidad.
- [ ] Movimientos de inventario (entradas, salidas, ajustes).

### Compras
- [ ] Catálogo de proveedores.
- [ ] Generación de órdenes de compra (manual y automática por stock mínimo).
- [ ] Recepción de mercancía.
- [ ] Conciliación OC vs inventario.

---

## 🚧 Fase 4: Recetas y Producción

### Recetas
- [ ] Editor de recetas con ingredientes y cantidades (UDM).
- [ ] Costeo automático con base en precios de inventario.
- [ ] Control de mermas y desperdicio.
- [ ] Rentabilidad por producto.

### Producción
- [ ] Planificador de producción (ej: 20 tortas de pollo).
- [ ] Validación de stock disponible antes de producir.
- [ ] Descuento automático de inventario al producir.
- [ ] Generación de OC si falta materia prima.

---

## 🚧 Fase 5: Reportes y KPIs avanzados

- [ ] Ventas por sucursal (comparativas históricas).
- [ ] Ventas por empleado.
- [ ] Horas pico y patrones de consumo.
- [ ] Exportación avanzada (PDF/Excel).
- [ ] Dashboard configurables (widgets movibles).

---

## 🚧 Fase 6: Administración y Seguridad

- [ ] **Gestión de personal**
  - CRUD de empleados (datos básicos).
  - Horarios y turnos.
  - Reportes de desempeño por ventas.
- [ ] **Roles y privilegios**
  - Control granular por módulo/submódulo.
  - No depender de roles POS, sistema independiente.
- [ ] Auditoría de acciones de usuario.

---

## 🚧 Fase 7: Integraciones

- [ ] Sincronización automática con Floreant POS:
  - Tickets.
  - Productos.
  - Usuarios/cajeros.
- [ ] KDS (Kitchen Display System) en sucursal Principal.
- [ ] API REST para apps móviles (opcional).

---

## 🚀 Fase 8: Optimización y despliegue

- [ ] Limpieza de CSS (unificar terrena.css con voceo.css).
- [ ] Optimizar consultas PostgreSQL.
- [ ] Implementar tests (PHPUnit).
- [ ] Documentar endpoints y flujo de instalación.
- [ ] Deploy productivo en Ubuntu Server.

---

## 🎯 Prioridades inmediatas (Septiembre 2025)

1. Resolver **sidebarCollapse** → ajustar ancho real + logo centrado.  
2. Reinstalar **Estatus de Cajas** en el Dashboard (con link a cortes).  
3. Mejorar formato de **tablas de actividad y órdenes recientes**.  
4. Implementar **Precorte completo** (con tickets abiertos y conteo rápido).  
5. Crear módulo de **Inventario → UDM + conversiones**.  

---

## 📅 Proyección de entregas

- **Septiembre 2025** → Finanzas y Cortes (precorte/corte/postcorte).  
- **Octubre 2025** → Inventario completo + Compras.  
- **Noviembre 2025** → Recetas y Producción.  
- **Diciembre 2025** → Roles/privilegios + Reportes avanzados.  
- **Q1 2026** → API REST + despliegue productivo.  
