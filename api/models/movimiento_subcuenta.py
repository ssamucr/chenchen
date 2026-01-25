from sqlalchemy import Column, BigInteger, String, Boolean, DateTime, Date, Numeric, Text, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class MovimientoSubcuenta(Base):
    __tablename__ = "movimientos_subcuentas"
    
    # Clave primaria
    movimiento_subcuenta_id = Column(BigInteger, primary_key=True, index=True)

    # Relaciones
    subcuenta_id = Column(BigInteger, ForeignKey('subcuentas.subcuenta_id', ondelete='RESTRICT'), nullable=False, index=True)
    subcuenta_destino_id = Column(BigInteger, ForeignKey('subcuentas.subcuenta_id', ondelete='RESTRICT'), nullable=True, index=True)
    transaccion_id = Column(BigInteger, ForeignKey('transacciones.transaccion_id', ondelete='RESTRICT'), nullable=False, index=True)

    # Datos principales
    fecha = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    tipo = Column(String(30), nullable=False)  # 'TRANSFERENCIA', 'AJUSTE', etc.
    monto = Column(Numeric(15, 2), nullable=False)
    descripcion = Column(Text, nullable=True)

    # Auditoría
    creado_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relaciones

    subcuenta = relationship("Subcuenta", foreign_keys=[subcuenta_id], back_populates="movimientos_subcuentas")
    subcuenta_destino = relationship("Subcuenta", foreign_keys=[subcuenta_destino_id], back_populates="movimientos_subcuentas_destino")

    transaccion = relationship("Transaccion", back_populates="movimientos_subcuentas")

    # Constraints (validaciones de negocio)
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('TRANSFERENCIA', 'AJUSTE', 'ASIGNACION', 'GASTO')",
            name='check_tipo_movimiento_valido'
        ),
        CheckConstraint(
            "monto > 0",
            name='check_monto_positivo'
        ),
        CheckConstraint(
            "tipo = 'TRANSFERENCIA' AND subcuenta_destino_id IS NOT NULL OR tipo != 'TRANSFERENCIA' AND subcuenta_destino_id IS NULL",
            name='check_transferencia_tiene_destino'
        ),
    )