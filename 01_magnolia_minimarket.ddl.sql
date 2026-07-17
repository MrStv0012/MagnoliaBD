CREATE TYPE MPAGO AS ENUM ('efectivo', 'tarjeta Crédito', 'tarjeta Débito', 'transferencia', 'transferencia bolsillo (Nequ, Daviplata, otro)');

CREATE TABLE pos_general (
    id_venta SERIAL PRIMARY KEY,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cliente_documento VARCHAR(20),
    vendedor_documento VARCHAR(20),
    producto_codigo VARCHAR(20),
    cliente_nombre VARCHAR(100),
    vendedor_nombre VARCHAR(100),
    producto_nombre VARCHAR(100),
    cliente_ciudad VARCHAR(50),
    proveedor_ciudad VARCHAR(50),
    cliente_departamento VARCHAR(50),  --- departamento al que pertence el cliente
    proveedor_departamento VARCHAR(50), --- departamento al que pertence el proveedor
    cliente_telefono VARCHAR(20),
    vendedor_sucursal VARCHAR(100),
    categoria VARCHAR(50), -- Categoria del producto
    subcategoria VARCHAR(50) DEFAULT 'NA', -- Subcategoria del producto
    proveedor_nombre VARCHAR(100), -- Proveedor del producto
    cantidad INTEGER CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) DEFAULT 0,
    metodo_pago MPAGO NOT NULL DEFAULT 'efectivo',
    banco VARCHAR(50),  -- ej. Bacncolombia, Davivienda, etc.
    garantia_meses INTEGER CHECK (garantia_meses >= 0)
);

CREATE TABLE pos_general_short (
   id_venta SERIAL PRIMARY KEY,
   fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
   vendedor_documento VARCHAR(20),
   producto_codigo VARCHAR(20),
   cantidad INTEGER CHECK (cantidad > 0),
   precio_unitario NUMERIC(10,2) DEFAULT 0,
   metodo_pago MPAGO NOT NULL DEFAULT 'efectivo'
);