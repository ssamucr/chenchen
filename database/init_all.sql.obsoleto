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

\echo '💸 Paso 4/12: Creando tabla TRANSACCIONES...'
\i V004__transacciones.sql
\echo '✅ Transacciones creada exitosamente'
\echo ''

\echo '🎯 Paso 5/12: Creando tabla SUBCUENTAS...'
\i V005__subcuentas.sql
\echo '✅ Subcuentas creada exitosamente'
\echo ''

-- NOTA: Tabla tarjetas eliminada - Las tarjetas ahora se manejan como tipo de cuenta
-- \echo '💳 Paso 6/12: Creando tabla TARJETAS...'
-- \i V006__tarjetas.sql
-- \echo '✅ Tarjetas creada exitosamente'
-- \echo ''
\echo ''

\echo '🔄 Paso 7/12: Creando tabla MOVIMIENTOS_SUBCUENTA...'
\i V007__movimientos_subcuenta.sql
\echo '✅ Movimientos Subcuenta creada exitosamente'
\echo ''

\echo '💸 Paso 8/12: Creando tabla DEUDAS...'
\i V008__deudas.sql
\echo '✅ Deudas creada exitosamente'
\echo ''

\echo '🔁 Paso 9/12: Creando tabla MOVIMIENTOS_DEUDA...'
\i V009__movimientos_deuda.sql
\echo '✅ Movimientos Deuda creada exitosamente'
\echo ''

\echo '📅 Paso 10/12: Creando tabla GASTOS_PLANIFICADOS...'
\i V010__gastos_planificados.sql
\echo '✅ Gastos Planificados creada exitosamente'
\echo ''

\echo '🔁 Paso 11/12: Creando tabla COMPROMISOS_RECURRENTES...'
\i V011__compromisos_recurrentes.sql
\echo '✅ Compromisos Recurrentes creada exitosamente'
\echo ''

\echo '📋 Paso 12/12: Creando tabla PLAN_QUINCENAL...'
\i V012__plan_quincenal.sql
\echo '✅ Plan Quincenal creada exitosamente'
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
    'transacciones' as tabla, COUNT(*) as registros FROM transacciones
UNION ALL
SELECT 
    'subcuentas' as tabla, COUNT(*) as registros FROM subcuentas
UNION ALL
SELECT 
    'movimientos_subcuenta' as tabla, COUNT(*) as registros FROM movimientos_subcuenta
UNION ALL
SELECT 
    'deudas' as tabla, COUNT(*) as registros FROM deudas
UNION ALL
SELECT 
    'movimientos_deuda' as tabla, COUNT(*) as registros FROM movimientos_deuda
UNION ALL
SELECT 
    'gastos_planificados' as tabla, COUNT(*) as registros FROM gastos_planificados
UNION ALL
SELECT 
    'compromisos_recurrentes' as tabla, COUNT(*) as registros FROM compromisos_recurrentes
UNION ALL
SELECT 
    'plan_quincenal' as tabla, COUNT(*) as registros FROM plan_quincenal;

\echo ''
\echo '🎉 ¡Base de datos creada exitosamente!'
\echo '💡 Próximo paso: Insertar datos de prueba o conectar con tu aplicación'
\echo ''