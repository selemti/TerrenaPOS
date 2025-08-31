<?php
namespace Terrena\Modules\Dashboard;

class DashboardController {
  public function view() {
    // Solo maquetación (sin datos)
    $title = 'Dashboard';
    ob_start();
    require __DIR__ . '/../../views/dashboard.php';
    $content = ob_get_clean();
    require __DIR__ . '/../../views/layout.php';
  }
}
