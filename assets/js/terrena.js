// Terrena JS – Layout + Dashboard
// Sucursales (fijo por ahora, luego desde BD)
const BRANCHES = ['Principal','NB','Torre','Terrena'];

// Rutas de logos
const LOGO_FULL = (window.__BASE__ || '') + '/assets/img/logo.svg';
const LOGO_MINI = (window.__BASE__ || '') + '/assets/img/logo2.svg';

document.addEventListener('DOMContentLoaded', () => {
  const sidebar             = document.getElementById('sidebar');
  const sidebarCollapseBtn  = document.getElementById('sidebarCollapse');        // desktop
  const sidebarToggleMobile = document.getElementById('sidebarToggleMobile');    // móvil
  const logoImg             = document.getElementById('logoImg');                // <img> del logo

  // ===== Toggle MÓVIL (off-canvas) =====
  sidebarToggleMobile?.addEventListener('click', (e) => {
    e.preventDefault();
    if (window.innerWidth < 992) sidebar?.classList.toggle('show');
  });
  // Cierra tocando fuera (solo móvil)
  document.addEventListener('click', (ev) => {
    if (window.innerWidth >= 992) return;
    if (!sidebar?.classList.contains('show')) return;
    const clickedInside = sidebar.contains(ev.target) || sidebarToggleMobile?.contains(ev.target);
    if (!clickedInside) sidebar.classList.remove('show');
  });

  // ===== Collapse DESKTOP =====
  sidebarCollapseBtn?.addEventListener('click', (e) => {
    e.preventDefault();
    if (!sidebar) return;
    sidebar.classList.toggle('collapsed');

    // Cambia logo según estado
    if (logoImg) {
      const isCollapsed = sidebar.classList.contains('collapsed');
      logoImg.src = isCollapsed ? LOGO_MINI : LOGO_FULL;
      logoImg.alt = isCollapsed ? 'Terrena mini' : 'Terrena';
    }
  });
  // Ajuste si recarga colapsado (por CSS server-side, si aplica)
  if (logoImg && sidebar?.classList.contains('collapsed')) {
    logoImg.src = LOGO_MINI;
  }

  // ===== Reloj / Fecha =====
  tickClock();
  setInterval(tickClock, 1000);

  // ===== Filtros =====
  setupFilters();

  // ===== Listas (header y tablero) =====
  renderHeaderAlerts();
  renderKpiRegisters();
  renderActivity();
  renderOrders();

  // ===== Gráficas =====
  initCharts();
});

/* =============== Reloj =============== */
function tickClock(){
  const now = new Date();
  const hh = String(now.getHours()).padStart(2,'0');
  const mm = String(now.getMinutes()).padStart(2,'0');
  const dd = String(now.getDate()).padStart(2,'0');
  const mo = String(now.getMonth()+1).padStart(2,'0');
  const yyyy = now.getFullYear();

  const topClock    = document.getElementById('live-clock');         // header
  const bottomClock = document.getElementById('live-clock-bottom');  // footer
  const dateEl      = document.getElementById('live-date');          // footer

  if (topClock)    topClock.textContent    = `${hh}:${mm}`;
  if (bottomClock) bottomClock.textContent = `${hh}:${mm}`;
  if (dateEl)      dateEl.textContent      = `${dd}/${mo}/${yyyy}`;
}

