from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes import usuarios, cuentas

app = FastAPI(
    title="ChenChen API",
    description="API para gestión de finanzas personales",
    version="0.1.0"
)

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir routers
app.include_router(usuarios.router)
app.include_router(cuentas.router)

@app.get("/")
async def root():
    return {"message": "Bienvenido a ChenChen API"}

@app.get("/health")
async def health_check():
    return {"status": "ok"}
