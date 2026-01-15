-- =====================================================
-- SCRIPT PRINCIPAL PARA EJECUTAR TODAS LAS MIGRACIONES
-- Ejecuta las migraciones en el orden correcto
-- =====================================================

\echo '🚀 Iniciando creación de base de datos para Finanzas Personales...'
\echo ''

-- Configuración inicial de la sesión
SET client_min_messages = WARNING;
SET timezone = 'UTC';

\echo '📊 Paso 1/4: Creando tabla USUARIOS...'
\i V001__usuarios.sql
\echo '✅ Usuarios creada exitosamente'
\echo ''

\echo '📋 Paso 2/4: Creando tabla CATEGORIAS...'
\i V002__categorias.sql
\echo '✅ Categorías creada exitosamente'
\echo ''

\echo '🏦 Paso 3/4: Creando tabla CUENTAS...'
\i V003__cuentas.sql
\echo '✅ Cuentas creada exitosamente'
\echo ''

\echo '💸 Paso 4/4: Creando tabla TRANSACCIONES...'
\i V004__transacciones.sql
\echo '✅ Transacciones creada exitosamente'
\echo ''

-- Verificar que todo se creó correctamente
\echo '🔍 Verificando estructura de la base de datos...'

SELECT 
    schemaname as esquema,
    tablename as tabla,
    tableowner as propietario
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

\echo ''
\echo '🎯 Contando registros iniciales...'

SELECT 
    'usuarios' as tabla, COUNT(*) as registros FROM usuarios
UNION ALL
SELECT 
    'categorias' as tabla, COUNT(*) as registros FROM categorias
UNION ALL
SELECT 
    'cuentas' as tabla, COUNT(*) as registros FROM cuentas
UNION ALL
SELECT 
    'transacciones' as tabla, COUNT(*) as registros FROM transacciones;

\echo ''
\echo '🎉 ¡Base de datos creada exitosamente!'
\echo '💡 Próximo paso: Insertar datos de prueba o conectar con tu aplicación'
\echo ''