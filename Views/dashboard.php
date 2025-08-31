<?php $title='Dashboard'; ob_start(); ?>

<!-- Filtros -->
<div class="filters-bar">
  <div class="d-flex align-items-center gap-2">
    <label class="mb-0">Sucursal</label>
    <select id="branch-select" class="form-select form-select-sm w-auto">
      <option value="all">Todas</option>
      <option value="s1">Sucursal 1</option>
      <option value="s2">Sucursal 2</option>
      <option value="s3">Sucursal 3</option>
    </select>
  </div>
  <div class="d-flex align-items-center gap-2">
    <label class="mb-0">Rango</label>
    <input type="date" id="start-date" class="form-control form-control-sm w-auto">
    <span class="text-muted">a</span>
    <input type="date" id="end-date" class="form-control form-control-sm w-auto">
  </div>
  <button class="btn btn-filter btn-sm" id="apply-filters"><i class="fa-solid fa-filter me-1"></i> Aplicar</button>
</div>

<!-- Tarjetas KPI -->
<div class="row g-3 mb-3">
  <div class="col-6 col-xl-2"><div class="card-kpi text-center">
    <h5 class="card-title"><i class="fa-solid fa-dollar-sign"></i> Ventas del día</h5>
    <div class="kpi-value" id="kpi-sales">$8,450</div>
    <div class="small text-muted"><span id="kpi-sales-tx">124 transacciones</span></div>
    <span class="badge bg-success mt-1" id="kpi-sales-diff">+12.5% vs. ayer</span>
  </div></div>

  <div class="col-6 col-xl-2"><div class="card-kpi text-center">
    <h5 class="card-title"><i class="fa-solid fa-mug-saucer"></i> Producto estrella</h5>
    <div class="kpi-value" id="kpi-top-item">Latte Vainilla</div>
    <div class="small text-muted" id="kpi-top-amount">$350.25 en ventas</div>
  </div></div>

  <div class="col-6 col-xl-2"><div class="card-kpi text-center">
    <h5 class="card-title"><i class="fa-solid fa-bell"></i> Alertas</h5>
    <div class="kpi-value" id="kpi-alerts">5</div>
    <div class="small text-muted">Inventario & Caja</div>
    <a href="reportes" class="stretched-link small fw-semibold">Ver todas</a>
  </div></div>

  <div class="col-6 col-xl-2"><div class="card-kpi text-center">
    <h5 class="card-title"><i class="fa-solid fa-box-open"></i> Productos vendidos</h5>
    <div class="kpi-value" id="kpi-items">385</div>
    <span class="badge bg-success mt-1" id="kpi-items-diff">+7.2% vs. ayer</span>
  </div></div>

  <div class="col-6 col-xl-2"><div class="card-kpi text-center">
    <h5 class="card-title"><i class="fa-solid fa-ticket"></i> Ticket promedio</h5>
    <div class="kpi-value" id="kpi-ticket">$68.15</div>
    <span class="badge bg-danger mt-1" id="kpi-ticket-diff">-1.1% vs. ayer</span>
  </div></div>

  <div class="col-12 col-xl-2"><div class="card-kpi">
    <h5 class="card-title"><i class="fa-solid fa-cash-register"></i> Estatus de cajas</h5>
    <div class="table-responsive">
      <table class="table table-sm mb-0 align-middle">
        <thead><tr><th>Sucursal</th><th>Estatus</th><th class="text-end">Vendido</th></tr></thead>
        <tbody id="kpi-registers"><!-- JS --></tbody>
      </table>
    </div>
  </div></div>
</div>

<!-- Tendencia + Alertas -->
<div class="row g-3 mb-3">
  <div class="col-lg-8">
    <div class="chart-container">
      <h5 class="card-title mb-2"><i class="fa-solid fa-chart-line"></i> Tendencia de ventas</h5>
      <div class="chart-wrapper"><canvas id="salesTrendChart"></canvas></div>
    </div>
  </div>
  <div class="col-lg-4">
    <div class="card-alerts">
      <div class="d-flex justify-content-between align-items-center mb-2">
        <h5 class="card-title mb-0"><i class="fa-solid fa-bell"></i> Alertas</h5>
        <a href="reportes" class="small fw-semibold">Ver todas</a>
      </div>
      <div id="alerts-list"><!-- JS --></div>
    </div>
  </div>
</div>

<!-- Ventas por sucursal (apiladas por FP) + Formas de pago -->
<div class="row g-3 mb-3">
  <div class="col-lg-8">
    <div class="chart-container">
      <h5 class="card-title mb-2"><i class="fa-solid fa-store"></i> Ventas por sucursal (Efectivo / Tarjeta / Transferencia)</h5>
      <div class="chart-wrapper"><canvas id="branchPaymentsChart"></canvas></div>
    </div>
  </div>
  <div class="col-lg-4">
    <div class="chart-container">
      <h5 class="card-title mb-2"><i class="fa-solid fa-credit-card"></i> Formas de pago</h5>
      <div class="chart-wrapper"><canvas id="paymentChart"></canvas></div>
    </div>
  </div>
</div>

<!-- Ventas por hora + Top 5 productos -->
<div class="row g-3 mb-3">
  <div class="col-lg-6">
    <div class="chart-container">
      <h5 class="card-title mb-2"><i class="fa-regular fa-clock"></i> Ventas por hora</h5>
      <div class="chart-wrapper"><canvas id="salesByHourChart"></canvas></div>
    </div>
  </div>
  <div class="col-lg-6">
    <div class="chart-container">
      <div class="d-flex justify-content-between">
        <h5 class="card-title mb-2"><i class="fa-solid fa-ranking-star"></i> Top 5 productos</h5>
        <a href="reportes" class="small fw-semibold">Ver todo</a>
      </div>
      <div class="chart-wrapper"><canvas id="topProductsChart"></canvas></div>
    </div>
  </div>
</div>

<!-- Actividad reciente + Órdenes recientes -->
<div class="row g-3">
  <div class="col-lg-6">
    <div class="card-vo">
      <div class="d-flex justify-content-between align-items-center mb-2">
        <h5 class="card-title mb-0"><i class="fa-solid fa-bolt"></i> Actividad reciente</h5>
        <a href="reportes" class="small fw-semibold">Ver todo</a>
      </div>
      <ul class="list-unstyled mb-0" id="activity-list"><!-- JS --></ul>
    </div>
  </div>
  <div class="col-lg-6">
    <div class="card-vo">
      <div class="d-flex justify-content-between align-items-center mb-2">
        <h5 class="card-title mb-0"><i class="fa-solid fa-receipt"></i> Órdenes recientes</h5>
        <a href="reportes" class="small fw-semibold">Ver todo</a>
      </div>
      <div class="table-responsive">
        <table class="table table-sm align-middle mb-0">
          <thead><tr><th>#Ticket</th><th>Sucursal</th><th>Hora</th><th class="text-end">Total</th></tr></thead>
          <tbody id="orders-table"><!-- JS --></tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<?php $content = ob_get_clean(); require __DIR__.'/layout.php'; ?>
