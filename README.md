# MagnoliaBD

Rediseño y re-implementación de la base de datos del sistema POS de la tienda de doña Magnolia. Parte de un esquema desnormalizado de una sola tabla (`pos_general`) y lo normaliza hasta 3FN, preservando la totalidad de los datos históricos, para resolver los nuevos requisitos de información de la tienda (ventas por ciudad, proveedores con mayor facturación, producto más vendido, clientes fieles a un proveedor, ciudad top por proveedor y mejor vendedor por sucursal).

Trabajo académico — curso Bases de Datos, Universidad del Valle (docente Jefferson A. Peña Torres).

## Contenido del repositorio

```
MagnoliaBD-main/
├── 01_magnolia_minimarket.ddl.sql   # Esquema legacy (pos_general) + esquema normalizado 3FN (7 tablas)
├── 02_magnolia_minimarket.dml.sql   # NO incluido en el repo (ver DML_no_incluido_en_repo.pdf) — pesa ~2.5GB
├── 03_magnolia_functions.sql        # 2 funciones + procedimiento de migración pos_general -> 3FN
├── 04_magnolia_triggers.sql         # Trigger de auditoría de ventas + trigger de auto-registro de ciudad
├── 05_magnolia_index.sql            # Índices sobre FKs y columnas usadas en los joins de los requisitos
├── demo/
│   └── 06_magnolia_queries.sql      # Consultas SQL para los 6 requisitos + demo de INSERT/UPDATE/DELETE
├── diagramas/
│   ├── Diagrama ER.jpg
│   └── Modelo Relacional.jpg
├── normalizacion_pos_general.txt    # Dependencias funcionales y proceso 1FN -> 2FN -> 3FN
├── DML_no_incluido_en_repo.pdf      # Explica por qué el DML no está en el repo y dónde descargarlo
└── Dockerfile
```

## Modelo de datos

- **Esquema legacy**: `pos_general` se conserva intacta. Sobre ella se cargan directamente los ~4 millones de registros históricos del DML, sin modificar ni un solo dato existente.
- **Esquema normalizado (3FN)**: 7 tablas — `ciudad`, `cliente`, `proveedor`, `sucursal`, `vendedor`, `producto`, `venta` — pobladas automáticamente a partir de `pos_general` mediante el procedimiento `sp_migrar_datos()`, sin pérdida de información.

El detalle de las dependencias funcionales y el paso a paso 1FN → 2FN → 3FN está en [`normalizacion_pos_general.txt`](normalizacion_pos_general.txt) y desarrollado con más profundidad en el informe PDF de la entrega.

Diagramas: [Diagrama ER](diagramas/Diagrama%20ER.jpg) · [Modelo Relacional](diagramas/Modelo%20Relacional.jpg)

## Cómo levantar el proyecto

### Prerrequisitos
- Docker instalado y corriendo.

### 1. Descargar el DML (no está en el repo por su tamaño)

El archivo `02_magnolia_minimarket.dml.sql` (~2.5 GB, ~4 millones de `INSERT`) supera el límite de GitHub, así que se aloja aparte. Detalle completo en [`DML_no_incluido_en_repo.pdf`](DML_no_incluido_en_repo.pdf).

1. Descárgalo desde el enlace de Google Drive indicado en ese PDF.
2. Colócalo en la raíz del proyecto, junto al `Dockerfile`, con el nombre exacto `02_magnolia_minimarket.dml.sql`.

### 2. Construir la imagen

```bash
docker build -t magnolia-db .
```

### 3. Levantar el contenedor

```bash
docker run --name magnolia-db -e POSTGRES_PASSWORD=m4gn0l14 -p 5432:5432 -d magnolia-db
```

Al iniciar, Postgres ejecuta automáticamente todos los `.sql` de la raíz en orden alfabético (`01` → `02` → `03` → `04` → `05`):
1. Crea `pos_general` y el esquema normalizado.
2. Carga los datos históricos en `pos_general`.
3. Crea funciones/procedimiento y migra los datos hacia el esquema 3FN.
4. Crea los triggers de auditoría y auto-registro de ciudad.
5. Crea los índices sobre las FKs.

> La primera carga puede tardar varios minutos por el volumen del DML. Sigue el progreso con:
> ```bash
> docker logs -f magnolia-db
> ```

### 4. Verificar que todo cargó bien

```bash
docker exec -it magnolia-db psql -U u_magnolia -d db_magnolia -c "SELECT COUNT(*) FROM pos_general;"
docker exec -it magnolia-db psql -U u_magnolia -d db_magnolia -c "SELECT COUNT(*) FROM venta;"
```

Ambos conteos deben coincidir (misma cantidad de filas en el esquema legacy y en el normalizado).

### 5. Ejecutar las consultas de demostración

```bash
docker exec -it magnolia-db psql -U u_magnolia -d db_magnolia -f /dev/stdin < demo/06_magnolia_queries.sql
```

o, para explorar de forma interactiva:

```bash
docker exec -it magnolia-db psql -U u_magnolia -d db_magnolia
```

y dentro de `psql`:

```sql
\i demo/06_magnolia_queries.sql
```

## Credenciales (solo para entorno de pruebas local)

| Variable | Valor |
|---|---|
| `POSTGRES_USER` | `u_magnolia` |
| `POSTGRES_PASSWORD` | `m4gn0l14` |
| `POSTGRES_DB` | `db_magnolia` |

## Requisitos de información resueltos

| # | Requisito | Dónde |
|---|---|---|
| 1 | Monto total vendido por ciudad con sede | `fn_total_vendido_ciudad()`, consulta en `demo/06...sql` |
| 2 | Proveedores con mayor facturación | Consulta en `demo/06...sql` |
| 3 | Producto más vendido (general y por ciudad) | `fn_producto_mas_vendido()` |
| 4 | Clientes que compran todos los productos de un proveedor | Consulta en `demo/06...sql` (división relacional) |
| 5 | Ciudad donde cada proveedor vende más | Consulta en `demo/06...sql` |
| 6 | Mejor vendedor por sucursal | Consulta en `demo/06...sql` |

## Restricciones de integridad

- `PRIMARY KEY` en todas las tablas del esquema normalizado.
- `FOREIGN KEY` con `ON UPDATE CASCADE ON DELETE RESTRICT` en todas las relaciones (evita huérfanos; propaga cambios de identificadores).
- `CHECK` en `cantidad > 0` y `garantia_meses >= 0`.
- `UNIQUE` en `proveedor.nombre` y en `(sucursal.nombre, sucursal.ciudad_fk)`.
- `NOT NULL` en atributos obligatorios (nombres, `metodo_pago`, etc.).
- Tipo `ENUM` (`MPAGO`) para restringir los métodos de pago a un dominio cerrado.

## Mecanismos avanzados

- **2 funciones**: `fn_total_vendido_ciudad`, `fn_producto_mas_vendido`.
- **1 procedimiento**: `sp_migrar_datos` (idempotente, migra sin duplicar).
- **2 triggers**: auditoría de `venta` (`INSERT`/`UPDATE`/`DELETE`) y auto-registro de `ciudad` al insertar cliente/proveedor/sucursal en una ciudad nueva.
- **Índices** sobre todas las FKs y sobre las columnas más consultadas en los 6 requisitos.

## Autor

Jhon Steven Angulo Nieves - 2415995.

## Recursos de la entrega

- Video: _[enlace]_
- Informe PDF: incluido en la entrega del campus virtual.
