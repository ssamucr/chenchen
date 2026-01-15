# 📊 DIAGRAMA FÍSICO - TABLA TRANSACCIONES

## 🎯 Constraint Principal
```sql
-- Al menos UNA de estas dos debe existir:
cuenta_origen_id IS NOT NULL OR cuenta_destino_id IS NOT NULL
```

## 📋 Casos de uso por tipo:

| Tipo | cuenta_origen_id | cuenta_destino_id | Descripción |
|------|------------------|-------------------|-------------|
| **INGRESO** | `NULL` | ✅ **Requerida** | Dinero entra al sistema |
| **GASTO** | ✅ **Requerida** | `NULL` | Dinero sale del sistema |
| **TRANSFERENCIA** | ✅ **Requerida** | ✅ **Requerida** | Entre cuentas del usuario |
| **AJUSTE** | Flexible | Flexible | Al menos una requerida |

## 🔗 Relaciones:

```
USUARIOS (1) ──────────────────── (N) TRANSACCIONES
                                         │
                    ┌────────────────────┴────────────────────┐
                    │                                         │
                    ▼                                         ▼
              CUENTAS (1) ──── (0..N) cuenta_origen    cuenta_destino (0..N) ──── (1) CUENTAS
```

## ⚡ Performance:
- **Índice principal**: usuario_id + fecha DESC
- **Índices opcionales**: cuenta_origen_id, cuenta_destino_id (donde NOT NULL)
- **Tipo de búsqueda más común**: "Mis transacciones del último mes"

## 🛡️ Constraints implementados:
1. ✅ Al menos una cuenta debe existir
2. ✅ Tipos válidos: INGRESO, GASTO, TRANSFERENCIA, AJUSTE  
3. ✅ Monto siempre positivo
4. ✅ Transferencias requieren ambas cuentas
5. ✅ No transferir a la misma cuenta

## 💡 Ventajas del diseño:
- ✅ Flexible para todos los tipos de transacción
- ✅ Integridad referencial fuerte
- ✅ Queries eficientes
- ✅ Auditable (creada_en)
- ✅ Extensible (nuevos tipos)