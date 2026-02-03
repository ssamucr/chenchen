from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from api.database import get_db
from api.models.cuenta import Cuenta
from api.models.usuario import Usuario
from api.models.transaccion import Transaccion
from api.models.categoria import Categoria
from api.schemas.cuenta import CuentaCreate, CuentaResponse, CuentaUpdate
from typing import List
from datetime import datetime
from decimal import Decimal

router = APIRouter(prefix="/cuentas", tags=["cuentas"])

@router.post("/", response_model=CuentaResponse, status_code=status.HTTP_201_CREATED)
async def crear_cuenta(cuenta: CuentaCreate, db: Session = Depends(get_db)):
    """
    Crear una nueva cuenta financiera.
    
    - **usuario_id**: ID del usuario propietario
    - **nombre**: Nombre descriptivo de la cuenta
    - **tipo_cuenta**: Tipo de cuenta (EFECTIVO, CUENTA_CORRIENTE, TARJETA_CREDITO, etc.)
    - **moneda**: Código ISO de 3 letras (USD, MXN, EUR, etc.)
    - **limite_credito**: Requerido solo para TARJETA_CREDITO
    - **saldo_inicial**: Saldo inicial (opcional, por defecto 0.00)
    
    Nota: La cuenta siempre inicia con saldo 0. Para establecer un saldo inicial,
    se debe crear una transacción de tipo AJUSTE_INICIAL después de crear la cuenta.
    """
    # Verificar que el usuario existe
    usuario = db.query(Usuario).filter(Usuario.usuario_id == cuenta.usuario_id).first()
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    # Verificar que no exista otra cuenta con el mismo nombre para el mismo usuario
    cuenta_existente = db.query(Cuenta).filter(
        Cuenta.usuario_id == cuenta.usuario_id,
        Cuenta.nombre == cuenta.nombre
    ).first()
    
    if cuenta_existente:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya existe una cuenta con ese nombre para este usuario"
        )
    
    # Crear la nueva cuenta (excluir saldo_inicial ya que no está en el modelo)
    datos_cuenta = cuenta.model_dump(exclude={'saldo_inicial'})
    nueva_cuenta = Cuenta(**datos_cuenta)
    
    db.add(nueva_cuenta)
    db.commit()
    db.refresh(nueva_cuenta)
    
    # Si hay saldo inicial, crear transacción de AJUSTE
    if cuenta.saldo_inicial and cuenta.saldo_inicial > 0:
        # Buscar o crear categoría para ajustes iniciales
        categoria_ajuste = db.query(Categoria).filter(
            Categoria.nombre == "Ajuste Inicial",
            Categoria.tipo_transaccion == "AJUSTE"
        ).first()
        
        if not categoria_ajuste:
            categoria_ajuste = Categoria(
                nombre="Ajuste Inicial",
                tipo_transaccion="AJUSTE",
                descripcion="Categoría para ajustes de saldo inicial",
                activa=True
            )
            db.add(categoria_ajuste)
            db.commit()
            db.refresh(categoria_ajuste)
        
        # Crear transacción de ajuste
        transaccion_ajuste = Transaccion(
            usuario_id=cuenta.usuario_id,
            cuenta_destino_id=nueva_cuenta.cuenta_id,
            categoria_id=categoria_ajuste.categoria_id,
            fecha=datetime.now(),
            tipo="AJUSTE",
            monto=Decimal(str(cuenta.saldo_inicial)),
            descripcion=f"Saldo inicial de cuenta: {nueva_cuenta.nombre}",
            referencia="AJUSTE_INICIAL"
        )
        
        db.add(transaccion_ajuste)
        db.commit()
        db.refresh(nueva_cuenta)
    
    return nueva_cuenta

