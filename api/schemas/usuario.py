from pydantic import BaseModel, EmailStr, Field, field_validator
from datetime import datetime
from typing import Optional

class UsuarioBase(BaseModel):
    email: EmailStr
    nombre: str = Field(..., min_length=1, max_length=100)
    apellido: str = Field(..., min_length=1, max_length=100)
    moneda_principal: str = Field(default='USD', pattern='^[A-Z]{3}$')
    zona_horaria: str = Field(default='UTC', max_length=50)
    idioma: str = Field(default='es', pattern='^[a-z]{2}$')

# Clase con validadores compartidos
class UsuarioValidators:
    @field_validator('nombre', 'apellido')
    @classmethod
    def validar_no_vacio(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and len(v.strip()) == 0:
            raise ValueError('El campo no puede estar vacío o contener solo espacios')
        return v
    
    @field_validator('moneda_principal')
    @classmethod
    def validar_moneda(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            if len(v) != 3 or not v.isupper() or not v.isalpha():
                raise ValueError('La moneda debe ser un código ISO de 3 letras mayúsculas (ej: USD, EUR, MXN)')
        return v
    
    @field_validator('idioma')
    @classmethod
    def validar_idioma(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            if len(v) != 2 or not v.islower() or not v.isalpha():
                raise ValueError('El idioma debe ser un código ISO de 2 letras minúsculas (ej: es, en, fr)')
        return v
    
    @field_validator('password')
    @classmethod
    def validar_password(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            if len(v) < 8:
                raise ValueError('La contraseña debe tener al menos 8 caracteres')
            if v.strip() != v:
                raise ValueError('La contraseña no puede tener espacios al inicio o al final')
        return v

class UsuarioCreate(UsuarioBase, UsuarioValidators):
    password: str = Field(..., min_length=8)

class UsuarioUpdate(BaseModel, UsuarioValidators):
    email: Optional[EmailStr] = None
    nombre: Optional[str] = Field(None, min_length=1, max_length=100)
    apellido: Optional[str] = Field(None, min_length=1, max_length=100)
    password: Optional[str] = Field(None, min_length=8)
    moneda_principal: Optional[str] = Field(None, pattern='^[A-Z]{3}$')
    zona_horaria: Optional[str] = Field(None, max_length=50)
    idioma: Optional[str] = Field(None, pattern='^[a-z]{2}$')
    activo: Optional[bool] = None

class UsuarioResponse(UsuarioBase):
    usuario_id: int
    activo: bool
    email_verificado: bool
    creado_en: datetime
    actualizado_en: datetime
    ultimo_acceso: Optional[datetime] = None

    class Config:
        from_attributes = True
