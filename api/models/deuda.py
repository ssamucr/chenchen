from sqlalchemy import Column, Integer, BigInteger, String, Boolean, DateTime, Date, Numeric, Text, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class Deuda(Base):
    __tablename__ = "deudas"
    
    # Clave primaria
    deuda_id = Column(BigInteger, primary_key=True, index=True)

    # Relaciones
    usuario_id = Column(BigInteger, ForeignKey('usuarios.usuario_id', ondelete='CASCADE'), nullable=False, index=True)
    cuenta_id = Column(BigInteger, ForeignKey('cuentas.cuenta_id', ondelete='SET NULL'), nullable=True, index=True)
    subcuenta_id = Column(BigInteger, ForeignKey('subcuentas.subcuenta_id', ondelete='SET NULL'), nullable=True, index=True)

    # Datos principales
    tipo = Column(String(30), nullable=False)  # 'PRESTAMO', 'TARJETA_CREDITO', etc.
    acreedor = Column(String(150), nullable=True)
    deudor = Column(String(150), nullable=True)
    descripcion = Column(Text, nullable=True)

    # Montos
    saldo_inicial = Column(Numeric(15, 2), nullable=False)
    saldo_actual = Column(Numeric(15, 2), nullable=False)

    # Información de pago
    monto_cuota = Column(Numeric(15, 2), nullable=True)
    frecuencia_pago = Column(String(30), nullable=True)  # 'MENSUAL', 'QUINCENAL', etc.
    dia_pago = Column(Integer, nullable=True)
    tasa_interes = Column(Numeric(5, 2), nullable=True)
    numero_cuotas = Column(Integer, nullable=True)
    cuotas_pagadas = Column(Integer, nullable=True, default=0)

    # Fechas
    fecha_inicio = Column(Date, nullable=False, server_default=func.current_date())
    fecha_vencimiento = Column(Date, nullable=True)
    proximo_pago = Column(Date, nullable=True)

    # Estado
    estado = Column(String(20), nullable=False, default='ACTIVA')  # 'ACTIVA', 'PAGADA', 'CANCELADA'
    prioridad = Column(String(20), nullable=True, default='MEDIA')  # 'BAJA', 'MEDIA', 'ALTA'

    # Configuración
    color_hex = Column(String(7), nullable=False, default='#EF4444')
    icono = Column(String(50), nullable=True)

    # Auditoría
    creada_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    actualizada_en = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    ultimo_pago = Column(DateTime(timezone=True), nullable=True)

    # Relaciones
    usuario = relationship("Usuario", back_populates="deudas")
    cuenta = relationship("Cuenta", back_populates="deudas")
    subcuenta = relationship("Subcuenta", back_populates="deudas")
    movimientos_deuda = relationship("MovimientoDeuda", back_populates="deuda", lazy="dynamic")

    # Constraints (validaciones de negocio)
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('TARJETA', 'PRESTAMO', 'HIPOTECA', 'AUTO', 'POR_PAGAR', 'POR_COBRAR', 'OTRO')",
            name='check_tipo_deuda_valido'
        ),
        CheckConstraint(
            "estado IN ('ACTIVA', 'PAGADA', 'CANCELADA', 'VENCIDA', 'REFINANCIADA')",
            name='check_estado_valido'
        ),
        CheckConstraint(
            "prioridad in ('BAJA', 'MEDIA', 'ALTA')",
            name='check_prioridad_valida'
        ),
        CheckConstraint(
            "frecuencia_pago IS NULL OR frecuencia_pago IN ('SEMANAL', 'QUINCENAL', 'MENSUAL', 'BIMESTRAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL')",
            name='check_frecuencia_valida'
        ),
        CheckConstraint(
            "(tipo = 'POR_COBRAR' AND saldo_inicial < 0 AND saldo_actual <= saldo_inicial) OR (tipo != 'POR_COBRAR' AND saldo_inicial > 0 AND saldo_actual >= 0 AND saldo_actual <= saldo_inicial)",
            name='check_saldos_coherentes'
        ),
        CheckConstraint(
            "dia_pago IS NULL OR (dia_pago BETWEEN 1 AND 31)",
            name='check_dia_pago_valido'
        ),
        CheckConstraint(
            "tasa_interes IS NULL OR (tasa_interes BETWEEN 0 AND 100)",
            name='check_tasa_interes_valida'
        ),
        CheckConstraint(
            "numero_cuotas IS NULL OR numero_cuotas > 0",
            name='check_numero_cuotas_valido'
        ),
        CheckConstraint(
            "numero_cuotas IS NULL OR cuotas_pagadas <= numero_cuotas",
            name='check_cuotas_pagadas_validas'
        ),
        CheckConstraint(
            "color_hex ~ '^#[0-9A-Fa-f]{6}$'",
            name='check_color_hex_valido'
        ),
        CheckConstraint(
            "(tipo IN ('TARJETA', 'PRESTAMO', 'HIPOTECA', 'AUTO', 'POR_PAGAR') AND acreedor IS NOT NULL) OR (tipo = 'POR_COBRAR' AND deudor IS NOT NULL) OR (tipo = 'OTRO')",
            name='check_acreedor_deudor_logico'
        ),
    )