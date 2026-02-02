from pydantic import BaseModel, Field, field_validator
from datetime import datetime, date
from typing import Optional
from decimal import Decimal

class CompromisoRecurrenteBase(BaseModel):
    usuario_id: int = Field(..., gt=0, description="ID del usuario propietario")
    cuenta_destino_id: Optional[int] = Field(None, gt=0, description="ID de la cuenta destino")
    descripcion: str = Field(..., min_length=1, description="Descripción del compromiso")
    tipo: str = Field(..., description="Tipo: INGRESO o EGRESO")
    categoria: Optional[str] = Field(None, max_length=100, description="Categoría del compromiso")
    monto: Decimal = Field(..., gt=Decimal('0.00'), description="Monto del compromiso")
    frecuencia: str = Field(..., description="Frecuencia del compromiso")
    dia_pago: Optional[int] = Field(None, ge=1, le=31, description="Día del pago (1-31)")
    fecha_inicio: date = Field(..., description="Fecha de inicio del compromiso")
    fecha_fin: Optional[date] = Field(None, description="Fecha de finalización")
    ultimo_evento: Optional[date] = Field(None, description="Fecha del último evento generado")
    activo: bool = Field(True, description="Si el compromiso está activo")
    auto_generar: bool = Field(False, description="Si debe generar transacciones automáticamente")
    color_hex: str = Field("#8B5CF6", description="Color en hexadecimal")
    icono: Optional[str] = Field(None, max_length=50, description="Nombre del icono")
    notas: Optional[str] = Field(None, description="Notas adicionales")

class CompromisoRecurrenteValidators:
    @field_validator('descripcion')
    @classmethod
    def validar_descripcion_no_vacia(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError('La descripción no puede estar vacía')
        return v.strip()
    
    @field_validator('tipo')
    @classmethod
    def validar_tipo(cls, v: str) -> str:
        tipos_validos = {'INGRESO', 'EGRESO'}
        v_upper = v.upper()
        if v_upper not in tipos_validos:
            raise ValueError(f'El tipo debe ser uno de: {", ".join(tipos_validos)}')
        return v_upper
    
    @field_validator('frecuencia')
    @classmethod
    def validar_frecuencia(cls, v: str) -> str:
        frecuencias_validas = {
            'DIARIA', 'SEMANAL', 'QUINCENAL', 'MENSUAL',
            'BIMESTRAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL'
        }
        v_upper = v.upper()
        if v_upper not in frecuencias_validas:
            raise ValueError(f'La frecuencia debe ser una de: {", ".join(frecuencias_validas)}')
        return v_upper
    
    @field_validator('color_hex')
    @classmethod
    def validar_color_hex(cls, v: str) -> str:
        import re
        if not re.match(r'^#[0-9A-Fa-f]{6}$', v):
            raise ValueError('El color debe ser un código hexadecimal válido (ej: #8B5CF6)')
        return v.upper()
    
    @field_validator('fecha_fin')
    @classmethod
    def validar_fecha_fin(cls, v, info):
        """Validar que fecha_fin sea posterior a fecha_inicio"""
        fecha_inicio = info.data.get('fecha_inicio')
        if v is not None and fecha_inicio is not None and v <= fecha_inicio:
            raise ValueError('La fecha de fin debe ser posterior a la fecha de inicio')
        return v

class CompromisoRecurrenteCreate(CompromisoRecurrenteBase, CompromisoRecurrenteValidators):
    """Schema para crear un nuevo compromiso recurrente"""
    pass

class CompromisoRecurrenteUpdate(BaseModel, CompromisoRecurrenteValidators):
    """Schema para actualizar un compromiso recurrente"""
    usuario_id: Optional[int] = Field(None, gt=0, description="ID del usuario")
    cuenta_destino_id: Optional[int] = Field(None, gt=0, description="ID de la cuenta destino")
    descripcion: Optional[str] = Field(None, min_length=1, description="Descripción")
    tipo: Optional[str] = Field(None, description="Tipo: INGRESO o EGRESO")
    categoria: Optional[str] = Field(None, max_length=100, description="Categoría")
    monto: Optional[Decimal] = Field(None, gt=Decimal('0.00'), description="Monto")
    frecuencia: Optional[str] = Field(None, description="Frecuencia")
    dia_pago: Optional[int] = Field(None, ge=1, le=31, description="Día del pago")
    fecha_inicio: Optional[date] = Field(None, description="Fecha de inicio")
    fecha_fin: Optional[date] = Field(None, description="Fecha de fin")
    ultimo_evento: Optional[date] = Field(None, description="Último evento")
    activo: Optional[bool] = Field(None, description="Activo")
    auto_generar: Optional[bool] = Field(None, description="Auto generar")
    color_hex: Optional[str] = Field(None, description="Color hexadecimal")
    icono: Optional[str] = Field(None, max_length=50, description="Icono")
    notas: Optional[str] = Field(None, description="Notas")

class CompromisoRecurrenteResponse(CompromisoRecurrenteBase):
    """Schema para respuesta de compromiso recurrente"""
    compromiso_id: int = Field(..., description="ID único del compromiso")
    creado_en: datetime = Field(..., description="Fecha de creación del registro")
    actualizado_en: datetime = Field(..., description="Fecha de última actualización")

    class Config:
        from_attributes = True

class CompromisoRecurrenteConProximoEvento(CompromisoRecurrenteResponse):
    """Schema con información del próximo evento"""
    proximo_evento: Optional[date] = Field(None, description="Fecha del próximo evento calculado")
    dias_hasta_proximo: Optional[int] = Field(None, description="Días hasta el próximo evento")
    total_generado: Optional[Decimal] = Field(None, description="Total generado hasta la fecha")

    class Config:
        from_attributes = True
