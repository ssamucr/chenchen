from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from decimal import Decimal

class SubcuentaBase(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=100, description="Nombre de la subcuenta")
    descripcion: Optional[str] = Field(None, description="Descripción de la subcuenta")
    monto_meta: Optional[Decimal] = Field(None, gt=Decimal('0.00'), description="Monto meta de la subcuenta")
    activa: bool = Field(default=True, description="Subcuenta activa")
    color_hex: str = Field(default='#8B5CF6', pattern='^#[0-9A-Fa-f]{6}$', description="Color en formato hexadecimal")
    icono: Optional[str] = Field(None, max_length=50, description="Icono de la subcuenta")
    orden_mostrar: int = Field(default=0, description="Orden de visualización")

class SubcuentaValidators:
    @field_validator('nombre')
    @classmethod
    def validar_nombre_no_vacio(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and len(v.strip()) == 0:
            raise ValueError('El nombre no puede estar vacío o contener solo espacios')
        return v
    
    @field_validator('monto_meta')
    @classmethod
    def validar_monto_meta_positivo(cls, v: Optional[Decimal]) -> Optional[Decimal]:
        if v is not None and v <= Decimal('0.00'):
            raise ValueError('El monto meta debe ser mayor a 0 si se proporciona')
        return v
    
    @field_validator('color_hex')
    @classmethod
    def validar_color_hex(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            import re
            if not re.match(r'^#[0-9A-Fa-f]{6}$', v):
                raise ValueError('El color debe ser un valor hexadecimal válido (ej: #8B5CF6)')
        return v
    
class SubcuentaCreate(SubcuentaBase, SubcuentaValidators):
    cuenta_id: int = Field(..., gt=0, description="ID de la cuenta principal")
    saldo_inicial: Optional[Decimal] = Field(default=Decimal('0.00'), description="Saldo inicial (se creará movimiento automáticamente si es mayor a 0)")

class SubcuentaUpdate(BaseModel, SubcuentaValidators):
    nombre: Optional[str] = Field(None, min_length=1, max_length=100)
    descripcion: Optional[str] = Field(None)
    monto_meta: Optional[Decimal] = Field(None, gt=Decimal('0.00'))
    activa: Optional[bool] = None
    color_hex: Optional[str] = Field(None, pattern='^#[0-9A-Fa-f]{6}$')
    icono: Optional[str] = Field(None, max_length=50)
    orden_mostrar: Optional[int] = None

class SubcuentaResponse(SubcuentaBase):
    subcuenta_id: int
    cuenta_id: int
    saldo_actual: Decimal = Field(description="Saldo actual (solo lectura, se modifica mediante movimientos)")
    creada_en: datetime
    actualizada_en: datetime

    class Config:
        from_attributes = True