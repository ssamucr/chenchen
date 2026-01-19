-- =====================================================
-- TABLA: subcuentas
-- Descripción: Subcuentas para organizar fondos dentro de cuentas principales
-- Dependencias: cuentas
-- =====================================================

CREATE TABLE subcuentas (
    -- ============ CLAVE PRIMARIA ============
    subcuenta_id        BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    cuenta_id           BIGINT NOT NULL,
    
    -- ============ DATOS PRINCIPALES ============
    nombre              VARCHAR(100) NOT NULL,
    descripcion         TEXT,
    
    -- ============ METAS Y SALDOS ============
    monto_meta          DECIMAL(15,2),
    saldo_actual        DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    
    -- ============ CONFIGURACIÓN ============
    activa              BOOLEAN NOT NULL DEFAULT TRUE,
    color_hex           CHAR(7) NOT NULL DEFAULT '#8B5CF6',
    icono               VARCHAR(50),
    orden_mostrar       INTEGER NOT NULL DEFAULT 0,
    
    -- ============ AUDITORIA ============
    creada_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizada_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_subcuenta_cuenta 
        FOREIGN KEY (cuenta_id) 
        REFERENCES cuentas(cuenta_id) 
        ON DELETE CASCADE,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Nombre no vacío
    CONSTRAINT check_nombre_no_vacio 
        CHECK (LENGTH(TRIM(nombre)) > 0),
    
    -- ✅ Meta debe ser positiva si existe
    CONSTRAINT check_monto_meta_positivo 
        CHECK (monto_meta IS NULL OR monto_meta > 0),
    
    -- ✅ Color hexadecimal válido
    CONSTRAINT check_color_hex_valido 
        CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por cuenta (más común)
CREATE INDEX idx_subcuentas_cuenta 
ON subcuentas(cuenta_id, orden_mostrar) 
WHERE activa = TRUE;

-- Búsquedas por progreso de meta
CREATE INDEX idx_subcuentas_con_meta 
ON subcuentas(cuenta_id, saldo_actual, monto_meta) 
WHERE monto_meta IS NOT NULL AND activa = TRUE;

-- Búsqueda de texto
CREATE INDEX idx_subcuentas_nombre_texto 
ON subcuentas USING gin(to_tsvector('spanish', nombre || ' ' || COALESCE(descripcion, '')));

-- ============ CONSTRAINT DE UNICIDAD ============

-- No duplicar nombres de subcuenta dentro de la misma cuenta
CREATE UNIQUE INDEX idx_subcuentas_nombre_cuenta_unico 
ON subcuentas(cuenta_id, LOWER(nombre))
WHERE activa = TRUE;

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

CREATE OR REPLACE FUNCTION actualizar_timestamp_subcuentas()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizada_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_subcuentas
    BEFORE UPDATE ON subcuentas
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_subcuentas();

-- ============ FUNCIÓN PARA CALCULAR PROGRESO ============

CREATE OR REPLACE FUNCTION calcular_progreso_subcuenta(p_subcuenta_id BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_saldo DECIMAL(15,2);
    v_meta DECIMAL(15,2);
    v_progreso NUMERIC;
BEGIN
    SELECT saldo_actual, monto_meta 
    INTO v_saldo, v_meta
    FROM subcuentas 
    WHERE subcuenta_id = p_subcuenta_id;
    
    IF v_meta IS NULL OR v_meta = 0 THEN
        RETURN NULL;
    END IF;
    
    v_progreso := (v_saldo / v_meta) * 100;
    RETURN ROUND(v_progreso, 2);
END;
$$ LANGUAGE plpgsql;

-- ============ VISTA DE SUBCUENTAS CON PROGRESO ============

CREATE VIEW vista_subcuentas_progreso AS
SELECT 
    s.subcuenta_id,
    s.cuenta_id,
    c.nombre AS cuenta_nombre,
    c.usuario_id,
    s.nombre,
    s.descripcion,
    s.saldo_actual,
    s.monto_meta,
    CASE 
        WHEN s.monto_meta IS NOT NULL AND s.monto_meta > 0 
        THEN ROUND((s.saldo_actual / s.monto_meta) * 100, 2)
        ELSE NULL 
    END AS porcentaje_progreso,
    CASE 
        WHEN s.monto_meta IS NOT NULL 
        THEN s.monto_meta - s.saldo_actual
        ELSE NULL 
    END AS monto_faltante,
    CASE 
        WHEN s.monto_meta IS NOT NULL AND s.saldo_actual >= s.monto_meta 
        THEN TRUE
        ELSE FALSE 
    END AS meta_alcanzada,
    s.activa,
    s.color_hex,
    s.icono,
    s.creada_en,
    s.actualizada_en
FROM subcuentas s
INNER JOIN cuentas c ON s.cuenta_id = c.cuenta_id;

-- ============ COMENTARIOS ============
COMMENT ON TABLE subcuentas IS 'Subcuentas para organizar fondos específicos dentro de cuentas principales';
COMMENT ON COLUMN subcuentas.subcuenta_id IS 'Identificador único de la subcuenta';
COMMENT ON COLUMN subcuentas.cuenta_id IS 'Cuenta principal a la que pertenece';
COMMENT ON COLUMN subcuentas.nombre IS 'Nombre descriptivo (ej: "Vacaciones", "Emergencias")';
COMMENT ON COLUMN subcuentas.descripcion IS 'Descripción detallada del propósito';
COMMENT ON COLUMN subcuentas.monto_meta IS 'Meta de ahorro (opcional)';
COMMENT ON COLUMN subcuentas.saldo_actual IS 'Saldo actual asignado a esta subcuenta';
COMMENT ON COLUMN subcuentas.activa IS 'Subcuenta habilitada';

-- ============ DATOS DE EJEMPLO ============
/*
-- Subcuentas para cuenta ID 1 (Cuenta Corriente)
INSERT INTO subcuentas (cuenta_id, nombre, descripcion, monto_meta, saldo_actual, color_hex, icono, orden_mostrar) VALUES
(1, 'Fondo de Emergencia', 'Ahorro para emergencias (3-6 meses)', 30000.00, 10000.00, '#EF4444', 'shield', 10),
(1, 'Vacaciones 2026', 'Viaje familiar verano', 15000.00, 5000.00, '#3B82F6', 'plane', 20),
(1, 'Gastos Hogar', 'Presupuesto mensual casa', NULL, 8000.00, '#10B981', 'home', 30);
*/