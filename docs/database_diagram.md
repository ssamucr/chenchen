# Diagrama del Modelo de Base de Datos

```mermaid
erDiagram
    usuarios ||--o{ cuentas : "tiene"
    usuarios ||--o{ transacciones : "registra"
    usuarios ||--o{ deudas : "gestiona"
    usuarios ||--o{ compromisos_recurrentes : "define"
    usuarios ||--o{ plan_quincenal : "planifica"
    
    cuentas ||--o{ subcuentas : "contiene"
    cuentas ||--o{ transacciones : "origen/destino"
    cuentas ||--o{ deudas : "asociada"
    cuentas ||--o{ compromisos_recurrentes : "destino"
    
    subcuentas ||--o{ movimientos_subcuenta : "registra"
    
    categorias ||--o{ transacciones : "clasifica"
    
    transacciones ||--o{ movimientos_subcuenta : "genera"
    transacciones ||--o{ movimientos_deuda : "genera"
    transacciones ||--o| compromisos_recurrentes : "actualiza"
    
    deudas ||--o{ movimientos_deuda : "registra"
    deudas ||--o| subcuentas : "asociada"
    
    compromisos_recurrentes ||--o| cuentas : "destino"
    
    plan_quincenal ||--o| cuentas : "origen"
    plan_quincenal ||--o| cuentas : "destino"
    plan_quincenal ||--o| subcuentas : "destino"
    plan_quincenal ||--o| deudas : "paga"
    plan_quincenal ||--o| transacciones : "genera"

    usuarios {
        bigint usuario_id PK
        varchar email UK
        varchar nombre
        varchar apellido
        timestamptz creado_en
    }

    cuentas {
        bigint cuenta_id PK
        bigint usuario_id FK
        varchar nombre
        varchar tipo_cuenta
        varchar institucion
        decimal saldo_actual
        boolean activa
        char color_hex
    }

    categorias {
        bigint categoria_id PK
        varchar nombre UK
        varchar tipo
        char color_hex
        varchar icono
    }

    subcuentas {
        bigint subcuenta_id PK
        bigint cuenta_id FK
        varchar nombre
        varchar tipo_subcuenta
        decimal saldo_actual
        decimal monto_meta
        boolean activa
    }

    transacciones {
        bigint transaccion_id PK
        bigint usuario_id FK
        bigint cuenta_origen_id FK
        bigint cuenta_destino_id FK
        bigint categoria_id FK
        bigint compromiso_recurrente_id FK
        date fecha
        varchar tipo
        decimal monto
        text descripcion
    }

    movimientos_subcuenta {
        bigint movimiento_subcuenta_id PK
        bigint subcuenta_id FK
        bigint transaccion_id FK
        timestamptz fecha
        varchar tipo
        decimal monto
        text descripcion
    }

    deudas {
        bigint deuda_id PK
        bigint usuario_id FK
        bigint cuenta_id FK
        bigint subcuenta_id FK
        varchar tipo
        varchar acreedor
        varchar deudor
        decimal saldo_inicial
        decimal saldo_actual
        decimal monto_cuota
        varchar frecuencia_pago
        date proximo_pago
        varchar estado
    }

    movimientos_deuda {
        bigint movimiento_deuda_id PK
        bigint deuda_id FK
        bigint transaccion_id FK
        timestamptz fecha
        varchar tipo
        decimal monto
        decimal capital_pagado
        decimal interes_pagado
        decimal interes_generado
    }

    compromisos_recurrentes {
        bigint compromiso_id PK
        bigint usuario_id FK
        bigint cuenta_destino_id FK
        varchar descripcion
        varchar tipo
        decimal monto
        varchar frecuencia
        date fecha_inicio
        date ultimo_evento
        boolean activo
    }

    plan_quincenal {
        bigint item_id PK
        bigint usuario_id FK
        varchar nombre
        varchar tipo_movimiento
        decimal monto
        bigint cuenta_origen_id FK
        bigint cuenta_destino_id FK
        bigint subcuenta_destino_id FK
        bigint deuda_id FK
        boolean activo
        boolean ejecutado
        integer orden_ejecucion
        bigint transaccion_generada_id FK
    }
```

## Visualización

Puedes visualizar este diagrama en:

1. **GitHub** - Este archivo se renderiza automáticamente en GitHub
2. **Mermaid Live Editor** - https://mermaid.live/
3. **VS Code** - Instala la extensión "Markdown Preview Mermaid Support"
4. **Confluence, Notion** - Soportan Mermaid nativamente

## Descripción de Relaciones Principales

### Flujo de Transacciones
- Usuario → crea → Transacción
- Transacción → afecta → Cuenta(s)
- Transacción → puede generar → Movimiento Subcuenta
- Transacción → puede generar → Movimiento Deuda

### Gestión de Deudas
- Usuario → tiene → Deudas
- Deuda → vinculada a → Cuenta
- Transacción → genera → Movimiento Deuda
- Movimiento Deuda → actualiza automáticamente → Saldo Deuda

### Compromisos Recurrentes
- Usuario → define → Compromisos Recurrentes
- Transacción → puede estar relacionada con → Compromiso
- Al crear Transacción con compromiso_id → actualiza último_evento automáticamente
- Vista calcula próximo_evento dinámicamente

### Plan Quincenal
- Usuario → crea → Items del Plan
- Item → puede ser:
  - Transferencia entre cuentas
  - Movimiento a subcuenta
  - Pago a deuda
- Al ejecutar → genera → Transacción
- Transacción → actualiza saldos automáticamente vía triggers
