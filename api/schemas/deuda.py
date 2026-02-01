from pydantic import BaseModel, Field, field_validator
from datetime import datetime, date
from typing import Optional
from decimal import Decimal

class DeudaBase(BaseModel):
    usuario_id: int = Field(..., description="ID of the user")
    cuenta_id: Optional[int] = Field(None, description="ID of the account")
    subcuenta_id: Optional[int] = Field(None, description="ID of the sub-account")
    tipo: str = Field(..., description="Type of debt")
    acreedor: Optional[str] = Field(None, max_length=150, description="Creditor name")
    deudor: Optional[str] = Field(None, max_length=150, description="Debtor name")
    descripcion: Optional[str] = Field(None, description="Description")
    saldo_inicial: Decimal = Field(..., description="Initial balance")
    saldo_actual: Decimal = Field(..., description="Current balance")
    monto_cuota: Optional[Decimal] = Field(None, description="Payment amount")
    frecuencia_pago: Optional[str] = Field(None, description="Payment frequency")
    dia_pago: Optional[int] = Field(None, ge=1, le=31, description="Payment day")
    tasa_interes: Optional[Decimal] = Field(None, ge=0, le=100, description="Interest rate")
    numero_cuotas: Optional[int] = Field(None, gt=0, description="Number of installments")
    cuotas_pagadas: int = Field(0, ge=0, description="Installments paid")
    fecha_inicio: date = Field(..., description="Start date")
    fecha_vencimiento: Optional[date] = Field(None, description="Due date")
    proximo_pago: Optional[date] = Field(None, description="Next payment date")
    estado: str = Field("ACTIVA", description="Status")
    prioridad: str = Field("MEDIA", description="Priority")
    color_hex: str = Field("#EF4444", description="Hex color")
    icono: Optional[str] = Field(None, max_length=50, description="Icon name")

class DeudaValidators:
    @field_validator('tipo')
    @classmethod
    def validar_tipo_deuda(cls, v: str) -> str:
        tipos_validos = {'TARJETA', 'PRESTAMO', 'HIPOTECA', 'AUTO', 'POR_PAGAR', 'POR_COBRAR', 'OTRO'}
        v_upper = v.upper()
        if v_upper not in tipos_validos:
            raise ValueError(f'El tipo debe ser uno de {tipos_validos}')
        return v_upper
    
    @field_validator('estado')
    @classmethod
    def validar_estado(cls, v: str) -> str:
        estados_validos = {'ACTIVA', 'PAGADA', 'VENCIDA', 'REFINANCIADA', 'CANCELADA'}
        v_upper = v.upper()
        if v_upper not in estados_validos:
            raise ValueError(f'El estado debe ser uno de {estados_validos}')
        return v_upper
    
    @field_validator('prioridad')
    @classmethod
    def validar_prioridad(cls, v: str) -> str:
        prioridades_validas = {'ALTA', 'MEDIA', 'BAJA'}
        v_upper = v.upper()
        if v_upper not in prioridades_validas:
            raise ValueError(f'La prioridad debe ser una de {prioridades_validas}')
        return v_upper
    
    @field_validator('frecuencia_pago')
    @classmethod
    def validar_frecuencia_pago(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        frecuencias_validas = {'SEMANAL', 'QUINCENAL', 'MENSUAL', 'BIMESTRAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL'}
        v_upper = v.upper()
        if v_upper not in frecuencias_validas:
            raise ValueError(f'La frecuencia de pago debe ser una de {frecuencias_validas}')
        return v_upper
    
    @field_validator('saldo_inicial')
    @classmethod
    def validar_saldo_inicial(cls, v: Decimal) -> Decimal:
        if v == 0:
            raise ValueError('El saldo inicial no puede ser 0')
        return v
    
    @field_validator('saldo_actual')
    @classmethod
    def validar_saldo_actual(cls, v: Decimal, values) -> Decimal:
        tipo = values.data.get('tipo', '').upper()
        saldo_inicial = values.data.get('saldo_inicial')
        
        if tipo == 'POR_COBRAR':
            if v > 0:
                raise ValueError('El saldo actual para cuentas por cobrar debe ser negativo o cero')
            if saldo_inicial and v < saldo_inicial:
                raise ValueError('El saldo actual no puede ser menor al saldo inicial')
        else:
            if v < 0:
                raise ValueError('El saldo actual no puede ser negativo')
            if saldo_inicial and v > saldo_inicial:
                raise ValueError('El saldo actual no puede ser mayor al saldo inicial')
        return v
    
    @field_validator('cuotas_pagadas')
    @classmethod
    def validar_cuotas_pagadas(cls, v: int, values) -> int:
        numero_cuotas = values.data.get('numero_cuotas')
        if numero_cuotas and v > numero_cuotas:
            raise ValueError('Las cuotas pagadas no pueden exceder el número de cuotas')
        return v
    
    @field_validator('color_hex')
    @classmethod
    def validar_color_hex(cls, v: str) -> str:
        import re
        if not re.match(r'^#[0-9A-Fa-f]{6}$', v):
            raise ValueError('El color debe estar en formato hexadecimal válido (#RRGGBB)')
        return v.upper()
    
    @field_validator('acreedor', 'deudor')
    @classmethod
    def validar_acreedor_deudor(cls, v: Optional[str], values) -> Optional[str]:
        tipo = values.data.get('tipo', '').upper()
        field_name = cls.__name__
        
        # Verificar que al menos uno esté presente según el tipo
        if tipo in ('TARJETA', 'PRESTAMO', 'HIPOTECA', 'AUTO', 'POR_PAGAR'):
            acreedor = values.data.get('acreedor')
            if not acreedor and field_name == 'acreedor':
                raise ValueError(f'El acreedor es obligatorio para tipo {tipo}')
        elif tipo == 'POR_COBRAR':
            deudor = values.data.get('deudor')
            if not deudor and field_name == 'deudor':
                raise ValueError('El deudor es obligatorio para tipo POR_COBRAR')
        
        return v

class DeudaCreate(DeudaBase, DeudaValidators):
    pass

class DeudaUpdate(BaseModel, DeudaValidators):
    usuario_id: Optional[int] = None
    cuenta_id: Optional[int] = None
    subcuenta_id: Optional[int] = None
    tipo: Optional[str] = None
    acreedor: Optional[str] = None
    deudor: Optional[str] = None
    descripcion: Optional[str] = None
    saldo_inicial: Optional[Decimal] = None
    saldo_actual: Optional[Decimal] = None
    monto_cuota: Optional[Decimal] = None
    frecuencia_pago: Optional[str] = None
    dia_pago: Optional[int] = None
    tasa_interes: Optional[Decimal] = None
    numero_cuotas: Optional[int] = None
    cuotas_pagadas: Optional[int] = None
    fecha_inicio: Optional[date] = None
    fecha_vencimiento: Optional[date] = None
    proximo_pago: Optional[date] = None
    estado: Optional[str] = None
    prioridad: Optional[str] = None
    color_hex: Optional[str] = None
    icono: Optional[str] = None

class DeudaResponse(DeudaBase):
    deuda_id: int
    creada_en: datetime
    actualizada_en: datetime
    ultimo_pago: Optional[datetime] = None

    class Config:
        from_attributes = True