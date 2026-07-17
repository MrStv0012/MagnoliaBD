-- =====================================================================
-- demo/06_magnolia_queries.sql
-- =====================================================================

-- =====================================================================
-- REQUISITO 1: monto total vendido por cada ciudad con sede
-- =====================================================================
SELECT s.ciudad_fk AS ciudad,
       SUM(v.cantidad * v.precio_unitario) AS monto_total
FROM venta v
JOIN vendedor ve ON ve.documento = v.vendedor_fk
JOIN sucursal s  ON s.id = ve.sucursal_fk
GROUP BY s.ciudad_fk
ORDER BY monto_total DESC;


-- =====================================================================
-- REQUISITO 2: proveedores con mayor facturacion
-- =====================================================================
SELECT p.nombre AS proveedor,
       SUM(v.cantidad * v.precio_unitario) AS facturacion
FROM venta v
JOIN producto pr  ON pr.codigo = v.producto_fk
JOIN proveedor p  ON p.id = pr.proveedor_fk
GROUP BY p.nombre
ORDER BY facturacion DESC;


-- =====================================================================
-- REQUISITO 3: producto que mas vende, en general y por cada ciudad
-- Usa las funciones creadas en 03_magnolia_functions.sql
-- =====================================================================

-- General (toda la tienda)
SELECT * FROM fn_producto_mas_vendido();

-- Por cada ciudad
SELECT c.nombre AS ciudad, fmv.codigo, fmv.nombre, fmv.total_unidades
FROM ciudad c
CROSS JOIN LATERAL fn_producto_mas_vendido(c.nombre) fmv;


-- =====================================================================
-- REQUISITO 4: clientes que compran TODOS los productos de un proveedor
-- (division relacional: el cliente no debe tener ningun producto de
-- ese proveedor sin comprar)
-- =====================================================================
SELECT cl.documento, cl.nombre AS cliente, p.nombre AS proveedor
FROM cliente cl
CROSS JOIN proveedor p
WHERE EXISTS (SELECT 1 FROM producto pr WHERE pr.proveedor_fk = p.id)
  AND NOT EXISTS (
        SELECT pr.codigo FROM producto pr WHERE pr.proveedor_fk = p.id
        EXCEPT
        SELECT v.producto_fk FROM venta v WHERE v.cliente_fk = cl.documento
  )
ORDER BY p.nombre, cl.nombre;


-- =====================================================================
-- REQUISITO 5: ciudad donde cada proveedor vende mas
-- =====================================================================
SELECT proveedor, ciudad, monto
FROM (
    SELECT p.nombre AS proveedor,
           s.ciudad_fk AS ciudad,
           SUM(v.cantidad * v.precio_unitario) AS monto,
           ROW_NUMBER() OVER (
               PARTITION BY p.nombre
               ORDER BY SUM(v.cantidad * v.precio_unitario) DESC
           ) AS rn
    FROM venta v
    JOIN producto pr  ON pr.codigo = v.producto_fk
    JOIN proveedor p  ON p.id = pr.proveedor_fk
    JOIN vendedor ve  ON ve.documento = v.vendedor_fk
    JOIN sucursal s   ON s.id = ve.sucursal_fk
    GROUP BY p.nombre, s.ciudad_fk
) t
WHERE rn = 1;


-- =====================================================================
-- REQUISITO 6: mejor vendedor por sucursal/sede
-- =====================================================================
SELECT sucursal, vendedor, monto
FROM (
    SELECT s.nombre AS sucursal,
           ve.nombre AS vendedor,
           SUM(v.cantidad * v.precio_unitario) AS monto,
           ROW_NUMBER() OVER (
               PARTITION BY s.id
               ORDER BY SUM(v.cantidad * v.precio_unitario) DESC
           ) AS rn
    FROM venta v
    JOIN vendedor ve ON ve.documento = v.vendedor_fk
    JOIN sucursal s  ON s.id = ve.sucursal_fk
    GROUP BY s.id, s.nombre, ve.nombre
) t
WHERE rn = 1;


-- =====================================================================
-- DEMOSTRACION DE INTERACCION (rubrica: insertar, actualizar, eliminar)
-- =====================================================================

-- --- INSERT: nuevo cliente en una ciudad que aun no existe en 'ciudad'.
-- Antes de nuestro trigger 2 (fn_autocompletar_ciudad), esto habria
-- fallado por violacion de la FK ciudad_fk. Ahora se resuelve solo.
INSERT INTO cliente (documento, nombre, telefono, ciudad_fk)
VALUES ('999999999', 'Cliente Demo', '3000000000', 'Popayán');

-- Verificar que la ciudad se creo automaticamente
SELECT * FROM ciudad WHERE nombre = 'Popayán';


-- --- UPDATE: se actualiza una venta existente.
-- El trigger 1 (fn_auditar_venta) debe dejar constancia del cambio.
UPDATE venta
SET banco = 'Banco Demo Actualizado'
WHERE id_venta = (SELECT MIN(id_venta) FROM venta);

-- Verificar que quedo registrado en la auditoria
SELECT * FROM auditoria_venta
WHERE operacion = 'UPDATE'
ORDER BY fecha_operacion DESC
LIMIT 1;


-- --- DELETE: se elimina una venta.
-- Esta es exactamente la anomalia original ("elimine la ultima venta
-- registrada") que ahora queda trazada en vez de perderse sin rastro.
DELETE FROM venta
WHERE id_venta = (SELECT MAX(id_venta) FROM venta);

-- Verificar que quedo registrado en la auditoria, con los datos previos
SELECT * FROM auditoria_venta
WHERE operacion = 'DELETE'
ORDER BY fecha_operacion DESC
LIMIT 1;
