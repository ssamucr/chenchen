-- =====================================================
-- TABLA: movimientos_deuda
-- Descripción: Movimientos de deudas (cargos, pagos, ajustes)
-- Dependencias: deudas, transacciones
-- =====================================================

CREATE TABLE movimientos_deuda (
    -- ============ CLAVE PRIMARIA ============
    movimiento_deuda_id BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    deuda_id            BIGINT NOT NULL,
    transaccion_id      BIGINT NOT NULL,
    
    -- ============ DATOS PRINCIPALES ============
    fecha               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tipo                VARCHAR(30) NOT NULL,
    monto               DECIMAL(15,2) NOT NULL,
    descripcion         TEXT,
    
    -- ============ INFORMACIÓN ADICIONAL ============
    interes_generado    DECIMAL(15,2) DEFAULT 0,
    capital_pagado      DECIMAL(15,2),
    interes_pagado      DECIMAL(15,2),
    
    -- ============ AUDITORIA ============
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_mov_deuda 
        FOREIGN KEY (deuda_id) 
        REFERENCES deudas(deuda_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_mov_deuda_trans 
        FOREIGN KEY (transaccion_id) 
        REFERENCES transacciones(transaccion_id) 
        ON DELETE RESTRICT,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Tipos válidos de movimiento
    CONSTRAINT check_tipo_movimiento_valido 
        CHECK (tipo IN (
            'CARGO',        -- Nuevo cargo a la deuda
            'PAGO',         -- Pago hacia la deuda
            'AJUSTE',       -- Ajuste manual
            'INTERES',      -- Cargo por intereses
            'REFINANCIACION' -- Refinanciación de deuda
        )),
    
    -- ✅ Monto positivo
    CONSTRAINT check_monto_positivo 
        CHECK (monto > 0),
    
    -- ✅ Interés generado no negativo
    CONSTRAINT check_interes_no_negativo 
        CHECK (interes_generado >= 0),
    
    -- ✅ Desglose de pago coherente
    CONSTRAINT check_desglose_pago_coherente 
        CHECK (
            tipo != 'PAGO' 
            OR (
                capital_pagado IS NOT NULL 
                AND interes_pagado IS NOT NULL 
                AND (capital_pagado + interes_pagado) = monto
            )
        )
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por deuda
CREATE INDEX idx_mov_deuda_deuda 
ON movimientos_deuda(deuda_id, fecha DESC);

-- Búsquedas por transacción
CREATE INDEX idx_mov_deuda_transaccion 
ON movimientos_deuda(transaccion_id);

-- Búsquedas por tipo
CREATE INDEX idx_mov_deuda_tipo 
ON movimientos_deuda(tipo, fecha DESC);

-- Búsquedas por fecha
CREATE INDEX idx_mov_deuda_fecha 
ON movimientos_deuda(fecha DESC);

-- ============ TRIGGER PARA ACTUALIZAR SALDO DE DEUDA ============

CREATE OR REPLACE FUNCTION actualizar_saldo_deuda_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_monto_ajuste DECIMAL(15,2);
    v_monto_reversion DECIMAL(15,2);
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Determinar ajuste según tipo de movimiento
        IF NEW.tipo IN ('CARGO', 'INTERES') THEN
            v_monto_ajuste := NEW.monto;
        ELSIF NEW.tipo = 'PAGO' THEN
            v_monto_ajuste := -NEW.monto;
        ELSIF NEW.tipo IN ('AJUSTE', 'REFINANCIACION') THEN
            v_monto_ajuste := NEW.monto;
        END IF;
        
        -- Actualizar saldo de la deuda
        UPDATE deudas 
        SET 
            saldo_actual = saldo_actual + v_monto_ajuste,
            cuotas_pagadas = CASE 
                WHEN NEW.tipo = 'PAGO' AND monto_cuota IS NOT NULL AND monto_cuota > 0
                THEN cuotas_pagadas + 1
                ELSE cuotas_pagadas
            END,
            ultimo_pago = CASE 
                WHEN NEW.tipo = 'PAGO' 
                THEN NEW.fecha
                ELSE ultimo_pago
            END
        WHERE deuda_id = NEW.deuda_id;
        
    ELSIF TG_OP = 'UPDATE' THEN
        -- Revertir el movimiento anterior
        IF OLD.tipo IN ('CARGO', 'INTERES') THEN
            v_monto_reversion := -OLD.monto;
        ELSIF OLD.tipo = 'PAGO' THEN
            v_monto_reversion := OLD.monto;
        ELSIF OLD.tipo IN ('AJUSTE', 'REFINANCIACION') THEN
            v_monto_reversion := -OLD.monto;
        END IF;
        
        -- Aplicar el nuevo movimiento
        IF NEW.tipo IN ('CARGO', 'INTERES') THEN
            v_monto_ajuste := NEW.monto;
        ELSIF NEW.tipo = 'PAGO' THEN
            v_monto_ajuste := -NEW.monto;
        ELSIF NEW.tipo IN ('AJUSTE', 'REFINANCIACION') THEN
            v_monto_ajuste := NEW.monto;
        END IF;
        
        -- Actualizar saldo con la diferencia
        UPDATE deudas 
        SET 
            saldo_actual = saldo_actual + v_monto_reversion + v_monto_ajuste,
            cuotas_pagadas = CASE 
                WHEN OLD.tipo = 'PAGO' AND cuotas_pagadas > 0 THEN cuotas_pagadas - 1
                ELSE cuotas_pagadas
            END + CASE 
                WHEN NEW.tipo = 'PAGO' AND monto_cuota IS NOT NULL AND monto_cuota > 0 THEN 1
                ELSE 0
            END,
            ultimo_pago = CASE 
                WHEN NEW.tipo = 'PAGO' THEN NEW.fecha
                ELSE ultimo_pago
            END
        WHERE deuda_id = NEW.deuda_id;
        
    ELSIF TG_OP = 'DELETE' THEN
        -- Revertir el movimiento
        IF OLD.tipo IN ('CARGO', 'INTERES') THEN
            v_monto_reversion := -OLD.monto;
        ELSIF OLD.tipo = 'PAGO' THEN
            v_monto_reversion := OLD.monto;
        ELSIF OLD.tipo IN ('AJUSTE', 'REFINANCIACION') THEN
            v_monto_reversion := -OLD.monto;
        END IF;
        
        UPDATE deudas 
        SET 
            saldo_actual = saldo_actual + v_monto_reversion,
            cuotas_pagadas = CASE 
                WHEN OLD.tipo = 'PAGO' AND cuotas_pagadas > 0
                THEN cuotas_pagadas - 1
                ELSE cuotas_pagadas
            END
        WHERE deuda_id = OLD.deuda_id;
        
        RETURN OLD;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_saldo_deuda
    AFTER INSERT OR UPDATE OR DELETE ON movimientos_deuda
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_saldo_deuda_trigger();

-- ============ VISTA DE MOVIMIENTOS CON DETALLES ============

CREATE VIEW vista_movimientos_deuda_detalle AS
SELECT 
    md.movimiento_deuda_id,
    md.deuda_id,
    d.tipo AS tipo_deuda,
    COALESCE(d.acreedor, d.deudor) AS contraparte,
    d.descripcion AS descripcion_deuda,
    md.transaccion_id,
    md.fecha,
    md.tipo AS tipo_movimiento,
    md.monto,
    md.capital_pagado,
    md.interes_pagado,
    md.interes_generado,
    md.descripcion,
    d.saldo_actual AS saldo_deuda_actual,
    d.estado AS estado_deuda,
    md.creado_en
FROM movimientos_deuda md
INNER JOIN deudas d ON md.deuda_id = d.deuda_id
ORDER BY md.fecha DESC;

-- ============ FUNCIÓN PARA CALCULAR PRÓXIMO PAGO ============

CREATE OR REPLACE FUNCTION calcular_proximo_pago_deuda(
    p_deuda_id BIGINT,
    p_monto_pago DECIMAL(15,2)
)
RETURNS TABLE (
    capital_a_pagar DECIMAL,
    interes_a_pagar DECIMAL,
    total_a_pagar DECIMAL,
    saldo_restante DECIMAL
) AS $$
DECLARE
    v_saldo_actual DECIMAL(15,2);
    v_tasa_mensual DECIMAL(10,6);
    v_interes_periodo DECIMAL(15,2);
    v_capital_pago DECIMAL(15,2);
BEGIN
    -- Obtener datos de la deuda
    SELECT 
        d.saldo_actual,
        COALESCE(d.tasa_interes, 0) / 12 / 100
    INTO v_saldo_actual, v_tasa_mensual
    FROM deudas d
    WHERE d.deuda_id = p_deuda_id;
    
    -- Calcular interés del período
    v_interes_periodo := v_saldo_actual * v_tasa_mensual;
    
    -- Calcular cuánto va a capital
    v_capital_pago := p_monto_pago - v_interes_periodo;
    
    -- Asegurar que no pague más del saldo
    IF v_capital_pago > v_saldo_actual THEN
        v_capital_pago := v_saldo_actual;
        p_monto_pago := v_capital_pago + v_interes_periodo;
    END IF;
    
    RETURN QUERY
    SELECT 
        v_capital_pago,
        v_interes_periodo,
        p_monto_pago,
        v_saldo_actual - v_capital_pago;
END;
$$ LANGUAGE plpgsql;

-- ============ FUNCIÓN PARA RESUMEN DE MOVIMIENTOS ============

CREATE OR REPLACE FUNCTION resumen_movimientos_deuda(
    p_deuda_id BIGINT,
    p_fecha_desde TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
    p_fecha_hasta TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (
    tipo_movimiento VARCHAR,
    cantidad_movimientos BIGINT,
    monto_total DECIMAL,
    total_capital DECIMAL,
    total_interes DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        md.tipo,
        COUNT(*)::BIGINT,
        SUM(md.monto),
        SUM(COALESCE(md.capital_pagado, 0)),
        SUM(COALESCE(md.interes_pagado, 0))
    FROM movimientos_deuda md
    WHERE md.deuda_id = p_deuda_id
        AND md.fecha BETWEEN p_fecha_desde AND p_fecha_hasta
    GROUP BY md.tipo
    ORDER BY md.tipo;
END;
$$ LANGUAGE plpgsql;

-- ============ COMENTARIOS ============
COMMENT ON TABLE movimientos_deuda IS 'Registro de movimientos de deudas (cargos, pagos, ajustes)';
COMMENT ON COLUMN movimientos_deuda.movimiento_deuda_id IS 'Identificador único del movimiento';
COMMENT ON COLUMN movimientos_deuda.deuda_id IS 'Deuda afectada';
COMMENT ON COLUMN movimientos_deuda.transaccion_id IS 'Transacción asociada';
COMMENT ON COLUMN movimientos_deuda.fecha IS 'Fecha y hora del movimiento';
COMMENT ON COLUMN movimientos_deuda.tipo IS 'Tipo: CARGO, PAGO, AJUSTE, INTERES, REFINANCIACION';
COMMENT ON COLUMN movimientos_deuda.monto IS 'Monto total del movimiento';
COMMENT ON COLUMN movimientos_deuda.capital_pagado IS 'Porción que va a capital (solo para pagos)';
COMMENT ON COLUMN movimientos_deuda.interes_pagado IS 'Porción que va a intereses (solo para pagos)';
COMMENT ON COLUMN movimientos_deuda.interes_generado IS 'Interés generado en este período';

-- ============ DATOS DE EJEMPLO ============
/*
-- Ejemplos de movimientos de deuda (requiere deudas y transacciones existentes)
INSERT INTO movimientos_deuda (deuda_id, transaccion_id, tipo, monto, capital_pagado, interes_pagado, descripcion) VALUES
(1, 10, 'PAGO', 1500.00, 1250.00, 250.00, 'Pago mensual tarjeta BBVA'),
(1, 11, 'CARGO', 500.00, NULL, NULL, 'Compra en Amazon'),
(2, 12, 'PAGO', 2500.00, 2200.00, 300.00, 'Cuota préstamo personal');
*/