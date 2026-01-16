-- =====================================================
-- TABLA: movimientos_subcuenta
-- Descripción: Movimientos de fondos en subcuentas
-- Dependencias: subcuentas, transacciones
-- =====================================================

CREATE TABLE movimientos_subcuenta (
    -- ============ CLAVE PRIMARIA ============
    movimiento_subcuenta_id BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    subcuenta_id        BIGINT NOT NULL,
    transaccion_id      BIGINT NOT NULL,
    
    -- ============ DATOS PRINCIPALES ============
    fecha               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tipo                VARCHAR(30) NOT NULL,
    monto               DECIMAL(15,2) NOT NULL,
    descripcion         TEXT,
    
    -- ============ AUDITORIA ============
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_mov_subcuenta 
        FOREIGN KEY (subcuenta_id) 
        REFERENCES subcuentas(subcuenta_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_mov_transaccion 
        FOREIGN KEY (transaccion_id) 
        REFERENCES transacciones(transaccion_id) 
        ON DELETE RESTRICT,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Tipos válidos de movimiento
    CONSTRAINT check_tipo_movimiento_valido 
        CHECK (tipo IN (
            'ASIGNACION',   -- Asignar fondos a subcuenta
            'GASTO',        -- Gastar desde subcuenta
            'AJUSTE',       -- Ajuste manual
            'TRANSFERENCIA' -- Mover entre subcuentas
        )),
    
    -- ✅ Monto positivo
    CONSTRAINT check_monto_positivo 
        CHECK (monto > 0)
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por subcuenta
CREATE INDEX idx_mov_subcuenta_subcuenta 
ON movimientos_subcuenta(subcuenta_id, fecha DESC);

-- Búsquedas por transacción
CREATE INDEX idx_mov_subcuenta_transaccion 
ON movimientos_subcuenta(transaccion_id);

-- Búsquedas por tipo y fecha
CREATE INDEX idx_mov_subcuenta_tipo_fecha 
ON movimientos_subcuenta(tipo, fecha DESC);

-- Búsquedas por rango de fechas
CREATE INDEX idx_mov_subcuenta_fecha 
ON movimientos_subcuenta(fecha DESC);

-- ============ TRIGGER PARA ACTUALIZAR SALDO DE SUBCUENTA ============

CREATE OR REPLACE FUNCTION actualizar_saldo_subcuenta_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_monto_ajuste DECIMAL(15,2);
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Determinar si suma o resta según el tipo
        IF NEW.tipo IN ('ASIGNACION') THEN
            v_monto_ajuste := NEW.monto;
        ELSIF NEW.tipo IN ('GASTO') THEN
            v_monto_ajuste := -NEW.monto;
        ELSIF NEW.tipo IN ('AJUSTE') THEN
            -- Para ajustes, el monto ya viene con el signo correcto
            v_monto_ajuste := NEW.monto;
        END IF;
        
        -- Actualizar saldo de la subcuenta
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + v_monto_ajuste
        WHERE subcuenta_id = NEW.subcuenta_id;
        
    ELSIF TG_OP = 'DELETE' THEN
        -- Revertir el movimiento
        IF OLD.tipo IN ('ASIGNACION') THEN
            v_monto_ajuste := -OLD.monto;
        ELSIF OLD.tipo IN ('GASTO') THEN
            v_monto_ajuste := OLD.monto;
        ELSIF OLD.tipo IN ('AJUSTE') THEN
            v_monto_ajuste := -OLD.monto;
        END IF;
        
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + v_monto_ajuste
        WHERE subcuenta_id = OLD.subcuenta_id;
        
        RETURN OLD;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_saldo_subcuenta
    AFTER INSERT OR DELETE ON movimientos_subcuenta
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_saldo_subcuenta_trigger();

-- ============ VISTA DE MOVIMIENTOS CON DETALLES ============

CREATE VIEW vista_movimientos_subcuenta_detalle AS
SELECT 
    ms.movimiento_subcuenta_id,
    ms.subcuenta_id,
    s.nombre AS subcuenta_nombre,
    s.cuenta_id,
    c.nombre AS cuenta_nombre,
    c.usuario_id,
    ms.transaccion_id,
    t.tipo AS tipo_transaccion,
    ms.fecha,
    ms.tipo AS tipo_movimiento,
    ms.monto,
    ms.descripcion,
    s.saldo_actual AS saldo_subcuenta_actual,
    s.monto_meta AS meta_subcuenta,
    ms.creado_en
FROM movimientos_subcuenta ms
INNER JOIN subcuentas s ON ms.subcuenta_id = s.subcuenta_id
INNER JOIN cuentas c ON s.cuenta_id = c.cuenta_id
INNER JOIN transacciones t ON ms.transaccion_id = t.transaccion_id
ORDER BY ms.fecha DESC;

-- ============ FUNCIÓN PARA OBTENER RESUMEN DE MOVIMIENTOS ============

CREATE OR REPLACE FUNCTION resumen_movimientos_subcuenta(
    p_subcuenta_id BIGINT,
    p_fecha_desde TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
    p_fecha_hasta TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (
    tipo_movimiento VARCHAR,
    cantidad_movimientos BIGINT,
    monto_total DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ms.tipo,
        COUNT(*)::BIGINT,
        SUM(CASE 
            WHEN ms.tipo IN ('ASIGNACION') THEN ms.monto
            WHEN ms.tipo IN ('GASTO') THEN -ms.monto
            ELSE ms.monto
        END)
    FROM movimientos_subcuenta ms
    WHERE ms.subcuenta_id = p_subcuenta_id
        AND ms.fecha BETWEEN p_fecha_desde AND p_fecha_hasta
    GROUP BY ms.tipo
    ORDER BY ms.tipo;
END;
$$ LANGUAGE plpgsql;

-- ============ COMENTARIOS ============
COMMENT ON TABLE movimientos_subcuenta IS 'Registro de movimientos de fondos en subcuentas';
COMMENT ON COLUMN movimientos_subcuenta.movimiento_subcuenta_id IS 'Identificador único del movimiento';
COMMENT ON COLUMN movimientos_subcuenta.subcuenta_id IS 'Subcuenta afectada';
COMMENT ON COLUMN movimientos_subcuenta.transaccion_id IS 'Transacción asociada';
COMMENT ON COLUMN movimientos_subcuenta.fecha IS 'Fecha y hora del movimiento';
COMMENT ON COLUMN movimientos_subcuenta.tipo IS 'Tipo: ASIGNACION, GASTO, AJUSTE, TRANSFERENCIA';
COMMENT ON COLUMN movimientos_subcuenta.monto IS 'Monto del movimiento (siempre positivo)';
COMMENT ON COLUMN movimientos_subcuenta.descripcion IS 'Descripción del movimiento';

-- ============ DATOS DE EJEMPLO ============
/*
-- Ejemplos de movimientos (requiere subcuentas y transacciones existentes)
INSERT INTO movimientos_subcuenta (subcuenta_id, transaccion_id, tipo, monto, descripcion) VALUES
(1, 1, 'ASIGNACION', 5000.00, 'Asignación mensual a fondo de emergencia'),
(1, 2, 'GASTO', 1500.00, 'Gasto médico de emergencia'),
(2, 3, 'ASIGNACION', 2000.00, 'Ahorro para vacaciones');
*/