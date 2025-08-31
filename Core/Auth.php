<?php
namespace Terrena\Core;

class Auth {
  public static function boot(): void {
    if (session_status() !== PHP_SESSION_ACTIVE) session_start();
    if (!isset($_SESSION['user'])) {
      $_SESSION['user'] = [
        'id' => 1,
        'username' => 'jperez',
        'fullname' => 'Juan Pérez',
        'role' => 'Gerente',
        'permissions' => [
          'dashboard.view',
          'cashcuts.view',
          'inventory.view','inventory.move','inventory.kardex',
          'purchasing.view','purchasing.suggested.view',
          'recipes.view',
          'production.view',
          'reports.view','finance.view',
          'admin.view',
          'items.view','kds.matrix.manage',
          'people.view','people.employees.manage','people.roles.manage','people.permissions.manage','people.schedules.manage','people.audit.view',
        ],
      ];
    }
  }

  public static function user(): array { self::boot(); return $_SESSION['user']; }
  public static function can(string $perm): bool { return in_array($perm, self::user()['permissions'] ?? [], true); }
  public static function any(array $perms): bool { foreach ($perms as $p) if (self::can($p)) return true; return false; }
  public static function all(array $perms): bool { foreach ($perms as $p) if (!self::can($p)) return false; return true; }
}
