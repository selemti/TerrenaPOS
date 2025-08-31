<?php
namespace Terrena\Core;

use Terrena\Core\Auth;

class Router {
  private array $routesGet = [];
  private array $routesPost = [];

  // Guardamos handler + permiso requerido
  public function get(string $path, $handler, ?string $requiredPerm = null): void {
    $this->routesGet[$path] = ['handler' => $handler, 'perm' => $requiredPerm];
  }

  public function post(string $path, $handler, ?string $requiredPerm = null): void {
    $this->routesPost[$path] = ['handler' => $handler, 'perm' => $requiredPerm];
  }

  public function run(): void {
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $uri    = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
    $base   = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\'); // /terrena/Terrena
    $path   = ($base && $base !== '/') ? preg_replace('#^'.$base.'#', '', $uri) : $uri;
    if ($path === '' || $path === false) $path = '/';

    $route = ($method === 'POST') ? ($this->routesPost[$path] ?? null) : ($this->routesGet[$path] ?? null);

    if (!$route) { http_response_code(404); echo '404'; return; }

    // Chequeo de permiso si fue definido
    $perm = $route['perm'] ?? null;
    if ($perm && !Auth::can($perm)) {
      http_response_code(403);
      echo '403 – No tienes permiso para acceder a esta sección.';
      return;
    }

    $handler = $route['handler'];
    if (is_callable($handler)) { $handler(); return; }
    if (is_array($handler) && count($handler)===2) { [$c,$m] = $handler; (new $c())->$m(); return; }

    require $handler;
  }
}
