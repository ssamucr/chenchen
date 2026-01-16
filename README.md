# 💰 Sistema de Finanzas Personales

Sistema completo de gestión de finanzas personales con **PostgreSQL**, **FastAPI** y arquitectura profesional.

## 🚀 Inicio Rápido

```bash
# 1. Clonar y configurar
git clone <tu-repo>
cd finanzas-personales
cp .env.example .env

# 2. Levantar base de datos
docker-compose up -d postgres

# 3. Verificar en Adminer (opcional)
# http://localhost:8080
# Server: postgres, User: finanzas_user, Password: finanzas_pass
```

## 📊 Stack Tecnológico

- **Base de datos**: PostgreSQL 16
- **Backend**: FastAPI (Python)
- **Frontend**: React/Next.js (por implementar)
- **Contenedores**: Docker + Docker Compose
- **ORM**: SQLAlchemy (por implementar)

## 🏗️ Arquitectura de la Base de Datos

### Tablas Principales

1. **usuarios** - Gestión de usuarios del sistema
2. **categorias** - Clasificación de transacciones (con subcategorías)
3. **cuentas** - Cuentas bancarias, efectivo, tarjetas, etc.
4. **transacciones** - Registro de todos los movimientos financieros
5. **subcuentas** - Organización de fondos específicos dentro de cuentas
6. **tarjetas** - Tarjetas de crédito/débito
7. **movimientos_subcuenta** - Movimientos de fondos en subcuentas
8. **deudas** - Gestión de deudas y préstamos
9. **movimientos_deuda** - Registro de pagos y cargos de deudas
10. **gastos_planificados** - Planificación de gastos futuros
11. **compromisos_recurrentes** - Ingresos/egresos recurrentes
12. **plan_quincenal** - Distribución quincenal de recursos

### Características Clave

✅ **Constraints robustos** - Integridad referencial fuerte  
✅ **Triggers automáticos** - Timestamps y validaciones  
✅ **Índices optimizados** - Queries eficientes  
✅ **Auditoría completa** - Tracking de cambios  
✅ **Multimoneda** - Soporte ISO 4217  
✅ **Categorización** - Sistema jerárquico de categorías  
✅ **Flexible** - Maneja todos los tipos de transacción  

## 🗃️ Estructura del Proyecto

```
finanzas-personales/
├── database/
│   ├── V001__usuarios.sql      # Tabla de usuarios
│   ├── V002__categorias.sql    # Categorías y subcategorías
│   ├── V003__cuentas.sql       # Cuentas financieras
│   ├── V004__transacciones.sql # Transacciones
│   ├── V005__subcuentas.sql    # Subcuentas
│   ├── V006__tarjetas.sql      # Tarjetas
│   ├── V007__movimientos_subcuenta.sql  # Movimientos subcuenta
│   ├── V008__deudas.sql        # Deudas
│   ├── V009__movimientos_deuda.sql      # Movimientos deuda
│   ├── V010__gastos_planificados.sql    # Gastos planificados
│   ├── V011__compromisos_recurrentes.sql # Compromisos
│   ├── V012__plan_quincenal.sql         # Plan quincenal
│   └── init_all.sql           # Script principal
├── docs/
│   └── modelo_fisico_transacciones.md
├── docker-compose.yml          # Configuración Docker
├── .env.example               # Variables de entorno
└── README.md                  # Este archivo
```

## 🔧 Comandos Útiles

### Base de datos

```bash
# Ejecutar todas las migraciones
docker-compose exec postgres psql -U finanzas_user -d finanzas -f /docker-entrypoint-initdb.d/init_all.sql

# Conectar directamente a PostgreSQL
docker-compose exec postgres psql -U finanzas_user -d finanzas

# Ver logs de la base de datos
docker-compose logs -f postgres

# Backup de la base de datos
docker-compose exec postgres pg_dump -U finanzas_user finanzas > backup.sql
```

### Docker

```bash
# Levantar solo la base de datos
docker-compose up -d postgres

# Levantar todo (incluye Adminer)
docker-compose up -d

# Parar servicios
docker-compose down

# Limpiar todo (¡CUIDADO! Borra datos)
docker-compose down -v
```

## 📋 Reglas de Negocio Implementadas

### Transacciones
- ✅ Al menos una cuenta (origen o destino) debe existir
- ✅ Montos siempre positivos
- ✅ Transferencias requieren ambas cuentas
- ✅ Tipos válidos: INGRESO, GASTO, TRANSFERENCIA, AJUSTE
- ✅ No transferir a la misma cuenta

### Cuentas
- ✅ Nombres únicos por usuario
- ✅ Saldos coherentes para tarjetas de crédito
- ✅ Límites de crédito solo para tarjetas
- ✅ Monedas ISO válidas

### Categorías
- ✅ Jerarquía padre-hijo
- ✅ Colores hexadecimales válidos
- ✅ Tipos de transacción específicos
- ✅ Nombres únicos por tipo y nivel

### Subcuentas y Tarjetas
- ✅ Organización de fondos con metas
- ✅ Seguimiento de progreso automático
- ✅ Gestión de límites de crédito
- ✅ Cálculo de disponibilidad

### Deudas y Planificación
- ✅ Seguimiento de deudas con amortización
- ✅ Gastos planificados con fechas objetivo
- ✅ Compromisos recurrentes automáticos
- ✅ Plan quincenal de distribución

## 🎯 Ejemplos de Datos

### Tipos de Cuenta Soportados
- `EFECTIVO` - Dinero en efectivo
- `CUENTA_CORRIENTE` - Cuenta bancaria corriente
- `CUENTA_AHORRO` - Cuenta de ahorros
- `TARJETA_CREDITO` - Tarjeta de crédito
- `INVERSION` - Cuentas de inversión
- `WALLET_DIGITAL` - Monederos digitales

### Categorías Predefinidas
- **Gastos**: Alimentación, Transporte, Vivienda, Salud...
- **Ingresos**: Salario, Freelance, Inversiones...
- **Transferencias**: Ahorro, Inversión, Pago de deudas...

## 🔐 Seguridad

- Passwords hasheados (bcrypt)
- Validación de emails
- Constraints de integridad
- Soft deletes donde corresponde
- Timestamps de auditoría

## 📈 Próximos Pasos

1. [ ] **Backend API** (FastAPI + SQLAlchemy)
2. [ ] **Autenticación JWT**
3. [ ] **Sistema de reportes**
4. [ ] **Frontend React/Next.js**
5. [ ] **API de graficos y estadísticas**
6. [ ] **Notificaciones y alertas**
7. [ ] **Import/Export de datos**
8. [ ] **Dashboard financiero**

## 🐛 Troubleshooting

### La base de datos no inicia
```bash
# Verificar logs
docker-compose logs postgres

# Limpiar y reiniciar
docker-compose down -v
docker-compose up -d postgres
```

### Problemas de permisos
```bash
# En Linux/Mac, asegurar permisos
sudo chown -R $USER:$USER ./database
```

### Puerto ocupado
```bash
# Cambiar puerto en docker-compose.yml
ports:
  - "5433:5432"  # Usar 5433 en lugar de 5432
```

## 🤝 Contribución

1. Fork del proyecto
2. Crear feature branch (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -m 'Agregar nueva funcionalidad'`)
4. Push al branch (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## 📝 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 👨‍💻 Autor

**Tu Nombre** - [tu-email@example.com](mailto:tu-email@example.com)

---

⭐ **¡Dale estrella al proyecto si te resulta útil!**