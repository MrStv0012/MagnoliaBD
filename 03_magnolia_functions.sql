-- =====================================================================
-- 03_magnolia_functions.sql
-- 2 funciones + 1 procedimiento (migracion pos_general -> esquema 3FN)
-- Este archivo se ejecuta automaticamente al levantar el contenedor,
-- DESPUES de que 02_magnolia_minimarket.dml.sql ya cargo pos_general.
-- =====================================================================

-- =====================================================================
-- FUNCION 1: fn_total_vendido_ciudad
-- Requisito 1: monto total vendido por cada ciudad con sede de la tienda
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_total_vendido_ciudad(p_ciudad VARCHAR)
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(v.cantidad * v.precio_unitario), 0)
    INTO v_total
    FROM venta v
    JOIN vendedor ve ON ve.documento = v.vendedor_fk
    JOIN sucursal s  ON s.id = ve.sucursal_fk
    WHERE s.ciudad_fk = p_ciudad;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql;


-- =====================================================================
-- FUNCION 2: fn_producto_mas_vendido
-- Requisito 3: producto que mas vende, en general o filtrado por ciudad
-- Si p_ciudad es NULL, calcula el mas vendido a nivel general.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_producto_mas_vendido(p_ciudad VARCHAR DEFAULT NULL)
RETURNS TABLE (codigo VARCHAR, nombre VARCHAR, total_unidades BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT pr.codigo, pr.nombre, SUM(v.cantidad)::BIGINT AS total_unidades
    FROM venta v
    JOIN producto pr ON pr.codigo = v.producto_fk
    JOIN vendedor ve ON ve.documento = v.vendedor_fk
    JOIN sucursal s  ON s.id = ve.sucursal_fk
    WHERE p_ciudad IS NULL OR s.ciudad_fk = p_ciudad
    GROUP BY pr.codigo, pr.nombre
    ORDER BY total_unidades DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;


-- =====================================================================
-- PROCEDIMIENTO: sp_migrar_datos
-- Transfiere pos_general (desnormalizada) hacia el esquema 3FN,
-- sin perdida de datos y respetando el orden de dependencias FK.
-- Es idempotente: se puede volver a ejecutar sin duplicar filas
-- (ON CONFLICT DO NOTHING en cada paso).
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_migrar_datos()
LANGUAGE plpgsql
AS $$
BEGIN

    -- 1) CIUDAD: union de ciudades de clientes y proveedores.
    --    MAX(departamento) rescata el departamento aunque
    --    proveedor_departamento venga NULL en algunas filas.
    INSERT INTO ciudad (nombre, departamento)
    SELECT ciudad, MAX(departamento)
    FROM (
        SELECT cliente_ciudad AS ciudad, cliente_departamento AS departamento
        FROM pos_general
        WHERE cliente_ciudad IS NOT NULL
        UNION ALL
        SELECT proveedor_ciudad, proveedor_departamento
        FROM pos_general
        WHERE proveedor_ciudad IS NOT NULL
    ) t
    GROUP BY ciudad
    ON CONFLICT (nombre) DO NOTHING;

    -- 2) CLIENTE: se toma el registro mas reciente por documento
    --    (por si el cliente cambio de ciudad/telefono con el tiempo).
    INSERT INTO cliente (documento, nombre, telefono, ciudad_fk)
    SELECT DISTINCT ON (cliente_documento)
           cliente_documento, cliente_nombre, cliente_telefono, cliente_ciudad
    FROM pos_general
    WHERE cliente_documento IS NOT NULL
    ORDER BY cliente_documento, fecha DESC NULLS LAST
    ON CONFLICT (documento) DO NOTHING;

    -- 3) PROVEEDOR
    INSERT INTO proveedor (nombre, ciudad_fk)
    SELECT DISTINCT ON (proveedor_nombre)
           proveedor_nombre, proveedor_ciudad
    FROM pos_general
    WHERE proveedor_nombre IS NOT NULL
    ORDER BY proveedor_nombre, fecha DESC NULLS LAST
    ON CONFLICT (nombre) DO NOTHING;

    -- 4) SUCURSAL: pos_general no trae la ciudad de la sucursal,
    --    se infiere como la ciudad mas frecuente de los clientes
    --    atendidos por vendedores de esa sucursal.
    INSERT INTO sucursal (nombre, ciudad_fk)
    SELECT sucursal, ciudad
    FROM (
        SELECT vendedor_sucursal AS sucursal,
               cliente_ciudad AS ciudad,
               ROW_NUMBER() OVER (
                   PARTITION BY vendedor_sucursal
                   ORDER BY COUNT(*) DESC
               ) AS rn
        FROM pos_general
        WHERE vendedor_sucursal IS NOT NULL AND cliente_ciudad IS NOT NULL
        GROUP BY vendedor_sucursal, cliente_ciudad
    ) t
    WHERE rn = 1
    ON CONFLICT (nombre, ciudad_fk) DO NOTHING;

    -- 5) VENDEDOR
    INSERT INTO vendedor (documento, nombre, sucursal_fk)
    SELECT DISTINCT ON (pg.vendedor_documento)
           pg.vendedor_documento, pg.vendedor_nombre, s.id
    FROM pos_general pg
    LEFT JOIN sucursal s ON s.nombre = pg.vendedor_sucursal
    WHERE pg.vendedor_documento IS NOT NULL
    ORDER BY pg.vendedor_documento, pg.fecha DESC NULLS LAST, s.id ASC
    ON CONFLICT (documento) DO NOTHING;

    -- 6) PRODUCTO
    INSERT INTO producto (codigo, nombre, categoria, subcategoria, garantia_meses, proveedor_fk)
    SELECT DISTINCT ON (pg.producto_codigo)
           pg.producto_codigo, pg.producto_nombre, pg.categoria,
           pg.subcategoria, pg.garantia_meses, p.id
    FROM pos_general pg
    LEFT JOIN proveedor p ON p.nombre = pg.proveedor_nombre
    WHERE pg.producto_codigo IS NOT NULL
    ORDER BY pg.producto_codigo, pg.fecha DESC NULLS LAST
    ON CONFLICT (codigo) DO NOTHING;

    -- 7) VENTA: se preserva el mismo id_venta de pos_general
    --    para trazabilidad 1 a 1 entre ambos esquemas.
    INSERT INTO venta (id_venta, fecha, cantidad, precio_unitario,
                        metodo_pago, banco, cliente_fk, vendedor_fk, producto_fk)
    SELECT id_venta, fecha, cantidad, precio_unitario,
           metodo_pago, banco, cliente_documento, vendedor_documento, producto_codigo
    FROM pos_general
    ON CONFLICT (id_venta) DO NOTHING;

    -- Re-sincroniza la secuencia de id_venta, ya que se insertaron
    -- valores explicitos en vez de dejar que SERIAL los generara.
    PERFORM setval(
        pg_get_serial_sequence('venta', 'id_venta'),
        COALESCE((SELECT MAX(id_venta) FROM venta), 1)
    );

    RAISE NOTICE 'Migracion completada: pos_general -> esquema 3FN';
END;
$$;


-- =====================================================================
-- Ejecuta la migracion automaticamente al levantar el contenedor,
-- una vez que 01 (DDL) y 02 (DML) ya corrieron.
-- =====================================================================
CALL sp_migrar_datos();
