from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from decimal import Decimal

class CuentaBase(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=100, description="Nombre de la cuenta")
    tipo_cuenta: str = Field(..., description="Tipo de cuenta")
    institucion: Optional[str] = Field(None, max_length=100, description="Institución financiera")
    numero_cuenta: Optional[str] = Field(None, max_length=50, description="Número de cuenta")
    moneda: str = Field(default='USD', pattern='^[A-Z]{3}$', description="Código ISO de moneda")
    
    # Configuración de crédito
    limite_credito: Optional[Decimal] = Field(None, ge=Decimal('0'), description="Límite de crédito (solo tarjetas)")
    
    # Información de tarjetas
    dia_corte: Optional[int] = Field(None, ge=1, le=31, description="Día de corte (1-31)")
    dia_pago: Optional[int] = Field(None, ge=1, le=31, description="Día de pago (1-31)")
    tasa_interes: Optional[Decimal] = Field(None, ge=Decimal('0'), le=Decimal('100'), description="Tasa de interés (%)")
    
    # Configuración
    activa: bool = Field(default=True, description="Cuenta activa")
    incluir_en_total: bool = Field(default=True, description="Incluir en total general")
    color_hex: str = Field(default='#3B82F6', pattern='^#[0-9A-Fa-f]{6}$', description="Color en formato hexadecimal")
    icono: Optional[str] = Field(None, max_length=50, description="Icono de la cuenta")
    orden_mostrar: int = Field(default=0, description="Orden de visualización")
    
    # Metadata
    descripcion: Optional[str] = Field(None, description="Descripción de la cuenta")
    notas: Optional[str] = Field(None, description="Notas adicionales")

class CuentaValidators:
    @field_validator('tipo_cuenta')
    @classmethod
    def validar_tipo_cuenta(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            tipos_validos = {
                'EFECTIVO',
                'CUENTA_CORRIENTE',
                'CUENTA_AHORRO',
                'CUENTA_NOMINA',
                'TARJETA_CREDITO',
                'TARJETA_DEBITO',
                'INVERSION',
                'PRESTAMO',
                'WALLET_DIGITAL',
                'CRIPTOMONEDA',
                'OTRO'
            }
            if v not in tipos_validos:
                raise ValueError(f'Tipo de cuenta inválido. Debe ser uno de: {", ".join(sorted(tipos_validos))}')
        return v
    
    @field_validator('nombre')
    @classmethod
    def validar_nombre_no_vacio(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and len(v.strip()) == 0:
            raise ValueError('El nombre no puede estar vacío')
        return v
    
    @field_validator('moneda')
    @classmethod
    def validar_moneda(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            if len(v) != 3 or not v.isupper() or not v.isalpha():
                raise ValueError('La moneda debe ser un código ISO de 3 letras mayúsculas (ej: USD, EUR, MXN)')
        return v
    
    @field_validator('limite_credito')
    @classmethod
    def validar_limite_credito(cls, v: Optional[Decimal], info) -> Optional[Decimal]:
        tipo_cuenta = info.data.get('tipo_cuenta')
        if tipo_cuenta == 'TARJETA_CREDITO':
            if v is None or v < 0:
                raise ValueError('Las tarjetas de crédito deben tener un límite de crédito válido (mayor o igual a 0)')
        elif v is not None and tipo_cuenta is not None:
            raise ValueError('El límite de crédito solo puede establecerse para tarjetas de crédito')
        return v

class CuentaCreate(CuentaBase, CuentaValidators):
    usuario_id: int = Field(..., gt=0, description="ID del usuario propietario")
    saldo_inicial: Optional[Decimal] = Field(default=Decimal('0.00'), description="Saldo inicial (se creará transacción AJUSTE_INICIAL automáticamente si es mayor a 0)")

class CuentaUpdate(BaseModel, CuentaValidators):
    nombre: Optional[str] = Field(None, min_length=1, max_length=100)
    tipo_cuenta: Optional[str] = Field(None, description="Tipo de cuenta")
    institucion: Optional[str] = Field(None, max_length=100)
    numero_cuenta: Optional[str] = Field(None, max_length=50)
    moneda: Optional[str] = Field(None, pattern='^[A-Z]{3}$')
    limite_credito: Optional[Decimal] = Field(None, ge=Decimal('0'))
    dia_corte: Optional[int] = Field(None, ge=1, le=31)
    dia_pago: Optional[int] = Field(None, ge=1, le=31)
    tasa_interes: Optional[Decimal] = Field(None, ge=Decimal('0'), le=Decimal('100'))
    activa: Optional[bool] = None
    incluir_en_total: Optional[bool] = None
    color_hex: Optional[str] = Field(None, pattern='^#[0-9A-Fa-f]{6}$')
    icono: Optional[str] = Field(None, max_length=50)
    orden_mostrar: Optional[int] = None
    descripcion: Optional[str] = None
    notas: Optional[str] = None

class CuentaResponse(CuentaBase):
    cuenta_id: int
    usuario_id: int
    creada_en: datetime
    saldo_actual: Decimal = Field(description="Saldo actual (solo lectura, se modifica mediante transacciones)")
    actualizada_en: datetime
    ultimo_movimiento: Optional[datetime] = None

    class Config:
        from_attributes = True
