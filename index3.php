<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema Administrativo - Cafetería</title>
    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Bootstrap Icons -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css">
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <!-- Custom CSS -->
    <style>
        :root {
            --bg-main: #EAEAEA;
            --green-dark: #234330;
            --green-darker: #1E3A2A;
            --orange: #E97A3A;
            --gold: #D2B464;
            --gray-light: #F5F5F5;
            --gray-medium: #DDD;
            --text-dark: #333;
            --text-light: #FFF;
        }

        /* Importación de fuentes locales */
        @font-face {
            font-family: 'Montserrat';
            src: url('font/Montserrat/static/Montserrat-Regular.ttf') format('truetype');
            font-weight: 400;
            font-style: normal;
            font-display: swap;
        }
        
        @font-face {
            font-family: 'Montserrat';
            src: url('font/Montserrat/static/Montserrat-SemiBold.ttf') format('truetype');
            font-weight: 600;
            font-style: normal;
            font-display: swap;
        }
        
        @font-face {
            font-family: 'Montserrat';
            src: url('font/Montserrat/static/Montserrat-Black.ttf') format('truetype');
            font-weight: 900;
            font-style: normal;
            font-display: swap;
        }
        
        @font-face {
            font-family: 'Roboto';
            src: url('font/Roboto/static/Roboto-Regular.ttf') format('truetype');
            font-weight: 400;
            font-style: normal;
            font-display: swap;
        }
        
        @font-face {
            font-family: 'Roboto';
            src: url('font/Roboto/static/Roboto-Medium.ttf') format('truetype');
            font-weight: 500;
            font-style: normal;
            font-display: swap;
        }

        body {
            font-family: 'Montserrat', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--bg-main);
            color: var(--text-dark);
            background-image: url("data:image/svg+xml,%3Csvg width='100' height='100' viewBox='0 0 100 100' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M11 18c3.866 0 7-3.134 7-7s-3.134-7-7-7-7 3.134-7 7 3.134 7 7 7zm48 25c3.866 0 7-3.134 7-7s-3.134-7-7-7-7 3.134-7 7 3.134 7 7 7zm-43-7c1.657 0 3-1.343 3-3s-1.343-3-3-3-3 1.343-3 3 1.343 3 3 3zm63 31c1.657 0 3-1.343 3-3s-1.343-3-3-3-3 1.343-3 3 1.343 3 3 3zM34 90c1.657 0 3-1.343 3-3s-1.343-3-3-3-3 1.343-3 3 1.343 3 3 3zm56-76c1.657 0 3-1.343 3-3s-1.343-3-3-3-3 1.343-3 3 1.343 3 3 3zM12 86c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm28-65c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm23-11c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm-6 60c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm29 22c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zM32 63c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm57-13c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm-9-21c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2zM60 91c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2zM35 41c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2zM12 60c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2z' fill='%23c5c5c5' fill-opacity='0.2' fill-rule='evenodd'/%3E%3C/svg%3E");
        }

        /* Topbar fija */
        .topbar {
            background-color: var(--green-dark);
            color: var(--text-light);
            padding: 12px 20px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            position: sticky;
            top: 0;
            z-index: 1000;
        }

        /* Sidebar */
        .sidebar {
            background-color: var(--green-darker);
            color: var(--text-light);
            height: 100vh;
            position: fixed;
            z-index: 100;
            box-shadow: 3px 0 10px rgba(0, 0, 0, 0.1);
            width: 250px;
            transition: all 0.3s ease;
        }

        .sidebar .logo {
            padding: 20px 15px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            font-family: 'Montserrat', sans-serif;
            font-weight: 900;
        }

        .sidebar .nav-link {
            color: rgba(255, 255, 255, 0.8);
            padding: 12px 20px;
            margin: 4px 0;
            border-radius: 5px;
            transition: all 0.3s;
            font-family: 'Montserrat', sans-serif;
            font-weight: 500;
        }

        .sidebar .nav-link:hover, .sidebar .nav-link.active {
            background-color: var(--orange);
            color: var(--text-light);
        }

        .sidebar .nav-link i {
            margin-right: 10px;
            width: 24px;
            text-align: center;
        }

        /* Main Content */
        .main-content {
            margin-left: 250px;
            padding: 20px;
            transition: all 0.3s;
        }

        /* Cards */
        .card {
            border: none;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
            margin-bottom: 20px;
            background-color: white;
        }

        .card-header {
            background-color: var(--green-dark);
            color: var(--text-light);
            border-radius: 12px 12px 0 0 !important;
            font-weight: 600;
            font-family: 'Montserrat', sans-serif;
            padding: 15px 20px;
        }

        /* Buttons */
        .btn-primary {
            background-color: var(--green-dark);
            border-color: var(--green-dark);
        }

        .btn-primary:hover {
            background-color: var(--green-darker);
            border-color: var(--green-darker);
        }

        .btn-warning {
            background-color: var(--orange);
            border-color: var(--orange);
            color: white;
        }

        .btn-warning:hover {
            background-color: #d4692e;
            border-color: #d4692e;
            color: white;
        }

        .btn-outline-primary {
            color: var(--green-dark);
            border-color: var(--green-dark);
        }

        .btn-outline-primary:hover {
            background-color: var(--green-dark);
            color: var(--text-light);
        }

        .btn-gold {
            background-color: var(--gold);
            border-color: var(--gold);
            color: var(--text-dark);
            font-weight: 600;
        }

        .btn-gold:hover {
            background-color: #c19c4b;
            border-color: #c19c4b;
            color: var(--text-dark);
        }

        /* KPI Cards */
        .kpi-card {
            border-left: 4px solid var(--orange);
            transition: all 0.3s;
        }

        .kpi-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 15px rgba(0, 0, 0, 0.1);
        }

        .kpi-icon {
            font-size: 2rem;
            color: var(--orange);
        }

        /* Tables */
        .table th {
            background-color: var(--green-dark);
            color: var(--text-light);
            font-family: 'Montserrat', sans-serif;
            font-weight: 600;
        }

        .table-hover tbody tr:hover {
            background-color: rgba(233, 122, 58, 0.1);
        }

        /* Badges */
        .badge.bg-success {
            background-color: var(--green-dark) !important;
        }

        .badge.bg-warning {
            background-color: var(--orange) !important;
        }

        /* Charts container */
        .chart-container {
            position: relative;
            height: 300px;
        }

        /* Mobile bottom navigation */
        .mobile-nav {
            display: none;
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            background-color: var(--green-darker);
            z-index: 1000;
            padding: 8px 0;
            box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
        }

        .mobile-nav-item {
            text-align: center;
            color: rgba(255, 255, 255, 0.7);
            text-decoration: none;
            font-size: 0.7rem;
            padding: 8px 5px;
        }

        .mobile-nav-item.active {
            color: var(--orange);
        }

        .mobile-nav-item i {
            display: block;
            font-size: 1.2rem;
            margin-bottom: 4px;
        }

        /* Responsive adjustments */
        @media (max-width: 992px) {
            .sidebar {
                transform: translateX(-100%);
                width: 220px;
            }
            
            .sidebar.show {
                transform: translateX(0);
            }
            
            .main-content {
                margin-left: 0;
            }
            
            .mobile-nav {
                display: flex;
                justify-content: space-around;
            }
            
            .topbar .datetime {
                font-size: 0.9rem;
            }
        }

        @media (max-width: 768px) {
            .kpi-card {
                margin-bottom: 15px;
            }
            
            .card-header {
                padding: 12px 15px;
            }
            
            .topbar .logo {
                font-size: 1.2rem;
            }
        }

        @media (max-width: 576px) {
            .main-content {
                padding: 15px 10px;
            }
            
            .topbar {
                padding: 10px 15px;
            }
            
            .table-responsive {
                font-size: 0.85rem;
            }
        }

        /* Toggle sidebar button */
        .sidebar-toggle {
            background: var(--orange);
            border: none;
            color: white;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            position: fixed;
            bottom: 80px;
            left: 15px;
            z-index: 101;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
        }
        
        /* Ajustes para el contenido con barra de navegación móvil */
        .content-with-mobile-nav {
            padding-bottom: 70px;
        }
    </style>
