-- =====================================================
-- TABLA: deudas
-- Descripción: Gestión de deudas (tarjetas, préstamos, cuentas por cobrar)
-- Dependencias: usuarios, subcuentas
-- =====================================================

CREATE TABLE deudas (
    -- ============ CLAVE PRIMARIA ============
    deuda_id            BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    usuario_id          BIGINT NOT NULL,
    cuenta_id           BIGINT,
    subcuenta_id        BIGINT,
    
    -- ============ DATOS PRINCIPALES ============
    tipo                VARCHAR(30) NOT NULL,
    acreedor            VARCHAR(150),
    deudor              VARCHAR(150),
    descripcion         TEXT,
    
    -- ============ MONTOS ============
    saldo_inicial       DECIMAL(15,2) NOT NULL,
    saldo_actual        DECIMAL(15,2) NOT NULL,
    
    -- ============ INFORMACIÓN DE PAGO ============
    monto_cuota         DECIMAL(15,2),
    frecuencia_pago     VARCHAR(30),
    dia_pago            INTEGER,
    tasa_interes        DECIMAL(5,2),
    numero_cuotas       INTEGER,
    cuotas_pagadas      INTEGER DEFAULT 0,
    
    -- ============ FECHAS ============
    fecha_inicio        DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_vencimiento   DATE,
    proximo_pago        DATE,
    
    -- ============ ESTADO ============
    estado              VARCHAR(20) NOT NULL DEFAULT 'ACTIVA',
    prioridad           VARCHAR(20) DEFAULT 'MEDIA',
    
    -- ============ CONFIGURACIÓN ============
    color_hex           CHAR(7) NOT NULL DEFAULT '#EF4444',
    icono               VARCHAR(50),
    
    -- ============ AUDITORIA ============
    creada_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizada_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ultimo_pago         TIMESTAMPTZ,
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_deuda_usuario 
        FOREIGN KEY (usuario_id) 
        REFERENCES usuarios(usuario_id) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk_deuda_cuenta 
        FOREIGN KEY (cuenta_id) 
        REFERENCES cuentas(cuenta_id) 
        ON DELETE SET NULL,
    
    CONSTRAINT fk_deuda_subcuenta 
        FOREIGN KEY (subcuenta_id) 
        REFERENCES subcuentas(subcuenta_id) 
        ON DELETE SET NULL,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Tipos válidos de deuda
    CONSTRAINT check_tipo_deuda_valido 
        CHECK (tipo IN (
            'TARJETA',      -- Deuda de tarjeta de crédito
            'PRESTAMO',     -- Préstamo bancario/personal
            'HIPOTECA',     -- Préstamo hipotecario
            'AUTO',         -- Préstamo automotriz
            'POR_PAGAR',    -- Cuenta por pagar
            'POR_COBRAR',   -- Cuenta por cobrar (deuda a favor)
            'OTRO'
        )),
    
    -- ✅ Estados válidos
    CONSTRAINT check_estado_valido 
        CHECK (estado IN (
            'ACTIVA',
            'PAGADA',
            'VENCIDA',
            'REFINANCIADA',
            'CANCELADA'
        )),
    
    -- ✅ Prioridades válidas
    CONSTRAINT check_prioridad_valida 
        CHECK (prioridad IN ('ALTA', 'MEDIA', 'BAJA')),
    
    -- ✅ Frecuencias válidas
    CONSTRAINT check_frecuencia_valida 
        CHECK (frecuencia_pago IS NULL OR frecuencia_pago IN (
            'SEMANAL',
            'QUINCENAL',
            'MENSUAL',
            'BIMESTRAL',
            'TRIMESTRAL',
            'SEMESTRAL',
            'ANUAL'
        )),
    
    -- ✅ Saldo inicial y actual positivos (o negativos para por_cobrar)
    CONSTRAINT check_saldos_coherentes 
        CHECK (
            (tipo = 'POR_COBRAR' AND saldo_inicial < 0 AND saldo_actual <= saldo_inicial)
            OR
            (tipo != 'POR_COBRAR' AND saldo_inicial > 0 AND saldo_actual >= 0 AND saldo_actual <= saldo_inicial)
        ),
    
    -- ✅ Día de pago válido
    CONSTRAINT check_dia_pago_valido 
        CHECK (dia_pago IS NULL OR (dia_pago BETWEEN 1 AND 31)),
    
    -- ✅ Tasa de interés válida
    CONSTRAINT check_tasa_interes_valida 
        CHECK (tasa_interes IS NULL OR (tasa_interes BETWEEN 0 AND 100)),
    
    -- ✅ Número de cuotas válido
    CONSTRAINT check_numero_cuotas_valido 
        CHECK (numero_cuotas IS NULL OR numero_cuotas > 0),
    
    -- ✅ Cuotas pagadas no puede exceder número de cuotas
    CONSTRAINT check_cuotas_pagadas_validas 
        CHECK (
            numero_cuotas IS NULL 
            OR cuotas_pagadas <= numero_cuotas
        ),
    
    -- ✅ Color hexadecimal válido
    CONSTRAINT check_color_hex_valido 
        CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    
    -- ✅ Acreedor o deudor según tipo
    CONSTRAINT check_acreedor_deudor_logico 
        CHECK (
            (tipo IN ('TARJETA', 'PRESTAMO', 'HIPOTECA', 'AUTO', 'POR_PAGAR') AND acreedor IS NOT NULL)
            OR
            (tipo = 'POR_COBRAR' AND deudor IS NOT NULL)
            OR
            (tipo = 'OTRO')
        )
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por usuario
CREATE INDEX idx_deudas_usuario 
ON deudas(usuario_id, estado);

-- Búsquedas por tipo y estado
CREATE INDEX idx_deudas_tipo_estado 
ON deudas(tipo, estado);

-- Búsquedas por estado y prioridad
CREATE INDEX idx_deudas_estado_prioridad 
ON deudas(estado, prioridad) 
WHERE estado = 'ACTIVA';

-- Próximos pagos
CREATE INDEX idx_deudas_proximo_pago 
ON deudas(proximo_pago) 
WHERE estado = 'ACTIVA' AND proximo_pago IS NOT NULL;

-- Búsquedas por subcuenta
CREATE INDEX idx_deudas_subcuenta 
ON deudas(subcuenta_id) 
WHERE subcuenta_id IS NOT NULL;

-- Búsqueda de texto
CREATE INDEX idx_deudas_texto 
ON deudas USING gin(to_tsvector('spanish', 
    COALESCE(acreedor, '') || ' ' || 
    COALESCE(deudor, '') || ' ' || 
    COALESCE(descripcion, '')
));

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

CREATE OR REPLACE FUNCTION actualizar_timestamp_deudas()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizada_en = NOW();
    
    -- Actualizar estado automáticamente
    IF NEW.saldo_actual <= 0 AND OLD.estado = 'ACTIVA' THEN
        NEW.estado = 'PAGADA';
    END IF;
    
    -- Actualizar próximo pago si se pagó una cuota
    IF NEW.cuotas_pagadas > OLD.cuotas_pagadas AND NEW.frecuencia_pago IS NOT NULL THEN
        NEW.proximo_pago = CASE NEW.frecuencia_pago
            WHEN 'SEMANAL' THEN NEW.proximo_pago + INTERVAL '7 days'
            WHEN 'QUINCENAL' THEN NEW.proximo_pago + INTERVAL '15 days'
            WHEN 'MENSUAL' THEN NEW.proximo_pago + INTERVAL '1 month'
            WHEN 'BIMESTRAL' THEN NEW.proximo_pago + INTERVAL '2 months'
            WHEN 'TRIMESTRAL' THEN NEW.proximo_pago + INTERVAL '3 months'
            WHEN 'SEMESTRAL' THEN NEW.proximo_pago + INTERVAL '6 months'
            WHEN 'ANUAL' THEN NEW.proximo_pago + INTERVAL '1 year'
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_deudas
    BEFORE UPDATE ON deudas
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_deudas();

-- ============ VISTA DE DEUDAS CON PROGRESO ============

CREATE VIEW vista_deudas_progreso AS
SELECT 
    d.deuda_id,
    d.usuario_id,
    u.nombre || ' ' || u.apellido AS usuario_nombre,
    d.tipo,
    COALESCE(d.acreedor, d.deudor) AS contraparte,
    d.descripcion,
    d.saldo_inicial,
    d.saldo_actual,
    d.saldo_inicial - d.saldo_actual AS monto_pagado,
    ROUND(((d.saldo_inicial - d.saldo_actual) / d.saldo_inicial) * 100, 2) AS porcentaje_pagado,
    d.monto_cuota,
    d.frecuencia_pago,
    d.numero_cuotas,
    d.cuotas_pagadas,
    CASE 
        WHEN d.numero_cuotas IS NOT NULL 
        THEN d.numero_cuotas - d.cuotas_pagadas
        ELSE NULL 
    END AS cuotas_pendientes,
    d.tasa_interes,
    d.proximo_pago,
    CASE 
        WHEN d.proximo_pago IS NOT NULL 
        THEN d.proximo_pago - CURRENT_DATE
        ELSE NULL 
    END AS dias_hasta_pago,
    d.estado,
    d.prioridad,
    d.color_hex,
    d.creada_en,
    d.ultimo_pago
FROM deudas d
INNER JOIN usuarios u ON d.usuario_id = u.usuario_id
ORDER BY 
    CASE d.prioridad 
        WHEN 'ALTA' THEN 1 
        WHEN 'MEDIA' THEN 2 
        WHEN 'BAJA' THEN 3 
    END,
    d.proximo_pago NULLS LAST;

-- ============ COMENTARIOS ============
COMMENT ON TABLE deudas IS 'Gestión de deudas, préstamos y cuentas por cobrar';
COMMENT ON COLUMN deudas.deuda_id IS 'Identificador único de la deuda';
COMMENT ON COLUMN deudas.usuario_id IS 'Propietario de la deuda';
COMMENT ON COLUMN deudas.subcuenta_id IS 'Subcuenta asociada (opcional)';
COMMENT ON COLUMN deudas.tipo IS 'Tipo: TARJETA, PRESTAMO, HIPOTECA, AUTO, POR_PAGAR, POR_COBRAR, OTRO';
COMMENT ON COLUMN deudas.acreedor IS 'A quién se le debe (banco, persona, empresa)';
COMMENT ON COLUMN deudas.deudor IS 'Quién debe (para cuentas por cobrar)';
COMMENT ON COLUMN deudas.saldo_inicial IS 'Monto original de la deuda';
COMMENT ON COLUMN deudas.saldo_actual IS 'Saldo pendiente de pago';
COMMENT ON COLUMN deudas.estado IS 'Estado: ACTIVA, PAGADA, VENCIDA, REFINANCIADA, CANCELADA';
COMMENT ON COLUMN deudas.prioridad IS 'Prioridad de pago: ALTA, MEDIA, BAJA';

-- ============ DATOS DE EJEMPLO ============
/*
-- Ejemplos de deudas
INSERT INTO deudas (usuario_id, tipo, acreedor, descripcion, saldo_inicial, saldo_actual, monto_cuota, frecuencia_pago, dia_pago, tasa_interes, numero_cuotas, fecha_inicio, proximo_pago, prioridad) VALUES
(1, 'TARJETA', 'BBVA México', 'Tarjeta Visa Platinum', 15000.00, 12000.00, 1500.00, 'MENSUAL', 20, 36.5, 12, '2025-01-01', '2026-02-20', 'ALTA'),
(1, 'PRESTAMO', 'Banco Santander', 'Préstamo personal', 50000.00, 40000.00, 2500.00, 'MENSUAL', 15, 18.5, 24, '2024-06-01', '2026-02-15', 'MEDIA'),
(1, 'POR_COBRAR', NULL, 'Préstamo a Juan Pérez', -5000.00, -3000.00, 1000.00, 'MENSUAL', 10, 0, 5, '2025-10-01', '2026-02-10', 'BAJA');
*/