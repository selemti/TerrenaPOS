document.addEventListener('DOMContentLoaded', () => {
  // Sidebar toggles
  const sidebar = document.getElementById('sidebar');
  document.getElementById('sidebarToggle')?.addEventListener('click', ()=> {
    if (window.innerWidth < 992) sidebar.classList.toggle('show'); else sidebar.classList.toggle('d-none');
  });
  document.getElementById('mobileSidebarToggle')?.addEventListener('click', ()=> sidebar.classList.toggle('show'));

  // Reloj vivo (arriba y abajo)
  tickClock(); setInterval(tickClock, 1000);

  // Filtros por fecha
  setupFilters();

  // KPIs, Alertas, Actividad, Órdenes
  renderKpiRegisters();
  renderAlerts();
  renderActivity();
  renderOrders();

  // Gráficas
  initCharts();
});

/* ======================== Reloj ======================== */
function tickClock(){
  const now = new Date();
  const hh = String(now.getHours()).padStart(2,'0');
  const mm = String(now.getMinutes()).padStart(2,'0');
  const ss = String(now.getSeconds()).padStart(2,'0');
  const dd = String(now.getDate()).padStart(2,'0');
  const mo = String(now.getMonth()+1).padStart(2,'0');
  const yyyy = now.getFullYear();
  const hms = `${hh}:${mm}:${ss}`;
  const dmy = `${dd}/${mo}/${yyyy}`;
  document.getElementById('live-clock')?.innerText = hms;
  document.getElementById('live-clock-bottom')?.innerText = hms;
  document.getElementById('live-date')?.innerText = dmy;
}

