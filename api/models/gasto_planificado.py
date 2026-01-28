from sqlalchemy import Column, Integer, BigInteger, String, Boolean, DateTime, Date, Numeric, Text, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class GastoPlanificado(Base):
    __tablename__ = 'gastos_planificados'

    # Clave primaria
    gasto_planificado_id = Column(BigInteger, primary_key=True, index=True)

    # Relaciones
    subcuenta_id = Column(BigInteger, ForeignKey('subcuentas.subcuenta_id', ondelete='CASCADE'), nullable=False)
    
    # Datos principales
    descripcion = Column(Text, nullable=False)
    categoria = Column(String(100), nullable=True)
    
    # Montos
    monto_total = Column(Numeric(15, 2), nullable=False)
    monto_gastado = Column(Numeric(15, 2), nullable=False, default=0.00, server_default='0.00')
    
    # Fechas
    fecha_creacion = Column(Date, nullable=False, server_default=func.current_date())
    fecha_objetivo = Column(Date, nullable=True)
    fecha_completado = Column(Date, nullable=True)
    
    # Estado
    estado = Column(String(20), nullable=False, default='PENDIENTE', server_default='PENDIENTE')
    prioridad = Column(String(20), nullable=True, default='MEDIA', server_default='MEDIA')
    
    # Configuración
    color_hex = Column(String(7), nullable=False, default='#F59E0B', server_default='#F59E0B')
    notas = Column(Text, nullable=True)
    
    # Auditoria
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    actualizado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
    
    # Relaciones con otros modelos
    subcuenta = relationship("Subcuenta", back_populates="gastos_planificados")
    
    # Constraints
    __table_args__ = (
        CheckConstraint(
            "estado IN ('PENDIENTE', 'EN_PROGRESO', 'COMPLETADO', 'CANCELADO', 'VENCIDO')",
            name='check_estado_valido'
        ),
        CheckConstraint(
            "prioridad IN ('ALTA', 'MEDIA', 'BAJA')",
            name='check_prioridad_valida'
        ),
        CheckConstraint(
            "LENGTH(TRIM(descripcion)) > 0",
            name='check_descripcion_no_vacia'
        ),
        CheckConstraint(
            "monto_total > 0",
            name='check_monto_total_positivo'
        ),
        CheckConstraint(
            "monto_gastado >= 0",
            name='check_monto_gastado_no_negativo'
        ),
        CheckConstraint(
            "monto_gastado <= monto_total",
            name='check_monto_gastado_coherente'
        ),
        CheckConstraint(
            "((estado = 'COMPLETADO' AND fecha_completado IS NOT NULL) OR (estado != 'COMPLETADO' AND fecha_completado IS NULL))",
            name='check_fecha_completado_coherente'
        ),
        CheckConstraint(
            "color_hex ~ '^#[0-9A-Fa-f]{6}$'",
            name='check_color_hex_valido'
        ),
    )