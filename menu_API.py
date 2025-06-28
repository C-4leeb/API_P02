from fastapi import FastAPI
from reservaciones import router as reservaciones_router
from clientes import router as clientes_router
from habitaciones import router as habitaciones_router
from pagos import router as pagos_router
from servicios import router as servicios_router
app = FastAPI()

app.include_router(reservaciones_router)
app.include_router(clientes_router)
app.include_router(habitaciones_router)
app.include_router(pagos_router)
app.include_router(servicios_router)