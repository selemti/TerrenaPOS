<?php
namespace Terrena\Modules\Caja;

class CortesController {
  public function view() {
    $title = 'Cortes de caja';
    ob_start();
    require __DIR__ . '/../../views/caja/cortes.php';
    $content = ob_get_clean();
    require __DIR__ . '/../../views/layout.php';
  }
}
