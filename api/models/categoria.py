from sqlalchemy import Column, BigInteger, String, Boolean, DateTime, Integer, Text, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class Categoria(Base):
    __tablename__ = "categorias"

    # Clave primaria
    categoria_id = Column(BigInteger, primary_key=True, index=True)
    
    # Datos principales
    nombre = Column(String(100), nullable=False)
    descripcion = Column(Text, nullable=True)
    color_hex = Column(String(7), nullable=False, default='#6B7280')
    icono = Column(String(50), nullable=True)
    
    # Clasificación
    tipo_transaccion = Column(String(20), nullable=False)  # 'INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE'
    es_subcategoria = Column(Boolean, nullable=False, default=False)
    categoria_padre_id = Column(BigInteger, ForeignKey('categorias.categoria_id', ondelete='SET NULL'), nullable=True)
    
    # Configuración
    activa = Column(Boolean, nullable=False, default=True)
    orden_mostrar = Column(Integer, nullable=False, default=0)
    
    # Auditoría
    creada_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    actualizada_en = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relaciones
    # Relación auto-referencial (categoría padre)
    categoria_padre = relationship("Categoria", remote_side=[categoria_id], back_populates="subcategorias")
    subcategorias = relationship("Categoria", back_populates="categoria_padre", lazy="dynamic")
    
    # Relación con transacciones
    transacciones = relationship("Transaccion", back_populates="categoria", lazy="dynamic")
    
    # Constraints (validaciones adicionales)
    __table_args__ = (
        CheckConstraint("tipo_transaccion IN ('INGRESO', 'GASTO', 'TRANSFERENCIA', 'AJUSTE')", name='check_tipo_transaccion_valido'),
        CheckConstraint("LENGTH(TRIM(nombre)) > 0", name='check_nombre_no_vacio'),
        CheckConstraint("color_hex ~ '^#[0-9A-Fa-f]{6}$'", name='check_color_hex_valido'),
        CheckConstraint("categoria_padre_id != categoria_id", name='check_no_auto_referencia'),
    )
