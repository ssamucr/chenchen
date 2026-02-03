from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from api.database import get_db
from api.models.categoria import Categoria
from api.schemas.categoria import CategoriaCreate, CategoriaResponse, CategoriaUpdate
from typing import List, Optional

router = APIRouter(prefix="/categorias", tags=["categorias"])

@router.get("/", response_model=List[CategoriaResponse])
async def listar_categorias(
    tipo_transaccion: Optional[str] = Query(None, description="Filtrar por tipo de transacción (INGRESO, GASTO, TRANSFERENCIA, AJUSTE)"),
    db: Session = Depends(get_db)
):
    """
    Listar todas las categorías. Opcionalmente filtrar por tipo de transacción.
    """
    query = db.query(Categoria)
    if tipo_transaccion:
        query = query.filter(Categoria.tipo_transaccion == tipo_transaccion)
    categorias = query.all()
    return categorias

@router.get("/{categoria_id}", response_model=CategoriaResponse)
async def obtener_categoria(categoria_id: int, db: Session = Depends(get_db)):
    """
    Obtener una categoría específica por ID.
    """
    categoria = db.query(Categoria).filter(Categoria.categoria_id == categoria_id).first()
    if not categoria:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoría no encontrada"
        )
    return categoria

@router.post("/", response_model=CategoriaResponse, status_code=status.HTTP_201_CREATED)
async def crear_categoria(
    nueva_categoria: CategoriaCreate,
    db: Session = Depends(get_db)
):
    """
    Crear una nueva categoría.
    """
    categoria = Categoria(**nueva_categoria.model_dump())
    db.add(categoria)
    db.commit()
    db.refresh(categoria)
    return categoria

@router.put("/{categoria_id}", response_model=CategoriaResponse)
async def actualizar_categoria(
    categoria_id: int,
    categoria_update: CategoriaUpdate,
    db: Session = Depends(get_db)
):
    """
    Actualizar una categoría existente.
    """
    categoria = db.query(Categoria).filter(Categoria.categoria_id == categoria_id).first()
    if not categoria:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoría no encontrada"
        )
    
    datos_actualizados = categoria_update.model_dump(exclude_unset=True)
    for campo, valor in datos_actualizados.items():
        setattr(categoria, campo, valor)
    
    db.commit()
    db.refresh(categoria)
    return categoria

@router.delete("/{categoria_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_categoria(categoria_id: int, db: Session = Depends(get_db)):
    """
    Eliminar una categoría por ID.
    """
    categoria = db.query(Categoria).filter(Categoria.categoria_id == categoria_id).first()
    if not categoria:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoría no encontrada"
        )
    
    db.delete(categoria)
    db.commit()
    return