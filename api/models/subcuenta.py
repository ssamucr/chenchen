from sqlalchemy import Column, BigInteger, String, Boolean, DateTime, Integer, Text, ForeignKey, CheckConstraint, Numeric
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class Subcuenta(Base):
    __tablename__ = "subcuentas"

    # Clave primaria
    subcuenta_id = Column(BigInteger, primary_key=True, index=True)

    # Relaciones
    cuenta_id = Column(BigInteger, ForeignKey('cuentas.cuenta_id', ondelete='CASCADE'), nullable=False)

    # Datos principales
    nombre = Column(String(100), nullable=False)
    descripcion = Column(Text, nullable=True)

    # Metas y saldos
    monto_meta = Column(Numeric(15, 2), nullable=True)
    saldo_actual = Column(Numeric(15, 2), nullable=False, default=0.00)

    # Configuración
    activa = Column(Boolean, nullable=False, default=True)
    color_hex = Column(String(7), nullable=False, default='#8B5CF6')
    icono = Column(String(50), nullable=True)
    orden_mostrar = Column(Integer, nullable=False, default=0)

    # Auditoría
    creada_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    actualizada_en = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relaciones
    cuenta = relationship("Cuenta", back_populates="subcuentas")

    # Constraints (validaciones de negocio)
    __table_args__ = (
        CheckConstraint("LENGTH(TRIM(nombre)) > 0", name='check_nombre_no_vacio'),
        CheckConstraint("monto_meta IS NULL OR monto_meta > 0", name='check_monto_meta_positivo'),
        CheckConstraint("color_hex ~ '^#[0-9A-Fa-f]{6}$'", name='check_color_hex_valido'),
    )