-- =====================================================
-- TABLA: compromisos_recurrentes
-- Descripción: Ingresos/egresos recurrentes (salario, renta, etc.)
-- Dependencias: usuarios, cuentas
-- =====================================================

CREATE TABLE compromisos_recurrentes (
    -- ============ CLAVE PRIMARIA ============
    compromiso_id       BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    usuario_id          BIGINT NOT NULL,
    cuenta_destino_id   BIGINT,
    
    -- ============ DATOS PRINCIPALES ============
    descripcion         TEXT NOT NULL,
    tipo                VARCHAR(20) NOT NULL,
    categoria           VARCHAR(100),
    
    -- ============ MONTO Y FRECUENCIA ============
    monto               DECIMAL(15,2) NOT NULL,
    frecuencia          VARCHAR(30) NOT NULL,
    dia_pago            INTEGER,
    
    -- ============ FECHAS ============
    fecha_inicio        DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin           DATE,
    proximo_evento      DATE,
    ultimo_evento       DATE,
    
    -- ============ ESTADO ============
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    auto_generar        BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- ============ CONFIGURACIÓN ============
    color_hex           CHAR(7) NOT NULL DEFAULT '#8B5CF6',
    icono               VARCHAR(50),
    notas               TEXT,
    
    -- ============ AUDITORIA ============
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_compromiso_usuario 
        FOREIGN KEY (usuario_id) 
        REFERENCES usuarios(usuario_id) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk_compromiso_cuenta 
        FOREIGN KEY (cuenta_destino_id) 
        REFERENCES cuentas(cuenta_id) 
        ON DELETE SET NULL,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Tipos válidos
    CONSTRAINT check_tipo_valido 
        CHECK (tipo IN ('INGRESO', 'EGRESO')),
    
    -- ✅ Frecuencias válidas
    CONSTRAINT check_frecuencia_valida 
        CHECK (frecuencia IN (
            'DIARIA',
            'SEMANAL',
            'QUINCENAL',
            'MENSUAL',
            'BIMESTRAL',
            'TRIMESTRAL',
            'SEMESTRAL',
            'ANUAL'
        )),
    
    -- ✅ Descripción no vacía
    CONSTRAINT check_descripcion_no_vacia 
        CHECK (LENGTH(TRIM(descripcion)) > 0),
    
    -- ✅ Monto positivo
    CONSTRAINT check_monto_positivo 
        CHECK (monto > 0),
    
    -- ✅ Día de pago válido
    CONSTRAINT check_dia_pago_valido 
        CHECK (dia_pago IS NULL OR (dia_pago BETWEEN 1 AND 31)),
    
    -- ✅ Fecha fin posterior a inicio
    CONSTRAINT check_fecha_fin_posterior 
        CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio),
    
    -- ✅ Color hexadecimal válido
    CONSTRAINT check_color_hex_valido 
        CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por usuario
CREATE INDEX idx_compromisos_usuario 
ON compromisos_recurrentes(usuario_id, activo);

-- Búsquedas por tipo
CREATE INDEX idx_compromisos_tipo 
ON compromisos_recurrentes(tipo, activo) 
WHERE activo = TRUE;

-- Próximos eventos
CREATE INDEX idx_compromisos_proximo_evento 
ON compromisos_recurrentes(proximo_evento) 
WHERE activo = TRUE AND proximo_evento IS NOT NULL;

-- Búsquedas por frecuencia
CREATE INDEX idx_compromisos_frecuencia 
ON compromisos_recurrentes(frecuencia) 
WHERE activo = TRUE;

-- Auto-generables
CREATE INDEX idx_compromisos_auto_generar 
ON compromisos_recurrentes(auto_generar, proximo_evento) 
WHERE auto_generar = TRUE AND activo = TRUE;

-- Búsqueda de texto
CREATE INDEX idx_compromisos_texto 
ON compromisos_recurrentes USING gin(to_tsvector('spanish', descripcion || ' ' || COALESCE(categoria, '')));

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

