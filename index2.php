<?php
// Datos simulados para el dashboard (en un entorno real, vendrían de una base de datos)
$sales_today = 1650.75; // Valor actualizado
$transactions_today = 92;
$sales_yesterday = 1450.00;
$sales_percentage_change = (($sales_today - $sales_yesterday) / $sales_yesterday) * 100;

// Los siguientes datos son arrays para las nuevas gráficas y listas
$kpi_sales = [
    'lunes' => 800,
    'martes' => 950,
    'miércoles' => 1100,
    'jueves' => 1050,
    'viernes' => 1400,
    'sábado' => 1650.75, // Valor actualizado
    'domingo' => 1250
];

$payment_methods = [
    'Efectivo' => 650.25, // Valor actualizado
    'Tarjeta' => 920.50, // Valor actualizado
    'Transferencia' => 80.00 // Valor actualizado
];

$branch_sales = [
    'Sucursal 1' => 5200, // Valor actualizado
    'Sucursal 2' => 3100, // Valor actualizado
    'Sucursal 3' => 4200 // Valor actualizado
];

$top_products = [
    ['name' => 'Latte Vainilla', 'sales' => 350.25],
    ['name' => 'Muffin de Chocolate', 'sales' => 215.00],
    ['name' => 'Frapé Oreo', 'sales' => 180.75],
    ['name' => 'Té Chai', 'sales' => 150.00],
    ['name' => 'Café Americano', 'sales' => 120.50]
];

$alerts = [
    ['type' => 'low-stock', 'message' => 'Inventario bajo: Leche (10L)', 'link' => '#'],
    ['type' => 'discrepancy', 'message' => 'Diferencia en corte: Sucursal 2', 'link' => '#'],
    ['type' => 'discount', 'message' => 'Descuento > $50 en orden #521', 'link' => '#'],
    ['type' => 'low-stock', 'message' => 'Producto a punto de agotarse: Café de Altura', 'link' => '#'],
    ['type' => 'discrepancy', 'message' => 'Diferencia en corte: Sucursal 1', 'link' => '#'] // Nueva alerta
];

$user_name = 'Ricardo';

// La clave de API debería estar en un lugar seguro (por ejemplo, una variable de entorno)
// En este ejemplo, la dejamos vacía y se inyectará en el entorno de ejecución.
const API_KEY = "";
const API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key=' . API_KEY;

// Detectar si es una solicitud de API (AJAX POST)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json');

    $request_body = file_get_contents('php://input');
    $data = json_decode($request_body, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        echo json_encode(['error' => 'Invalid JSON input']);
        exit;
    }

    $sales_today = $data['sales_today'] ?? 0;
    $transactions_today = $data['transactions_today'] ?? 0;
    $top_product = $data['top_product'] ?? 'No especificado';
    $top_product_sales = $data['top_product_sales'] ?? 0;
    $cash_register_status = $data['cash_register_status'] ?? 'No especificado';

    // Construir el prompt para el modelo de lenguaje
    $prompt = "Actúa como un analista de negocios experto para una cafetería. Analiza los siguientes KPI de hoy:
    - Ventas totales: $" . number_format($sales_today, 2) . "
    - Número de transacciones: " . $transactions_today . "
    - Producto estrella: " . $top_product . " con $" . number_format($top_product_sales, 2) . " en ventas.
    - Estado de caja: " . $cash_register_status . ".
    
    Proporciona un breve resumen del día y, a continuación, ofrece 3-5 sugerencias de negocio concisas y accionables para mejorar el rendimiento. La respuesta debe ser en español y formateada en una lista con viñetas. Evita saludos o introducciones innecesarias.";

    // Estructura del payload para la API de Gemini
    $payload = json_encode([
        'contents' => [
            [
                'parts' => [
                    ['text' => $prompt]
                ]
            ]
        ]
    ]);

    // Configuración de la solicitud cURL
    $ch = curl_init(API_URL);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type' => 'application/json',
        'Content-Length' => strlen($payload)
    ]);

    $response = curl_exec($ch);
    $http_status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_error = curl_error($ch);
    curl_close($ch);

    if ($http_status != 200) {
        http_response_code($http_status);
        echo json_encode(['error' => "API request failed with status $http_status. cURL Error: " . $curl_error]);
        exit;
    }

    $result = json_decode($response, true);

    // Extraer el texto de la respuesta de la API
    $generated_text = 'No se pudo generar el análisis. Por favor, inténtelo de nuevo.';
    if (isset($result['candidates'][0]['content']['parts'][0]['text'])) {
        $generated_text = $result['candidates'][0]['content']['parts'][0]['text'];
    }

    // Enviar la respuesta como JSON y salir
    echo json_encode(['text' => $generated_text]);
    exit;
}

