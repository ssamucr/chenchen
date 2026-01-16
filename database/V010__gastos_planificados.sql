-- =====================================================
-- TABLA: gastos_planificados
-- Descripción: Planificación de gastos futuros asociados a subcuentas
-- Dependencias: subcuentas
-- =====================================================

CREATE TABLE gastos_planificados (
    -- ============ CLAVE PRIMARIA ============
    gasto_planificado_id BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    subcuenta_id        BIGINT NOT NULL,
    
    -- ============ DATOS PRINCIPALES ============
    descripcion         TEXT NOT NULL,
    categoria           VARCHAR(100),
    
    -- ============ MONTOS ============
    monto_total         DECIMAL(15,2) NOT NULL,
    monto_gastado       DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    
    -- ============ FECHAS ============
    fecha_creacion      DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_objetivo      DATE,
    fecha_completado    DATE,
    
    -- ============ ESTADO ============
    estado              VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    prioridad           VARCHAR(20) DEFAULT 'MEDIA',
    
    -- ============ CONFIGURACIÓN ============
    color_hex           CHAR(7) NOT NULL DEFAULT '#F59E0B',
    notas               TEXT,
    
    -- ============ AUDITORIA ============
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_gasto_subcuenta 
        FOREIGN KEY (subcuenta_id) 
        REFERENCES subcuentas(subcuenta_id) 
        ON DELETE CASCADE,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Estados válidos
    CONSTRAINT check_estado_valido 
        CHECK (estado IN (
            'PENDIENTE',
            'EN_PROGRESO',
            'COMPLETADO',
            'CANCELADO',
            'VENCIDO'
        )),
    
    -- ✅ Prioridades válidas
    CONSTRAINT check_prioridad_valida 
        CHECK (prioridad IN ('ALTA', 'MEDIA', 'BAJA')),
    
    -- ✅ Descripción no vacía
    CONSTRAINT check_descripcion_no_vacia 
        CHECK (LENGTH(TRIM(descripcion)) > 0),
    
    -- ✅ Monto total positivo
    CONSTRAINT check_monto_total_positivo 
        CHECK (monto_total > 0),
    
    -- ✅ Monto gastado no negativo
    CONSTRAINT check_monto_gastado_no_negativo 
        CHECK (monto_gastado >= 0),
    
    -- ✅ Monto gastado no excede total
    CONSTRAINT check_monto_gastado_coherente 
        CHECK (monto_gastado <= monto_total),
    
    -- ✅ Fecha completado coherente con estado
    CONSTRAINT check_fecha_completado_coherente 
        CHECK (
            (estado = 'COMPLETADO' AND fecha_completado IS NOT NULL)
            OR
            (estado != 'COMPLETADO' AND fecha_completado IS NULL)
        ),
    
    -- ✅ Color hexadecimal válido
    CONSTRAINT check_color_hex_valido 
        CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por subcuenta
CREATE INDEX idx_gastos_planificados_subcuenta 
ON gastos_planificados(subcuenta_id, estado);

-- Búsquedas por estado
CREATE INDEX idx_gastos_planificados_estado 
ON gastos_planificados(estado, prioridad);

-- Búsquedas por fecha objetivo
CREATE INDEX idx_gastos_planificados_fecha_objetivo 
ON gastos_planificados(fecha_objetivo) 
WHERE estado IN ('PENDIENTE', 'EN_PROGRESO');

-- Búsquedas por categoría
CREATE INDEX idx_gastos_planificados_categoria 
ON gastos_planificados(categoria) 
WHERE categoria IS NOT NULL;

-- Búsqueda de texto
CREATE INDEX idx_gastos_planificados_texto 
ON gastos_planificados USING gin(to_tsvector('spanish', descripcion || ' ' || COALESCE(categoria, '')));

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

CREATE OR REPLACE FUNCTION actualizar_timestamp_gastos_planificados()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizado_en = NOW();
    
    -- Actualizar estado automáticamente
    IF NEW.monto_gastado >= NEW.monto_total AND OLD.estado != 'COMPLETADO' THEN
        NEW.estado = 'COMPLETADO';
        NEW.fecha_completado = CURRENT_DATE;
    END IF;
    
    -- Marcar como en progreso si hay gasto parcial
    IF NEW.monto_gastado > 0 AND NEW.monto_gastado < NEW.monto_total AND OLD.estado = 'PENDIENTE' THEN
        NEW.estado = 'EN_PROGRESO';
    END IF;
    
    -- Marcar como vencido si pasó la fecha objetivo
    IF NEW.fecha_objetivo IS NOT NULL 
       AND NEW.fecha_objetivo < CURRENT_DATE 
       AND NEW.estado IN ('PENDIENTE', 'EN_PROGRESO') THEN
        NEW.estado = 'VENCIDO';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_gastos_planificados
    BEFORE UPDATE ON gastos_planificados
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_gastos_planificados();

-- ============ VISTA DE GASTOS CON PROGRESO ============

CREATE VIEW vista_gastos_planificados_progreso AS
SELECT 
    gp.gasto_planificado_id,
    gp.subcuenta_id,
    s.nombre AS subcuenta_nombre,
    s.cuenta_id,
    c.nombre AS cuenta_nombre,
    c.usuario_id,
    gp.descripcion,
    gp.categoria,
    gp.monto_total,
    gp.monto_gastado,
    gp.monto_total - gp.monto_gastado AS monto_pendiente,
    ROUND((gp.monto_gastado / gp.monto_total) * 100, 2) AS porcentaje_progreso,
    gp.fecha_objetivo,
    CASE 
        WHEN gp.fecha_objetivo IS NOT NULL 
        THEN gp.fecha_objetivo - CURRENT_DATE
        ELSE NULL 
    END AS dias_hasta_objetivo,
    CASE 
        WHEN gp.fecha_objetivo IS NOT NULL AND gp.fecha_objetivo < CURRENT_DATE 
        THEN TRUE
        ELSE FALSE 
    END AS esta_vencido,
    gp.estado,
    gp.prioridad,
    gp.color_hex,
    gp.fecha_creacion,
    gp.fecha_completado
FROM gastos_planificados gp
INNER JOIN subcuentas s ON gp.subcuenta_id = s.subcuenta_id
INNER JOIN cuentas c ON s.cuenta_id = c.cuenta_id
ORDER BY 
    CASE gp.prioridad 
        WHEN 'ALTA' THEN 1 
        WHEN 'MEDIA' THEN 2 
        WHEN 'BAJA' THEN 3 
    END,
    gp.fecha_objetivo NULLS LAST;

-- ============ FUNCIÓN PARA OBTENER GASTOS PRÓXIMOS ============

CREATE OR REPLACE FUNCTION gastos_proximos_vencer(
    p_usuario_id BIGINT,
    p_dias INTEGER DEFAULT 30
)
RETURNS TABLE (
    gasto_planificado_id BIGINT,
    descripcion TEXT,
    monto_total DECIMAL,
    monto_gastado DECIMAL,
    dias_restantes INTEGER,
    prioridad VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        gp.gasto_planificado_id,
        gp.descripcion,
        gp.monto_total,
        gp.monto_gastado,
        (gp.fecha_objetivo - CURRENT_DATE)::INTEGER,
        gp.prioridad
    FROM gastos_planificados gp
    INNER JOIN subcuentas s ON gp.subcuenta_id = s.subcuenta_id
    INNER JOIN cuentas c ON s.cuenta_id = c.cuenta_id
    WHERE c.usuario_id = p_usuario_id
        AND gp.estado IN ('PENDIENTE', 'EN_PROGRESO')
        AND gp.fecha_objetivo IS NOT NULL
        AND gp.fecha_objetivo BETWEEN CURRENT_DATE AND CURRENT_DATE + p_dias
    ORDER BY gp.fecha_objetivo;
END;
$$ LANGUAGE plpgsql;

-- ============ COMENTARIOS ============
COMMENT ON TABLE gastos_planificados IS 'Planificación de gastos futuros asociados a subcuentas';
COMMENT ON COLUMN gastos_planificados.gasto_planificado_id IS 'Identificador único del gasto planificado';
COMMENT ON COLUMN gastos_planificados.subcuenta_id IS 'Subcuenta de donde se tomará el dinero';
COMMENT ON COLUMN gastos_planificados.descripcion IS 'Descripción del gasto (ej: "Compra de laptop")';
COMMENT ON COLUMN gastos_planificados.categoria IS 'Categoría del gasto';
COMMENT ON COLUMN gastos_planificados.monto_total IS 'Monto total planeado';
COMMENT ON COLUMN gastos_planificados.monto_gastado IS 'Monto ya ejecutado';
COMMENT ON COLUMN gastos_planificados.fecha_objetivo IS 'Fecha límite para realizar el gasto';
COMMENT ON COLUMN gastos_planificados.estado IS 'Estado: PENDIENTE, EN_PROGRESO, COMPLETADO, CANCELADO, VENCIDO';
COMMENT ON COLUMN gastos_planificados.prioridad IS 'Prioridad: ALTA, MEDIA, BAJA';

-- ============ DATOS DE EJEMPLO ============
/*
-- Ejemplos de gastos planificados
INSERT INTO gastos_planificados (subcuenta_id, descripcion, categoria, monto_total, monto_gastado, fecha_objetivo, prioridad, color_hex) VALUES
(1, 'Compra de Laptop nueva', 'Tecnología', 25000.00, 10000.00, '2026-03-15', 'ALTA', '#3B82F6'),
(2, 'Viaje a Cancún', 'Vacaciones', 15000.00, 5000.00, '2026-07-01', 'MEDIA', '#10B981'),
(1, 'Reparación de auto', 'Mantenimiento', 8000.00, 0.00, '2026-02-28', 'ALTA', '#EF4444');
*/