from sqlalchemy import Column, BigInteger, String, Boolean, DateTime, Date, Numeric, Text, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class Transaccion(Base):
    __tablename__ = "transacciones"

    # Clave primaria
    transaccion_id = Column(BigInteger, primary_key=True, index=True)
    
    # Relaciones (Foreign Keys)
    usuario_id = Column(BigInteger, ForeignKey('usuarios.usuario_id', ondelete='RESTRICT'), nullable=False, index=True)
    cuenta_origen_id = Column(BigInteger, ForeignKey('cuentas.cuenta_id', ondelete='RESTRICT'), nullable=True, index=True)
    cuenta_destino_id = Column(BigInteger, ForeignKey('cuentas.cuenta_id', ondelete='RESTRICT'), nullable=True, index=True)
    categoria_id = Column(BigInteger, ForeignKey('categorias.categoria_id', ondelete='SET NULL'), nullable=True, index=True)
    compromiso_recurrente_id = Column(BigInteger, ForeignKey('compromisos_recurrentes.compromiso_id', ondelete='SET NULL'), nullable=True)

    # Datos principales
    fecha = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    tipo = Column(String(20), nullable=False)  # 'INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE'
    monto = Column(Numeric(15, 2), nullable=False)
    descripcion = Column(Text, nullable=True)
    referencia = Column(String(100), nullable=True)

    # Auditoría
    creada_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    actualizada_en = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    # ============ RELATIONSHIPS (para navegación ORM) ============
    # Relación con Usuario
    usuario = relationship("Usuario", back_populates="transacciones")
    
    # Relación con Cuentas (origen y destino)
    cuenta_origen = relationship("Cuenta", foreign_keys=[cuenta_origen_id], back_populates="transacciones_origen")
    cuenta_destino = relationship("Cuenta", foreign_keys=[cuenta_destino_id], back_populates="transacciones_destino")
    
    # Relación con Categoría
    categoria = relationship("Categoria", back_populates="transacciones")
    
    # Relación con Compromiso Recurrente (si existe)
    compromiso_recurrente = relationship("CompromisoRecurrente", back_populates="transacciones")
    
    # Relación con Movimientos de Subcuentas
    movimientos_subcuenta = relationship("MovimientoSubcuenta", back_populates="transaccion", lazy="dynamic")
    movimientos_deuda = relationship("MovimientoDeuda", back_populates="transaccion", lazy="dynamic")
    
    # Relación con Plan Quincenal
    plan_quincenal = relationship("PlanQuincenal", foreign_keys="PlanQuincenal.transaccion_generada_id", back_populates="transaccion_generada")

    # Constraints (validaciones de negocio)
    __table_args__ = (
        CheckConstraint(
            "cuenta_origen_id IS NOT NULL OR cuenta_destino_id IS NOT NULL",
            name='check_al_menos_una_cuenta'
        ),
        CheckConstraint(
            "tipo IN ('INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE')",
            name='check_tipo_valido'
        ),
        CheckConstraint(
            "monto > 0",
            name='check_monto_positivo'
        ),
        CheckConstraint(
            "(tipo = 'TRANSFERENCIA' AND cuenta_origen_id IS NOT NULL AND cuenta_destino_id IS NOT NULL) OR (tipo != 'TRANSFERENCIA')",
            name='check_logica_transferencia'
        ),
        CheckConstraint(
            "cuenta_origen_id IS NULL OR cuenta_destino_id IS NULL OR cuenta_origen_id != cuenta_destino_id",
            name='check_cuentas_diferentes'
        ),
    )