// Intenta codificar los datos de ventas para JavaScript.
// Se incluye un bloque try-catch para manejar errores de codificación JSON
try {
    $kpi_sales_labels = json_encode(array_keys($kpi_sales), JSON_THROW_ON_ERROR);
    $kpi_sales_data = json_encode(array_values($kpi_sales), JSON_THROW_ON_ERROR);
    $payment_methods_labels = json_encode(array_keys($payment_methods), JSON_THROW_ON_ERROR);
    $payment_methods_data = json_encode(array_values($payment_methods), JSON_THROW_ON_ERROR);
    $branch_sales_labels = json_encode(array_keys($branch_sales), JSON_THROW_ON_ERROR);
    $branch_sales_data = json_encode(array_values($branch_sales), JSON_THROW_ON_ERROR);
    $top_products_json = json_encode($top_products, JSON_THROW_ON_ERROR);
} catch (Exception $e) {
    // En caso de error, inicializa los datos como un JSON vacío para evitar fallos.
    $kpi_sales_labels = '[]';
    $kpi_sales_data = '[]';
    $payment_methods_labels = '[]';
    $payment_methods_data = '[]';
    $branch_sales_labels = '[]';
    $branch_sales_data = '[]';
    $top_products_json = '[]';
    error_log("Error al codificar JSON: " . $e->getMessage());
}
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Voceo POS - Dashboard</title>
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Font Awesome para iconos -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <!-- Estilos personalizados -->
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

        body {
            background-color: var(--bg-main);
            color: var(--text-dark);
            font-family: 'Montserrat', sans-serif;
            overflow-x: hidden;
        }
        
        .container-fluid {
            min-height: 100vh;
            display: flex;
        }

        .sidebar {
            width: 280px;
            background-color: var(--green-darker);
            color: var(--text-light);
            padding: 2rem 1rem;
            display: flex;
            flex-direction: column;
        }

        .sidebar .nav-link {
            color: var(--text-light);
            font-weight: 500;
            padding: 0.75rem 1rem;
            margin-bottom: 0.5rem;
            border-radius: 0.5rem;
            transition: all 0.2s ease-in-out;
        }
        
        .sidebar .nav-link:hover {
            background-color: var(--green-dark);
            color: var(--gold);
        }
        
        .sidebar .nav-link.active {
            background-color: var(--orange);
            color: var(--text-light);
            font-weight: 600;
        }

        .main-content {
            flex-grow: 1;
            padding: 0;
            background-color: var(--bg-main);
        }
        
        .top-bar {
            background-color: #ffffff;
            padding: 1.5rem 2rem;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 2rem;
        }
        
        .top-bar-title {
            font-family: 'Anton', sans-serif;
            font-size: 2rem;
            color: var(--green-dark);
        }
        
        .user-profile {
            display: flex;
            align-items: center;
        }

        .user-profile-name {
            font-weight: 600;
            color: var(--text-dark);
            margin-right: 1rem;
        }
        
        .user-profile-icon {
            width: 40px;
            height: 40px;
            background-color: var(--orange);
            color: var(--text-light);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .dashboard-grid {
            padding: 0 2rem;
        }
        
        .card-kpi, .card-ai, .card-charts, .card-alerts {
            background-color: #ffffff;
            border-radius: 1rem;
            padding: 1.5rem;
            box-shadow: 0 4px 15px rgba(0,0,0,0.05);
            transition: transform 0.2s ease-in-out;
            height: 100%;
        }

        .card-kpi:hover {
            transform: translateY(-5px);
        }

        .card-title {
            font-weight: 600;
            color: var(--green-dark);
        }

        .kpi-value {
            font-family: 'Anton', sans-serif;
            font-size: 2.5rem;
            line-height: 1;
            color: var(--orange);
        }

        .kpi-text {
            color: #6c757d;
        }

        .chart-container {
            background-color: #ffffff;
            border-radius: 1rem;
            padding: 1.5rem;
            box-shadow: 0 4px 15px rgba(0,0,0,0.05);
        }
        
        /* Esta es la regla CSS para evitar que los gráficos se agranden */
        .chart-wrapper {
            position: relative; /* Importante para que el canvas se adapte a este contenedor */
            height: 300px; /* Altura fija para evitar el crecimiento */
        }

        .logo-brand {
            font-family: 'Montserrat', sans-serif;
            font-weight: 900;
            font-size: 1.8rem;
            color: var(--gold);
            text-align: center;
            margin-bottom: 2rem;
        }

        .logo-brand i {
            margin-right: 0.5rem;
            color: var(--orange);
        }

        .btn-ai {
            background-color: var(--green-dark);
            color: var(--text-light);
            border-radius: 0.5rem;
            transition: background-color 0.2s;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 0.75rem 1.5rem;
            font-weight: 600;
        }
        .btn-ai:hover {
            background-color: var(--orange);
            color: var(--text-light);
        }

        #ai-insights-output {
            margin-top: 1rem;
            padding: 1rem;
            background-color: var(--gray-light);
            border-left: 4px solid var(--orange);
            border-radius: 0.5rem;
            white-space: pre-wrap;
        }

        .alert-item {
            display: flex;
            align-items: center;
            margin-bottom: 0.75rem;
            padding: 0.75rem 1rem;
            border-radius: 0.5rem;
            background-color: #f8f9fa;
            border-left: 3px solid transparent;
            text-decoration: none;
            color: #333;
            transition: all 0.2s ease-in-out;
        }

        .alert-item:hover {
            background-color: #e9ecef;
            transform: translateX(3px);
        }
        
        .alert-item .icon {
            font-size: 1.2rem;
            margin-right: 0.75rem;
        }

        .alert-item.low-stock { border-left-color: #ffc107; }
        .alert-item.discrepancy { border-left-color: #dc3545; }
        .alert-item.discount { border-left-color: #0d6efd; }
        
        .top-product-item {
            display: flex;
            justify-content: space-between;
            padding: 0.5rem 0;
            border-bottom: 1px solid #eee;
        }
        .top-product-item:last-child {
            border-bottom: none;
        }

        .filters-bar {
            background-color: #ffffff;
            padding: 1rem 2rem;
            border-radius: 1rem;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            margin-bottom: 2rem;
            display: flex;
            align-items: center;
            gap: 1.5rem;
        }
        
        .filters-bar label, .filters-bar input, .filters-bar select {
            font-weight: 500;
            color: var(--text-dark);
        }

    </style>
</head>
<body>
    <div class="container-fluid">
        <!-- Barra de navegación lateral -->
        <div class="sidebar d-none d-md-flex">
            <div class="logo-brand">
                <i class="fas fa-mug-hot"></i> Voceo
            </div>
            <ul class="nav flex-column">
                <li class="nav-item">
                    <a class="nav-link active" href="#">
                        <i class="fas fa-tachometer-alt me-2"></i> Dashboard
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-chart-bar me-2"></i> Reportes
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-boxes me-2"></i> Inventario
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-receipt me-2"></i> Compras
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-cash-register me-2"></i> Corte de Caja
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-utensils me-2"></i> Recetas
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-store me-2"></i> Sucursales
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-users-cog me-2"></i> Gestión de Personal
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link" href="#">
                        <i class="fas fa-cogs me-2"></i> Configuración
                    </a>
                </li>
            </ul>
        </div>
        
        <!-- Contenido principal -->
        <div class="main-content">
            <!-- Barra superior con título y usuario -->
            <div class="top-bar">
                <div class="top-bar-title" id="current-page-title">Dashboard de Cafetería</div>
                <div class="user-profile">
                    <span class="user-profile-name"><?php echo htmlspecialchars($user_name); ?></span>
                    <div class="user-profile-icon">
                        <i class="fas fa-user-circle"></i>
                    </div>
                </div>
            </div>

            <!-- Barra de filtros -->
            <div class="dashboard-grid mb-4">
                <div class="filters-bar">
                    <div class="d-flex align-items-center gap-3">
                        <label for="branch-select" class="form-label mb-0">Sucursal:</label>
                        <select id="branch-select" class="form-select w-auto">
                            <option value="all">Todas</option>
                            <option value="sucursal1">Sucursal 1</option>
                            <option value="sucursal2">Sucursal 2</option>
                            <option value="sucursal3">Sucursal 3</option>
                        </select>
                    </div>
                    <div class="d-flex align-items-center gap-3">
                        <label for="start-date" class="form-label mb-0">Rango de fechas:</label>
                        <input type="date" id="start-date" class="form-control w-auto">
                        <span class="text-muted">a</span>
                        <input type="date" id="end-date" class="form-control w-auto">
                    </div>
                </div>
            </div>

            <div class="dashboard-grid">
                <!-- Fila de KPI -->
                <div class="row g-4 mb-4">
                    <div class="col-md-6 col-lg-3">
                        <div class="card-kpi text-center">
                            <i class="fas fa-dollar-sign fa-2x mb-3 text-success"></i>
                            <h5 class="card-title">Ventas del día</h5>
                            <!-- Los datos de ventas del día se llenan desde el array PHP al inicio del archivo -->
                            <h2 class="kpi-value">$<?php echo number_format($sales_today, 2); ?></h2>
                            <p class="kpi-text">
                                <?php echo $transactions_today; ?> transacciones
                                <br>
                                <span class="badge <?php echo $sales_percentage_change >= 0 ? 'bg-success' : 'bg-danger'; ?>">
                                    <?php echo sprintf('%+0.1f%%', $sales_percentage_change); ?> vs. ayer
                                </span>
                            </p>
                        </div>
                    </div>
                    <div class="col-md-6 col-lg-3">
                        <div class="card-kpi text-center">
                            <i class="fas fa-fire fa-2x mb-3 text-danger"></i>
                            <h5 class="card-title">Producto estrella</h5>
                            <!-- El producto más vendido se llena desde el primer elemento del array $top_products -->
                            <h2 class="kpi-value"><?php echo htmlspecialchars($top_products[0]['name']); ?></h2>
                            <p class="kpi-text">$<?php echo number_format($top_products[0]['sales'], 2); ?> en ventas</p>
                        </div>
                    </div>
                    <div class="col-md-6 col-lg-3">
                        <div class="card-kpi text-center">
                            <i class="fas fa-boxes fa-2x mb-3 text-info"></i>
                            <h5 class="card-title">Alertas activas</h5>
                            <!-- La cantidad de alertas activas se obtiene contando los elementos en el array $alerts -->
                            <h2 class="kpi-value" style="color: var(--orange);"><?php echo count($alerts); ?></h2>
                            <p class="kpi-text">Revisar inventario y operaciones</p>
                        </div>
                    </div>
                    <div class="col-md-6 col-lg-3">
                        <div class="card-kpi text-center">
                            <i class="fas fa-cash-register fa-2x mb-3 text-primary"></i>
                            <h5 class="card-title">Corte de caja</h5>
                            <h2 class="kpi-value" style="color: var(--green-dark);">Cerrado</h2>
                            <p class="kpi-text">Último: 19:30</p>
                        </div>
                    </div>
                </div>

                <!-- Fila de gráficas y alertas -->
                <div class="row g-4 mb-4">
                    <div class="col-lg-6">
                        <div class="chart-container">
                            <h5 class="card-title mb-3">Tendencia de ventas</h5>
                            <!-- Se agrega un contenedor con altura fija para evitar el problema -->
                            <div class="chart-wrapper">
                                <canvas id="salesTrendChart"></canvas>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-6">
                        <div class="card-alerts">
                            <h5 class="card-title mb-3">Alertas</h5>
                            <div id="alerts-list">
                                <!-- Cada alerta se muestra en un bucle que recorre el array $alerts de PHP -->
                                <?php foreach ($alerts as $alert): ?>
                                    <a href="<?php echo $alert['link']; ?>" class="alert-item <?php echo $alert['type']; ?>">
                                        <i class="icon fas
                                            <?php if ($alert['type'] == 'low-stock') echo 'fa-exclamation-triangle text-warning'; ?>
                                            <?php if ($alert['type'] == 'discrepancy') echo 'fa-exclamation-circle text-danger'; ?>
                                            <?php if ($alert['type'] == 'discount') echo 'fa-tags text-primary'; ?>">
                                        </i>
                                        <span><?php echo $alert['message']; ?></span>
                                    </a>
                                <?php endforeach; ?>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Fila de gráficas adicionales y top 5 -->
                <div class="row g-4 mb-4">
                    <div class="col-lg-6">
                        <div class="chart-container">
                            <h5 class="card-title mb-3">Ventas por Sucursal</h5>
                            <!-- Se agrega un contenedor con altura fija para evitar el problema -->
                            <div class="chart-wrapper">
                                <canvas id="branchSalesChart"></canvas>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-6">
                        <div class="card-charts">
                            <h5 class="card-title mb-3">Formas de Pago</h5>
                            <!-- Se agrega un contenedor con altura fija para evitar el problema -->
                            <div class="chart-wrapper">
                                <canvas id="paymentChart"></canvas>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Fila de top 5 y asistente de IA -->
                <div class="row g-4">
                    <div class="col-lg-6">
                        <div class="card-charts">
                            <h5 class="card-title mb-3">Top 5 Productos más Vendidos</h5>
                            <ul class="list-unstyled">
                                <!-- La lista de los 5 productos más vendidos se llena en un bucle que recorre el array $top_products -->
                                <?php foreach ($top_products as $index => $product): ?>
                                <li class="top-product-item">
                                    <span>#<?php echo $index + 1; ?>. <?php echo htmlspecialchars($product['name']); ?></span>
                                    <span class="fw-bold">$<?php echo number_format($product['sales'], 2); ?></span>
                                </li>
                                <?php endforeach; ?>
                            </ul>
                        </div>
                    </div>
                    <div class="col-lg-6">
                        <div class="card-ai">
                            <h5 class="card-title mb-3">Asistente de Gerencia</h5>
                            <p class="kpi-text">Obtén un análisis de desempeño y sugerencias estratégicas basadas en tus KPI.</p>
                            <button class="btn btn-ai w-100" id="generate-insights">Generar Análisis ✨</button>
                            <div id="ai-insights-output"></div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Bootstrap JS y Chart.js para los gráficos -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            console.log('DOM completamente cargado. Inicializando dashboard.');

            // Variable global para almacenar las instancias de los gráficos
            let salesTrendChart;
            let branchSalesChart;
            let paymentChart;

            // Opciones de configuración de los gráficos con animaciones desactivadas para mejor rendimiento
            const chartOptions = {
                responsive: true,
                maintainAspectRatio: false,
                animation: false, // Desactiva las animaciones
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: { color: 'rgba(0,0,0,0.05)' }
                    },
                    x: {
                        grid: { display: false }
                    }
                },
                plugins: {
                    legend: { display: false }
                }
            };

            // Función para dibujar los gráficos
            function drawCharts() {
                console.log('Función drawCharts llamada. Preparando para dibujar.');

                // Destruir las instancias de gráficos existentes antes de crear las nuevas
                if (salesTrendChart) {
                    salesTrendChart.destroy();
                    console.log('salesTrendChart destruido.');
                }
                if (branchSalesChart) {
                    branchSalesChart.destroy();
                    console.log('branchSalesChart destruido.');
                }
                if (paymentChart) {
                    paymentChart.destroy();
                    console.log('paymentChart destruido.');
                }

                // Los datos se pasan de PHP a JavaScript como JSON.
                const kpiSalesLabels = <?php echo $kpi_sales_labels; ?>;
                const kpiSalesData = <?php echo $kpi_sales_data; ?>;
                const paymentMethodsLabels = <?php echo $payment_methods_labels; ?>;
                const paymentMethodsData = <?php echo $payment_methods_data; ?>;
                const branchSalesLabels = <?php echo $branch_sales_labels; ?>;
                const branchSalesData = <?php echo $branch_sales_data; ?>;

                // Gráfico de Tendencia de Ventas
                const salesTrendCtx = document.getElementById('salesTrendChart').getContext('2d');
                salesTrendChart = new Chart(salesTrendCtx, {
                    type: 'line',
                    data: {
                        labels: kpiSalesLabels,
                        datasets: [{
                            label: 'Ventas Diarias ($)',
                            data: kpiSalesData,
                            fill: true,
                            backgroundColor: 'rgba(210, 180, 100, 0.2)',
                            borderColor: '#E97A3A',
                            tension: 0.4
                        }]
                    },
                    options: chartOptions
                });
                console.log('salesTrendChart creado.');

                // Gráfico de Ventas por Sucursal
                const branchSalesCtx = document.getElementById('branchSalesChart').getContext('2d');
                branchSalesChart = new Chart(branchSalesCtx, {
                    type: 'bar',
                    data: {
                        labels: branchSalesLabels,
                        datasets: [{
                            label: 'Ventas ($)',
                            data: branchSalesData,
                            backgroundColor: '#234330',
                            borderRadius: 5
                        }]
                    },
                    options: chartOptions
                });
                console.log('branchSalesChart creado.');

                // Gráfico de Formas de Pago
                const paymentCtx = document.getElementById('paymentChart').getContext('2d');
                paymentChart = new Chart(paymentCtx, {
                    type: 'doughnut',
                    data: {
                        labels: paymentMethodsLabels,
                        datasets: [{
                            label: 'Ventas ($)',
                            data: paymentMethodsData,
                            backgroundColor: [
                                '#D2B464',
                                '#E97A3A',
                                '#234330'
                            ],
                            hoverOffset: 4
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        animation: false, // Desactiva las animaciones
                        plugins: {
                            legend: {
                                position: 'bottom',
                                labels: {
                                    usePointStyle: true,
                                    padding: 20
                                }
                            }
                        }
                    }
                });
                console.log('paymentChart creado.');
            }

            // Llamar a la función de dibujo al cargar la página por primera vez
            drawCharts();

            // Lógica para el Asistente de IA
            const generateButton = document.getElementById('generate-insights');
            const insightsOutput = document.getElementById('ai-insights-output');

            generateButton.addEventListener('click', async () => {
                insightsOutput.innerHTML = `<i class="fas fa-spinner fa-spin me-2"></i> Generando análisis...`;
                generateButton.disabled = true;

                // Datos de los KPI actuales para enviar a la IA
                const data = {
                    sales_today: <?php echo $sales_today; ?>,
                    transactions_today: <?php echo $transactions_today; ?>,
                    top_product: '<?php echo $top_products[0]['name']; ?>',
                    top_product_sales: <?php echo $top_products[0]['sales']; ?>,
                    cash_register_status: 'Cerrado'
                };

                try {
                    const response = await fetch('dashboard.php', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify(data)
                    });
                    const result = await response.json();
                    
                    if (result.error) {
                        insightsOutput.innerHTML = `<span style="color: red;">Error: ${result.error}</span>`;
                    } else {
                        insightsOutput.innerHTML = result.text;
                    }
                } catch (error) {
                    insightsOutput.innerHTML = `<span style="color: red;">Error en la conexión con el servidor. Por favor, inténtelo de nuevo.</span>`;
                    console.error('Error fetching AI insights:', error);
                } finally {
                    generateButton.disabled = false;
                }
            });

            // Lógica de los filtros (simulada)
            const filters = document.querySelectorAll('#branch-select, #start-date, #end-date');
            filters.forEach(filter => {
                filter.addEventListener('change', () => {
                    console.log('Un filtro ha cambiado. Redibujando gráficos.');
                    // En un entorno real, aquí se volvería a renderizar todas las gráficas con los nuevos datos
                    const selectedBranch = document.getElementById('branch-select').value;
                    const startDate = document.getElementById('start-date').value;
                    const endDate = document.getElementById('end-date').value;
                    
                    const newTitle = document.getElementById('current-page-title');
                    newTitle.textContent = `Dashboard de ${selectedBranch === 'all' ? 'Todas las Sucursales' : selectedBranch}`;
                    
                    // Llama a la función para redibujar los gráficos
                    drawCharts();
                });
            });
        });
    </script>
</body>
</html>

