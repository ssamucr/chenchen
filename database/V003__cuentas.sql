-- =====================================================
-- TABLA: cuentas
-- Descripción: Cuentas financieras del usuario (bancos, efectivo, etc.)
-- Dependencias: usuarios
-- =====================================================

CREATE TABLE cuentas (
    -- ============ CLAVE PRIMARIA ============
    cuenta_id           BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    usuario_id          BIGINT NOT NULL,
    
    -- ============ DATOS PRINCIPALES ============
    nombre              VARCHAR(100) NOT NULL,
    tipo_cuenta         VARCHAR(30) NOT NULL,
    institucion         VARCHAR(100),
    numero_cuenta       VARCHAR(50),
    moneda              CHAR(3) NOT NULL DEFAULT 'USD',
    
    -- ============ SALDOS ============
    saldo_inicial       DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    saldo_actual        DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    limite_credito      DECIMAL(15,2),
    
    -- ============ CONFIGURACIÓN ============
    activa              BOOLEAN NOT NULL DEFAULT TRUE,
    incluir_en_total    BOOLEAN NOT NULL DEFAULT TRUE,
    color_hex           CHAR(7) NOT NULL DEFAULT '#3B82F6',
    icono               VARCHAR(50),
    orden_mostrar       INTEGER NOT NULL DEFAULT 0,
    
    -- ============ METADATA ============
    descripcion         TEXT,
    notas               TEXT,
    
    -- ============ AUDITORIA ============
    creada_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizada_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ultimo_movimiento   TIMESTAMPTZ,
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_cuenta_usuario 
        FOREIGN KEY (usuario_id) 
        REFERENCES usuarios(usuario_id) 
        ON DELETE CASCADE,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Tipos de cuenta válidos
    CONSTRAINT check_tipo_cuenta_valido 
        CHECK (tipo_cuenta IN (
            'EFECTIVO',
            'CUENTA_CORRIENTE', 
            'CUENTA_AHORRO',
            'CUENTA_NOMINA',
            'TARJETA_CREDITO',
            'TARJETA_DEBITO',
            'INVERSION',
            'PRESTAMO',
            'WALLET_DIGITAL',
            'CRIPTOMONEDA',
            'OTRO'
        )),
    
    -- ✅ Moneda ISO válida
    CONSTRAINT check_moneda_iso 
        CHECK (moneda ~ '^[A-Z]{3}$'),
    
    -- ✅ Nombre no vacío
    CONSTRAINT check_nombre_no_vacio 
        CHECK (LENGTH(TRIM(nombre)) > 0),
    
    -- ✅ Color hexadecimal válido
    CONSTRAINT check_color_hex_valido 
        CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    
    -- ✅ Límite de crédito solo para tarjetas de crédito
    CONSTRAINT check_limite_credito_logico 
        CHECK (
            (tipo_cuenta = 'TARJETA_CREDITO' AND limite_credito >= 0)
            OR 
            (tipo_cuenta != 'TARJETA_CREDITO' AND limite_credito IS NULL)
        ),
    
    -- ✅ Saldo inicial coherente para créditos
    CONSTRAINT check_saldo_inicial_credito 
        CHECK (
            (tipo_cuenta = 'TARJETA_CREDITO' AND saldo_inicial <= 0)
            OR 
            (tipo_cuenta != 'TARJETA_CREDITO')
        )
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por usuario (más común)
CREATE INDEX idx_cuentas_usuario 
ON cuentas(usuario_id, orden_mostrar) 
WHERE activa = TRUE;

-- Búsquedas por tipo de cuenta
CREATE INDEX idx_cuentas_tipo 
ON cuentas(tipo_cuenta) 
WHERE activa = TRUE;

-- Búsquedas por moneda
CREATE INDEX idx_cuentas_moneda 
ON cuentas(moneda);

-- Búsquedas por saldo (para reportes)
CREATE INDEX idx_cuentas_saldo 
ON cuentas(saldo_actual) 
WHERE activa = TRUE AND incluir_en_total = TRUE;

-- Búsqueda de texto por nombre e institución
CREATE INDEX idx_cuentas_nombre_texto 
ON cuentas USING gin(to_tsvector('spanish', nombre || ' ' || COALESCE(institucion, '')));

-- ============ CONSTRAINT DE UNICIDAD ============

-- No duplicar nombres de cuenta para el mismo usuario
CREATE UNIQUE INDEX idx_cuentas_nombre_usuario_unico 
ON cuentas(usuario_id, LOWER(nombre))
WHERE activa = TRUE;

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

-- Función para actualizar timestamp
CREATE OR REPLACE FUNCTION actualizar_timestamp_cuentas()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizada_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger que se ejecuta en cada UPDATE
CREATE TRIGGER trigger_actualizar_cuentas
    BEFORE UPDATE ON cuentas
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_cuentas();

-- ============ FUNCIÓN PARA ACTUALIZAR SALDO ============

-- Función que será llamada cuando haya transacciones
CREATE OR REPLACE FUNCTION actualizar_saldo_cuenta(
    p_cuenta_id BIGINT,
    p_monto DECIMAL(15,2),
    p_es_ingreso BOOLEAN
)
RETURNS VOID AS $$
BEGIN
    UPDATE cuentas 
    SET 
        saldo_actual = CASE 
            WHEN p_es_ingreso THEN saldo_actual + p_monto
            ELSE saldo_actual - p_monto
        END,
        ultimo_movimiento = NOW(),
        actualizada_en = NOW()
    WHERE cuenta_id = p_cuenta_id;
    
    -- Verificar que la cuenta existe
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta con ID % no encontrada', p_cuenta_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============ VISTA PARA SALDOS CONSOLIDADOS ============

CREATE VIEW vista_saldos_usuario AS
SELECT 
    u.usuario_id,
    u.nombre || ' ' || u.apellido AS usuario_nombre,
    u.moneda_principal,
    
    -- Saldos por tipo de cuenta
    COALESCE(SUM(CASE WHEN c.tipo_cuenta = 'EFECTIVO' THEN c.saldo_actual END), 0) AS saldo_efectivo,
    COALESCE(SUM(CASE WHEN c.tipo_cuenta IN ('CUENTA_CORRIENTE', 'CUENTA_AHORRO', 'CUENTA_NOMINA') THEN c.saldo_actual END), 0) AS saldo_bancos,
    COALESCE(SUM(CASE WHEN c.tipo_cuenta = 'TARJETA_CREDITO' THEN ABS(c.saldo_actual) END), 0) AS deuda_credito,
    COALESCE(SUM(CASE WHEN c.tipo_cuenta = 'INVERSION' THEN c.saldo_actual END), 0) AS saldo_inversiones,
    
    -- Total neto (solo cuentas que se incluyen en total)
    COALESCE(SUM(CASE WHEN c.incluir_en_total = TRUE THEN c.saldo_actual END), 0) AS patrimonio_neto,
    
    -- Estadísticas generales
    COUNT(CASE WHEN c.activa = TRUE THEN 1 END) AS total_cuentas_activas,
    MAX(c.ultimo_movimiento) AS ultimo_movimiento_general
    
FROM usuarios u
LEFT JOIN cuentas c ON u.usuario_id = c.usuario_id
GROUP BY u.usuario_id, u.nombre, u.apellido, u.moneda_principal;

-- ============ COMENTARIOS ============
COMMENT ON TABLE cuentas IS 'Cuentas financieras del usuario (bancos, efectivo, tarjetas, etc.)';
COMMENT ON COLUMN cuentas.cuenta_id IS 'Identificador único de la cuenta';
COMMENT ON COLUMN cuentas.usuario_id IS 'Propietario de la cuenta';
COMMENT ON COLUMN cuentas.nombre IS 'Nombre descriptivo de la cuenta (ej: "Cuenta Corriente BBVA")';
COMMENT ON COLUMN cuentas.tipo_cuenta IS 'Tipo: EFECTIVO, CUENTA_CORRIENTE, TARJETA_CREDITO, etc.';
COMMENT ON COLUMN cuentas.institucion IS 'Banco o institución financiera (ej: "BBVA", "Banamex")';
COMMENT ON COLUMN cuentas.numero_cuenta IS 'Número de cuenta (últimos 4 dígitos por seguridad)';
COMMENT ON COLUMN cuentas.moneda IS 'Moneda de la cuenta (ISO 4217)';
COMMENT ON COLUMN cuentas.saldo_inicial IS 'Saldo al momento de registrar la cuenta';
COMMENT ON COLUMN cuentas.saldo_actual IS 'Saldo actual calculado (se actualiza con transacciones)';
COMMENT ON COLUMN cuentas.limite_credito IS 'Límite de crédito (solo para tarjetas de crédito)';
COMMENT ON COLUMN cuentas.activa IS 'Cuenta habilitada para transacciones';
COMMENT ON COLUMN cuentas.incluir_en_total IS 'Incluir en cálculo de patrimonio total';
COMMENT ON COLUMN cuentas.color_hex IS 'Color para identificar en la UI';
COMMENT ON COLUMN cuentas.icono IS 'Icono representativo (ej: "bank", "credit-card", "wallet")';
COMMENT ON COLUMN cuentas.orden_mostrar IS 'Orden para mostrar en la UI';
COMMENT ON COLUMN cuentas.ultimo_movimiento IS 'Fecha de la última transacción';

-- ============ DATOS DE EJEMPLO ============
/*
-- Cuentas de ejemplo para usuario ID 1
INSERT INTO cuentas (usuario_id, nombre, tipo_cuenta, institucion, numero_cuenta, moneda, saldo_inicial, saldo_actual, color_hex, icono, orden_mostrar) VALUES
(1, 'Efectivo', 'EFECTIVO', NULL, NULL, 'MXN', 1000.00, 1000.00, '#10B981', 'wallet', 10),
(1, 'Cuenta Corriente BBVA', 'CUENTA_CORRIENTE', 'BBVA México', '****1234', 'MXN', 5000.00, 5000.00, '#3B82F6', 'university', 20),
(1, 'Cuenta de Ahorros', 'CUENTA_AHORRO', 'Banorte', '****5678', 'MXN', 10000.00, 10000.00, '#059669', 'piggy-bank', 30),
(1, 'Tarjeta BBVA', 'TARJETA_CREDITO', 'BBVA México', '****9012', 'MXN', 0.00, -1500.00, '#EF4444', 'credit-card', 40);
*/