from sqlalchemy import Column, Integer, BigInteger, String, Boolean, DateTime, Date, Numeric, Text, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from api.database import Base

class MovimientoDeuda(Base):
    __tablename__ = "movimientos_deuda"

    # Clave primaria
    movimiento_deuda_id = Column(BigInteger, primary_key=True, index=True)

    # Relaciones
    deuda_id = Column(BigInteger, ForeignKey('deudas.deuda_id', ondelete='RESTRICT'), nullable=False, index=True)
    transaccion_id = Column(BigInteger, ForeignKey('transacciones.transaccion_id', ondelete='RESTRICT'), nullable=False, index=True)

    # Datos principales
    fecha = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    tipo = Column(String(30), nullable=False) 
    monto = Column(Numeric(15, 2), nullable=False)
    descripcion = Column(Text, nullable=True)

    # Información adicional
    interes_generado = Column(Numeric(15, 2), nullable=True)
    capital_pagado = Column(Numeric(15, 2), nullable=True)
    interes_pagado = Column(Numeric(15, 2), nullable=True)

    # Auditoría
    creado_en = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relaciones ORM
    deuda = relationship("Deuda", back_populates="movimientos_deuda")
    transaccion = relationship("Transaccion", back_populates="movimientos_deuda")

    __table_args__ = (
        CheckConstraint(
            "tipo IN ('CARGO', 'PAGO', 'AJUSTE', 'INTERES', 'REFINANCIACION')",
            name='check_tipo_movimiento_valido'
        ),
        CheckConstraint(
            "monto > 0",
            name='check_monto_positivo'
        ),
        CheckConstraint(
            "interes_generado >= 0",
            name='check_interes_no_negativo'
        ),
        CheckConstraint(
            "tipo != 'PAGO' OR (capital_pagado IS NOT NULL AND interes_pagado IS NOT NULL AND (capital_pagado + interes_pagado) = monto)",
            name='check_desglose_pago_coherente'
        ),
        CheckConstraint(
            "tipo = 'PAGO' OR (capital_pagado IS NULL AND interes_pagado IS NULL)",
            name='check_campos_pago_solo_en_pago'
        ),
        CheckConstraint(
            "tipo = 'INTERES' OR interes_generado = 0 OR interes_generado IS NULL",
            name='check_interes_generado_solo_en_interes'
        ),
    )