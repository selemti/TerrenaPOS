<?php
declare(strict_types=1);

namespace Terrena\Core;

abstract class Controller
{
    /**
     * Renderiza una vista capturando su salida en $content y luego aplica el layout.
     * $viewPath: ruta absoluta del archivo de vista (que NO debe incluir el layout).
     * $vars: array asociativo para exponer variables a la vista (ej. ['title' => '...', 'data' => ...])
     */
    protected static function render(string $viewPath, array $vars = []): void
    {
        if (!is_file($viewPath)) {
            http_response_code(500);
            echo "Vista no encontrada: {$viewPath}";
            return;
        }

        // Defaults
        $title   = $vars['title']   ?? '';
        $content = '';

        // Exponer todas las variables del array $vars como locales de la vista
        (function () use ($viewPath, &$title, &$content, $vars) {
            extract($vars, EXTR_SKIP);
            require $viewPath;

            if (!isset($content)) $content = '';
            if (!isset($title) || $title === '') $title = 'Voceo POS';
        })();

        $layoutFile = dirname($viewPath) . '/layout.php';
        if (!is_file($layoutFile)) {
            http_response_code(500);
            echo "Layout no encontrado: {$layoutFile}";
            return;
        }

        require $layoutFile;
    }
}
