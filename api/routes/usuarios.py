from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from api.database import get_db
from api.models.usuario import Usuario
from api.schemas.usuario import UsuarioCreate, UsuarioResponse
from typing import List
import bcrypt

router = APIRouter(prefix="/usuarios", tags=["usuarios"])

def hash_password(password: str) -> str:
    """Hash de contraseña usando bcrypt"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verificar contraseña"""
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

@router.post("/", response_model=UsuarioResponse, status_code=status.HTTP_201_CREATED)
async def crear_usuario(usuario: UsuarioCreate, db: Session = Depends(get_db)):
    """
    Crear un nuevo usuario
    """
    # Verificar si el email ya existe
    db_usuario = db.query(Usuario).filter(Usuario.email == usuario.email).first()
    if db_usuario:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El email ya está registrado"
        )
    
    # Crear el nuevo usuario
    nuevo_usuario = Usuario(
        email=usuario.email,
        nombre=usuario.nombre,
        apellido=usuario.apellido,
        password_hash=hash_password(usuario.password),
        moneda_principal=usuario.moneda_principal,
        zona_horaria=usuario.zona_horaria,
        idioma=usuario.idioma
    )
    
    db.add(nuevo_usuario)
    db.commit()
    db.refresh(nuevo_usuario)
    
    return nuevo_usuario

@router.get("/", response_model=List[UsuarioResponse])
async def obtener_usuarios(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """
    Obtener todos los usuarios con paginación
    """
    usuarios = db.query(Usuario).offset(skip).limit(limit).all()
    return usuarios

@router.get("/{usuario_id}", response_model=UsuarioResponse)
async def obtener_usuario(usuario_id: int, db: Session = Depends(get_db)):
    """
    Obtener un usuario específico por ID
    """
    usuario = db.query(Usuario).filter(Usuario.usuario_id == usuario_id).first()
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    return usuario
