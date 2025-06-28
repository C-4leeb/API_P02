from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from conexion_BD import get_connection
from datetime import time
import psycopg2.extras
from typing import Optional
from fastapi import Query

router = APIRouter()

class ServicioRequest(BaseModel):
    documento_identidad: str  # obligatorio por FK
    nombre_servicio: str
    disponible: bool
    horario: time
    precio_unitario: float
    promociones: str
    servicios_extra: str
    ofertas_personalizadas: str

@router.post("/servicios")
def crear_servicio(data: ServicioRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL crear_servicio(%s, %s, %s, %s, %s, %s, %s, %s);
        """, (
            data.documento_identidad,
            data.nombre_servicio,
            data.disponible,
            data.horario,
            data.precio_unitario,
            data.promociones,
            data.servicios_extra,
            data.ofertas_personalizadas
        ))
        conn.commit()
        return {"mensaje": "Servicio registrado exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()


class ServicioUpdateRequest(BaseModel):
    nombre: str
    disponible: bool
    precio: float
    promociones: str
    servicios_extra: str
    ofertas_personalizadas: str


@router.put("/servicios/{id_servicio}")
def actualizar_servicio(id_servicio: int, data: ServicioUpdateRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL actualizar_servicio(%s, %s, %s, %s, %s, %s, %s);
        """, (
            id_servicio,
            data.nombre,
            data.disponible,
            data.precio,
            data.promociones,
            data.servicios_extra,
            data.ofertas_personalizadas
        ))
        conn.commit()
        return {"mensaje": f"Servicio {id_servicio} actualizado exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.delete("/servicios/{id_servicio}")
def eliminar_servicio(id_servicio: int):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("CALL eliminar_servicio(%s);", (id_servicio,))
        conn.commit()
        return {"mensaje": f"Servicio {id_servicio} eliminado exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.get("/servicios/{id_servicio}")
def obtener_servicio(id_servicio: int):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("SELECT * FROM obtener_servicio(%s);", (id_servicio,))
        servicio = cur.fetchone()
        if not servicio:
            raise HTTPException(status_code=404, detail="Servicio no encontrado")
        return servicio
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.get("/servicios")
def listar_servicios(disponible: Optional[bool] = Query(None)):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("SELECT * FROM filtrar_servicios(%s);", (disponible,))
        servicios = cur.fetchall()
        return servicios
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()