/* ======================== Filtros ======================== */
function setupFilters(){
  const s = document.getElementById('start-date');
  const e = document.getElementById('end-date');
  const btn = document.getElementById('apply-filters');
  const today = new Date();
  const weekAgo = new Date(today); weekAgo.setDate(today.getDate()-7);
  if (s) s.value = toISODate(weekAgo);
  if (e) e.value = toISODate(today);

  btn?.addEventListener('click', ()=>{
    toast('Filtros aplicados');
    // TODO: disparar fetch a endpoints PHP para recargar datasets y re-renderizar
  });
}
function toISODate(d){return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`}

/* ======================== KPIs ======================== */
function renderKpiRegisters(){
  const rows = [
    {sucursal:'Sucursal 1', abierto:true,  vendido: 3250.50},
    {sucursal:'Sucursal 2', abierto:false, vendido: 0.00},
    {sucursal:'Sucursal 3', abierto:true,  vendido: 1980.00},
  ];
  const tbody = document.getElementById('kpi-registers');
  if (!tbody) return;
  tbody.innerHTML = rows.map(r => `
    <tr>
      <td>${r.sucursal}</td>
      <td>${r.abierto
        ? '<span class="badge text-bg-success">Abierto</span>'
        : '<span class="badge text-bg-secondary">Cerrado</span>'}</td>
      <td class="text-end">${r.abierto ? money(r.vendido) : '-'}</td>
    </tr>`).join('');
}

/* ======================== Alertas ======================== */
function renderAlerts(){
  // TODO: fetch alertas reales; type: low|error|info; minutesAgo
  const data = [
    {type:'low',  icon:'fa-triangle-exclamation text-warning', txt:'Inventario bajo: Leche (10L)',       minutesAgo: 8},
    {type:'error',icon:'fa-circle-exclamation text-danger',    txt:'Diferencia en corte: Sucursal 2',    minutesAgo: 18},
    {type:'info', icon:'fa-tags text-primary',                  txt:'Descuento > $50 en ticket #521',     minutesAgo: 25},
    {type:'low',  icon:'fa-triangle-exclamation text-warning',  txt:'A punto de agotarse: Café de Altura',minutesAgo: 47},
    {type:'info', icon:'fa-ticket text-primary',                txt:'Tickets abiertos: 3 en Sucursal 3',  minutesAgo: 60},
  ].slice(0,5);
  const cont = document.getElementById('alerts-list');
  if (!cont) return;
  cont.innerHTML = data.map(a => `
    <a href="reportes" class="alert-item ${a.type}">
      <i class="icon fa-solid ${a.icon}"></i>
      <span>${a.txt}</span>
      <span class="timeago">${timeago(a.minutesAgo)}</span>
    </a>`).join('');
}

function timeago(mins){
  if (mins < 1) return 'ahora';
  if (mins < 60) return `hace ${mins} min`;
  const h = Math.floor(mins/60); const m = mins%60;
  return `hace ${h}h ${m}m`;
}

/* ======================== Actividad reciente ======================== */
function renderActivity(){
  // TODO: fetch actividad real
  const items = [
    {txt:'Usuario jperez cerró corte en Sucursal 1', minutesAgo:12},
    {txt:'Se registró OC #1024 a Lácteos MX', minutesAgo:28},
    {txt:'Se aplicó descuento 15% ticket #531', minutesAgo:39},
    {txt:'Se generó OP-001 (Tortas de pollo x20)', minutesAgo:52},
    {txt:'Se actualizó costo de Leche 1.5L', minutesAgo:63},
  ].slice(0,5);
  const ul = document.getElementById('activity-list');
  if (!ul) return;
  ul.innerHTML = items.map(i => `
    <li><i class="fa-solid fa-circle small text-muted"></i>
      <span>${i.txt}</span>
      <span class="timeago">${timeago(i.minutesAgo)}</span>
    </li>`).join('');
}

/* ======================== Órdenes recientes ======================== */
function renderOrders(){
  // TODO: fetch órdenes reales
  const rows = [
    {ticket: 1543, suc:'Sucursal 1', hora:'13:42', total: 128.50},
    {ticket: 1542, suc:'Sucursal 3', hora:'13:35', total:  58.00},
    {ticket: 1541, suc:'Sucursal 2', hora:'13:31', total:  82.90},
    {ticket: 1540, suc:'Sucursal 1', hora:'13:25', total:  32.00},
    {ticket: 1539, suc:'Sucursal 1', hora:'13:18', total:  49.00},
  ].slice(0,5);
  const tb = document.getElementById('orders-table');
  if (!tb) return;
  tb.innerHTML = rows.map(r => `
    <tr><td>${r.ticket}</td><td>${r.suc}</td><td>${r.hora}</td><td class="text-end">${money(r.total)}</td></tr>
  `).join('');
}

/* ======================== Gráficas ======================== */
function initCharts(){
  // Tendencia (7d)
  makeLine('salesTrendChart',
    ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'],
    [{label:'Ventas Diarias ($)',data:[2450,3120,2980,4050,4780,6250,5820],bg:'rgba(233,122,58,.2)',stroke:'#E97A3A'}]
  );

  // Ventas por sucursal apiladas (efectivo/tarjeta/transferencia)
  makeStackedBars('branchPaymentsChart',
    ['Sucursal 1','Sucursal 2','Sucursal 3'],
    [
      {label:'Efectivo', data:[2100,1200,1500], color:'#D2B464'},
      {label:'Tarjeta',  data:[2600,1400,1900], color:'#E97A3A'},
      {label:'Transf.',  data:[500,  500,  300], color:'#234330'},
    ]
  );

  // Formas de pago (dona)
  makeDoughnut('paymentChart',
    ['Efectivo','Tarjeta','Transferencia'],
    [650.25,920.5,80], ['#D2B464','#E97A3A','#234330']
  );

  // Ventas por hora (bar)
  makeBars('salesByHourChart',
    ['08h','09h','10h','11h','12h','13h','14h','15h','16h','17h'],
    [{label:'$ por hora', data:[150,230,310,400,620,700,680,540,430,350], color:'#234330'}]
  );

  // Top 5 productos (bar horizontal)
  makeHorizontalBars('topProductsChart',
    ['Latte Vainilla','Capuchino','Torta Pollo','Americano','Croissant'],
    [{label:'Ventas ($)', data:[350.25, 290.10, 245.00, 230.40, 190.50], color:'#E97A3A'}]
  );
}

/* ======================== Helpers Chart.js ======================== */
function makeLine(id, labels, datasets){
  const el = document.getElementById(id); if(!el) return;
  new Chart(el.getContext('2d'),{
    type:'line',
    data:{labels, datasets:datasets.map(d=>({
      label:d.label, data:d.data, fill:true,
      backgroundColor:d.bg, borderColor:d.stroke, tension:.4
    }))},
    options:{responsive:true,maintainAspectRatio:false,
      scales:{x:{grid:{display:false}},y:{beginAtZero:true,grid:{color:'rgba(0,0,0,.05)'}}}}
  });
}
function makeBars(id, labels, datasets){
  const el = document.getElementById(id); if(!el) return;
  new Chart(el.getContext('2d'),{
    type:'bar',
    data:{labels, datasets:datasets.map(d=>({
      label:d.label, data:d.data, backgroundColor:d.color, borderRadius:6
    }))},
    options:{responsive:true,maintainAspectRatio:false,
      scales:{x:{grid:{display:false}},y:{beginAtZero:true,grid:{color:'rgba(0,0,0,.05)'}}}}
  });
}
function makeStackedBars(id, labels, datasets){
  const el = document.getElementById(id); if(!el) return;
  new Chart(el.getContext('2d'),{
    type:'bar',
    data:{labels, datasets:datasets.map(d=>({
      label:d.label, data:d.data, backgroundColor:d.color, borderRadius:6
    }))},
    options:{responsive:true,maintainAspectRatio:false,
      scales:{x:{stacked:true,grid:{display:false}},y:{stacked:true,beginAtZero:true,grid:{color:'rgba(0,0,0,.05)'}}},
      plugins:{legend:{position:'bottom',labels:{usePointStyle:true,padding:16}}}}
  });
}
function makeDoughnut(id, labels, data, colors){
  const el = document.getElementById(id); if(!el) return;
  new Chart(el.getContext('2d'),{
    type:'doughnut',
    data:{labels, datasets:[{data, backgroundColor:colors, hoverOffset:4}]},
    options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:'bottom',labels:{usePointStyle:true,padding:18}}}}
  });
}
function makeHorizontalBars(id, labels, datasets){
  const el = document.getElementById(id); if(!el) return;
  new Chart(el.getContext('2d'),{
    type:'bar',
    data:{labels, datasets:datasets.map(d=>({label:d.label, data:d.data, backgroundColor:d.color, borderRadius:6}))},
    options:{indexAxis:'y', responsive:true, maintainAspectRatio:false,
      scales:{x:{beginAtZero:true, grid:{color:'rgba(0,0,0,.05)'}}, y:{grid:{display:false}}}}
  });
}
function money(n){return n.toLocaleString('es-MX',{style:'currency',currency:'MXN'})}
function toast(msg,type='success'){
  const el=document.createElement('div');
  el.className=`alert alert-${type} alert-dismissible fade show`;
  Object.assign(el.style,{position:'fixed',top:'20px',right:'20px',zIndex:'2000',minWidth:'280px'});
  el.innerHTML=`${msg}<button type="button" class="btn-close" data-bs-dismiss="alert"></button>`;
  document.body.appendChild(el); setTimeout(()=>el.remove(),4000);
}
