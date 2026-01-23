from sqlalchemy import Column, BigInteger, String, Boolean, DateTime, Numeric, Integer, Text, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class Cuenta(Base):
    __tablename__ = "cuentas"

    # Clave primaria
    cuenta_id = Column(BigInteger, primary_key=True, index=True)
    
    # Relaciones
    usuario_id = Column(BigInteger, ForeignKey('usuarios.usuario_id', ondelete='CASCADE'), nullable=False)
    
    # Datos principales
    nombre = Column(String(100), nullable=False)
    tipo_cuenta = Column(String(30), nullable=False)
    institucion = Column(String(100), nullable=True)
    numero_cuenta = Column(String(50), nullable=True)
    moneda = Column(String(3), nullable=False, default='USD')
    
    # Saldos
    saldo_actual = Column(Numeric(15, 2), nullable=False, default=0.00)
    limite_credito = Column(Numeric(15, 2), nullable=True)
    
    # Información de tarjetas
    dia_corte = Column(Integer, nullable=True)
    dia_pago = Column(Integer, nullable=True)
    tasa_interes = Column(Numeric(5, 2), nullable=True)
    
    # Configuración
    activa = Column(Boolean, nullable=False, default=True)
    incluir_en_total = Column(Boolean, nullable=False, default=True)
    color_hex = Column(String(7), nullable=False, default='#3B82F6')
    icono = Column(String(50), nullable=True)
    orden_mostrar = Column(Integer, nullable=False, default=0)
    
    # Metadata
    descripcion = Column(Text, nullable=True)
    notas = Column(Text, nullable=True)
    
    # Auditoría
    creada_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    actualizada_en = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    ultimo_movimiento = Column(DateTime(timezone=True), nullable=True)