CREATE OR REPLACE FUNCTION actualizar_timestamp_compromisos()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizado_en = NOW();
    
    -- Desactivar si pasó la fecha fin
    IF NEW.fecha_fin IS NOT NULL AND NEW.fecha_fin < CURRENT_DATE THEN
        NEW.activo = FALSE;
    END IF;
    
    -- Calcular próximo evento si no existe
    IF NEW.proximo_evento IS NULL AND NEW.activo = TRUE THEN
        NEW.proximo_evento = CASE NEW.frecuencia
            WHEN 'DIARIA' THEN CURRENT_DATE + INTERVAL '1 day'
            WHEN 'SEMANAL' THEN CURRENT_DATE + INTERVAL '7 days'
            WHEN 'QUINCENAL' THEN CURRENT_DATE + INTERVAL '15 days'
            WHEN 'MENSUAL' THEN CURRENT_DATE + INTERVAL '1 month'
            WHEN 'BIMESTRAL' THEN CURRENT_DATE + INTERVAL '2 months'
            WHEN 'TRIMESTRAL' THEN CURRENT_DATE + INTERVAL '3 months'
            WHEN 'SEMESTRAL' THEN CURRENT_DATE + INTERVAL '6 months'
            WHEN 'ANUAL' THEN CURRENT_DATE + INTERVAL '1 year'
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_compromisos
    BEFORE UPDATE ON compromisos_recurrentes
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_compromisos();

-- ============ FUNCIÓN PARA AVANZAR AL PRÓXIMO EVENTO ============

CREATE OR REPLACE FUNCTION avanzar_proximo_evento(p_compromiso_id BIGINT)
RETURNS DATE AS $$
DECLARE
    v_frecuencia VARCHAR(30);
    v_proximo_evento DATE;
    v_nuevo_evento DATE;
BEGIN
    SELECT frecuencia, proximo_evento 
    INTO v_frecuencia, v_proximo_evento
    FROM compromisos_recurrentes
    WHERE compromiso_id = p_compromiso_id;
    
    v_nuevo_evento := CASE v_frecuencia
        WHEN 'DIARIA' THEN v_proximo_evento + INTERVAL '1 day'
        WHEN 'SEMANAL' THEN v_proximo_evento + INTERVAL '7 days'
        WHEN 'QUINCENAL' THEN v_proximo_evento + INTERVAL '15 days'
        WHEN 'MENSUAL' THEN v_proximo_evento + INTERVAL '1 month'
        WHEN 'BIMESTRAL' THEN v_proximo_evento + INTERVAL '2 months'
        WHEN 'TRIMESTRAL' THEN v_proximo_evento + INTERVAL '3 months'
        WHEN 'SEMESTRAL' THEN v_proximo_evento + INTERVAL '6 months'
        WHEN 'ANUAL' THEN v_proximo_evento + INTERVAL '1 year'
    END;
    
    UPDATE compromisos_recurrentes
    SET 
        ultimo_evento = v_proximo_evento,
        proximo_evento = v_nuevo_evento,
        actualizado_en = NOW()
    WHERE compromiso_id = p_compromiso_id;
    
    RETURN v_nuevo_evento;
END;
$$ LANGUAGE plpgsql;

-- ============ VISTA DE COMPROMISOS CON ESTADO ============

CREATE VIEW vista_compromisos_estado AS
SELECT 
    cr.compromiso_id,
    cr.usuario_id,
    u.nombre || ' ' || u.apellido AS usuario_nombre,
    cr.descripcion,
    cr.tipo,
    cr.categoria,
    cr.monto,
    cr.frecuencia,
    cr.dia_pago,
    cr.proximo_evento,
    CASE 
        WHEN cr.proximo_evento IS NOT NULL 
        THEN cr.proximo_evento - CURRENT_DATE
        ELSE NULL 
    END AS dias_hasta_proximo,
    CASE 
        WHEN cr.proximo_evento IS NOT NULL AND cr.proximo_evento <= CURRENT_DATE 
        THEN TRUE
        ELSE FALSE 
    END AS evento_pendiente,
    cr.cuenta_destino_id,
    c.nombre AS cuenta_destino_nombre,
    cr.activo,
    cr.auto_generar,
    cr.fecha_inicio,
    cr.fecha_fin,
    cr.ultimo_evento,
    cr.color_hex,
    cr.creado_en
