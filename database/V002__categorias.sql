-- =====================================================
-- TABLA: categorias
-- Descripción: Categorías para clasificar transacciones
-- Dependencias: Ninguna (tabla independiente)
-- =====================================================

CREATE TABLE categorias (
    -- ============ CLAVE PRIMARIA ============
    categoria_id        BIGSERIAL PRIMARY KEY,
    
    -- ============ DATOS PRINCIPALES ============
    nombre              VARCHAR(100) NOT NULL,
    descripcion         TEXT,
    color_hex           CHAR(7) NOT NULL DEFAULT '#6B7280',
    icono               VARCHAR(50),
    
    -- ============ CLASIFICACIÓN ============
    tipo_transaccion    VARCHAR(20) NOT NULL,
    es_subcategoria     BOOLEAN NOT NULL DEFAULT FALSE,
    categoria_padre_id  BIGINT NULL,
    
    -- ============ CONFIGURACIÓN ============
    activa              BOOLEAN NOT NULL DEFAULT TRUE,
    orden_mostrar       INTEGER NOT NULL DEFAULT 0,
    
    -- ============ AUDITORIA ============
    creada_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizada_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- ============ FOREIGN KEYS ============
    CONSTRAINT fk_categoria_padre 
        FOREIGN KEY (categoria_padre_id) 
        REFERENCES categorias(categoria_id) 
        ON DELETE SET NULL,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Tipos válidos de transacción
    CONSTRAINT check_tipo_transaccion_valido 
        CHECK (tipo_transaccion IN ('INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE')),
    
    -- ✅ Nombre no vacío
    CONSTRAINT check_nombre_no_vacio 
        CHECK (LENGTH(TRIM(nombre)) > 0),
    
    -- ✅ Color hexadecimal válido
    CONSTRAINT check_color_hex_valido 
        CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    
    -- ✅ Una categoría no puede ser padre de sí misma
    CONSTRAINT check_no_auto_referencia 
        CHECK (categoria_padre_id != categoria_id),
    
    -- ✅ Solo subcategorías pueden tener padre
    CONSTRAINT check_subcategoria_logica 
        CHECK (
            (es_subcategoria = TRUE AND categoria_padre_id IS NOT NULL) 
            OR 
            (es_subcategoria = FALSE AND categoria_padre_id IS NULL)
        )
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsqueda por tipo de transacción
CREATE INDEX idx_categorias_tipo 
ON categorias(tipo_transaccion) 
WHERE activa = TRUE;

-- Búsqueda por categorías padre
CREATE INDEX idx_categorias_padre 
ON categorias(categoria_padre_id) 
WHERE categoria_padre_id IS NOT NULL;

-- Ordenamiento para mostrar
CREATE INDEX idx_categorias_orden 
ON categorias(tipo_transaccion, orden_mostrar) 
WHERE activa = TRUE;

-- Búsqueda de texto por nombre
CREATE INDEX idx_categorias_nombre_texto 
ON categorias USING gin(to_tsvector('spanish', nombre));

-- ============ CONSTRAINT DE UNICIDAD ============

-- No duplicar nombres dentro del mismo tipo y nivel
CREATE UNIQUE INDEX idx_categorias_nombre_unico 
ON categorias(LOWER(nombre), tipo_transaccion, COALESCE(categoria_padre_id, 0))
WHERE activa = TRUE;

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

-- Función para actualizar timestamp
CREATE OR REPLACE FUNCTION actualizar_timestamp_categorias()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizada_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger que se ejecuta en cada UPDATE
CREATE TRIGGER trigger_actualizar_categorias
    BEFORE UPDATE ON categorias
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_categorias();

-- ============ COMENTARIOS ============
COMMENT ON TABLE categorias IS 'Categorías para clasificar transacciones (ingresos, gastos, etc.)';
COMMENT ON COLUMN categorias.categoria_id IS 'Identificador único de la categoría';
COMMENT ON COLUMN categorias.nombre IS 'Nombre de la categoría (ej: "Alimentación", "Salario")';
COMMENT ON COLUMN categorias.descripcion IS 'Descripción opcional de la categoría';
COMMENT ON COLUMN categorias.color_hex IS 'Color en hexadecimal para UI (#FF5733)';
COMMENT ON COLUMN categorias.icono IS 'Nombre del icono (ej: "food", "salary", "car")';
COMMENT ON COLUMN categorias.tipo_transaccion IS 'Tipo de transacción: INGRESO, GASTO, TRANSFERENCIA, AJUSTE';
COMMENT ON COLUMN categorias.es_subcategoria IS 'TRUE si es subcategoría, FALSE si es categoría principal';
COMMENT ON COLUMN categorias.categoria_padre_id IS 'ID de la categoría padre (solo para subcategorías)';
COMMENT ON COLUMN categorias.activa IS 'Categoría habilitada para usar';
COMMENT ON COLUMN categorias.orden_mostrar IS 'Orden para mostrar en la UI (menor = primero)';

-- ============ DATOS INICIALES ============

-- Categorías principales de GASTOS
INSERT INTO categorias (nombre, tipo_transaccion, color_hex, icono, orden_mostrar) VALUES
('Alimentación', 'GASTO', '#FF6B6B', 'utensils', 10),
('Transporte', 'GASTO', '#4ECDC4', 'car', 20),
('Vivienda', 'GASTO', '#45B7D1', 'home', 30),
('Salud', 'GASTO', '#96CEB4', 'heart', 40),
('Entretenimiento', 'GASTO', '#FFEAA7', 'gamepad', 50),
('Educación', 'GASTO', '#DDA0DD', 'graduation-cap', 60),
('Ropa', 'GASTO', '#FD79A8', 'tshirt', 70),
('Servicios', 'GASTO', '#FDCB6E', 'wrench', 80),
('Otros Gastos', 'GASTO', '#6C5CE7', 'ellipsis', 90);

-- Subcategorías de ALIMENTACIÓN
INSERT INTO categorias (nombre, tipo_transaccion, color_hex, icono, es_subcategoria, categoria_padre_id, orden_mostrar) VALUES
('Supermercado', 'GASTO', '#FF6B6B', 'shopping-cart', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Alimentación' AND tipo_transaccion = 'GASTO'), 11),
('Restaurantes', 'GASTO', '#FF6B6B', 'utensils', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Alimentación' AND tipo_transaccion = 'GASTO'), 12),
('Comida Rápida', 'GASTO', '#FF6B6B', 'hamburger', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Alimentación' AND tipo_transaccion = 'GASTO'), 13);

-- Subcategorías de TRANSPORTE
INSERT INTO categorias (nombre, tipo_transaccion, color_hex, icono, es_subcategoria, categoria_padre_id, orden_mostrar) VALUES
('Gasolina', 'GASTO', '#4ECDC4', 'gas-pump', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Transporte' AND tipo_transaccion = 'GASTO'), 21),
('Transporte Público', 'GASTO', '#4ECDC4', 'bus', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Transporte' AND tipo_transaccion = 'GASTO'), 22),
('Uber/Taxi', 'GASTO', '#4ECDC4', 'taxi', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Transporte' AND tipo_transaccion = 'GASTO'), 23),
('Mantenimiento Auto', 'GASTO', '#4ECDC4', 'tools', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Transporte' AND tipo_transaccion = 'GASTO'), 24);

-- Categorías principales de INGRESOS
INSERT INTO categorias (nombre, tipo_transaccion, color_hex, icono, orden_mostrar) VALUES
('Salario', 'INGRESO', '#00B894', 'money-bill-wave', 10),
('Freelance', 'INGRESO', '#00CEFF', 'laptop', 20),
('Inversiones', 'INGRESO', '#6C5CE7', 'chart-line', 30),
('Ventas', 'INGRESO', '#A29BFE', 'handshake', 40),
('Otros Ingresos', 'INGRESO', '#FD79A8', 'plus-circle', 50);

-- Subcategorías de SALARIO
INSERT INTO categorias (nombre, tipo_transaccion, color_hex, icono, es_subcategoria, categoria_padre_id, orden_mostrar) VALUES
('Sueldo Base', 'INGRESO', '#00B894', 'money-bill', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Salario' AND tipo_transaccion = 'INGRESO'), 11),
('Bonos', 'INGRESO', '#00B894', 'gift', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Salario' AND tipo_transaccion = 'INGRESO'), 12),
('Comisiones', 'INGRESO', '#00B894', 'percent', TRUE, (SELECT categoria_id FROM categorias WHERE nombre = 'Salario' AND tipo_transaccion = 'INGRESO'), 13);

-- Categorías para TRANSFERENCIAS
INSERT INTO categorias (nombre, tipo_transaccion, color_hex, icono, orden_mostrar) VALUES
('Ahorro', 'TRANSFERENCIA', '#74B9FF', 'piggy-bank', 10),
('Inversión', 'TRANSFERENCIA', '#0984E3', 'chart-area', 20),
('Pago Deudas', 'TRANSFERENCIA', '#E17055', 'credit-card', 30);

-- Categorías para AJUSTES
INSERT INTO categorias (nombre, tipo_transaccion, color_hex, icono, orden_mostrar) VALUES
('Corrección de Saldo', 'AJUSTE', '#636E72', 'edit', 10),
('Ajuste Inicial', 'AJUSTE', '#2D3436', 'cog', 20);