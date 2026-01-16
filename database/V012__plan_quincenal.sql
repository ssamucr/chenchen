-- =====================================================
-- TABLA: plan_quincenal
-- Descripción: Planificación de distribución quincenal de recursos
-- Dependencias: compromisos_recurrentes, cuentas, subcuentas
-- =====================================================

CREATE TABLE plan_quincenal (
    -- ============ CLAVE PRIMARIA ============
    plan_id             BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    compromiso_id       BIGINT,
    cuenta_id           BIGINT NOT NULL,
    subcuenta_id        BIGINT NOT NULL,
    
    -- ============ DATOS PRINCIPALES ============
    nombre              VARCHAR(150) NOT NULL,
    descripcion         TEXT,
    
    -- ============ MONTO ============
    monto_quincenal     DECIMAL(15,2) NOT NULL,
    monto_acumulado     DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    
    -- ============ CONFIGURACIÓN ============
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    prioridad           VARCHAR(20) DEFAULT 'MEDIA',
    orden_ejecucion     INTEGER NOT NULL DEFAULT 0,
    
    -- ============ AUDITORIA ============
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ultimo_proceso      TIMESTAMPTZ,
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_plan_compromiso 
        FOREIGN KEY (compromiso_id) 
        REFERENCES compromisos_recurrentes(compromiso_id) 
        ON DELETE SET NULL,
    
    CONSTRAINT fk_plan_cuenta 
        FOREIGN KEY (cuenta_id) 
        REFERENCES cuentas(cuenta_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_plan_subcuenta 
        FOREIGN KEY (subcuenta_id) 
        REFERENCES subcuentas(subcuenta_id) 
        ON DELETE RESTRICT,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Prioridades válidas
    CONSTRAINT check_prioridad_valida 
        CHECK (prioridad IN ('ALTA', 'MEDIA', 'BAJA')),
    
    -- ✅ Nombre no vacío
    CONSTRAINT check_nombre_no_vacio 
        CHECK (LENGTH(TRIM(nombre)) > 0),
    
    -- ✅ Monto quincenal positivo
    CONSTRAINT check_monto_quincenal_positivo 
        CHECK (monto_quincenal > 0),
    
    -- ✅ Monto acumulado no negativo
    CONSTRAINT check_monto_acumulado_no_negativo 
        CHECK (monto_acumulado >= 0),
    
    -- ✅ Subcuenta debe pertenecer a la cuenta
    CONSTRAINT check_subcuenta_pertenece_cuenta 
        CHECK (
            EXISTS (
                SELECT 1 
                FROM subcuentas s 
                WHERE s.subcuenta_id = plan_quincenal.subcuenta_id 
                AND s.cuenta_id = plan_quincenal.cuenta_id
            )
        )
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por cuenta
CREATE INDEX idx_plan_quincenal_cuenta 
ON plan_quincenal(cuenta_id, activo);

-- Búsquedas por subcuenta
CREATE INDEX idx_plan_quincenal_subcuenta 
ON plan_quincenal(subcuenta_id, activo);

-- Búsquedas por compromiso
CREATE INDEX idx_plan_quincenal_compromiso 
ON plan_quincenal(compromiso_id) 
WHERE compromiso_id IS NOT NULL;

-- Orden de ejecución
CREATE INDEX idx_plan_quincenal_orden 
ON plan_quincenal(orden_ejecucion, prioridad) 
WHERE activo = TRUE;

-- Búsqueda de texto
CREATE INDEX idx_plan_quincenal_texto 
ON plan_quincenal USING gin(to_tsvector('spanish', nombre || ' ' || COALESCE(descripcion, '')));

-- ============ CONSTRAINT DE UNICIDAD ============

-- No duplicar nombre dentro de la misma cuenta
CREATE UNIQUE INDEX idx_plan_quincenal_nombre_unico 
ON plan_quincenal(cuenta_id, LOWER(nombre))
WHERE activo = TRUE;

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

CREATE OR REPLACE FUNCTION actualizar_timestamp_plan_quincenal()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizado_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_plan_quincenal
    BEFORE UPDATE ON plan_quincenal
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_plan_quincenal();

-- ============ FUNCIÓN PARA EJECUTAR PLAN QUINCENAL ============

CREATE OR REPLACE FUNCTION ejecutar_plan_quincenal(
    p_cuenta_id BIGINT,
    p_usuario_id BIGINT
)
RETURNS TABLE (
    plan_id BIGINT,
    nombre VARCHAR,
    monto_asignado DECIMAL,
    exitoso BOOLEAN,
    mensaje TEXT
) AS $$
DECLARE
    v_plan RECORD;
    v_saldo_disponible DECIMAL(15,2);
    v_total_asignado DECIMAL(15,2) := 0;
BEGIN
    -- Obtener saldo disponible de la cuenta
    SELECT saldo_actual INTO v_saldo_disponible
    FROM cuentas
    WHERE cuenta_id = p_cuenta_id AND usuario_id = p_usuario_id;
    
    IF v_saldo_disponible IS NULL THEN
        RAISE EXCEPTION 'Cuenta no encontrada o no pertenece al usuario';
    END IF;
    
    -- Procesar cada item del plan en orden
    FOR v_plan IN 
        SELECT pq.plan_id, pq.nombre, pq.monto_quincenal, pq.subcuenta_id
        FROM plan_quincenal pq
        WHERE pq.cuenta_id = p_cuenta_id 
            AND pq.activo = TRUE
        ORDER BY pq.orden_ejecucion, pq.prioridad
    LOOP
        -- Verificar si hay saldo suficiente
        IF v_saldo_disponible >= v_plan.monto_quincenal THEN
            -- Actualizar subcuenta
            UPDATE subcuentas
            SET saldo_actual = saldo_actual + v_plan.monto_quincenal
            WHERE subcuenta_id = v_plan.subcuenta_id;
            
            -- Actualizar plan
            UPDATE plan_quincenal
            SET 
                monto_acumulado = monto_acumulado + v_plan.monto_quincenal,
                ultimo_proceso = NOW()
            WHERE plan_quincenal.plan_id = v_plan.plan_id;
            
            -- Actualizar saldo disponible
            v_saldo_disponible := v_saldo_disponible - v_plan.monto_quincenal;
            v_total_asignado := v_total_asignado + v_plan.monto_quincenal;
            
            RETURN QUERY SELECT v_plan.plan_id, v_plan.nombre, v_plan.monto_quincenal, TRUE, 'Asignado exitosamente'::TEXT;
        ELSE
            RETURN QUERY SELECT v_plan.plan_id, v_plan.nombre, v_plan.monto_quincenal, FALSE, 'Saldo insuficiente'::TEXT;
        END IF;
    END LOOP;
    
    -- Actualizar saldo de cuenta
    UPDATE cuentas
    SET saldo_actual = saldo_actual - v_total_asignado
    WHERE cuenta_id = p_cuenta_id;
    
END;
$$ LANGUAGE plpgsql;

-- ============ VISTA DE PLAN CON DETALLES ============

CREATE VIEW vista_plan_quincenal_detalle AS
SELECT 
    pq.plan_id,
    pq.cuenta_id,
    c.nombre AS cuenta_nombre,
    c.usuario_id,
    u.nombre || ' ' || u.apellido AS usuario_nombre,
    pq.subcuenta_id,
    s.nombre AS subcuenta_nombre,
    s.saldo_actual AS saldo_subcuenta,
    s.monto_meta AS meta_subcuenta,
    pq.compromiso_id,
    cr.descripcion AS compromiso_descripcion,
    pq.nombre AS plan_nombre,
    pq.descripcion AS plan_descripcion,
    pq.monto_quincenal,
    pq.monto_acumulado,
    ROUND((pq.monto_quincenal / NULLIF(c.saldo_actual, 0)) * 100, 2) AS porcentaje_cuenta,
    pq.prioridad,
    pq.orden_ejecucion,
    pq.activo,
    pq.ultimo_proceso,
    pq.creado_en
FROM plan_quincenal pq
INNER JOIN cuentas c ON pq.cuenta_id = c.cuenta_id
INNER JOIN usuarios u ON c.usuario_id = u.usuario_id
INNER JOIN subcuentas s ON pq.subcuenta_id = s.subcuenta_id
LEFT JOIN compromisos_recurrentes cr ON pq.compromiso_id = cr.compromiso_id
ORDER BY 
    c.usuario_id, 
    pq.orden_ejecucion,
    CASE pq.prioridad 
        WHEN 'ALTA' THEN 1 
        WHEN 'MEDIA' THEN 2 
        WHEN 'BAJA' THEN 3 
    END;

-- ============ FUNCIÓN PARA RESUMEN DE PLAN ============

CREATE OR REPLACE FUNCTION resumen_plan_quincenal(p_cuenta_id BIGINT)
RETURNS TABLE (
    total_planes BIGINT,
    total_monto_quincenal DECIMAL,
    total_acumulado DECIMAL,
    saldo_cuenta_actual DECIMAL,
    suficiente_para_ejecutar BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT,
        COALESCE(SUM(pq.monto_quincenal), 0),
        COALESCE(SUM(pq.monto_acumulado), 0),
        c.saldo_actual,
        c.saldo_actual >= COALESCE(SUM(pq.monto_quincenal), 0)
    FROM plan_quincenal pq
    INNER JOIN cuentas c ON pq.cuenta_id = c.cuenta_id
    WHERE pq.cuenta_id = p_cuenta_id
        AND pq.activo = TRUE
    GROUP BY c.saldo_actual;
END;
$$ LANGUAGE plpgsql;

-- ============ COMENTARIOS ============
COMMENT ON TABLE plan_quincenal IS 'Planificación de distribución quincenal de recursos entre subcuentas';
COMMENT ON COLUMN plan_quincenal.plan_id IS 'Identificador único del plan';
COMMENT ON COLUMN plan_quincenal.compromiso_id IS 'Compromiso recurrente asociado (opcional)';
COMMENT ON COLUMN plan_quincenal.cuenta_id IS 'Cuenta de donde se toman los fondos';
COMMENT ON COLUMN plan_quincenal.subcuenta_id IS 'Subcuenta destino de los fondos';
COMMENT ON COLUMN plan_quincenal.nombre IS 'Nombre del plan (ej: "Ahorro vacaciones")';
COMMENT ON COLUMN plan_quincenal.monto_quincenal IS 'Monto a asignar cada quincena';
COMMENT ON COLUMN plan_quincenal.monto_acumulado IS 'Total acumulado asignado';
COMMENT ON COLUMN plan_quincenal.prioridad IS 'Prioridad: ALTA, MEDIA, BAJA';
COMMENT ON COLUMN plan_quincenal.orden_ejecucion IS 'Orden de ejecución (menor = primero)';
COMMENT ON COLUMN plan_quincenal.ultimo_proceso IS 'Última vez que se ejecutó el plan';

-- ============ DATOS DE EJEMPLO ============
/*
-- Ejemplos de plan quincenal (requiere cuentas y subcuentas existentes)
INSERT INTO plan_quincenal (cuenta_id, subcuenta_id, nombre, descripcion, monto_quincenal, prioridad, orden_ejecucion) VALUES
(1, 1, 'Fondo de Emergencia', 'Ahorro quincenal para emergencias', 2000.00, 'ALTA', 1),
(1, 2, 'Vacaciones', 'Ahorro para viaje de verano', 1500.00, 'MEDIA', 2),
(1, 3, 'Gastos del Hogar', 'Presupuesto quincenal casa', 3000.00, 'ALTA', 3);
*/