FROM compromisos_recurrentes cr
INNER JOIN usuarios u ON cr.usuario_id = u.usuario_id
LEFT JOIN cuentas c ON cr.cuenta_destino_id = c.cuenta_id
ORDER BY cr.proximo_evento NULLS LAST;

-- ============ FUNCIÓN PARA OBTENER EVENTOS PENDIENTES ============

CREATE OR REPLACE FUNCTION eventos_compromisos_pendientes(
    p_usuario_id BIGINT,
    p_dias_adelante INTEGER DEFAULT 7
)
RETURNS TABLE (
    compromiso_id BIGINT,
    descripcion TEXT,
    tipo VARCHAR,
    monto DECIMAL,
    proximo_evento DATE,
    dias_restantes INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cr.compromiso_id,
        cr.descripcion,
        cr.tipo,
        cr.monto,
        cr.proximo_evento,
        (cr.proximo_evento - CURRENT_DATE)::INTEGER
    FROM compromisos_recurrentes cr
    WHERE cr.usuario_id = p_usuario_id
        AND cr.activo = TRUE
        AND cr.proximo_evento IS NOT NULL
        AND cr.proximo_evento BETWEEN CURRENT_DATE AND CURRENT_DATE + p_dias_adelante
    ORDER BY cr.proximo_evento;
END;
$$ LANGUAGE plpgsql;

-- ============ COMENTARIOS ============
COMMENT ON TABLE compromisos_recurrentes IS 'Ingresos y egresos recurrentes (salario, renta, servicios, etc.)';
COMMENT ON COLUMN compromisos_recurrentes.compromiso_id IS 'Identificador único del compromiso';
COMMENT ON COLUMN compromisos_recurrentes.usuario_id IS 'Propietario del compromiso';
COMMENT ON COLUMN compromisos_recurrentes.cuenta_destino_id IS 'Cuenta destino (para ingresos) u origen (para egresos)';
COMMENT ON COLUMN compromisos_recurrentes.descripcion IS 'Descripción (ej: "Salario mensual", "Renta departamento")';
COMMENT ON COLUMN compromisos_recurrentes.tipo IS 'Tipo: INGRESO, EGRESO';
COMMENT ON COLUMN compromisos_recurrentes.monto IS 'Monto del compromiso';
COMMENT ON COLUMN compromisos_recurrentes.frecuencia IS 'Frecuencia: DIARIA, SEMANAL, QUINCENAL, MENSUAL, etc.';
COMMENT ON COLUMN compromisos_recurrentes.dia_pago IS 'Día del mes de pago (1-31)';
COMMENT ON COLUMN compromisos_recurrentes.proximo_evento IS 'Fecha del próximo evento';
COMMENT ON COLUMN compromisos_recurrentes.auto_generar IS 'Generar transacción automáticamente';

-- ============ DATOS DE EJEMPLO ============
/*
-- Ejemplos de compromisos recurrentes
INSERT INTO compromisos_recurrentes (usuario_id, descripcion, tipo, categoria, monto, frecuencia, dia_pago, cuenta_destino_id, auto_generar, color_hex, icono) VALUES
(1, 'Salario Mensual', 'INGRESO', 'Salario', 25000.00, 'MENSUAL', 15, 1, TRUE, '#10B981', 'money-bill-wave'),
(1, 'Renta Departamento', 'EGRESO', 'Vivienda', 8000.00, 'MENSUAL', 1, 1, TRUE, '#EF4444', 'home'),
(1, 'Netflix', 'EGRESO', 'Entretenimiento', 299.00, 'MENSUAL', 10, 1, TRUE, '#E50914', 'tv'),
(1, 'Gym', 'EGRESO', 'Salud', 800.00, 'MENSUAL', 5, 1, FALSE, '#F59E0B', 'dumbbell');
*/