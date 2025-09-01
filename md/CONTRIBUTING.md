# 🤝 Contribución — Terrena POS Admin

## Branching
- `main`: estable.
- `dev`: integración diaria.
- feature branches: `feat/<modulo>-<tema>`, ej. `feat/caja-precorte-ui`.

## Estilo
- PHP 8.2+, PSR-12, autoload PSR-4.
- JS modular simple (ES6), sin jQuery.
- CSS: `assets/css/terrena.css` (no duplicar reglas de `voceo.css`).

## Pull Requests
- Incluye descripción y **Checklist**:
  - [ ] Consulta SQL (si aplica) está en `QUERIES.md`.
  - [ ] Endpoint documentado en `API_SPEC.md`.
  - [ ] Rutas agregadas al Router.
  - [ ] Vista usa `render_layout()` (sin duplicar layout).
  - [ ] Pruebas manuales básicas (XAMPP).
  - [ ] Sin `var_dump`/`die` dejados.

## Validación local
1. `composer install`
2. Crear DB local con `query/POS_*` y `precorte_pack_final_*.sql`
3. Configurar `.env` y `config.php`
4. Abrir `http://localhost/terrena/Terrena/`

## Revisión
- Mantenedores: validar seguridad (SQLi/CSRF) y performance (índices/EXPLAIN).