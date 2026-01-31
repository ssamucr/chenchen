from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from decimal import Decimal

class TransaccionBase(BaseModel):
    usuario_id: int = Field(..., gt=0, description="ID del usuario propietario")

    cuenta_origen_id: Optional[int] = Field(None, gt=0, description="ID de la cuenta de origen (si aplica)")
    cuenta_destino_id: Optional[int] = Field(None, gt=0, description="ID de la cuenta de destino (si aplica)")

    categoria_id: Optional[int] = Field(None, gt=0, description="ID de la categoría (si aplica)")
    compromiso_recurrente_id: Optional[int] = Field(None, gt=0, description="ID del compromiso recurrente (si aplica)")

    fecha: datetime = Field(..., description="Fecha de la transacción")
    tipo: str = Field(..., description="Tipo de transacción: 'INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE'")
    monto: Decimal = Field(..., gt=Decimal('0.00'), description="Monto de la transacción")
    descripcion: Optional[str] = Field(None, description="Descripción de la transacción")
    referencia: Optional[str] = Field(None, max_length=100, description="Referencia o nota adicional")

class TransaccionValidators:
    @field_validator('tipo')
    @classmethod
    def validar_tipo(cls, v):
        if v is not None:
            tipos_validos = {'INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE'}
            if v not in tipos_validos:
                raise ValueError(f"Tipo inválido. Debe ser uno de: {', '.join(tipos_validos)}")
        return v
    
    @field_validator('cuenta_origen_id', 'cuenta_destino_id')
    @classmethod
    def validar_cuentas(cls, v, info):
         tipo = info.data.get('tipo')
         if tipo == 'TRANSFERENCIA':
              if info.field_name == 'cuenta_origen_id' and v is None:
                raise ValueError("Para transferencias, 'cuenta_origen_id' no puede ser nulo.")
              if info.field_name == 'cuenta_destino_id' and v is None:
                raise ValueError("Para transferencias, 'cuenta_destino_id' no puede ser nulo.")
         return v

    @field_validator('cuenta_origen_id', 'cuenta_destino_id')
    @classmethod
    def validar_cuentas_diferentes(cls, v, info):
        cuenta_origen = info.data.get('cuenta_origen_id')
        cuenta_destino = info.data.get('cuenta_destino_id')
        if cuenta_origen is not None and cuenta_destino is not None and cuenta_origen == cuenta_destino:
            raise ValueError("Las cuentas de origen y destino deben ser diferentes.")
        return v

    @field_validator('cuenta_origen_id', 'cuenta_destino_id')
    @classmethod
    def validar_al_menos_una_cuenta(cls, v, info):
        cuenta_origen = info.data.get('cuenta_origen_id')
        cuenta_destino = info.data.get('cuenta_destino_id')
        if cuenta_origen is None and cuenta_destino is None:
            raise ValueError("Al menos una de 'cuenta_origen_id' o 'cuenta_destino_id' debe ser proporcionada.")
        return v

    @field_validator('monto')
    @classmethod
    def validar_monto_positivo(cls, v):
        if v is not None and v <= Decimal('0.00'):
            raise ValueError("El monto debe ser un valor positivo.")
        return v

class TransaccionCreate(TransaccionBase, TransaccionValidators):
    pass

class TransaccionUpdate(BaseModel, TransaccionValidators):
    cuenta_origen_id: Optional[int] = Field(None, gt=0, description="ID de la cuenta de origen (si aplica)")
    cuenta_destino_id: Optional[int] = Field(None, gt=0, description="ID de la cuenta de destino (si aplica)")
    categoria_id: Optional[int] = Field(None, gt=0, description="ID de la categoría (si aplica)")
    compromiso_recurrente_id: Optional[int] = Field(None, gt=0, description="ID del compromiso recurrente (si aplica)")
    fecha: Optional[datetime] = Field(None, description="Fecha de la transacción")
    tipo: Optional[str] = Field(None, description="Tipo de transacción: 'INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE'")
    monto: Optional[Decimal] = Field(None, gt=Decimal('0.00'), description="Monto de la transacción")
    descripcion: Optional[str] = Field(None, description="Descripción de la transacción")
    referencia: Optional[str] = Field(None, max_length=100, description="Referencia o nota adicional")

class TransaccionResponse(TransaccionBase):
    transaccion_id: int = Field(..., description="ID único de la transacción")
    creada_en: datetime = Field(..., description="Fecha y hora de creación de la transacción")
    actualizada_en: datetime = Field(..., description="Fecha y hora de la última actualización de la transacción")

    class Config:
        from_attributes = True
