from sqlalchemy import Column, Integer, BigInteger, String, Boolean, DateTime, Date, Numeric, Text, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class CompromisoRecurrente(Base):
    __tablename__ = 'compromisos_recurrentes'

    # Clave primaria
    compromiso_id = Column(BigInteger, primary_key=True, index=True)

    # Relaciones
    usuario_id = Column(BigInteger, ForeignKey('usuarios.usuario_id', ondelete='CASCADE'), nullable=False)
    cuenta_destino_id = Column(BigInteger, ForeignKey('cuentas.cuenta_id', ondelete='SET NULL'), nullable=True)
    
    # Datos principales
    descripcion = Column(Text, nullable=False)
    tipo = Column(String(20), nullable=False)
    categoria = Column(String(100), nullable=True)
    
    # Monto y frecuencia
    monto = Column(Numeric(15, 2), nullable=False)
    frecuencia = Column(String(30), nullable=False)
    dia_pago = Column(Integer, nullable=True)
    
    # Fechas
    fecha_inicio = Column(Date, nullable=False, server_default=func.current_date())
    fecha_fin = Column(Date, nullable=True)
    ultimo_evento = Column(Date, nullable=True)
    
    # Estado
    activo = Column(Boolean, nullable=False, default=True, server_default='true')
    auto_generar = Column(Boolean, nullable=False, default=False, server_default='false')
    
    # Configuración
    color_hex = Column(String(7), nullable=False, default='#8B5CF6', server_default='#8B5CF6')
    icono = Column(String(50), nullable=True)
    notas = Column(Text, nullable=True)
    
    # Auditoria
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    actualizado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
    
    # Relaciones con otros modelos
    usuario = relationship("Usuario", back_populates="compromisos_recurrentes")
    cuenta_destino = relationship("Cuenta", back_populates="compromisos_recurrentes")
    transacciones = relationship("Transaccion", back_populates="compromiso_recurrente", lazy="dynamic")

    # Constraints
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('INGRESO', 'EGRESO')",
            name='check_tipo_valido'
        ),
        CheckConstraint(
            "frecuencia IN ('DIARIA', 'SEMANAL', 'QUINCENAL', 'MENSUAL', 'BIMESTRAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL')",
            name='check_frecuencia_valida'
        ),
        CheckConstraint(
            "LENGTH(TRIM(descripcion)) > 0",
            name='check_descripcion_no_vacia'
        ),
        CheckConstraint(
            "monto > 0",
            name='check_monto_positivo'
        ),
        CheckConstraint(
            "dia_pago IS NULL OR (dia_pago BETWEEN 1 AND 31)",
            name='check_dia_pago_valido'
        ),
        CheckConstraint(
            "fecha_fin IS NULL OR fecha_fin > fecha_inicio",
            name='check_fecha_fin_posterior'
        ),
        CheckConstraint(
            "color_hex ~ '^#[0-9A-Fa-f]{6}$'",
            name='check_color_hex_valido'
        ),
    )
