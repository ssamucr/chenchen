from sqlalchemy import Column, BigInteger, String, Boolean, DateTime, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
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
    
    # Relaciones
    transacciones = relationship("Transaccion", back_populates="usuario", lazy="dynamic")
    cuentas = relationship("Cuenta", back_populates="usuario", lazy="dynamic")
    deudas = relationship("Deuda", back_populates="usuario", lazy="dynamic")
    compromisos_recurrentes = relationship("CompromisoRecurrente", back_populates="usuario", lazy="dynamic")
    
    # Constraints (validaciones de negocio)
    __table_args__ = (
        CheckConstraint("email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'", name='check_email_valido'),
        CheckConstraint("LENGTH(TRIM(nombre)) > 0", name='check_nombre_no_vacio'),
        CheckConstraint("LENGTH(TRIM(apellido)) > 0", name='check_apellido_no_vacio'),
        CheckConstraint("moneda_principal ~ '^[A-Z]{3}$'", name='check_moneda_iso'),
        CheckConstraint("idioma ~ '^[a-z]{2}$'", name='check_idioma_iso'),
        CheckConstraint("LENGTH(password_hash) >= 8", name='check_password_no_vacio'),
    )
