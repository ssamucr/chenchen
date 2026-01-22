from sqlalchemy import Column, BigInteger, String, Boolean, DateTime
from sqlalchemy.sql import func
from api.database import Base

class Usuario(Base):
    __tablename__ = "usuarios"

    usuario_id = Column(BigInteger, primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    nombre = Column(String(100), nullable=False)
    apellido = Column(String(100), nullable=False)
    password_hash = Column(String(255), nullable=False)
    moneda_principal = Column(String(3), nullable=False, default='USD')
    zona_horaria = Column(String(50), nullable=False, default='UTC')
    idioma = Column(String(2), nullable=False, default='es')
    activo = Column(Boolean, nullable=False, default=True)
    email_verificado = Column(Boolean, nullable=False, default=False)
    creado_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    actualizado_en = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    ultimo_acceso = Column(DateTime(timezone=True), nullable=True)
