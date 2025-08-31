<?php
use Terrena\Core\Auth;
$base = $GLOBALS['__BASE__'] ?? '';     // p.ej. /terrena/Terrena
$user = Auth::user();
?><!DOCTYPE html>
<html lang="es">
<head>
  <base href="<?= htmlspecialchars($base . '/', ENT_QUOTES) ?>">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Voceo POS – <?= htmlspecialchars($title ?? '') ?></title>

  <!-- Bootstrap + Icons -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css" rel="stylesheet">
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet">

  <!-- Fuentes locales -->
  <style>
    @font-face{font-family:'Montserrat';src:url('assets/font/Montserrat/static/Montserrat-Regular.ttf') format('truetype');font-weight:400;font-style:normal;font-display:swap}
    @font-face{font-family:'Montserrat';src:url('assets/font/Montserrat/static/Montserrat-Bold.ttf') format('truetype');font-weight:700;font-style:normal;font-display:swap}
    @font-face{font-family:'Anton';src:url('assets/font/Anton/Anton-Regular.ttf') format('truetype');font-weight:400;font-style:normal;font-display:swap}
  </style>

  <!-- Estilos del proyecto -->
  <link rel="stylesheet" href="assets/css/terrena.css">

  <!-- Chart.js (las vistas lo usan) -->
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
<div class="container-fluid p-0 d-flex" style="min-height:100vh;">
  <!-- Sidebar -->
  <aside class="sidebar d-none d-lg-flex flex-column" id="sidebar">
    <div class="logo-brand"><i class="fa-solid fa-mug-hot me-2"></i>Voceo POS</div>
    <nav class="nav flex-column">
      <?php if (Auth::can('dashboard.view')): ?>
        <a class="nav-link <?= ($title??'')==='Dashboard'?'active':'' ?>" href="dashboard"><i class="fa-solid fa-gauge"></i> Dashboard</a>
      <?php endif; ?>
      <?php if (Auth::can('cashcuts.view')): ?>
        <a class="nav-link <?= ($title??'')==='Cortes de caja'?'active':'' ?>" href="caja/cortes"><i class="fa-solid fa-cash-register"></i> Cortes de Caja</a>
      <?php endif; ?>
      <?php if (Auth::can('inventory.view')): ?>
        <a class="nav-link <?= ($title??'')==='Inventario'?'active':'' ?>" href="inventario"><i class="fa-solid fa-boxes-stacked"></i> Inventario</a>
      <?php endif; ?>
      <?php if (Auth::can('purchasing.view')): ?>
        <a class="nav-link <?= ($title??'')==='Compras'?'active':'' ?>" href="compras"><i class="fa-solid fa-receipt"></i> Compras</a>
      <?php endif; ?>
      <?php if (Auth::can('recipes.view')): ?>
        <a class="nav-link <?= ($title??'')==='Recetas & Costos'?'active':'' ?>" href="recetas"><i class="fa-solid fa-utensils"></i> Recetas</a>
      <?php endif; ?>
      <?php if (Auth::can('production.view')): ?>
        <a class="nav-link <?= ($title??'')==='Producción'?'active':'' ?>" href="produccion"><i class="fa-solid fa-kitchen-set"></i> Producción</a>
      <?php endif; ?>
      <?php if (Auth::can('reports.view')): ?>
        <a class="nav-link <?= ($title??'')==='Reportes'?'active':'' ?>" href="reportes"><i class="fa-solid fa-chart-line"></i> Reportes</a>
      <?php endif; ?>
      <?php if (Auth::can('admin.view')): ?>
        <a class="nav-link <?= ($title??'')==='Admin'?'active':'' ?>" href="admin"><i class="fa-solid fa-gear"></i> Configuración</a>
      <?php endif; ?>
      <?php if (Auth::can('people.view')): ?>
        <a class="nav-link <?= ($title??'')==='Personal'?'active':'' ?>" href="personal"><i class="fa-solid fa-users"></i> Personal</a>
      <?php endif; ?>
    </nav>
  </aside>

  <!-- Main -->
  <main class="main-content flex-grow-1">
    <!-- Top bar -->
    <div class="top-bar">
      <div class="d-flex align-items-center gap-2">
        <button class="btn btn-sm btn-outline-secondary d-lg-none" id="sidebarToggle"><i class="fa-solid fa-bars"></i></button>
        <h1 class="top-bar-title m-0"><?= htmlspecialchars($title ?? '') ?></h1>
      </div>

      <!-- Usuario + reloj + menú -->
      <div class="d-flex align-items-center gap-3">
        <div class="d-none d-md-flex align-items-center text-muted small">
          <i class="fa-regular fa-clock me-2"></i>
          <span id="live-clock">--:--:--</span>
        </div>

        <div class="dropdown">
          <button class="btn btn-sm btn-outline-secondary d-flex align-items-center gap-2" data-bs-toggle="dropdown">
            <div class="user-profile-icon"><i class="fa-solid fa-user"></i></div>
            <span class="fw-semibold d-none d-sm-inline"><?= htmlspecialchars($user['fullname'] ?? 'Usuario') ?></span>
            <i class="fa-solid fa-chevron-down small"></i>
          </button>
          <ul class="dropdown-menu dropdown-menu-end shadow">
            <li class="dropdown-header">
              <div class="small text-muted">Conectado como</div>
              <div class="fw-semibold"><?= htmlspecialchars($user['username'] ?? 'user') ?></div>
            </li>
            <li><hr class="dropdown-divider"></li>
            <li><a class="dropdown-item" href="personal"><i class="fa-regular fa-id-card me-2"></i>Mi perfil</a></li>
            <li><a class="dropdown-item" href="admin"><i class="fa-solid fa-gear me-2"></i>Configuración</a></li>
            <li><a class="dropdown-item" href="#"><i class="fa-solid fa-key me-2"></i>Cambiar contraseña</a></li>
            <li><hr class="dropdown-divider"></li>
            <li><a class="dropdown-item text-danger" href="#"><i class="fa-solid fa-right-from-bracket me-2"></i>Cerrar sesión</a></li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Contenido de cada vista -->
    <div class="dashboard-grid">
      <?= $content ?? '' ?>
    </div>

    <!-- Footer / barra de estado -->
    <footer class="status-bar">
      <div class="container-status">
        <span class="me-3"><i class="fa-solid fa-store me-1"></i> Sucursal: <strong>PRINCIPAL</strong></span>
        <span class="me-3"><i class="fa-regular fa-calendar me-1"></i> <span id="live-date">--/--/----</span></span>
        <span><i class="fa-regular fa-clock me-1"></i> <span id="live-clock-bottom">--:--:--</span></span>
      </div>
    </footer>
  </main>
</div>

<!-- Toggle móvil flotante -->
<button class="mobile-nav-toggle d-lg-none" id="mobileSidebarToggle" aria-label="Menú"><i class="fa-solid fa-bars"></i></button>

<!-- Bootstrap JS + JS del proyecto -->
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="assets/js/terrena.js"></script>
</body>
</html>
