from sqlalchemy import Column, BigInteger, String, Boolean, DateTime, Numeric, Integer, Text, ForeignKey, CheckConstraint
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
    
    # Relaciones
    transacciones_origen = relationship("Transaccion", foreign_keys="Transaccion.cuenta_origen_id", back_populates="cuenta_origen", lazy="dynamic")
    transacciones_destino = relationship("Transaccion", foreign_keys="Transaccion.cuenta_destino_id", back_populates="cuenta_destino", lazy="dynamic")
    
    usuario = relationship("Usuario", back_populates="cuentas")

    subcuentas = relationship("Subcuenta", back_populates="cuenta", lazy="dynamic")

    deudas = relationship("Deuda", back_populates="cuenta", lazy="dynamic")
    
    compromisos_recurrentes = relationship("CompromisoRecurrente", back_populates="cuenta_destino", lazy="dynamic")
    
    plan_quincenal_origen = relationship("PlanQuincenal", foreign_keys="PlanQuincenal.cuenta_origen_id", back_populates="cuenta_origen", lazy="dynamic")
    plan_quincenal_destino = relationship("PlanQuincenal", foreign_keys="PlanQuincenal.cuenta_destino_id", back_populates="cuenta_destino", lazy="dynamic")

    # Constraints (validaciones de negocio)
    __table_args__ = (
        CheckConstraint(
            "tipo_cuenta IN ('EFECTIVO', 'CUENTA_CORRIENTE', 'CUENTA_AHORRO', 'CUENTA_NOMINA', 'TARJETA_CREDITO', 'TARJETA_DEBITO', 'INVERSION', 'PRESTAMO', 'WALLET_DIGITAL', 'CRIPTOMONEDA', 'OTRO')",
            name='check_tipo_cuenta_valido'
        ),
        CheckConstraint("moneda ~ '^[A-Z]{3}$'", name='check_moneda_iso'),
        CheckConstraint("LENGTH(TRIM(nombre)) > 0", name='check_nombre_no_vacio'),
        CheckConstraint("color_hex ~ '^#[0-9A-Fa-f]{6}$'", name='check_color_hex_valido'),
        CheckConstraint(
            "(tipo_cuenta = 'TARJETA_CREDITO' AND limite_credito >= 0) OR (tipo_cuenta != 'TARJETA_CREDITO' AND limite_credito IS NULL)",
            name='check_limite_credito_logico'
        ),
        CheckConstraint("dia_corte IS NULL OR (dia_corte BETWEEN 1 AND 31)", name='check_dia_corte_valido'),
        CheckConstraint("dia_pago IS NULL OR (dia_pago BETWEEN 1 AND 31)", name='check_dia_pago_valido'),
        CheckConstraint("tasa_interes IS NULL OR (tasa_interes BETWEEN 0 AND 100)", name='check_tasa_interes_valida'),
    )
