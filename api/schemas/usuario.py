from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional

class UsuarioBase(BaseModel):
    email: EmailStr
    nombre: str = Field(..., min_length=1, max_length=100)
    apellido: str = Field(..., min_length=1, max_length=100)
    moneda_principal: str = Field(default='USD', pattern='^[A-Z]{3}$')
    zona_horaria: str = Field(default='UTC', max_length=50)
    idioma: str = Field(default='es', pattern='^[a-z]{2}$')

class UsuarioCreate(UsuarioBase):
    password: str = Field(..., min_length=8)

class UsuarioUpdate(BaseModel):
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
