document.addEventListener('DOMContentLoaded', function() {
    // Toggle del sidebar
    const sidebar = document.getElementById('sidebar');
    const sidebarToggle = document.getElementById('sidebarToggle');
    const mobileSidebarToggle = document.getElementById('mobileSidebarToggle');
    
    if (sidebarToggle) {
        sidebarToggle.addEventListener('click', () => {
            sidebar.classList.toggle('d-none');
        });
    }
    
    if (mobileSidebarToggle) {
        mobileSidebarToggle.addEventListener('click', () => {
            sidebar.classList.toggle('show');
        });
    }

    // Inicializar gráficos
    initCharts();

    // Asistente de IA (simulado)
    const generateButton = document.getElementById('generate-insights');
    const insightsOutput = document.getElementById('ai-insights-output');

    if (generateButton && insightsOutput) {
        generateButton.addEventListener('click', () => {
            generateInsights();
        });
    }

    // Configurar filtros
    setupFilters();
});

// Función para inicializar gráficos
function initCharts() {
    // Gráfico de Tendencia de Ventas
    const salesTrendCtx = document.getElementById('salesTrendChart');
    if (salesTrendCtx) {
        new Chart(salesTrendCtx.getContext('2d'), {
            type: 'line',
            data: {
                labels: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
                datasets: [{
                    label: 'Ventas Diarias ($)',
                    data: [2450, 3120, 2980, 4050, 4780, 6250, 5820],
                    fill: true,
                    backgroundColor: 'rgba(233, 122, 58, 0.2)',
                    borderColor: '#E97A3A',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: { color: 'rgba(0,0,0,0.05)' }
                    },
                    x: {
                        grid: { display: false }
                    }
                }
            }
        });
    }

    // Gráfico de Ventas por Sucursal
    const branchSalesCtx = document.getElementById('branchSalesChart');
    if (branchSalesCtx) {
        new Chart(branchSalesCtx.getContext('2d'), {
            type: 'bar',
            data: {
                labels: ['Sucursal 1', 'Sucursal 2', 'Sucursal 3'],
                datasets: [{
                    label: 'Ventas ($)',
                    data: [5200, 3100, 4200],
                    backgroundColor: '#234330',
                    borderRadius: 5
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: { color: 'rgba(0,0,0,0.05)' }
                    },
                    x: {
                        grid: { display: false }
                    }
                }
            }
        });
    }

    // Gráfico de Formas de Pago
    const paymentCtx = document.getElementById('paymentChart');
    if (paymentCtx) {
        new Chart(paymentCtx.getContext('2d'), {
            type: 'doughnut',
            data: {
                labels: ['Efectivo', 'Tarjeta', 'Transferencia'],
                datasets: [{
                    label: 'Ventas ($)',
                    data: [650.25, 920.50, 80.00],
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
    }
}

// Función para generar insights de IA
function generateInsights() {
    const generateButton = document.getElementById('generate-insights');
    const insightsOutput = document.getElementById('ai-insights-output');
    
    if (!generateButton || !insightsOutput) return;
    
    insightsOutput.innerHTML = `<i class="fas fa-spinner fa-spin me-2"></i> Generando análisis...`;
    generateButton.disabled = true;
    
    setTimeout(() => {
        insightsOutput.innerHTML = `
        <strong>Resumen del día:</strong>
        - Ventas totales: $8,450 (124 transacciones)
        - Ticket promedio: $68.15
        - Producto estrella: Latte Vainilla ($350.25)
        
        <strong>Sugerencias:</strong>
        • Incrementar inventario de Leche (solo 10L restantes)
        • Revisar proceso de corte en Sucursal 2 (hay discrepancias)
        • Promocionar Té Chai (alto margen de ganancia)
        `;
        generateButton.disabled = false;
    }, 2000);
}

// Función para configurar filtros
function setupFilters() {
    const branchSelect = document.getElementById('branch-select');
    const startDate = document.getElementById('start-date');
    const endDate = document.getElementById('end-date');
    const applyFiltersBtn = document.getElementById('apply-filters');
    
    // Establecer fecha actual como valor por defecto
    const today = new Date();
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(today.getDate() - 7);
    
    if (startDate) {
        startDate.value = formatDate(sevenDaysAgo);
    }
    
    if (endDate) {
        endDate.value = formatDate(today);
    }
    
    if (applyFiltersBtn) {
        applyFiltersBtn.addEventListener('click', applyFilters);
    }
}

// Función para aplicar filtros
function applyFilters() {
    const branchSelect = document.getElementById('branch-select');
    const startDate = document.getElementById('start-date');
    const endDate = document.getElementById('end-date');
    
    const selectedBranch = branchSelect ? branchSelect.value : 'all';
    const startValue = startDate ? startDate.value : '';
    const endValue = endDate ? endDate.value : '';
    
    // En una implementación real, aquí se haría una llamada a la API
    // o se filtrarían los datos localmente según los criterios seleccionados
    
    console.log('Aplicando filtros:', {
        branch: selectedBranch,
        startDate: startValue,
        endDate: endValue
    });
    
    // Mostrar mensaje de filtros aplicados
    showNotification('Filtros aplicados correctamente');
}

// Función auxiliar para formatear fecha como YYYY-MM-DD
function formatDate(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

// Función para mostrar notificaciones
function showNotification(message, type = 'success') {
    // Crear elemento de notificación
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show`;
    notification.style.position = 'fixed';
    notification.style.top = '20px';
    notification.style.right = '20px';
    notification.style.zIndex = '1050';
    notification.style.minWidth = '300px';
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    // Agregar al documento
    document.body.appendChild(notification);
    
    // Auto-eliminar después de 5 segundos
    setTimeout(() => {
        if (notification.parentNode) {
            notification.parentNode.removeChild(notification);
        }
    }, 5000);
}

// Función para actualizar KPIs en tiempo real (simulado)
function updateKPIs() {
    // En una implementación real, estos datos vendrían de una API
    const kpis = [
        { id: 'sales-today', value: '$8,450' },
        { id: 'top-product', value: 'Latte Vainilla' },
        { id: 'alerts-count', value: '5' },
        { id: 'register-status', value: 'Cerrado' }
    ];
    
    kpis.forEach(kpi => {
        const element = document.getElementById(kpi.id);
        if (element) {
            element.textContent = kpi.value;
        }
    });
}

// Actualizar KPIs cada 30 segundos (simulación)
setInterval(updateKPIs, 30000);