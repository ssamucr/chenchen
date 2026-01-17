-- =====================================================
-- TABLA: usuarios
-- Descripción: Usuarios del sistema de finanzas personales
-- Dependencias: Ninguna (tabla base)
-- =====================================================

CREATE TABLE usuarios (
    -- ============ CLAVE PRIMARIA ============
    usuario_id          BIGSERIAL PRIMARY KEY,
    
    -- ============ DATOS PRINCIPALES ============
    email               VARCHAR(255) NOT NULL UNIQUE,
    nombre              VARCHAR(100) NOT NULL,
    apellido            VARCHAR(100) NOT NULL,
    password_hash       VARCHAR(255) NOT NULL,
    
    -- ============ CONFIGURACIÓN PERSONAL ============
    moneda_principal    CHAR(3) NOT NULL DEFAULT 'USD',
    zona_horaria        VARCHAR(50) NOT NULL DEFAULT 'UTC',
    idioma              CHAR(2) NOT NULL DEFAULT 'es',
    
    -- ============ ESTADO DE CUENTA ============
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    email_verificado    BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- ============ AUDITORIA ============
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ultimo_acceso       TIMESTAMPTZ,
    
    -- ============ REGLAS DE NEGOCIO ============
    
    -- ✅ Email válido
    CONSTRAINT check_email_valido 
        CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    
    -- ✅ Nombres no vacíos
    CONSTRAINT check_nombre_no_vacio 
        CHECK (LENGTH(TRIM(nombre)) > 0),
    
    CONSTRAINT check_apellido_no_vacio 
        CHECK (LENGTH(TRIM(apellido)) > 0),
    
    -- ✅ Moneda ISO válida
    CONSTRAINT check_moneda_iso 
        CHECK (moneda_principal ~ '^[A-Z]{3}$'),
    
    -- ✅ Idioma ISO válido
    CONSTRAINT check_idioma_iso 
        CHECK (idioma ~ '^[a-z]{2}$'),
    
    -- ✅ Password hash no vacío
    CONSTRAINT check_password_no_vacio 
        CHECK (LENGTH(password_hash) >= 8)
);

-- ============ ÍNDICES PARA RENDIMIENTO ============

-- Búsqueda por email (login)
CREATE UNIQUE INDEX idx_usuarios_email_lower 
ON usuarios(LOWER(email));

-- Búsquedas por estado activo
CREATE INDEX idx_usuarios_activo 
ON usuarios(activo) 
WHERE activo = TRUE;

-- Búsquedas por fecha de creación
CREATE INDEX idx_usuarios_creado_en 
ON usuarios(creado_en DESC);

-- Índice compuesto para login con validación de estado
CREATE INDEX idx_usuarios_email_activo 
ON usuarios(LOWER(email), activo) 
WHERE activo = TRUE;

-- ============ TRIGGER PARA ACTUALIZACIÓN AUTOMÁTICA ============

-- Función para actualizar timestamp
CREATE OR REPLACE FUNCTION actualizar_timestamp_usuarios()
RETURNS TRIGGER AS $$
BEGIN
    NEW.actualizado_en = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger que se ejecuta en cada UPDATE
CREATE TRIGGER trigger_actualizar_usuarios
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_usuarios();

-- ============ COMENTARIOS ============
COMMENT ON TABLE usuarios IS 'Usuarios registrados en el sistema de finanzas personales';
COMMENT ON COLUMN usuarios.usuario_id IS 'Identificador único del usuario';
COMMENT ON COLUMN usuarios.email IS 'Email único para login (case insensitive)';
COMMENT ON COLUMN usuarios.nombre IS 'Nombre del usuario';
COMMENT ON COLUMN usuarios.apellido IS 'Apellido del usuario';
COMMENT ON COLUMN usuarios.password_hash IS 'Hash seguro de la contraseña (bcrypt/scrypt)';
COMMENT ON COLUMN usuarios.moneda_principal IS 'Moneda por defecto (ISO 4217: USD, EUR, MXN, etc.)';
COMMENT ON COLUMN usuarios.zona_horaria IS 'Zona horaria del usuario (IANA: America/Mexico_City, etc.)';
COMMENT ON COLUMN usuarios.idioma IS 'Idioma preferido (ISO 639-1: es, en, fr, etc.)';
COMMENT ON COLUMN usuarios.activo IS 'Usuario habilitado para usar el sistema';
COMMENT ON COLUMN usuarios.email_verificado IS 'Email confirmado por el usuario';
COMMENT ON COLUMN usuarios.ultimo_acceso IS 'Última vez que hizo login';

-- ============ DATOS DE PRUEBA ============
/*
-- Usuario de ejemplo (password: "123456" hasheado)
INSERT INTO usuarios (email, nombre, apellido, password_hash, moneda_principal, zona_horaria) 
VALUES (
    'juan.perez@email.com', 
    'Juan', 
    'Pérez',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdqLpO0w.pK2P3e', -- hash de "123456"
    'MXN',
    'America/Mexico_City'
);
*/