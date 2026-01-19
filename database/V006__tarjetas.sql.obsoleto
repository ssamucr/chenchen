-- =====================================================
-- TABLA: tarjetas
-- Descripción: Tarjetas de crédito/débito del usuario
-- Dependencias: usuarios
-- =====================================================

CREATE TABLE tarjetas (
    -- ============ CLAVE PRIMARIA ============
    tarjeta_id          BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    usuario_id          BIGINT NOT NULL,
    
    -- ============ DATOS PRINCIPALES ============
    nombre              VARCHAR(100) NOT NULL,
    banco               VARCHAR(100),
    tipo_tarjeta        VARCHAR(30) NOT NULL,
    numero_tarjeta      VARCHAR(50),
    
    -- ============ LÍMITES Y SALDOS ============
    limite_credito      DECIMAL(15,2),
    saldo_actual        DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    saldo_disponible    DECIMAL(15,2) GENERATED ALWAYS AS (
        CASE 
            WHEN tipo_tarjeta = 'CREDITO' THEN COALESCE(limite_credito, 0) - ABS(saldo_actual)
            ELSE NULL 
        END
    ) STORED,
    
    -- ============ INFORMACIÓN DE PAGO ============
    dia_corte           INTEGER,
    dia_pago            INTEGER,
    tasa_interes        DECIMAL(5,2),
    
    -- ============ CONFIGURACIÓN ============
    activa              BOOLEAN NOT NULL DEFAULT TRUE,
    color_hex           CHAR(7) NOT NULL DEFAULT '#6366F1',
    icono               VARCHAR(50),
    orden_mostrar       INTEGER NOT NULL DEFAULT 0,
    
    -- ============ METADATA ============
    notas               TEXT,
    
    -- ============ AUDITORIA ============
    creada_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizada_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ultimo_movimiento   TIMESTAMPTZ,
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_tarjeta_usuario 
        FOREIGN KEY (usuario_id) 
        REFERENCES usuarios(usuario_id) 
        ON DELETE CASCADE,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Tipos válidos de tarjeta
    CONSTRAINT check_tipo_tarjeta_valido 
        CHECK (tipo_tarjeta IN ('CREDITO', 'DEBITO', 'PREPAGO')),
    
    -- ✅ Nombre no vacío
    CONSTRAINT check_nombre_no_vacio 
        CHECK (LENGTH(TRIM(nombre)) > 0),
    
    -- ✅ Límite de crédito solo para tarjetas de crédito
    CONSTRAINT check_limite_credito_logico 
        CHECK (
            (tipo_tarjeta = 'CREDITO' AND limite_credito IS NOT NULL AND limite_credito > 0)
            OR 
            (tipo_tarjeta != 'CREDITO' AND limite_credito IS NULL)
        ),
    
    -- ✅ Saldo negativo solo para crédito
    CONSTRAINT check_saldo_segun_tipo 
        CHECK (
            (tipo_tarjeta = 'CREDITO' AND saldo_actual <= 0)
            OR 
            (tipo_tarjeta != 'CREDITO' AND saldo_actual >= 0)
        ),
    
    -- ✅ Día de corte válido (1-31)
    CONSTRAINT check_dia_corte_valido 
        CHECK (dia_corte IS NULL OR (dia_corte BETWEEN 1 AND 31)),
    
    -- ✅ Día de pago válido (1-31)
    CONSTRAINT check_dia_pago_valido 
        CHECK (dia_pago IS NULL OR (dia_pago BETWEEN 1 AND 31)),
    
    -- ✅ Tasa de interés válida (0-100%)
    CONSTRAINT check_tasa_interes_valida 
        CHECK (tasa_interes IS NULL OR (tasa_interes BETWEEN 0 AND 100)),
    
    -- ✅ Color hexadecimal válido
    CONSTRAINT check_color_hex_valido 
        CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    
    -- ✅ No exceder límite de crédito
    CONSTRAINT check_no_exceder_limite 
        CHECK (
            tipo_tarjeta != 'CREDITO' 
            OR limite_credito IS NULL 
            OR ABS(saldo_actual) <= limite_credito
        )
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por usuario
CREATE INDEX idx_tarjetas_usuario 
ON tarjetas(usuario_id, orden_mostrar) 
WHERE activa = TRUE;

-- Búsquedas por tipo de tarjeta
CREATE INDEX idx_tarjetas_tipo 
ON tarjetas(tipo_tarjeta) 
WHERE activa = TRUE;

-- Búsquedas por banco
CREATE INDEX idx_tarjetas_banco 
ON tarjetas(banco) 
WHERE activa = TRUE;

-- Tarjetas cerca del límite
CREATE INDEX idx_tarjetas_cerca_limite 
ON tarjetas(usuario_id, saldo_actual, limite_credito) 
WHERE tipo_tarjeta = 'CREDITO' AND activa = TRUE;

-- Búsqueda de texto
CREATE INDEX idx_tarjetas_nombre_texto 
ON tarjetas USING gin(to_tsvector('spanish', nombre || ' ' || COALESCE(banco, '')));

-- ============ CONSTRAINT DE UNICIDAD ============

-- No duplicar nombres de tarjeta para el mismo usuario
CREATE UNIQUE INDEX idx_tarjetas_nombre_usuario_unico 
ON tarjetas(usuario_id, LOWER(nombre))
WHERE activa = TRUE;

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

CREATE OR REPLACE FUNCTION actualizar_timestamp_tarjetas()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizada_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_tarjetas
    BEFORE UPDATE ON tarjetas
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_tarjetas();

-- ============ VISTA DE TARJETAS CON ESTADO ============

CREATE VIEW vista_tarjetas_estado AS
SELECT 
    t.tarjeta_id,
    t.usuario_id,
    u.nombre || ' ' || u.apellido AS usuario_nombre,
    t.nombre,
    t.banco,
    t.tipo_tarjeta,
    t.limite_credito,
    t.saldo_actual,
    t.saldo_disponible,
    CASE 
        WHEN t.tipo_tarjeta = 'CREDITO' AND t.limite_credito > 0 
        THEN ROUND((ABS(t.saldo_actual) / t.limite_credito) * 100, 2)
        ELSE NULL 
    END AS porcentaje_uso,
    CASE 
        WHEN t.tipo_tarjeta = 'CREDITO' AND t.limite_credito > 0 
        THEN 
            CASE 
                WHEN (ABS(t.saldo_actual) / t.limite_credito) >= 0.8 THEN 'ALTO'
                WHEN (ABS(t.saldo_actual) / t.limite_credito) >= 0.5 THEN 'MEDIO'
                ELSE 'BAJO'
            END
        ELSE NULL 
    END AS nivel_uso,
    t.dia_corte,
    t.dia_pago,
    t.tasa_interes,
    t.activa,
    t.color_hex,
    t.ultimo_movimiento,
    t.creada_en
FROM tarjetas t
INNER JOIN usuarios u ON t.usuario_id = u.usuario_id;

-- ============ FUNCIÓN PARA CALCULAR DÍAS HASTA PAGO ============

CREATE OR REPLACE FUNCTION dias_hasta_pago_tarjeta(p_tarjeta_id BIGINT)
RETURNS INTEGER AS $$
DECLARE
    v_dia_pago INTEGER;
    v_dias_faltantes INTEGER;
    v_fecha_actual DATE := CURRENT_DATE;
    v_mes_actual INTEGER := EXTRACT(MONTH FROM v_fecha_actual);
    v_anio_actual INTEGER := EXTRACT(YEAR FROM v_fecha_actual);
    v_fecha_pago DATE;
BEGIN
    SELECT dia_pago INTO v_dia_pago
    FROM tarjetas 
    WHERE tarjeta_id = p_tarjeta_id;
    
    IF v_dia_pago IS NULL THEN
        RETURN NULL;
    END IF;
    
    v_fecha_pago := make_date(v_anio_actual, v_mes_actual, v_dia_pago);
    
    IF v_fecha_pago < v_fecha_actual THEN
        -- Siguiente mes
        IF v_mes_actual = 12 THEN
            v_fecha_pago := make_date(v_anio_actual + 1, 1, v_dia_pago);
        ELSE
            v_fecha_pago := make_date(v_anio_actual, v_mes_actual + 1, v_dia_pago);
        END IF;
    END IF;
    
    v_dias_faltantes := v_fecha_pago - v_fecha_actual;
    RETURN v_dias_faltantes;
END;
$$ LANGUAGE plpgsql;

-- ============ COMENTARIOS ============
COMMENT ON TABLE tarjetas IS 'Tarjetas de crédito/débito del usuario';
COMMENT ON COLUMN tarjetas.tarjeta_id IS 'Identificador único de la tarjeta';
COMMENT ON COLUMN tarjetas.usuario_id IS 'Propietario de la tarjeta';
COMMENT ON COLUMN tarjetas.nombre IS 'Nombre descriptivo (ej: "Visa Platinum BBVA")';
COMMENT ON COLUMN tarjetas.banco IS 'Institución emisora';
COMMENT ON COLUMN tarjetas.tipo_tarjeta IS 'Tipo: CREDITO, DEBITO, PREPAGO';
COMMENT ON COLUMN tarjetas.numero_tarjeta IS 'Últimos 4 dígitos (por seguridad)';
COMMENT ON COLUMN tarjetas.limite_credito IS 'Límite máximo de crédito (solo CREDITO)';
COMMENT ON COLUMN tarjetas.saldo_actual IS 'Deuda actual (negativo) o saldo (positivo)';
COMMENT ON COLUMN tarjetas.saldo_disponible IS 'Crédito disponible (calculado automáticamente)';
COMMENT ON COLUMN tarjetas.dia_corte IS 'Día del mes de corte de cuenta (1-31)';
COMMENT ON COLUMN tarjetas.dia_pago IS 'Día del mes de pago (1-31)';
COMMENT ON COLUMN tarjetas.tasa_interes IS 'Tasa de interés anual (%)';

-- ============ DATOS DE EJEMPLO ============
/*
-- Tarjetas de ejemplo para usuario ID 1
INSERT INTO tarjetas (usuario_id, nombre, banco, tipo_tarjeta, numero_tarjeta, limite_credito, saldo_actual, dia_corte, dia_pago, tasa_interes, color_hex, icono, orden_mostrar) VALUES
(1, 'Visa Platinum BBVA', 'BBVA México', 'CREDITO', '****4532', 50000.00, -15000.00, 15, 20, 36.5, '#004481', 'credit-card', 10),
(1, 'Mastercard Débito', 'Santander', 'DEBITO', '****8765', NULL, 2500.00, NULL, NULL, NULL, '#EC0000', 'credit-card', 20),
(1, 'American Express', 'American Express', 'CREDITO', '****1234', 30000.00, -5000.00, 10, 25, 42.0, '#006FCF', 'credit-card', 30);
*/