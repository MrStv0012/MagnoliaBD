-- =====================================================================
-- 04_magnolia_triggers.sql
-- Se ejecuta despues de 03 (funciones + migracion ya corrida).
-- =====================================================================

-- =====================================================================
-- TRIGGER 1: Auditoria de ventas
-- Resuelve directamente la anomalia del diseno original discutida en
-- el Opcional 1 ("Elimine la ultima venta registrada en la tabla"):
-- ahora cualquier INSERT, UPDATE o DELETE sobre venta queda trazado,
-- en vez de perderse sin dejar rastro.
-- =====================================================================

CREATE TABLE auditoria_venta (
    id                SERIAL PRIMARY KEY,
    operacion         VARCHAR(10) NOT NULL,
    id_venta          INTEGER,
    datos_anteriores  JSONB,
    datos_nuevos      JSONB,
    usuario_bd        VARCHAR(50) DEFAULT CURRENT_USER,
    fecha_operacion   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION fn_auditar_venta()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria_venta(operacion, id_venta, datos_anteriores)
        VALUES ('DELETE', OLD.id_venta, to_jsonb(OLD));
        RETURN OLD;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_venta(operacion, id_venta, datos_anteriores, datos_nuevos)
        VALUES ('UPDATE', NEW.id_venta, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_venta(operacion, id_venta, datos_nuevos)
        VALUES ('INSERT', NEW.id_venta, to_jsonb(NEW));
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_venta
AFTER INSERT OR UPDATE OR DELETE ON venta
FOR EACH ROW EXECUTE FUNCTION fn_auditar_venta();


-- =====================================================================
-- TRIGGER 2: Auto-registro de ciudad
-- Resuelve la anomalia "Insertar un proveedor sin ventas": en el
-- diseno normalizado, cliente/proveedor/sucursal dependen de que la
-- ciudad ya exista (FK). Este trigger crea la ciudad automaticamente
-- si aun no esta registrada, para que la insercion nunca falle por
-- una FK faltante despues de la migracion inicial.
-- Un mismo trigger function se reutiliza en las 3 tablas.
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_autocompletar_ciudad()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.ciudad_fk IS NOT NULL THEN
        INSERT INTO ciudad (nombre, departamento)
        VALUES (NEW.ciudad_fk, 'Sin definir')
        ON CONFLICT (nombre) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_autocompletar_ciudad_cliente
BEFORE INSERT OR UPDATE ON cliente
FOR EACH ROW EXECUTE FUNCTION fn_autocompletar_ciudad();

CREATE TRIGGER trg_autocompletar_ciudad_proveedor
BEFORE INSERT OR UPDATE ON proveedor
FOR EACH ROW EXECUTE FUNCTION fn_autocompletar_ciudad();

CREATE TRIGGER trg_autocompletar_ciudad_sucursal
BEFORE INSERT OR UPDATE ON sucursal
FOR EACH ROW EXECUTE FUNCTION fn_autocompletar_ciudad();
