from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from decimal import Decimal

class CategoriaBase(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=100, description="Nombre de la categoría")
    descripcion: Optional[str] = Field(None, description="Descripción de la categoría")
    color_hex: str = Field(default='#6B7280', pattern='^#[0-9A-Fa-f]{6}$', description="Color en formato hexadecimal")
    icono: Optional[str] = Field(None, max_length=50, description="Icono de la categoría")
    tipo_transaccion: str = Field(..., description="Tipo de transacción: 'INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE'")
    es_subcategoria: bool = Field(default=False, description="Si es subcategoría o categoría principal")
    categoria_padre_id: Optional[int] = Field(None, gt=0, description="ID de la categoría padre (solo para subcategorías)")
    activa: bool = Field(default=True, description="Categoría activa")
    orden_mostrar: int = Field(default=0, description="Orden de visualización")

# Clase con validadores compartidos
class CategoriaValidators:
    @field_validator('nombre')
    @classmethod
    def validar_nombre_no_vacio(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and len(v.strip()) == 0:
            raise ValueError('El nombre no puede estar vacío o contener solo espacios')
        return v
    
    @field_validator('tipo_transaccion')
    @classmethod
    def validar_tipo_transaccion(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            tipos_validos = {'INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE'}
            if v not in tipos_validos:
                raise ValueError(f'Tipo de transacción inválido. Debe ser uno de: {", ".join(sorted(tipos_validos))}')
        return v
    
    @field_validator('color_hex')
    @classmethod
    def validar_color_hex(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            import re
            if not re.match(r'^#[0-9A-Fa-f]{6}$', v):
                raise ValueError('El color debe ser un valor hexadecimal válido (ej: #6B7280)')
        return v
    
    @field_validator('categoria_padre_id')
    @classmethod
    def validar_logica_subcategoria(cls, v: Optional[int], info) -> Optional[int]:
        es_subcategoria = info.data.get('es_subcategoria')
        
        # Si es subcategoría, debe tener padre
        if es_subcategoria and v is None:
            raise ValueError('Las subcategorías deben tener una categoría padre (categoria_padre_id)')
        
        # Si NO es subcategoría, NO debe tener padre
        if not es_subcategoria and v is not None:
            raise ValueError('Las categorías principales no pueden tener categoria_padre_id')
        
        return v

class CategoriaCreate(CategoriaBase, CategoriaValidators):
    pass

class CategoriaUpdate(BaseModel, CategoriaValidators):
    nombre: Optional[str] = Field(None, min_length=1, max_length=100)
    descripcion: Optional[str] = Field(None)
    color_hex: Optional[str] = Field(None, pattern='^#[0-9A-Fa-f]{6}$')
    icono: Optional[str] = Field(None, max_length=50)
    tipo_transaccion: Optional[str] = Field(None)
    es_subcategoria: Optional[bool] = None
    categoria_padre_id: Optional[int] = Field(None, gt=0)
    activa: Optional[bool] = None
    orden_mostrar: Optional[int] = None

class CategoriaResponse(CategoriaBase):
    categoria_id: int
    creada_en: datetime
    actualizada_en: datetime

    class Config:
        from_attributes = True
