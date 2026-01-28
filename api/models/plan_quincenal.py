from sqlalchemy import Column, Integer, BigInteger, String, Boolean, DateTime, Numeric, Text, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class PlanQuincenal(Base):
    __tablename__ = 'plan_quincenal'

    # Clave primaria
    item_id = Column(BigInteger, primary_key=True, index=True)

    # Relaciones
    usuario_id = Column(BigInteger, ForeignKey('usuarios.usuario_id', ondelete='CASCADE'), nullable=False)
    cuenta_origen_id = Column(BigInteger, ForeignKey('cuentas.cuenta_id', ondelete='RESTRICT'), nullable=True)
    cuenta_destino_id = Column(BigInteger, ForeignKey('cuentas.cuenta_id', ondelete='RESTRICT'), nullable=True)
    subcuenta_destino_id = Column(BigInteger, ForeignKey('subcuentas.subcuenta_id', ondelete='RESTRICT'), nullable=True)
    deuda_id = Column(BigInteger, ForeignKey('deudas.deuda_id', ondelete='RESTRICT'), nullable=True)
    transaccion_generada_id = Column(BigInteger, ForeignKey('transacciones.transaccion_id', ondelete='SET NULL'), nullable=True)
    
    # Datos principales
    nombre = Column(String(150), nullable=False)
    descripcion = Column(Text, nullable=True)
    tipo_movimiento = Column(String(30), nullable=False)
    
    # Monto
    monto = Column(Numeric(15, 2), nullable=False)
    
    # Configuración
    activo = Column(Boolean, nullable=False, default=True, server_default='true')
    ejecutado = Column(Boolean, nullable=False, default=False, server_default='false')
    prioridad = Column(String(20), nullable=True, default='MEDIA', server_default='MEDIA')
    orden_ejecucion = Column(Integer, nullable=False, default=0, server_default='0')
    
    # Auditoria
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    actualizado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
    ejecutado_en = Column(DateTime(timezone=True), nullable=True)
    
    # Relaciones con otros modelos
    usuario = relationship("Usuario", back_populates="plan_quincenal")
    cuenta_origen = relationship("Cuenta", foreign_keys=[cuenta_origen_id], back_populates="plan_quincenal_origen")
    cuenta_destino = relationship("Cuenta", foreign_keys=[cuenta_destino_id], back_populates="plan_quincenal_destino")
    subcuenta_destino = relationship("Subcuenta", back_populates="plan_quincenal")
    deuda = relationship("Deuda", back_populates="plan_quincenal")
    transaccion_generada = relationship("Transaccion", foreign_keys=[transaccion_generada_id], back_populates="plan_quincenal")
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "tipo_movimiento IN ('TRANSFERENCIA_CUENTAS', 'MOVIMIENTO_SUBCUENTA', 'PAGO_DEUDA', 'AHORRO')",
            name='check_tipo_movimiento_valido'
        ),
        CheckConstraint(
            "prioridad IN ('ALTA', 'MEDIA', 'BAJA')",
            name='check_prioridad_valida'
        ),
        CheckConstraint(
            "LENGTH(TRIM(nombre)) > 0",
            name='check_nombre_no_vacio'
        ),
        CheckConstraint(
            "monto > 0",
            name='check_monto_positivo'
        ),
        CheckConstraint(
            """(tipo_movimiento = 'TRANSFERENCIA_CUENTAS' 
                AND cuenta_origen_id IS NOT NULL 
                AND cuenta_destino_id IS NOT NULL
                AND cuenta_origen_id != cuenta_destino_id)
            OR
            (tipo_movimiento IN ('MOVIMIENTO_SUBCUENTA', 'AHORRO')
                AND cuenta_origen_id IS NOT NULL 
                AND subcuenta_destino_id IS NOT NULL)
            OR
            (tipo_movimiento = 'PAGO_DEUDA' 
                AND cuenta_origen_id IS NOT NULL 
                AND deuda_id IS NOT NULL)""",
            name='check_destinos_segun_tipo'
        ),
    )
