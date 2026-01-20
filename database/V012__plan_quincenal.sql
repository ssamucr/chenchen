-- =====================================================
-- TABLA: plan_quincenal
-- Descripción: Planificación de movimientos financieros recurrentes
--              Soporta múltiples tipos: transferencias entre cuentas,
--              movimientos a subcuentas, pagos a deudas, etc.
-- Dependencias: usuarios, cuentas, subcuentas, deudas
-- =====================================================

CREATE TABLE plan_quincenal (
    -- ============ CLAVE PRIMARIA ============
    item_id             BIGSERIAL PRIMARY KEY,
    
    -- ============ RELACIONES ============
    usuario_id          BIGINT NOT NULL,
    
    -- ============ DATOS PRINCIPALES ============
    nombre              VARCHAR(150) NOT NULL,
    descripcion         TEXT,
    tipo_movimiento     VARCHAR(30) NOT NULL,
    
    -- ============ MONTO ============
    monto               DECIMAL(15,2) NOT NULL,
    
    -- ============ ORIGEN Y DESTINO (según tipo) ============
    cuenta_origen_id    BIGINT,         -- Para transferencias y pagos
    cuenta_destino_id   BIGINT,         -- Para transferencias
    subcuenta_destino_id BIGINT,        -- Para movimientos a subcuenta
    deuda_id            BIGINT,         -- Para pagos a deudas
    
    -- ============ CONFIGURACIÓN ============
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    ejecutado           BOOLEAN NOT NULL DEFAULT FALSE,
    prioridad           VARCHAR(20) DEFAULT 'MEDIA',
    orden_ejecucion     INTEGER NOT NULL DEFAULT 0,
    
    -- ============ AUDITORIA ============
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ejecutado_en        TIMESTAMPTZ,
    transaccion_generada_id BIGINT,     -- Referencia a transacción creada
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_plan_usuario 
        FOREIGN KEY (usuario_id) 
        REFERENCES usuarios(usuario_id) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk_plan_cuenta_origen 
        FOREIGN KEY (cuenta_origen_id) 
        REFERENCES cuentas(cuenta_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_plan_cuenta_destino 
        FOREIGN KEY (cuenta_destino_id) 
        REFERENCES cuentas(cuenta_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_plan_subcuenta_destino 
        FOREIGN KEY (subcuenta_destino_id) 
        REFERENCES subcuentas(subcuenta_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_plan_deuda 
        FOREIGN KEY (deuda_id) 
        REFERENCES deudas(deuda_id) 
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_plan_transaccion 
        FOREIGN KEY (transaccion_generada_id) 
        REFERENCES transacciones(transaccion_id) 
        ON DELETE SET NULL,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Tipos de movimiento válidos
    CONSTRAINT check_tipo_movimiento_valido 
        CHECK (tipo_movimiento IN (
            'TRANSFERENCIA_CUENTAS',    -- Entre cuentas propias
            'MOVIMIENTO_SUBCUENTA',     -- A subcuenta desde cuenta
            'PAGO_DEUDA'                -- Pago a deuda/tarjeta
        )),
    
    -- ✅ Prioridades válidas
    CONSTRAINT check_prioridad_valida 
        CHECK (prioridad IN ('ALTA', 'MEDIA', 'BAJA')),
    
    -- ✅ Nombre no vacío
    CONSTRAINT check_nombre_no_vacio 
        CHECK (LENGTH(TRIM(nombre)) > 0),
    
    -- ✅ Monto positivo
    CONSTRAINT check_monto_positivo 
        CHECK (monto > 0),
    
    -- ✅ Validar destinos según tipo de movimiento
    CONSTRAINT check_destinos_segun_tipo 
        CHECK (
            (tipo_movimiento = 'TRANSFERENCIA_CUENTAS' 
                AND cuenta_origen_id IS NOT NULL 
                AND cuenta_destino_id IS NOT NULL
                AND cuenta_origen_id != cuenta_destino_id)
            OR
            (tipo_movimiento = 'MOVIMIENTO_SUBCUENTA' 
                AND cuenta_origen_id IS NOT NULL 
                AND subcuenta_destino_id IS NOT NULL)
            OR
            (tipo_movimiento = 'PAGO_DEUDA' 
                AND cuenta_origen_id IS NOT NULL 
                AND deuda_id IS NOT NULL)
            OR
            (tipo_movimiento = 'AHORRO' 
                AND cuenta_origen_id IS NOT NULL 
                AND subcuenta_destino_id IS NOT NULL)
        )
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsquedas por usuario
CREATE INDEX idx_plan_usuario 
ON plan_quincenal(usuario_id, activo, ejecutado);

-- Orden de ejecución
CREATE INDEX idx_plan_orden 
ON plan_quincenal(orden_ejecucion, prioridad) 
WHERE activo = TRUE AND ejecutado = FALSE;

-- Búsquedas por tipo
CREATE INDEX idx_plan_tipo 
ON plan_quincenal(tipo_movimiento, activo);

-- Búsqueda de texto
CREATE INDEX idx_plan_texto 
ON plan_quincenal USING gin(to_tsvector('spanish', nombre || ' ' || COALESCE(descripcion, '')));

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

CREATE OR REPLACE FUNCTION actualizar_timestamp_plan()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizado_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_plan
    BEFORE UPDATE ON plan_quincenal
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_plan();

-- ============ FUNCIÓN PARA EJECUTAR UN ITEM DEL PLAN ============

CREATE OR REPLACE FUNCTION ejecutar_item_plan(
    p_item_id BIGINT,
    p_usuario_id BIGINT
)
RETURNS TABLE (
    exitoso BOOLEAN,
    mensaje TEXT,
    transaccion_id BIGINT
) AS $$
DECLARE
    v_item RECORD;
    v_transaccion_id BIGINT;
    v_saldo_origen DECIMAL(15,2);
    v_tipo_transaccion VARCHAR(20);
BEGIN
    -- Obtener el item del plan
    SELECT * INTO v_item
    FROM plan_quincenal
    WHERE item_id = p_item_id
        AND usuario_id = p_usuario_id
        AND activo = TRUE
        AND ejecutado = FALSE;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Item no encontrado, ya ejecutado o inactivo'::TEXT, NULL::BIGINT;
        RETURN;
    END IF;
    
    -- Verificar saldo suficiente en cuenta origen
    IF v_item.cuenta_origen_id IS NOT NULL THEN
        SELECT saldo_actual INTO v_saldo_origen
        FROM cuentas
        WHERE cuenta_id = v_item.cuenta_origen_id;
        
        IF v_saldo_origen < v_item.monto THEN
            RETURN QUERY SELECT FALSE, 'Saldo insuficiente en cuenta origen'::TEXT, NULL::BIGINT;
            RETURN;
        END IF;
    END IF;
    
    -- Ejecutar según el tipo de movimiento
    CASE v_item.tipo_movimiento
        
        -- ========== TRANSFERENCIA ENTRE CUENTAS ==========
        WHEN 'TRANSFERENCIA_CUENTAS' THEN
            INSERT INTO transacciones (
                usuario_id, cuenta_origen_id, cuenta_destino_id,
                tipo, monto, descripcion, fecha
            ) VALUES (
                p_usuario_id, v_item.cuenta_origen_id, v_item.cuenta_destino_id,
                'TRANSFERENCIA', v_item.monto, 
                'Plan: ' || v_item.nombre, CURRENT_DATE
            ) RETURNING transaccion_id INTO v_transaccion_id;
        
        -- ========== MOVIMIENTO A SUBCUENTA ==========
        WHEN 'MOVIMIENTO_SUBCUENTA', 'AHORRO' THEN
            -- Crear transacción de ajuste
            INSERT INTO transacciones (
                usuario_id, cuenta_origen_id,
                tipo, monto, descripcion, fecha
            ) VALUES (
                p_usuario_id, v_item.cuenta_origen_id,
                'AJUSTE', v_item.monto,
                'Plan: ' || v_item.nombre || ' (Movimiento a subcuenta)', CURRENT_DATE
            ) RETURNING transaccion_id INTO v_transaccion_id;
            
            -- Crear movimiento de subcuenta
            INSERT INTO movimientos_subcuenta (
                subcuenta_id, transaccion_id, tipo, monto, descripcion, fecha
            ) VALUES (
                v_item.subcuenta_destino_id, v_transaccion_id,
                'DEPOSITO', v_item.monto,
                'Plan: ' || v_item.nombre, CURRENT_DATE
            );
        
        -- ========== PAGO A DEUDA ==========
        WHEN 'PAGO_DEUDA' THEN
            -- Crear transacción de gasto
            INSERT INTO transacciones (
                usuario_id, cuenta_origen_id,
                tipo, monto, descripcion, fecha
            ) VALUES (
                p_usuario_id, v_item.cuenta_origen_id,
                'GASTO', v_item.monto,
                'Plan: ' || v_item.nombre || ' (Pago deuda)', CURRENT_DATE
            ) RETURNING transaccion_id INTO v_transaccion_id;
            
            -- Crear movimiento de deuda
            INSERT INTO movimientos_deuda (
                deuda_id, transaccion_id, tipo, monto, descripcion, fecha
            ) VALUES (
                v_item.deuda_id, v_transaccion_id,
                'PAGO', v_item.monto,
                'Plan: ' || v_item.nombre, CURRENT_DATE
            );
    END CASE;
    
    -- Marcar item como ejecutado
    UPDATE plan_quincenal
    SET 
        ejecutado = TRUE,
        ejecutado_en = NOW(),
        transaccion_generada_id = v_transaccion_id
    WHERE item_id = p_item_id;
    
    RETURN QUERY SELECT TRUE, 'Ejecutado exitosamente'::TEXT, v_transaccion_id;
END;
$$ LANGUAGE plpgsql;

-- ============ FUNCIÓN PARA EJECUTAR TODOS LOS ITEMS DEL PLAN ============

CREATE OR REPLACE FUNCTION ejecutar_plan_completo(
    p_usuario_id BIGINT
)
RETURNS TABLE (
    item_id BIGINT,
    nombre VARCHAR,
    exitoso BOOLEAN,
    mensaje TEXT
) AS $$
DECLARE
    v_item RECORD;
    v_resultado RECORD;
BEGIN
    -- Procesar cada item activo no ejecutado, en orden
    FOR v_item IN 
        SELECT pq.item_id, pq.nombre
        FROM plan_quincenal pq
        WHERE pq.usuario_id = p_usuario_id
            AND pq.activo = TRUE
            AND pq.ejecutado = FALSE
        ORDER BY pq.orden_ejecucion, 
                 CASE pq.prioridad 
                     WHEN 'ALTA' THEN 1 
                     WHEN 'MEDIA' THEN 2 
                     WHEN 'BAJA' THEN 3 
                 END
    LOOP
        -- Ejecutar el item
        SELECT * INTO v_resultado
        FROM ejecutar_item_plan(v_item.item_id, p_usuario_id);
        
        RETURN QUERY SELECT v_item.item_id, v_item.nombre, v_resultado.exitoso, v_resultado.mensaje;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============ FUNCIÓN PARA REINICIAR EL PLAN ============

CREATE OR REPLACE FUNCTION reiniciar_plan(
    p_usuario_id BIGINT
)
RETURNS INTEGER AS $$
DECLARE
    v_items_reiniciados INTEGER;
BEGIN
    UPDATE plan_quincenal
    SET 
        ejecutado = FALSE,
        ejecutado_en = NULL,
        transaccion_generada_id = NULL,
        actualizado_en = NOW()
    WHERE usuario_id = p_usuario_id
        AND activo = TRUE
        AND ejecutado = TRUE;
    
    GET DIAGNOSTICS v_items_reiniciados = ROW_COUNT;
    
    RETURN v_items_reiniciados;
END;
$$ LANGUAGE plpgsql;

-- ============ VISTA DE PLAN CON DETALLES ============

CREATE VIEW vista_plan_detalle AS
SELECT 
    pq.item_id,
    pq.usuario_id,
    u.nombre || ' ' || u.apellido AS usuario_nombre,
    pq.nombre AS item_nombre,
    pq.descripcion,
    pq.tipo_movimiento,
    pq.monto,
    -- Cuenta origen
    pq.cuenta_origen_id,
    co.nombre AS cuenta_origen_nombre,
    co.saldo_actual AS saldo_cuenta_origen,
    -- Cuenta destino
    pq.cuenta_destino_id,
    cd.nombre AS cuenta_destino_nombre,
    -- Subcuenta destino
    pq.subcuenta_destino_id,
    sc.nombre AS subcuenta_destino_nombre,
    sc.saldo_actual AS saldo_subcuenta,
    -- Deuda
    pq.deuda_id,
    d.descripcion AS deuda_descripcion,
    d.saldo_actual AS saldo_deuda,
    -- Estado
    pq.activo,
    pq.ejecutado,
    pq.ejecutado_en,
    pq.prioridad,
    pq.orden_ejecucion,
    pq.transaccion_generada_id,
    pq.creado_en
FROM plan_quincenal pq
INNER JOIN usuarios u ON pq.usuario_id = u.usuario_id
LEFT JOIN cuentas co ON pq.cuenta_origen_id = co.cuenta_id
LEFT JOIN cuentas cd ON pq.cuenta_destino_id = cd.cuenta_id
LEFT JOIN subcuentas sc ON pq.subcuenta_destino_id = sc.subcuenta_id
LEFT JOIN deudas d ON pq.deuda_id = d.deuda_id
ORDER BY 
    pq.orden_ejecucion,
    CASE pq.prioridad 
        WHEN 'ALTA' THEN 1 
        WHEN 'MEDIA' THEN 2 
        WHEN 'BAJA' THEN 3 
    END;

-- ============ FUNCIÓN PARA RESUMEN DE PLAN ============

CREATE OR REPLACE FUNCTION resumen_plan(
    p_usuario_id BIGINT
)
RETURNS TABLE (
    total_items BIGINT,
    items_pendientes BIGINT,
    items_ejecutados BIGINT,
    monto_total_pendiente DECIMAL,
    puede_ejecutar_todos BOOLEAN
) AS $$
DECLARE
    v_saldo_minimo_requerido DECIMAL(15,2);
    v_saldo_disponible DECIMAL(15,2);
BEGIN
    -- Calcular monto total pendiente
    SELECT COALESCE(SUM(monto), 0) INTO v_saldo_minimo_requerido
    FROM plan_quincenal
    WHERE usuario_id = p_usuario_id
        AND activo = TRUE
        AND ejecutado = FALSE;
    
    -- Obtener saldo disponible en cuentas
    SELECT COALESCE(SUM(saldo_actual), 0) INTO v_saldo_disponible
    FROM cuentas
    WHERE usuario_id = p_usuario_id
        AND activa = TRUE;
    
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE ejecutado = FALSE)::BIGINT,
        COUNT(*) FILTER (WHERE ejecutado = TRUE)::BIGINT,
        v_saldo_minimo_requerido,
        v_saldo_disponible >= v_saldo_minimo_requerido
    FROM plan_quincenal
    WHERE usuario_id = p_usuario_id
        AND activo = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============ COMENTARIOS ============
COMMENT ON TABLE plan_quincenal IS 'Planificación de movimientos financieros recurrentes (transferencias, ahorros, pagos)';
COMMENT ON COLUMN plan_quincenal.item_id IS 'Identificador único del item';
COMMENT ON COLUMN plan_quincenal.usuario_id IS 'Usuario propietario del plan';
COMMENT ON COLUMN plan_quincenal.nombre IS 'Nombre del item (ej: "Transferir a ahorros")';
COMMENT ON COLUMN plan_quincenal.tipo_movimiento IS 'Tipo: TRANSFERENCIA_CUENTAS, MOVIMIENTO_SUBCUENTA, PAGO_DEUDA, AHORRO';
COMMENT ON COLUMN plan_quincenal.monto IS 'Monto del movimiento';
COMMENT ON COLUMN plan_quincenal.cuenta_origen_id IS 'Cuenta de donde sale el dinero';
COMMENT ON COLUMN plan_quincenal.ejecutado IS 'Si el item ya fue ejecutado este período';
COMMENT ON COLUMN plan_quincenal.transaccion_generada_id IS 'Transacción creada al ejecutar';
COMMENT ON COLUMN plan_quincenal.orden_ejecucion IS 'Orden de ejecución (menor = primero)';

-- ============ DATOS DE EJEMPLO ============
/*
-- Ejemplos de plan quincenal

-- 1. Transferencia entre cuentas
INSERT INTO plan_quincenal (usuario_id, nombre, tipo_movimiento, monto, cuenta_origen_id, cuenta_destino_id, prioridad, orden_ejecucion) 
VALUES (1, 'Ahorro mensual', 'TRANSFERENCIA_CUENTAS', 5000.00, 1, 2, 'ALTA', 1);

-- 2. Movimiento a subcuenta
INSERT INTO plan_quincenal (usuario_id, nombre, tipo_movimiento, monto, cuenta_origen_id, subcuenta_destino_id, prioridad, orden_ejecucion) 
VALUES (1, 'Fondo de emergencia', 'AHORRO', 2000.00, 1, 1, 'ALTA', 2);

-- 3. Pago a deuda
INSERT INTO plan_quincenal (usuario_id, nombre, tipo_movimiento, monto, cuenta_origen_id, deuda_id, prioridad, orden_ejecucion) 
VALUES (1, 'Pago tarjeta BBVA', 'PAGO_DEUDA', 1500.00, 1, 1, 'ALTA', 3);

-- Ejecutar un item específico:
SELECT * FROM ejecutar_item_plan(1, 1);

-- Ejecutar todos los items:
SELECT * FROM ejecutar_plan_completo(1);

-- Ver resumen:
SELECT * FROM resumen_plan(1);

-- Reiniciar plan para el próximo período:
SELECT reiniciar_plan(1);
*/