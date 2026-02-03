from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from api.database import get_db
from api.models.transaccion import Transaccion
from api.schemas.transaccion import TransaccionCreate, TransaccionUpdate, TransaccionResponse
from typing import List, Optional

router = APIRouter(prefix="/transacciones", tags=["transacciones"])

@router.get("/", response_model=List[TransaccionResponse])
def obtener_transacciones(
    skip: int = Query(0, ge=0, description="Número de registros a omitir"),
    limit: int = Query(10, ge=1, le=300, description="Número máximo de registros a retornar"),
    usuario_id: Optional[int] = Query(None, description="Filtrar por ID de usuario"),
    cuenta_id: Optional[int] = Query(None, description="Filtrar por ID de cuenta"),
    db: Session = Depends(get_db)
):
    """
    Obtener todas las transacciones con filtros opcionales.

    Parámetros de consulta:
    - **skip**: Registros a omitir (paginación)
    - **limit**: Límite de registros
    - **usuario_id**: Filtrar por ID de usuario
    - **cuenta_id**: Filtrar por ID de cuenta
    """
    query = db.query(Transaccion)

    if usuario_id is not None:
        query = query.filter(Transaccion.usuario_id == usuario_id)

    if cuenta_id is not None:
        query = query.filter(Transaccion.cuenta_id == cuenta_id)
    
    transacciones = query.order_by(Transaccion.fecha.desc()).offset(skip).limit(limit).all()
    return transacciones

@router.get("/{transaccion_id}", response_model=TransaccionResponse)
def obtener_transaccion(transaccion_id: int, db: Session = Depends(get_db)):
    """
    Obtener una transacción específica por ID.
    """
    transaccion = db.query(Transaccion).filter(Transaccion.transaccion_id == transaccion_id).first()
    if not transaccion:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transacción no encontrada"
        )
    return transaccion

@router.post("/", response_model=TransaccionResponse, status_code=status.HTTP_201_CREATED)
def crear_transaccion(transaccion: TransaccionCreate, db: Session = Depends(get_db)):
    """
    Crear una nueva transacción.
    """
    nueva_transaccion = Transaccion(**transaccion.model_dump())
    db.add(nueva_transaccion)
    db.commit()
    db.refresh(nueva_transaccion)

    return nueva_transaccion

@router.put("/{transaccion_id}", response_model=TransaccionResponse)
def actualizar_transaccion(transaccion_id: int, transaccion_update: TransaccionUpdate, db: Session = Depends(get_db)):
    """
    Actualizar una transacción existente.
    Solo se actualizarán los campos proporcionados.
    """
    transaccion_db = db.query(Transaccion).filter(Transaccion.transaccion_id == transaccion_id).first()
    if not transaccion_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transacción no encontrada"
        )
    
    datos_actualizados = transaccion_update.model_dump(exclude_unset=True)
    
    for campo, valor in datos_actualizados.items():
        setattr(transaccion_db, campo, valor)

    db.commit()
    db.refresh(transaccion_db)

    return transaccion_db

@router.delete("/{transaccion_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_transaccion(transaccion_id: int, db: Session = Depends(get_db)):
    """
    Eliminar una transacción por ID.
    """
    transaccion = db.query(Transaccion).filter(Transaccion.transaccion_id == transaccion_id).first()
    if not transaccion:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transacción no encontrada"
        )
    
    db.delete(transaccion)
    db.commit()

    return