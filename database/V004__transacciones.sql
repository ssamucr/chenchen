-- =====================================================
-- TABLA: transacciones
-- Descripción: Registro de todas las transacciones financieras
-- Restricción especial: Al menos cuenta_origen_id O cuenta_destino_id debe existir
-- =====================================================

CREATE TABLE transacciones (
    -- ============ CLAVE PRIMARIA ============
    transaccion_id      BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    usuario_id          BIGINT NOT NULL,
    cuenta_origen_id    BIGINT NULL,        -- Puede ser NULL (ej: ingreso inicial)
    cuenta_destino_id   BIGINT NULL,        -- Puede ser NULL (ej: gasto en efectivo)
    categoria_id        BIGINT NULL,        -- Categoría para clasificar la transacción
    
    -- ============ DATOS PRINCIPALES ============
    fecha               DATE NOT NULL DEFAULT CURRENT_DATE,
    tipo                VARCHAR(20) NOT NULL,
    monto               DECIMAL(15,2) NOT NULL,
    descripcion         TEXT,
    referencia          VARCHAR(100),
    
    -- ============ AUDITORIA ============
    creada_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_transaccion_usuario 
        FOREIGN KEY (usuario_id) 
        REFERENCES usuarios(usuario_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_transaccion_cuenta_origen 
        FOREIGN KEY (cuenta_origen_id) 
        REFERENCES cuentas(cuenta_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_transaccion_cuenta_destino 
        FOREIGN KEY (cuenta_destino_id) 
        REFERENCES cuentas(cuenta_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_transaccion_categoria 
        FOREIGN KEY (categoria_id) 
        REFERENCES categorias(categoria_id) 
        ON DELETE SET NULL,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ CONSTRAINT PRINCIPAL: Al menos una cuenta debe existir
    CONSTRAINT check_al_menos_una_cuenta 
        CHECK (
            cuenta_origen_id IS NOT NULL 
            OR 
            cuenta_destino_id IS NOT NULL
        ),
    
    -- ✅ Tipos de transacción válidos
    CONSTRAINT check_tipo_valido 
        CHECK (tipo IN (
            'INGRESO',      -- Entra dinero (cuenta_destino_id requerida)
            'GASTO',        -- Sale dinero (cuenta_origen_id requerida) 
            'TRANSFERENCIA', -- Entre cuentas (ambas requeridas)
            'AJUSTE'        -- Correcciones
        )),
    
    -- ✅ Monto siempre positivo
    CONSTRAINT check_monto_positivo 
        CHECK (monto > 0),
    
    -- ✅ Lógica específica por tipo
    CONSTRAINT check_logica_transferencia 
        CHECK (
            (tipo = 'TRANSFERENCIA' AND cuenta_origen_id IS NOT NULL AND cuenta_destino_id IS NOT NULL)
            OR
            (tipo != 'TRANSFERENCIA')
        ),
    
    -- ✅ No transferir a la misma cuenta
    CONSTRAINT check_cuentas_diferentes 
        CHECK (
            cuenta_origen_id IS NULL 
            OR cuenta_destino_id IS NULL 
            OR cuenta_origen_id != cuenta_destino_id
        )
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por usuario y fecha (más común)
CREATE INDEX idx_transacciones_usuario_fecha 
ON transacciones(usuario_id, fecha DESC);

-- Búsquedas por cuenta origen
CREATE INDEX idx_transacciones_cuenta_origen 
ON transacciones(cuenta_origen_id) 
WHERE cuenta_origen_id IS NOT NULL;

-- Búsquedas por cuenta destino
CREATE INDEX idx_transacciones_cuenta_destino 
ON transacciones(cuenta_destino_id) 
WHERE cuenta_destino_id IS NOT NULL;

-- Búsquedas por tipo
CREATE INDEX idx_transacciones_tipo 
ON transacciones(tipo);

-- Búsquedas por categoría
CREATE INDEX idx_transacciones_categoria 
ON transacciones(categoria_id) 
WHERE categoria_id IS NOT NULL;

-- ============ COMENTARIOS ============
COMMENT ON TABLE transacciones IS 'Registro de todas las transacciones financieras del usuario';
COMMENT ON COLUMN transacciones.transaccion_id IS 'Identificador único de la transacción';
COMMENT ON COLUMN transacciones.usuario_id IS 'Usuario propietario de la transacción';
COMMENT ON COLUMN transacciones.cuenta_origen_id IS 'Cuenta de donde sale el dinero (NULL para ingresos externos)';
COMMENT ON COLUMN transacciones.cuenta_destino_id IS 'Cuenta a donde llega el dinero (NULL para gastos externos)';
COMMENT ON COLUMN transacciones.categoria_id IS 'Categoría para clasificar la transacción';
COMMENT ON COLUMN transacciones.tipo IS 'Tipo: INGRESO, GASTO, TRANSFERENCIA, AJUSTE';
COMMENT ON COLUMN transacciones.monto IS 'Cantidad de dinero (siempre positivo)';
COMMENT ON COLUMN transacciones.descripcion IS 'Descripción detallada de la transacción';
COMMENT ON COLUMN transacciones.referencia IS 'Referencia externa (número de factura, etc.)';

-- ============ EJEMPLOS DE USO ============
/*
-- ✅ INGRESO (solo cuenta destino)
INSERT INTO transacciones (usuario_id, cuenta_destino_id, categoria_id, tipo, monto, descripcion) 
VALUES (1, 1, (SELECT categoria_id FROM categorias WHERE nombre = 'Salario' LIMIT 1), 'INGRESO', 3000.00, 'Salario enero 2026');

-- ✅ GASTO (solo cuenta origen)
INSERT INTO transacciones (usuario_id, cuenta_origen_id, categoria_id, tipo, monto, descripcion) 
VALUES (1, 1, (SELECT categoria_id FROM categorias WHERE nombre = 'Alimentación' LIMIT 1), 'GASTO', 50.00, 'Almuerzo');

-- ✅ TRANSFERENCIA (ambas cuentas)
INSERT INTO transacciones (usuario_id, cuenta_origen_id, cuenta_destino_id, categoria_id, tipo, monto, descripcion) 
VALUES (1, 1, 2, (SELECT categoria_id FROM categorias WHERE nombre = 'Ahorro' LIMIT 1), 'TRANSFERENCIA', 500.00, 'Ahorro mensual');

-- ❌ ESTO FALLARÍA (ninguna cuenta)
INSERT INTO transacciones (usuario_id, tipo, monto, descripcion) 
VALUES (1, 'GASTO', 50.00, 'Sin cuenta'); -- ERROR: check_al_menos_una_cuenta
*/