/* =============== Filtros =============== */
function setupFilters(){
  const s = document.getElementById('start-date');
  const e = document.getElementById('end-date');
  const btn = document.getElementById('apply-filters');
  if (!s || !e) return;

  const today = new Date();
  const weekAgo = new Date(today); weekAgo.setDate(today.getDate() - 7);

  s.value = toISODate(weekAgo);
  e.value = toISODate(today);

  btn?.addEventListener('click', () => {
    toast('Filtros aplicados');
    // TODO: fetch a PHP/PostgreSQL, refrescar KPIs/Charts/Tablas
  });
}
function toISODate(d){return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`}

/* =============== Header Alerts (campana) =============== */
function renderHeaderAlerts(){
  const badge = document.getElementById('hdr-alerts-badge');
  const list  = document.getElementById('hdr-alerts-list');
  if (!badge || !list) return;

  // Dummy (reemplazar por tu API)
  const data = [
    {type:'low',  icon:'fa-triangle-exclamation text-warning', txt:'Inventario bajo: Leche (10L)',       minutesAgo: 8},
    {type:'error',icon:'fa-circle-exclamation text-danger',    txt:'Diferencia en corte: Sucursal NB',   minutesAgo: 18},
    {type:'info', icon:'fa-tags text-primary',                 txt:'Descuento > $50 en ticket #521',     minutesAgo: 25},
    {type:'low',  icon:'fa-triangle-exclamation text-warning', txt:'A punto de agotarse: Café de Altura',minutesAgo: 47},
    {type:'info', icon:'fa-ticket text-primary',               txt:'Tickets abiertos: 3 en Torre',       minutesAgo: 60},
  ].slice(0,5);

  badge.textContent = data.length;
  badge.style.display = (data.length > 0) ? 'inline-block' : 'none';

  list.innerHTML = data.map(a => `
    <a class="hdr-alert" href="${(window.__BASE__||'')+'/reportes'}">
      <i class="fa-solid ${a.icon}"></i>
      <span>${a.txt}</span>
      <span class="timeago">${timeago(a.minutesAgo)}</span>
    </a>`).join('');
}

/* =============== KPIs – Estatus de cajas (tabla) =============== */
function renderKpiRegisters(){
  const tbody = document.getElementById('kpi-registers');
  if (!tbody) return;
  const rows = [
    {sucursal:'Principal', abierto:true,  vendido: 3250.50},
    {sucursal:'NB',        abierto:false, vendido: 0.00},
    {sucursal:'Torre',     abierto:true,  vendido: 1980.00},
    {sucursal:'Terrena',   abierto:false, vendido: 0.00},
  ];
  tbody.innerHTML = rows.map(r => `
    <tr>
      <td>${r.sucursal}</td>
      <td>${r.abierto
        ? '<span class="badge text-bg-success">Abierto</span>'
        : '<span class="badge text-bg-secondary">Cerrado</span>'}</td>
      <td class="text-end">${r.abierto ? money(r.vendido) : '-'}</td>
    </tr>`).join('');
}

/* =============== Actividad reciente =============== */
function renderActivity(){
  const ul = document.getElementById('activity-list');
  if (!ul) return;
  const items = [
    {txt:'Admin cerró corte en Principal', minutesAgo:12},
    {txt:'OC #1024 registrada a Lácteos MX', minutesAgo:28},
    {txt:'Descuento 15% aplicado en ticket #531', minutesAgo:39},
    {txt:'OP-001 (Tortas de pollo x20) generada', minutesAgo:52},
    {txt:'Costo actualizado: Leche 1.5L', minutesAgo:63},
  ].slice(0,5);
  ul.innerHTML = items.map(i => `
    <li><i class="fa-solid fa-circle small text-muted"></i>
      <span>${i.txt}</span>
      <span class="timeago">${timeago(i.minutesAgo)}</span>
    </li>`).join('');
}

/* =============== Órdenes recientes =============== */
function renderOrders(){
  const tb = document.getElementById('orders-table');
  if (!tb) return;
  const rows = [
    {ticket: 1543, suc:'Principal', hora:'13:42', total: 128.50},
    {ticket: 1542, suc:'Torre',     hora:'13:35', total:  58.00},
    {ticket: 1541, suc:'NB',        hora:'13:31', total:  82.90},
    {ticket: 1540, suc:'Principal', hora:'13:25', total:  32.00},
    {ticket: 1539, suc:'Principal', hora:'13:18', total:  49.00},
  ].slice(0,5);
  tb.innerHTML = rows.map(r => `
    <tr><td>${r.ticket}</td><td>${r.suc}</td><td>${r.hora}</td><td class="text-end">${money(r.total)}</td></tr>
  `).join('');
}

/* =============== Helpers =============== */
function timeago(mins){
  if (mins < 1) return 'ahora';
  if (mins < 60) return `hace ${mins} min`;
  const h = Math.floor(mins/60); const m = mins%60;
  return `hace ${h}h ${m}m`;
}
function money(n){ return n.toLocaleString('es-MX',{style:'currency',currency:'MXN'}); }
function toast(msg,type='success'){
  const el=document.createElement('div');
  el.className=`alert alert-${type} alert-dismissible fade show`;
  Object.assign(el.style,{position:'fixed',top:'20px',right:'20px',zIndex:'2000',minWidth:'280px'});
  el.innerHTML=`${msg}<button type="button" class="btn-close" data-bs-dismiss="alert"></button>`;
  document.body.appendChild(el); setTimeout(()=>el.remove(),4000);
}

/* =============== Charts =============== */
function initCharts(){
  if (typeof Chart === 'undefined') return;

  // Tendencia 7 días
  if (document.getElementById('salesTrendChart')) {
    makeLine('salesTrendChart',
      ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'],
      [{label:'Ventas Diarias ($)',data:[2450,3120,2980,4050,4780,6250,5820],bg:'rgba(233,122,58,.2)',stroke:'#E97A3A'}]
    );
  }

  // Ventas por hora – barra apilada por sucursal
  if (document.getElementById('salesByHourChart')) {
    const hours = ['08h','09h','10h','11h','12h','13h','14h','15h','16h','17h'];
    makeStackedBars('salesByHourChart', hours, [
      {label:'Principal', data:[120,180,260,340,520,620,600,520,430,350], color:'#234330'},
      {label:'NB',        data:[ 20, 30, 45, 60,  80,100, 90, 70, 50, 40], color:'#D2B464'},
      {label:'Torre',     data:[ 10, 20, 35,  0,  20, 30, 40, 50, 60, 70], color:'#E97A3A'},
      {label:'Terrena',   data:[  0,  0, 10, 20,  30, 50, 60, 40, 20, 10], color:'#6C757D'},
    ]);
  }

  // Top 5 productos – horizontal apilada por sucursal
  if (document.getElementById('topProductsChart')) {
    const labels = ['Latte Vainilla','Capuchino','Torta Pollo','Americano','Croissant'];
    makeStackedHorizontalBars('topProductsChart', labels, [
      {label:'Principal', data:[350.25, 290.10, 245.00, 230.40, 190.50], color:'#234330'},
      {label:'NB',        data:[ 40.00,  35.00,  20.00,  18.00,  12.00], color:'#D2B464'},
      {label:'Torre',     data:[ 30.00,  25.00,  18.00,  15.00,  10.00], color:'#E97A3A'},
      {label:'Terrena',   data:[ 10.00,  12.00,   8.00,   9.00,   6.00], color:'#6C757D'},
    ]);
  }

  // Ventas por sucursal por tipo (apilada)
  if (document.getElementById('branchPaymentsChart')) {
    makeStackedBars('branchPaymentsChart', BRANCHES, [
      {label:'Efectivo', data:[2100,1800,1200,900],  color:'#D2B464'},
      {label:'Tarjeta',  data:[2600,1500,1400,800],  color:'#E97A3A'},
      {label:'Transf.',  data:[ 500, 300, 250,120],  color:'#234330'},
    ]);
  }

  // Formas de pago (dona)
  if (document.getElementById('paymentChart')) {
    makeDoughnut('paymentChart',
      ['Efectivo','Tarjeta','Transferencia'],
      [650.25, 920.50, 80.00],
      ['#D2B464','#E97A3A','#234330']
    );
  }
}

/* ====== Chart helpers ====== */
function makeLine(canvasId, labels, datasets){
  const ctx = document.getElementById(canvasId);
  new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: datasets.map(ds => ({
        label: ds.label,
        data: ds.data,
        fill: true,
        backgroundColor: ds.bg || 'rgba(0,0,0,.05)',
        borderColor: ds.stroke || '#333',
        tension: 0.35,
        pointRadius: 0
      }))
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { display: true } },
      scales: { x: { grid:{display:false} }, y: { beginAtZero: true } }
    }
  });
}

function makeStackedBars(canvasId, labels, series){
  const ctx = document.getElementById(canvasId);
  new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: series.map(s => ({
        label: s.label, data: s.data, backgroundColor: s.color, borderWidth:0
      }))
    },
    options: {
      responsive:true, maintainAspectRatio:false,
      plugins:{ legend:{ display:true } },
      scales:{
        x:{ stacked:true, grid:{ display:false } },
        y:{ stacked:true, beginAtZero:true }
      }
    }
  });
}

function makeStackedHorizontalBars(canvasId, labels, series){
  const ctx = document.getElementById(canvasId);
  new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: series.map(s => ({
        label: s.label, data: s.data, backgroundColor: s.color, borderWidth:0
      }))
    },
    options: {
      indexAxis: 'y',
      responsive:true, maintainAspectRatio:false,
      plugins:{ legend:{ display:true } },
      scales:{
        x:{ stacked:true, beginAtZero:true },
        y:{ stacked:true, grid:{ display:false } }
      }
    }
  });
}

function makeDoughnut(canvasId, labels, data, colors){
  const ctx = document.getElementById(canvasId);
  new Chart(ctx, {
    type: 'doughnut',
    data: { labels, datasets:[{ data, backgroundColor: colors }] },
    options: { responsive:true, maintainAspectRatio:false, plugins:{ legend:{ position:'bottom' } } }
  });
}
