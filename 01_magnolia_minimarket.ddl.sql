-- =====================================================================
-- 01_magnolia_minimarket.ddl.sql
-- Base de datos: db_magnolia
-- =====================================================================

-- =====================================================================
-- SECCION 1: ESQUEMA LEGACY (pos_general)
-- No se modifica: preserva los datos historicos de 3 anios del sistema
-- POS actual. El DML de 2.5GB inserta directamente sobre estas tablas.
-- =====================================================================

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
    cliente_departamento VARCHAR(50),
    proveedor_departamento VARCHAR(50),
    cliente_telefono VARCHAR(20),
    vendedor_sucursal VARCHAR(100),
    categoria VARCHAR(50),
    subcategoria VARCHAR(50) DEFAULT 'NA',
    proveedor_nombre VARCHAR(100),
    cantidad INTEGER CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) DEFAULT 0,
    metodo_pago MPAGO NOT NULL DEFAULT 'efectivo',
    banco VARCHAR(50),
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


-- =====================================================================
-- SECCION 2: ESQUEMA NORMALIZADO (3FN)
-- 7 tablas resultantes de la normalizacion de pos_general.
-- Se pueblan mediante migracion (INSERT ... SELECT DISTINCT) en
-- 03_magnolia_functions.sql, no directamente por el DML legacy.
-- =====================================================================

CREATE TABLE ciudad (
    nombre         VARCHAR(50) PRIMARY KEY,
    departamento   VARCHAR(50) NOT NULL
);

CREATE TABLE cliente (
    documento      VARCHAR(20) PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    telefono       VARCHAR(20),
    ciudad_fk      VARCHAR(50) REFERENCES ciudad(nombre)
                       ON UPDATE CASCADE
                       ON DELETE RESTRICT
);

CREATE TABLE proveedor (
    id             SERIAL PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL UNIQUE,
    ciudad_fk      VARCHAR(50) REFERENCES ciudad(nombre)
                       ON UPDATE CASCADE
                       ON DELETE RESTRICT
);

CREATE TABLE sucursal (
    id             SERIAL PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    ciudad_fk      VARCHAR(50) REFERENCES ciudad(nombre)
                       ON UPDATE CASCADE
                       ON DELETE RESTRICT,
    UNIQUE (nombre, ciudad_fk)
);

CREATE TABLE vendedor (
    documento      VARCHAR(20) PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    sucursal_fk    INTEGER REFERENCES sucursal(id)
                       ON UPDATE CASCADE
                       ON DELETE RESTRICT
);

CREATE TABLE producto (
    codigo         VARCHAR(20) PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    categoria      VARCHAR(50),
    subcategoria   VARCHAR(50) DEFAULT 'NA',
    garantia_meses INTEGER CHECK (garantia_meses >= 0),
    proveedor_fk   INTEGER REFERENCES proveedor(id)
                       ON UPDATE CASCADE
                       ON DELETE RESTRICT
);

CREATE TABLE venta (
    id_venta        SERIAL PRIMARY KEY,
    fecha           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cantidad        INTEGER CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) DEFAULT 0,
    metodo_pago     MPAGO NOT NULL DEFAULT 'efectivo',
    banco           VARCHAR(50),
    cliente_fk      VARCHAR(20) REFERENCES cliente(documento)
                       ON UPDATE CASCADE
                       ON DELETE RESTRICT,
    vendedor_fk     VARCHAR(20) REFERENCES vendedor(documento)
                       ON UPDATE CASCADE
                       ON DELETE RESTRICT,
    producto_fk     VARCHAR(20) REFERENCES producto(codigo)
                       ON UPDATE CASCADE
                       ON DELETE RESTRICT
);
