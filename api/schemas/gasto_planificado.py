from pydantic import BaseModel, Field, field_validator
from datetime import datetime, date
from typing import Optional
from decimal import Decimal

class GastoPlanificadoBase(BaseModel):
    subcuenta_id: int = Field(..., gt=0, description="ID de la subcuenta asociada")
    descripcion: str = Field(..., min_length=1, description="Descripción del gasto planificado")
    categoria: Optional[str] = Field(None, max_length=100, description="Categoría del gasto")
    monto_total: Decimal = Field(..., gt=Decimal('0.00'), description="Monto total planificado")
    monto_gastado: Decimal = Field(Decimal('0.00'), ge=Decimal('0.00'), description="Monto ya gastado")
    fecha_creacion: date = Field(..., description="Fecha de creación")
    fecha_objetivo: Optional[date] = Field(None, description="Fecha objetivo para completar")
    fecha_completado: Optional[date] = Field(None, description="Fecha en que se completó")
    estado: str = Field("PENDIENTE", description="Estado del gasto planificado")
    prioridad: str = Field("MEDIA", description="Prioridad del gasto")
    color_hex: str = Field("#F59E0B", description="Color en hexadecimal")
    notas: Optional[str] = Field(None, description="Notas adicionales")

class GastoPlanificadoValidators:
    @field_validator('descripcion')
    @classmethod
    def validar_descripcion_no_vacia(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError('La descripción no puede estar vacía')
        return v.strip()
    
    @field_validator('estado')
    @classmethod
    def validar_estado(cls, v: str) -> str:
        estados_validos = {'PENDIENTE', 'EN_PROGRESO', 'COMPLETADO', 'CANCELADO', 'VENCIDO'}
        v_upper = v.upper()
        if v_upper not in estados_validos:
            raise ValueError(f'El estado debe ser uno de: {", ".join(estados_validos)}')
        return v_upper
    
    @field_validator('prioridad')
    @classmethod
    def validar_prioridad(cls, v: str) -> str:
        prioridades_validas = {'ALTA', 'MEDIA', 'BAJA'}
        v_upper = v.upper()
        if v_upper not in prioridades_validas:
            raise ValueError(f'La prioridad debe ser una de: {", ".join(prioridades_validas)}')
        return v_upper
    
    @field_validator('color_hex')
    @classmethod
    def validar_color_hex(cls, v: str) -> str:
        import re
        if not re.match(r'^#[0-9A-Fa-f]{6}$', v):
            raise ValueError('El color debe ser un código hexadecimal válido (ej: #F59E0B)')
        return v.upper()
    
    @field_validator('monto_gastado')
    @classmethod
    def validar_monto_gastado(cls, v, info):
        """Validar que monto_gastado no supere monto_total"""
        monto_total = info.data.get('monto_total')
        if monto_total is not None and v > monto_total:
            raise ValueError(f'El monto gastado ({v}) no puede superar el monto total ({monto_total})')
        return v
    
    @field_validator('fecha_objetivo')
    @classmethod
    def validar_fecha_objetivo(cls, v, info):
        """Validar que fecha_objetivo sea posterior a fecha_creacion"""
        fecha_creacion = info.data.get('fecha_creacion')
        if v is not None and fecha_creacion is not None and v < fecha_creacion:
            raise ValueError('La fecha objetivo debe ser posterior a la fecha de creación')
        return v

class GastoPlanificadoCreate(GastoPlanificadoBase, GastoPlanificadoValidators):
    """Schema para crear un nuevo gasto planificado"""
    pass

class GastoPlanificadoUpdate(BaseModel, GastoPlanificadoValidators):
    """Schema para actualizar un gasto planificado"""
    subcuenta_id: Optional[int] = Field(None, gt=0, description="ID de la subcuenta asociada")
    descripcion: Optional[str] = Field(None, min_length=1, description="Descripción del gasto")
    categoria: Optional[str] = Field(None, max_length=100, description="Categoría del gasto")
    monto_total: Optional[Decimal] = Field(None, gt=Decimal('0.00'), description="Monto total planificado")
    monto_gastado: Optional[Decimal] = Field(None, ge=Decimal('0.00'), description="Monto gastado")
    fecha_creacion: Optional[date] = Field(None, description="Fecha de creación")
    fecha_objetivo: Optional[date] = Field(None, description="Fecha objetivo")
    fecha_completado: Optional[date] = Field(None, description="Fecha de completado")
    estado: Optional[str] = Field(None, description="Estado del gasto")
    prioridad: Optional[str] = Field(None, description="Prioridad")
    color_hex: Optional[str] = Field(None, description="Color hexadecimal")
    notas: Optional[str] = Field(None, description="Notas")

class GastoPlanificadoResponse(GastoPlanificadoBase):
    """Schema para respuesta de gasto planificado"""
    gasto_planificado_id: int = Field(..., description="ID único del gasto planificado")
    creado_en: datetime = Field(..., description="Fecha de creación del registro")
    actualizado_en: datetime = Field(..., description="Fecha de última actualización")

    class Config:
        from_attributes = True

class GastoPlanificadoConProgreso(GastoPlanificadoResponse):
    """Schema con información de progreso"""
    porcentaje_progreso: Decimal = Field(..., description="Porcentaje de progreso (0-100)")
    monto_restante: Decimal = Field(..., description="Monto restante por gastar")
    dias_restantes: Optional[int] = Field(None, description="Días restantes hasta fecha objetivo")

    class Config:
        from_attributes = True
