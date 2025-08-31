<?php
declare(strict_types=1);

// Usa SIEMPRE los mismos nombres que tus carpetas reales (Core, Modules, Views)
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/Core/Auth.php';    // <-- Core (C mayúscula)
require_once __DIR__ . '/Core/Router.php';  // <-- Core (C mayúscula)

use Terrena\Core\Auth;
use Terrena\Core\Router;

// Base dinámica para <base href="">
$base = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\');
$GLOBALS['__BASE__'] = $base;

// ¡Muy importante! Inicializa sesión/usuario simulado
Auth::boot();

/* ===== Controladores (usa 'Modules' con M mayúscula) ===== */
require_once __DIR__ . '/Modules/Dashboard/DashboardController.php';
require_once __DIR__ . '/Modules/Caja/CortesController.php';
require_once __DIR__ . '/Modules/Inventario/InventarioController.php';
require_once __DIR__ . '/Modules/Compras/ComprasController.php';
require_once __DIR__ . '/Modules/Recetas/RecetasController.php';
require_once __DIR__ . '/Modules/Produccion/ProduccionController.php';
require_once __DIR__ . '/Modules/Reportes/ReportesController.php';
require_once __DIR__ . '/Modules/Admin/AdminController.php';
require_once __DIR__ . '/Modules/Admin/ItemsController.php';
require_once __DIR__ . '/Modules/Personal/PersonalController.php';

/* ====================== Rutas ======================== */
$router = new Router();

// Dashboard
$router->get('/',           [Terrena\Modules\Dashboard\DashboardController::class, 'view'], 'dashboard.view');
$router->get('/dashboard',  [Terrena\Modules\Dashboard\DashboardController::class, 'view'], 'dashboard.view');

// Caja
$router->get('/caja/cortes',[Terrena\Modules\Caja\CortesController::class, 'view'], 'cashcuts.view');

// Inventario
$router->get('/inventario', [Terrena\Modules\Inventario\InventarioController::class, 'view'], 'inventory.view');

// Compras
$router->get('/compras',    [Terrena\Modules\Compras\ComprasController::class, 'view'], 'purchasing.view');

// Recetas
$router->get('/recetas',    [Terrena\Modules\Recetas\RecetasController::class, 'view'], 'recipes.view');

// Producción
$router->get('/produccion', [Terrena\Modules\Produccion\ProduccionController::class, 'view'], 'production.view');

// Reportes
$router->get('/reportes',   [Terrena\Modules\Reportes\ReportesController::class, 'view'], 'reports.view');

// Admin general
$router->get('/admin',      [Terrena\Modules\Admin\AdminController::class, 'view'], 'admin.view');

// Items & KDS
$router->get('/admin/items',[Terrena\Modules\Admin\ItemsController::class, 'view'], 'items.view');

// Personal
$router->get('/personal',   [Terrena\Modules\Personal\PersonalController::class, 'view'], 'people.view');

$router->get('/reportes/pnl',   function(){ $title='P&L';   ob_start(); require __DIR__.'/Views/reportes/pnl.php';   $content=ob_get_clean(); require __DIR__.'/Views/layout.php'; }, 'reports.view');
$router->get('/reportes/flujo', function(){ $title='Flujo'; ob_start(); require __DIR__.'/Views/reportes/flujo.php'; $content=ob_get_clean(); require __DIR__.'/Views/layout.php'; }, 'reports.view');



$router->run();
