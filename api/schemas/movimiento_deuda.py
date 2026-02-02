from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from decimal import Decimal

class MovimientoDeudaBase(BaseModel):
    deuda_id: int = Field(..., gt=0, description="ID de la deuda afectada")
    transaccion_id: int = Field(..., gt=0, description="ID de la transacción asociada")
    fecha: datetime = Field(..., description="Fecha y hora del movimiento")
    tipo: str = Field(..., description="Tipo de movimiento: CARGO, PAGO, AJUSTE, INTERES, REFINANCIACION")
    monto: Decimal = Field(..., gt=Decimal('0.00'), description="Monto total del movimiento")
    descripcion: Optional[str] = Field(None, description="Descripción del movimiento")
    interes_generado: Optional[Decimal] = Field(None, ge=Decimal('0.00'), description="Interés generado en este período")
    capital_pagado: Optional[Decimal] = Field(None, ge=Decimal('0.00'), description="Porción que va a capital (solo para pagos)")
    interes_pagado: Optional[Decimal] = Field(None, ge=Decimal('0.00'), description="Porción que va a intereses (solo para pagos)")

class MovimientoDeudaValidators:
    @field_validator('tipo')
    @classmethod
    def validar_tipo(cls, v: str) -> str:
        tipos_validos = {'CARGO', 'PAGO', 'AJUSTE', 'INTERES', 'REFINANCIACION'}
        v_upper = v.upper()
        if v_upper not in tipos_validos:
            raise ValueError(f'El tipo debe ser uno de: {", ".join(tipos_validos)}')
        return v_upper
    
    @field_validator('capital_pagado', 'interes_pagado')
    @classmethod
    def validar_campos_pago(cls, v, info):
        """Validar que capital_pagado e interes_pagado solo se usen en pagos"""
        tipo = info.data.get('tipo')
        if v is not None and tipo != 'PAGO':
            raise ValueError(f"{info.field_name} solo debe usarse cuando el tipo es 'PAGO'")
        return v
    
    @field_validator('interes_pagado')
    @classmethod
    def validar_desglose_pago(cls, v, info):
        """Validar que capital_pagado + interes_pagado = monto para pagos"""
        tipo = info.data.get('tipo')
        capital_pagado = info.data.get('capital_pagado')
        monto = info.data.get('monto')
        
        if tipo == 'PAGO':
            if capital_pagado is None or v is None:
                raise ValueError("Para pagos, 'capital_pagado' e 'interes_pagado' son obligatorios")
            
            total = capital_pagado + v
            if abs(total - monto) > Decimal('0.01'):  # Tolerancia para decimales
                raise ValueError(f"La suma de capital_pagado ({capital_pagado}) e interes_pagado ({v}) debe ser igual al monto ({monto})")
        
        return v
    
    @field_validator('interes_generado')
    @classmethod
    def validar_interes_generado(cls, v, info):
        """Validar que interes_generado solo se use en movimientos de tipo INTERES"""
        tipo = info.data.get('tipo')
        if v is not None and v > 0 and tipo != 'INTERES':
            raise ValueError("'interes_generado' solo debe usarse cuando el tipo es 'INTERES'")
        return v

class MovimientoDeudaCreate(MovimientoDeudaBase, MovimientoDeudaValidators):
    """Schema para crear un nuevo movimiento de deuda"""
    pass

class MovimientoDeudaUpdate(BaseModel, MovimientoDeudaValidators):
    """Schema para actualizar un movimiento de deuda"""
    deuda_id: Optional[int] = Field(None, gt=0, description="ID de la deuda afectada")
    transaccion_id: Optional[int] = Field(None, gt=0, description="ID de la transacción asociada")
    fecha: Optional[datetime] = Field(None, description="Fecha y hora del movimiento")
    tipo: Optional[str] = Field(None, description="Tipo de movimiento")
    monto: Optional[Decimal] = Field(None, gt=Decimal('0.00'), description="Monto total del movimiento")
    descripcion: Optional[str] = Field(None, description="Descripción del movimiento")
    interes_generado: Optional[Decimal] = Field(None, ge=Decimal('0.00'), description="Interés generado")
    capital_pagado: Optional[Decimal] = Field(None, ge=Decimal('0.00'), description="Capital pagado")
    interes_pagado: Optional[Decimal] = Field(None, ge=Decimal('0.00'), description="Interés pagado")

class MovimientoDeudaResponse(MovimientoDeudaBase):
    """Schema para respuesta de movimiento de deuda"""
    movimiento_deuda_id: int = Field(..., description="ID único del movimiento")
    creado_en: datetime = Field(..., description="Fecha de creación del registro")

    class Config:
        from_attributes = True

class MovimientoDeudaDetalleResponse(MovimientoDeudaResponse):
    """Schema para respuesta detallada con información de deuda y transacción"""
    # Campos de la deuda
    tipo_deuda: Optional[str] = Field(None, description="Tipo de deuda")
    contraparte: Optional[str] = Field(None, description="Acreedor o deudor")
    descripcion_deuda: Optional[str] = Field(None, description="Descripción de la deuda")
    saldo_deuda_actual: Optional[Decimal] = Field(None, description="Saldo actual de la deuda")
    estado_deuda: Optional[str] = Field(None, description="Estado de la deuda")

    class Config:
        from_attributes = True

class ResumenMovimientoDeuda(BaseModel):
    """Schema para resumen de movimientos por tipo"""
    tipo_movimiento: str = Field(..., description="Tipo de movimiento")
    cantidad_movimientos: int = Field(..., description="Cantidad de movimientos")
    monto_total: Decimal = Field(..., description="Monto total")
    total_capital: Decimal = Field(..., description="Total de capital")
    total_interes: Decimal = Field(..., description="Total de intereses")

    class Config:
        from_attributes = True

class ProximoPagoResponse(BaseModel):
    """Schema para respuesta de cálculo de próximo pago"""
    capital_a_pagar: Decimal = Field(..., description="Capital a pagar")
    interes_a_pagar: Decimal = Field(..., description="Interés a pagar")
    total_a_pagar: Decimal = Field(..., description="Total a pagar")
    saldo_restante: Decimal = Field(..., description="Saldo restante después del pago")

    class Config:
        from_attributes = True
