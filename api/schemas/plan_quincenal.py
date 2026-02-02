from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from decimal import Decimal

class PlanQuincenalBase(BaseModel):
    usuario_id: int = Field(..., gt=0, description="ID del usuario propietario")
    nombre: str = Field(..., min_length=1, max_length=150, description="Nombre del item del plan")
    descripcion: Optional[str] = Field(None, description="Descripción detallada")
    tipo_movimiento: str = Field(..., description="Tipo de movimiento a realizar")
    monto: Decimal = Field(..., gt=Decimal('0.00'), description="Monto del movimiento")
    cuenta_origen_id: Optional[int] = Field(None, gt=0, description="ID de cuenta origen (si aplica)")
    cuenta_destino_id: Optional[int] = Field(None, gt=0, description="ID de cuenta destino (si aplica)")
    subcuenta_destino_id: Optional[int] = Field(None, gt=0, description="ID de subcuenta destino (si aplica)")
    deuda_id: Optional[int] = Field(None, gt=0, description="ID de deuda (si aplica)")
    transaccion_generada_id: Optional[int] = Field(None, gt=0, description="ID de transacción generada")
    activo: bool = Field(True, description="Si el item está activo")
    ejecutado: bool = Field(False, description="Si el item ya fue ejecutado")
    prioridad: str = Field("MEDIA", description="Prioridad del item")
    orden_ejecucion: int = Field(0, ge=0, description="Orden de ejecución (menor = primero)")

class PlanQuincenalValidators:
    @field_validator('nombre')
    @classmethod
    def validar_nombre_no_vacio(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError('El nombre no puede estar vacío')
        return v.strip()
    
    @field_validator('tipo_movimiento')
    @classmethod
    def validar_tipo_movimiento(cls, v: str) -> str:
        tipos_validos = {
            'TRANSFERENCIA_CUENTAS',
            'MOVIMIENTO_SUBCUENTA',
            'PAGO_DEUDA',
            'AHORRO'
        }
        v_upper = v.upper()
        if v_upper not in tipos_validos:
            raise ValueError(f'El tipo de movimiento debe ser uno de: {", ".join(tipos_validos)}')
        return v_upper
    
    @field_validator('prioridad')
    @classmethod
    def validar_prioridad(cls, v: str) -> str:
        prioridades_validas = {'ALTA', 'MEDIA', 'BAJA'}
        v_upper = v.upper()
        if v_upper not in prioridades_validas:
            raise ValueError(f'La prioridad debe ser una de: {", ".join(prioridades_validas)}')
        return v_upper
    
    @field_validator('cuenta_destino_id')
    @classmethod
    def validar_transferencia_cuentas(cls, v, info):
        """Validar que transferencias tengan cuenta origen y destino"""
        tipo = info.data.get('tipo_movimiento')
        cuenta_origen = info.data.get('cuenta_origen_id')
        
        if tipo == 'TRANSFERENCIA_CUENTAS':
            if cuenta_origen is None:
                raise ValueError('Las transferencias requieren cuenta_origen_id')
            if v is None:
                raise ValueError('Las transferencias requieren cuenta_destino_id')
            if cuenta_origen == v:
                raise ValueError('La cuenta origen y destino deben ser diferentes')
        
        return v
    
    @field_validator('subcuenta_destino_id')
    @classmethod
    def validar_movimiento_subcuenta(cls, v, info):
        """Validar que movimientos a subcuenta tengan cuenta origen y subcuenta destino"""
        tipo = info.data.get('tipo_movimiento')
        cuenta_origen = info.data.get('cuenta_origen_id')
        
        if tipo == 'MOVIMIENTO_SUBCUENTA':
            if cuenta_origen is None:
                raise ValueError('Los movimientos a subcuenta requieren cuenta_origen_id')
            if v is None:
                raise ValueError('Los movimientos a subcuenta requieren subcuenta_destino_id')
        
        return v
    
    @field_validator('deuda_id')
    @classmethod
    def validar_pago_deuda(cls, v, info):
        """Validar que pagos a deuda tengan cuenta origen y deuda"""
        tipo = info.data.get('tipo_movimiento')
        cuenta_origen = info.data.get('cuenta_origen_id')
        
        if tipo == 'PAGO_DEUDA':
            if cuenta_origen is None:
                raise ValueError('Los pagos a deuda requieren cuenta_origen_id')
            if v is None:
                raise ValueError('Los pagos a deuda requieren deuda_id')
        
        return v

class PlanQuincenalCreate(PlanQuincenalBase, PlanQuincenalValidators):
    """Schema para crear un nuevo item del plan quincenal"""
    pass

class PlanQuincenalUpdate(BaseModel, PlanQuincenalValidators):
    """Schema para actualizar un item del plan quincenal"""
    usuario_id: Optional[int] = Field(None, gt=0, description="ID del usuario")
    nombre: Optional[str] = Field(None, min_length=1, max_length=150, description="Nombre")
    descripcion: Optional[str] = Field(None, description="Descripción")
    tipo_movimiento: Optional[str] = Field(None, description="Tipo de movimiento")
    monto: Optional[Decimal] = Field(None, gt=Decimal('0.00'), description="Monto")
    cuenta_origen_id: Optional[int] = Field(None, gt=0, description="Cuenta origen")
    cuenta_destino_id: Optional[int] = Field(None, gt=0, description="Cuenta destino")
    subcuenta_destino_id: Optional[int] = Field(None, gt=0, description="Subcuenta destino")
    deuda_id: Optional[int] = Field(None, gt=0, description="Deuda")
    transaccion_generada_id: Optional[int] = Field(None, gt=0, description="Transacción generada")
    activo: Optional[bool] = Field(None, description="Activo")
    ejecutado: Optional[bool] = Field(None, description="Ejecutado")
    prioridad: Optional[str] = Field(None, description="Prioridad")
    orden_ejecucion: Optional[int] = Field(None, ge=0, description="Orden de ejecución")

class PlanQuincenalResponse(PlanQuincenalBase):
    """Schema para respuesta de item del plan quincenal"""
    item_id: int = Field(..., description="ID único del item")
    creado_en: datetime = Field(..., description="Fecha de creación del registro")
    actualizado_en: datetime = Field(..., description="Fecha de última actualización")
    ejecutado_en: Optional[datetime] = Field(None, description="Fecha de ejecución")

    class Config:
        from_attributes = True

class PlanQuincenalConDetalles(PlanQuincenalResponse):
    """Schema con detalles extendidos (nombres de cuentas, subcuentas, etc)"""
    nombre_cuenta_origen: Optional[str] = Field(None, description="Nombre de la cuenta origen")
    nombre_cuenta_destino: Optional[str] = Field(None, description="Nombre de la cuenta destino")
    nombre_subcuenta_destino: Optional[str] = Field(None, description="Nombre de la subcuenta destino")
    descripcion_deuda: Optional[str] = Field(None, description="Descripción de la deuda")

    class Config:
        from_attributes = True

class ResumenPlanQuincenal(BaseModel):
    """Schema para resumen del plan quincenal"""
    total_items: int = Field(..., description="Total de items en el plan")
    items_activos: int = Field(..., description="Items activos")
    items_ejecutados: int = Field(..., description="Items ejecutados")
    monto_total_planificado: Decimal = Field(..., description="Monto total planificado")
    monto_ejecutado: Decimal = Field(..., description="Monto ya ejecutado")
    monto_pendiente: Decimal = Field(..., description="Monto pendiente de ejecutar")

    class Config:
        from_attributes = True