</head>
<body>
    <!-- Topbar -->
    <div class="topbar d-flex justify-content-between align-items-center">
        <div class="d-flex align-items-center">
            <div class="logo me-4">
                <h4 class="mb-0"><i class="fas fa-mug-hot me-2" style="color: var(--gold);"></i> CaféAdmin</h4>
            </div>
            <div class="datetime">
                <i class="fas fa-calendar-alt me-2"></i>
                <span id="current-date">20 de Julio, 2023</span>
                <i class="fas fa-clock ms-3 me-2"></i>
                <span id="current-time">10:45 AM</span>
            </div>
        </div>
        <div class="d-flex align-items-center">
            <div class="conn me-4">
                <i class="fas fa-wifi me-2"></i>
                <span id="connStatus">Conectado</span>
                <span class="dot ok ms-2"></span>
            </div>
            <div class="dropdown">
                <button class="btn btn-gold dropdown-toggle" type="button" id="userDropdown" data-bs-toggle="dropdown" aria-expanded="false">
                    <i class="fas fa-user me-2"></i> Administrador
                </button>
                <ul class="dropdown-menu" aria-labelledby="userDropdown">
                    <li><a class="dropdown-item" href="#"><i class="fas fa-user-circle me-2"></i>Mi Perfil</a></li>
                    <li><a class="dropdown-item" href="#"><i class="fas fa-cog me-2"></i>Configuración</a></li>
                    <li><hr class="dropdown-divider"></li>
                    <li><a class="dropdown-item" href="#"><i class="fas fa-sign-out-alt me-2"></i>Cerrar Sesión</a></li>
                </ul>
            </div>
        </div>
    </div>

    <!-- Sidebar -->
    <div class="sidebar d-none d-lg-block">
        <div class="logo">
            <h4 class="text-center"><i class="fas fa-mug-hot me-2" style="color: var(--gold);"></i> CaféAdmin</h4>
        </div>
        <nav class="nav flex-column mt-3">
            <a class="nav-link active" href="#"><i class="fas fa-home"></i> <span>Dashboard</span></a>
            <a class="nav-link" href="#"><i class="fas fa-cash-register"></i> <span>Punto de Venta</span></a>
            <a class="nav-link" href="#"><i class="fas fa-chart-line"></i> <span>Finanzas</span></a>
            <a class="nav-link" href="#"><i class="fas fa-boxes"></i> <span>Inventario</span></a>
            <a class="nav-link" href="#"><i class="fas fa-receipt"></i> <span>Cortes de Caja</span></a>
            <a class="nav-link" href="#"><i class="fas fa-utensils"></i> <span>Recetas</span></a>
            <a class="nav-link" href="#"><i class="fas fa-store"></i> <span>Sucursales</span></a>
            <a class="nav-link" href="#"><i class="fas fa-chart-bar"></i> <span>Reportes</span></a>
            <a class="nav-link" href="#"><i class="fas fa-cog"></i> <span>Configuración</span></a>
        </nav>
    </div>

    <!-- Main Content -->
    <div class="main-content content-with-mobile-nav">
        <!-- KPI Section -->
        <div class="row mb-4">
            <div class="col-md-3 col-sm-6">
                <div class="card kpi-card">
                    <div class="card-body">
                        <div class="d-flex justify-content-between">
                            <div>
                                <h6 class="card-subtitle mb-1 text-muted">Ventas Hoy</h6>
                                <h3 class="card-title" style="color: var(--green-dark);">$8,450</h3>
                                <p class="card-text"><small class="text-success"><i class="fas fa-arrow-up"></i> 12% vs ayer</small></p>
                            </div>
                            <div class="kpi-icon">
                                <i class="fas fa-dollar-sign"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3 col-sm-6">
                <div class="card kpi-card">
                    <div class="card-body">
                        <div class="d-flex justify-content-between">
                            <div>
                                <h6 class="card-subtitle mb-1 text-muted">Órdenes Hoy</h6>
                                <h3 class="card-title" style="color: var(--green-dark);">124</h3>
                                <p class="card-text"><small class="text-success"><i class="fas fa-arrow-up"></i> 8% vs ayer</small></p>
                            </div>
                            <div class="kpi-icon">
                                <i class="fas fa-shopping-bag"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3 col-sm-6">
                <div class="card kpi-card">
                    <div class="card-body">
                        <div class="d-flex justify-content-between">
                            <div>
                                <h6 class="card-subtitle mb-1 text-muted">Productos Vendidos</h6>
                                <h3 class="card-title" style="color: var(--green-dark);">287</h3>
                                <p class="card-text"><small class="text-success"><i class="fas fa-arrow-up"></i> 5% vs ayer</small></p>
                            </div>
                            <div class="kpi-icon">
                                <i class="fas fa-coffee"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3 col-sm-6">
                <div class="card kpi-card">
                    <div class="card-body">
                        <div class="d-flex justify-content-between">
                            <div>
                                <h6 class="card-subtitle mb-1 text-muted">Ticket Promedio</h6>
                                <h3 class="card-title" style="color: var(--green-dark);">$68.15</h3>
                                <p class="card-text"><small class="text-success"><i class="fas fa-arrow-up"></i> 3% vs ayer</small></p>
                            </div>
                            <div class="kpi-icon">
                                <i class="fas fa-receipt"></i>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Charts and Tables Section -->
        <div class="row">
            <div class="col-lg-8">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <span>Ventas de la Semana</span>
                        <div>
                            <button class="btn btn-sm btn-gold">Ver Reporte</button>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="chart-container">
                            <canvas id="salesChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-lg-4">
                <div class="card">
                    <div class="card-header">Productos Más Vendidos</div>
                    <div class="card-body">
                        <ul class="list-group list-group-flush">
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                <span><i class="fas fa-coffee me-2" style="color: var(--orange);"></i> Café Americano</span>
                                <span class="badge rounded-pill" style="background-color: var(--green-dark);">87</span>
                            </li>
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                <span><i class="fas fa-coffee me-2" style="color: var(--orange);"></i> Capuchino</span>
                                <span class="badge rounded-pill" style="background-color: var(--green-dark);">65</span>
                            </li>
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                <span><i class="fas fa-bread-slice me-2" style="color: var(--orange);"></i> Croissant</span>
                                <span class="badge rounded-pill" style="background-color: var(--green-dark);">52</span>
                            </li>
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                <span><i class="fas fa-mug-hot me-2" style="color: var(--orange);"></i> Té Verde</span>
                                <span class="badge rounded-pill" style="background-color: var(--green-dark);">41</span>
                            </li>
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                <span><i class="fas fa-cookie me-2" style="color: var(--orange);"></i> Muffin de Arándano</span>
                                <span class="badge rounded-pill" style="background-color: var(--green-dark);">38</span>
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>

        <!-- Recent Orders Section -->
        <div class="row mt-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <span>Órdenes Recientes</span>
                        <div>
                            <button class="btn btn-sm btn-gold">Ver Todas</button>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-hover">
                                <thead>
                                    <tr>
                                        <th># Orden</th>
                                        <th>Hora</th>
                                        <th>Productos</th>
                                        <th>Total</th>
                                        <th>Estado</th>
                                        <th>Acciones</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td>#ORD-1025</td>
                                        <td>10:25 AM</td>
                                        <td>Café Americano (2), Croissant</td>
                                        <td>$9.50</td>
                                        <td><span class="badge" style="background-color: var(--green-dark);">Completada</span></td>
                                        <td>
                                            <button class="btn btn-sm btn-outline-primary"><i class="fas fa-eye"></i></button>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>#ORD-1024</td>
                                        <td>10:18 AM</td>
                                        <td>Capuchino Grande, Muffin</td>
                                        <td>$8.25</td>
                                        <td><span class="badge" style="background-color: var(--green-dark);">Completada</span></td>
                                        <td>
                                            <button class="btn btn-sm btn-outline-primary"><i class="fas fa-eye"></i></button>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>#ORD-1023</td>
                                        <td>10:05 AM</td>
                                        <td>Té Verde, Sándwich</td>
                                        <td>$12.80</td>
                                        <td><span class="badge" style="background-color: var(--orange);">En Proceso</span></td>
                                        <td>
                                            <button class="btn btn-sm btn-outline-primary"><i class="fas fa-eye"></i></button>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>#ORD-1022</td>
                                        <td>09:52 AM</td>
                                        <td>Expreso Doble, Galleta</td>
                                        <td>$6.75</td>
                                        <td><span class="badge" style="background-color: var(--green-dark);">Completada</span></td>
                                        <td>
                                            <button class="btn btn-sm btn-outline-primary"><i class="fas fa-eye"></i></button>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>#ORD-1021</td>
                                        <td>09:40 AM</td>
                                        <td>Latte, Bagel</td>
                                        <td>$10.30</td>
                                        <td><span class="badge" style="background-color: var(--green-dark);">Completada</span></td>
                                        <td>
                                            <button class="btn btn-sm btn-outline-primary"><i class="fas fa-eye"></i></button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Mobile Bottom Navigation -->
    <nav class="mobile-nav">
        <a href="#" class="mobile-nav-item active">
            <i class="fas fa-home"></i>
            <span>Inicio</span>
        </a>
        <a href="#" class="mobile-nav-item">
            <i class="fas fa-cash-register"></i>
            <span>Ventas</span>
        </a>
        <a href="#" class="mobile-nav-item">
            <i class="fas fa-boxes"></i>
            <span>Inventario</span>
        </a>
        <a href="#" class="mobile-nav-item">
            <i class="fas fa-chart-bar"></i>
            <span>Reportes</span>
        </a>
        <a href="#" class="mobile-nav-item">
            <i class="fas fa-cog"></i>
            <span>Más</span>
        </a>
    </nav>

    <!-- Toggle Sidebar Button (Mobile) -->
    <button class="sidebar-toggle d-lg-none">
        <i class="fas fa-bars"></i>
    </button>

    <!-- Bootstrap & Chart JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script>
        // Actualizar fecha y hora
        function updateDateTime() {
            const now = new Date();
            const options = { year: 'numeric', month: 'long', day: 'numeric' };
            document.getElementById('current-date').textContent = now.toLocaleDateString('es-ES', options);
            document.getElementById('current-time').textContent = now.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });
        }
        
        setInterval(updateDateTime, 60000);
        updateDateTime();
        
        // Sample chart initialization
        document.addEventListener('DOMContentLoaded', function() {
            const ctx = document.getElementById('salesChart').getContext('2d');
            const salesChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
                    datasets: [{
                        label: 'Ventas $',
                        data: [2450, 3120, 2980, 4050, 4780, 6250, 5820],
                        backgroundColor: 'rgba(233, 122, 58, 0.1)',
                        borderColor: '#E97A3A',
                        borderWidth: 2,
                        tension: 0.3,
                        fill: true
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true,
                            grid: {
                                color: 'rgba(0, 0, 0, 0.05)'
                            }
                        },
                        x: {
                            grid: {
                                display: false
                            }
                        }
                    },
                    plugins: {
                        legend: {
                            display: false
                        }
                    }
                }
            });
        });
        
        // Toggle sidebar on mobile
        document.querySelector('.sidebar-toggle').addEventListener('click', function() {
            document.querySelector('.sidebar').classList.toggle('show');
        });
    </script>
</body>
</html>