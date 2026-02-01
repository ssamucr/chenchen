from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from decimal import Decimal

class MovimientoSubcuentaBase(BaseModel):
    subcuenta_id: int = Field(..., description="ID of the sub-account")
    subcuenta_destino_id: Optional[int] = Field(None, description="ID of the destination sub-account")
    transaccion_id: Optional[int] = Field(None, description="ID of the transaction")
    fecha: datetime = Field(..., description="Date of the movement")
    tipo: str = Field(..., description="Type of movement")
    monto: Decimal = Field(..., description="Amount of the movement")
    descripcion: Optional[str] = Field(None, description="Description of the movement")

class MovimientoSubcuentaValidators:
    @field_validator('monto')
    @classmethod
    def validar_monto_positivo(cls, v: Decimal) -> Decimal:
        if v <= Decimal('0.00'):
            raise ValueError('El monto debe ser mayor a 0')
        return v
    
    @field_validator('tipo')
    @classmethod
    def validar_tipo_movimiento(cls, v: str) -> str:
        tipos_validos = {'ASIGNACION', 'GASTO', 'TRANSFERENCIA', 'AJUSTE'}
        v_upper = v.upper()
        if v_upper not in tipos_validos:
            raise ValueError(f'El tipo de movimiento debe ser uno de {tipos_validos}')
        return v_upper
    
    @field_validator('subcuenta_destino_id')
    @classmethod
    def validar_transferencia_destino(cls, v: Optional[int], values) -> Optional[int]:
        tipo = values.get('tipo')
        if tipo and tipo.upper() == 'TRANSFERENCIA' and v is None:
            raise ValueError('El ID de la subcuenta destino es obligatorio para transferencias')
        return v
    
class MovimientoSubcuentaCreate(MovimientoSubcuentaBase, MovimientoSubcuentaValidators):
    pass

class MovimientoSubcuentaUpdate(BaseModel, MovimientoSubcuentaValidators):
    subcuenta_id: Optional[int] = None
    subcuenta_destino_id: Optional[int] = None
    transaccion_id: Optional[int] = None
    fecha: Optional[datetime] = None
    tipo: Optional[str] = None
    monto: Optional[Decimal] = None
    descripcion: Optional[str] = None

class MovimientoSubcuentaResponse(MovimientoSubcuentaBase):
    movimiento_subcuenta_id: int
    creado_en: datetime
    actualizado_en: datetime

    class Config:
        from_attributes = True