# 🧱 STACK — Terrena POS Admin

## Lenguajes y librerías
- PHP 8 (PSR-4, Composer)
- PostgreSQL 9.5 (POS + auxiliares `pc_*`)
- Bootstrap 5, Chart.js
- Composer: `mike42/escpos-php`, `vlucas/phpdotenv` (recomendado)

## Estructura


Raíz
├─ .env.example
├─ composer.json
├─ config.php
├─ Core/ # Router, Auth, DB (PDO)
├─ Modules/ # Caja, Inventario, Compras, Recetas, Produccion, Reportes, Admin, Personal
├─ Views/ # layout.php, dashboard.php, ...
├─ assets/
│ ├─ css/terrena.css
│ ├─ js/terrena.js
│ └─ img/logo.svg, logo2.svg
└─ query/
├─ POS_structure_30_08_2025.sql
├─ POS_Cortes_preview_30_08_2025.sql
└─ precorte_pack_final_v3_consolidated_perfect_v15.1.sql


## Composer (sugerido)
```json
{
  "name": "grupoo/terrena-pos-admin",
  "require": {
    "php": "^8.2",
    "mike42/escpos-php": "^3.2",
    "vlucas/phpdotenv": "^5.6"
  },
  "autoload": {
    "psr-4": {
      "Terrena\\": "Core/",
      "Terrena\\Modules\\": "Modules/"
    }
  }
}

.env.example
APP_ENV=local
APP_DEBUG=true
BASE_PATH=/terrena/Terrena

DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=floreant
DB_USER=postgres
DB_PASS=postgres

config.php (leer .env cuando esté disponible)
<?php
$base = $_ENV['BASE_PATH'] ?? '/terrena/Terrena';
$GLOBALS['__BASE__'] = $base;

define('DB_HOST', $_ENV['DB_HOST'] ?? '127.0.0.1');
define('DB_PORT', $_ENV['DB_PORT'] ?? '5432');
define('DB_NAME', $_ENV['DB_NAME'] ?? 'floreant');
define('DB_USER', $_ENV['DB_USER'] ?? 'postgres');
define('DB_PASS', $_ENV['DB_PASS'] ?? 'postgres');

function db(): PDO {
  static $pdo=null;
  if ($pdo) return $pdo;
  $dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', DB_HOST, DB_PORT, DB_NAME);
  $pdo = new PDO($dsn, DB_USER, DB_PASS, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  ]);
  return $pdo;
}

Apache (.htaccess en raíz)
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [QSA,L]

Seguridad

Sesión/JWT, CSRF tokens para formularios, sanitizar inputs (PDO con bind).

Principio de menor privilegio en DB: rol terrena_app con SELECT en POS y ALL en pc_*.

Registra trace_id por request para auditoría.

Logging

PHP error log + canal app (monolog recomendado).

Logs de consultas costosas (ver log_min_duration_statement de PostgreSQL).

Testing

PHPUnit para servicios/queries (mocks de PDO).

Pruebas de carga puntuales (dashboard y cortes).

CI/CD (sugerido)

GitHub Actions: composer validate, php -l, phpunit, deploy GitHub → Ubuntu (rsync/ssh).


---