@router.get("/", response_model=List[CuentaResponse])
async def obtener_cuentas(
    skip: int = Query(0, ge=0, description="Número de registros a omitir"),
    limit: int = Query(100, ge=1, le=1000, description="Número máximo de registros"),
    usuario_id: int = Query(None, description="Filtrar por usuario"),
    activa: bool = Query(None, description="Filtrar por estado activo"),
    tipo_cuenta: str = Query(None, description="Filtrar por tipo de cuenta"),
    db: Session = Depends(get_db)
):
    """
    Obtener todas las cuentas con filtros opcionales.
    
    Parámetros de consulta:
    - **skip**: Registros a omitir (paginación)
    - **limit**: Límite de registros
    - **usuario_id**: Filtrar por ID de usuario
    - **activa**: Filtrar por estado (true/false)
    - **tipo_cuenta**: Filtrar por tipo de cuenta
    """
    query = db.query(Cuenta)
    
    if usuario_id is not None:
        query = query.filter(Cuenta.usuario_id == usuario_id)
    
    if activa is not None:
        query = query.filter(Cuenta.activa == activa)
    
    if tipo_cuenta is not None:
        query = query.filter(Cuenta.tipo_cuenta == tipo_cuenta)
    
    cuentas = query.order_by(Cuenta.orden_mostrar, Cuenta.nombre).offset(skip).limit(limit).all()
    return cuentas

@router.get("/{cuenta_id}", response_model=CuentaResponse)
async def obtener_cuenta(cuenta_id: int, db: Session = Depends(get_db)):
    """
    Obtener una cuenta específica por ID.
    """
    cuenta = db.query(Cuenta).filter(Cuenta.cuenta_id == cuenta_id).first()
    if not cuenta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cuenta no encontrada"
        )
    return cuenta

@router.put("/{cuenta_id}", response_model=CuentaResponse)
async def actualizar_cuenta(
    cuenta_id: int,
    cuenta_actualizada: CuentaUpdate,
    db: Session = Depends(get_db)
):
    """
    Actualizar una cuenta existente.
    
    Solo se actualizarán los campos proporcionados.
    """
    cuenta = db.query(Cuenta).filter(Cuenta.cuenta_id == cuenta_id).first()
    if not cuenta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cuenta no encontrada"
        )
    
    # Actualizar solo los campos proporcionados
    datos_actualizados = cuenta_actualizada.model_dump(exclude_unset=True)
    
    # Verificar unicidad del nombre si se está actualizando
    if 'nombre' in datos_actualizados:
        cuenta_con_mismo_nombre = db.query(Cuenta).filter(
            Cuenta.usuario_id == cuenta.usuario_id,
            Cuenta.nombre == datos_actualizados['nombre'],
            Cuenta.cuenta_id != cuenta_id
        ).first()
        
        if cuenta_con_mismo_nombre:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ya existe otra cuenta con ese nombre para este usuario"
            )
    
    for campo, valor in datos_actualizados.items():
        setattr(cuenta, campo, valor)
    
    db.commit()
    db.refresh(cuenta)
    
    return cuenta

@router.delete("/{cuenta_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_cuenta(cuenta_id: int, db: Session = Depends(get_db)):
    """
    Eliminar una cuenta.
    
    Nota: Esto eliminará la cuenta y todos sus datos relacionados en cascada.
    """
    cuenta = db.query(Cuenta).filter(Cuenta.cuenta_id == cuenta_id).first()
    if not cuenta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cuenta no encontrada"
        )
    
    db.delete(cuenta)
    db.commit()
    
    return None

@router.get("/usuario/{usuario_id}/resumen")
async def obtener_resumen_cuentas(usuario_id: int, db: Session = Depends(get_db)):
    """
    Obtener un resumen de todas las cuentas de un usuario.
    
    Retorna el saldo total, cantidad de cuentas activas y desglose por tipo.
    """
    # Verificar que el usuario existe
    usuario = db.query(Usuario).filter(Usuario.usuario_id == usuario_id).first()
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    cuentas = db.query(Cuenta).filter(Cuenta.usuario_id == usuario_id).all()
    
    total_saldo = sum(
        float(c.saldo_actual) for c in cuentas 
        if c.activa and c.incluir_en_total
    )
    
    cuentas_activas = sum(1 for c in cuentas if c.activa)
    
    por_tipo = {}
    for cuenta in cuentas:
        if cuenta.activa:
            if cuenta.tipo_cuenta not in por_tipo:
                por_tipo[cuenta.tipo_cuenta] = {
                    "cantidad": 0,
                    "saldo_total": 0
                }
            por_tipo[cuenta.tipo_cuenta]["cantidad"] += 1
            por_tipo[cuenta.tipo_cuenta]["saldo_total"] += float(cuenta.saldo_actual)
    
    return {
        "usuario_id": usuario_id,
        "total_cuentas": len(cuentas),
        "cuentas_activas": cuentas_activas,
        "saldo_total": total_saldo,
        "moneda": usuario.moneda_principal,
        "desglose_por_tipo": por_tipo
    }
