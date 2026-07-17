-- =====================================================================
-- 05_magnolia_index.sql
-- Se ejecuta despues de 03 (datos ya migrados) y 04 (triggers).
-- Postgres NO crea automaticamente indices sobre columnas FK (solo
-- sobre PK y UNIQUE), asi que cada join usado en los requisitos de
-- informacion necesita su propio indice explicito.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Claves foraneas de VENTA: la tabla mas grande y la mas consultada
-- (aparece en los 6 requisitos de informacion, siempre via JOIN).
-- ---------------------------------------------------------------------
CREATE INDEX idx_venta_cliente_fk   ON venta (cliente_fk);
CREATE INDEX idx_venta_vendedor_fk  ON venta (vendedor_fk);
CREATE INDEX idx_venta_producto_fk  ON venta (producto_fk);

-- Indice compuesto: cubre agregaciones SUM(cantidad)/COUNT(*)
-- agrupadas por producto sin tener que volver a la tabla (index-only scan).
-- Usado por el requisito 3 (producto mas vendido).
CREATE INDEX idx_venta_producto_cantidad ON venta (producto_fk, cantidad);

-- Consultas por rango de fecha (reportes por periodo).
CREATE INDEX idx_venta_fecha ON venta (fecha);


-- ---------------------------------------------------------------------
-- Cadenas de FK hacia CIUDAD: requisitos 1, 3, 5 y 6 dependen de
-- resolver "vendedor -> sucursal -> ciudad" o "proveedor -> ciudad".
-- ---------------------------------------------------------------------
CREATE INDEX idx_vendedor_sucursal_fk ON vendedor (sucursal_fk);
CREATE INDEX idx_sucursal_ciudad_fk   ON sucursal (ciudad_fk);
CREATE INDEX idx_cliente_ciudad_fk    ON cliente (ciudad_fk);
CREATE INDEX idx_proveedor_ciudad_fk  ON proveedor (ciudad_fk);


-- ---------------------------------------------------------------------
-- PRODUCTO -> PROVEEDOR: requisitos 2, 4 y 5 (facturacion y
-- preferencia de clientes por proveedor).
-- ---------------------------------------------------------------------
CREATE INDEX idx_producto_proveedor_fk ON producto (proveedor_fk);


-- ---------------------------------------------------------------------
-- AUDITORIA_VENTA: consultas de trazabilidad por venta o por fecha
-- (util para revisar el historial que genera el trigger 1).
-- ---------------------------------------------------------------------
CREATE INDEX idx_auditoria_venta_id_venta ON auditoria_venta (id_venta);
CREATE INDEX idx_auditoria_venta_fecha    ON auditoria_venta (fecha_operacion);
