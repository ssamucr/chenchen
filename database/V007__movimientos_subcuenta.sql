-- =====================================================
-- TABLA: movimientos_subcuenta
-- Descripción: Movimientos de fondos en subcuentas
-- Dependencias: subcuentas, transacciones
-- NOTA: Los movimientos son EDITABLES y ELIMINABLES
--       Los triggers mantienen automáticamente la integridad de saldos
-- =====================================================

CREATE TABLE movimientos_subcuenta (
    -- ============ CLAVE PRIMARIA ============
    movimiento_subcuenta_id BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    subcuenta_id        BIGINT NOT NULL,  -- Subcuenta origen (o única subcuenta para otros tipos)
    subcuenta_destino_id BIGINT,          -- Solo para transferencias entre subcuentas
    transaccion_id      BIGINT,           -- Opcional: solo cuando el movimiento viene de una transacción
    
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
    
    CONSTRAINT fk_mov_subcuenta_destino 
        FOREIGN KEY (subcuenta_destino_id) 
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
        CHECK (monto > 0),
    
    -- ✅ Si es transferencia, debe tener subcuenta destino
    CONSTRAINT check_transferencia_tiene_destino
        CHECK (
            (tipo = 'TRANSFERENCIA' AND subcuenta_destino_id IS NOT NULL AND subcuenta_destino_id != subcuenta_id)
            OR (tipo != 'TRANSFERENCIA' AND subcuenta_destino_id IS NULL)
        )
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

-- ============ TRIGGERS PARA MANTENER INTEGRIDAD DE SALDOS ============

-- Trigger para INSERT: aplicar movimiento a saldos
CREATE OR REPLACE FUNCTION aplicar_movimiento_subcuenta()
RETURNS TRIGGER AS $$
BEGIN
    -- Determinar si suma o resta según el tipo
    IF NEW.tipo = 'ASIGNACION' THEN
        -- Sumar fondos a la subcuenta
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_id;
        
    ELSIF NEW.tipo = 'GASTO' THEN
        -- Restar fondos de la subcuenta
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_id;
        
    ELSIF NEW.tipo = 'AJUSTE' THEN
        -- Para ajustes, el monto ya viene con el signo correcto
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_id;
        
    ELSIF NEW.tipo = 'TRANSFERENCIA' THEN
        -- Restar de la subcuenta origen
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_id;
        
        -- Sumar a la subcuenta destino
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_destino_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_aplicar_movimiento_subcuenta
    AFTER INSERT ON movimientos_subcuenta
    FOR EACH ROW
    EXECUTE FUNCTION aplicar_movimiento_subcuenta();

-- Trigger para UPDATE: revertir movimiento anterior y aplicar nuevo
CREATE OR REPLACE FUNCTION actualizar_movimiento_subcuenta()
RETURNS TRIGGER AS $$
BEGIN
    -- Revertir el movimiento anterior
    IF OLD.tipo = 'ASIGNACION' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_id;
        
    ELSIF OLD.tipo = 'GASTO' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_id;
        
    ELSIF OLD.tipo = 'AJUSTE' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_id;
        
    ELSIF OLD.tipo = 'TRANSFERENCIA' THEN
        -- Devolver fondos a la subcuenta origen
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_id;
        
        -- Restar de la subcuenta destino
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_destino_id;
    END IF;
    
    -- Aplicar el nuevo movimiento
    IF NEW.tipo = 'ASIGNACION' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_id;
        
    ELSIF NEW.tipo = 'GASTO' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_id;
        
    ELSIF NEW.tipo = 'AJUSTE' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_id;
        
    ELSIF NEW.tipo = 'TRANSFERENCIA' THEN
        -- Restar de la subcuenta origen
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_id;
        
        -- Sumar a la subcuenta destino
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + NEW.monto
        WHERE subcuenta_id = NEW.subcuenta_destino_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_movimiento_subcuenta
    BEFORE UPDATE ON movimientos_subcuenta
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_movimiento_subcuenta();

-- Trigger para DELETE: revertir movimiento
CREATE OR REPLACE FUNCTION eliminar_movimiento_subcuenta()
RETURNS TRIGGER AS $$
BEGIN
    -- Revertir el movimiento
    IF OLD.tipo = 'ASIGNACION' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_id;
        
    ELSIF OLD.tipo = 'GASTO' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_id;
        
    ELSIF OLD.tipo = 'AJUSTE' THEN
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_id;
        
    ELSIF OLD.tipo = 'TRANSFERENCIA' THEN
        -- Devolver fondos a la subcuenta origen
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual + OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_id;
        
        -- Restar de la subcuenta destino
        UPDATE subcuentas 
        SET saldo_actual = saldo_actual - OLD.monto
        WHERE subcuenta_id = OLD.subcuenta_destino_id;
    END IF;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_eliminar_movimiento_subcuenta
    BEFORE DELETE ON movimientos_subcuenta
    FOR EACH ROW
    EXECUTE FUNCTION eliminar_movimiento_subcuenta();

-- ============ VISTA DE MOVIMIENTOS CON DETALLES ============

CREATE VIEW vista_movimientos_subcuenta_detalle AS
SELECT 
    ms.movimiento_subcuenta_id,
    ms.subcuenta_id,
    s.nombre AS subcuenta_nombre,
    ms.subcuenta_destino_id,
    sd.nombre AS subcuenta_destino_nombre,
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
LEFT JOIN subcuentas sd ON ms.subcuenta_destino_id = sd.subcuenta_id
LEFT JOIN transacciones t ON ms.transaccion_id = t.transaccion_id
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
COMMENT ON TABLE movimientos_subcuenta IS 'Registro de movimientos de fondos en subcuentas (EDITABLES y ELIMINABLES)';
COMMENT ON COLUMN movimientos_subcuenta.movimiento_subcuenta_id IS 'Identificador único del movimiento';
COMMENT ON COLUMN movimientos_subcuenta.subcuenta_id IS 'Subcuenta origen o afectada';
COMMENT ON COLUMN movimientos_subcuenta.subcuenta_destino_id IS 'Subcuenta destino (solo para transferencias)';
COMMENT ON COLUMN movimientos_subcuenta.transaccion_id IS 'Transacción asociada (opcional)';
COMMENT ON COLUMN movimientos_subcuenta.fecha IS 'Fecha y hora del movimiento';
COMMENT ON COLUMN movimientos_subcuenta.tipo IS 'Tipo: ASIGNACION, GASTO, AJUSTE, TRANSFERENCIA';
COMMENT ON COLUMN movimientos_subcuenta.monto IS 'Monto del movimiento (siempre positivo)';
COMMENT ON COLUMN movimientos_subcuenta.descripcion IS 'Descripción del movimiento';

-- ============ DATOS DE EJEMPLO ============
/*
-- ⚠️ IMPORTANTE: Los movimientos son EDITABLES y ELIMINABLES
-- Los triggers mantienen automáticamente la integridad de los saldos de las subcuentas

-- ✅ ASIGNACION con transacción asociada (cuando un gasto real se asigna a una subcuenta)
-- Ejemplo: Tienes $5000 en una cuenta y quieres asignar parte de eso a "Fondo de Emergencia"
INSERT INTO movimientos_subcuenta (subcuenta_id, transaccion_id, tipo, monto, descripcion) VALUES
(1, 1, 'ASIGNACION', 5000.00, 'Asignación mensual a fondo de emergencia');

-- ✅ GASTO con transacción asociada (cuando se gasta desde una subcuenta)
-- Ejemplo: Usas $1500 del fondo de emergencia para una consulta médica
INSERT INTO movimientos_subcuenta (subcuenta_id, transaccion_id, tipo, monto, descripcion) VALUES
(1, 2, 'GASTO', 1500.00, 'Gasto médico de emergencia');

-- ✅ AJUSTE sin transacción (movimiento interno para corrección)
-- Ejemplo: Corregir un error en el saldo
INSERT INTO movimientos_subcuenta (subcuenta_id, tipo, monto, descripcion) VALUES
(2, 'AJUSTE', 100.00, 'Corrección de saldo por error de cálculo');

-- ✅ TRANSFERENCIA entre subcuentas (movimiento interno sin transacción)
-- Ejemplo: Mover dinero de "Fondo de Emergencia" a "Vacaciones"
-- Nota: Resta de subcuenta_id (origen) y suma a subcuenta_destino_id (destino)
INSERT INTO movimientos_subcuenta (subcuenta_id, subcuenta_destino_id, tipo, monto, descripcion) VALUES
(1, 2, 'TRANSFERENCIA', 500.00, 'Mover fondos de emergencia a vacaciones');

-- ✅ EDITAR un movimiento (los saldos se ajustan automáticamente)
-- El trigger revierte el movimiento anterior y aplica el nuevo
-- Ejemplo: Cambiar el monto de una asignación de 5000 a 6000
UPDATE movimientos_subcuenta 
SET monto = 6000.00, descripcion = 'Monto actualizado después de revisión'
WHERE movimiento_subcuenta_id = 1;

-- ✅ ELIMINAR un movimiento (los saldos se revierten automáticamente)
-- El trigger revierte completamente el movimiento en la(s) subcuenta(s) afectada(s)
-- Ejemplo: Cancelar completamente una asignación
DELETE FROM movimientos_subcuenta WHERE movimiento_subcuenta_id = 1;
*/
