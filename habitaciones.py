from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from typing import Optional, List
from conexion_BD import get_connection
import psycopg2.extras

router = APIRouter()

class HabitacionRequest(BaseModel):
    numero: int
    tipo: str
    descripcion: str
    disponibilidad: str
    caracteristicas: str
    temporada: str
    promociones_especiales: str
    precio_noche: float

class HabitacionUpdateRequest(BaseModel):
    tipo: str
    descripcion: str
    disponibilidad: str
    precio_noche: float

@router.post("/habitaciones")
def crear_habitacion(data: HabitacionRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL crear_habitacion(%s, %s, %s, %s, %s, %s, %s, %s);
        """, (
            data.numero,
            data.tipo,
            data.descripcion,
            data.disponibilidad,
            data.caracteristicas,
            data.temporada,
            data.promociones_especiales,
            data.precio_noche
        ))
        conn.commit()
        return {"mensaje": "Habitación creada exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.get("/habitaciones/{id_habitacion}")
def obtener_habitacion(id_habitacion: int):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("SELECT * FROM obtener_habitacion(%s);", (id_habitacion,))
        habitacion = cur.fetchone()
        if not habitacion:
            raise HTTPException(status_code=404, detail="Habitación no encontrada")
        return habitacion
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.put("/habitaciones/{id_habitacion}")
def actualizar_habitacion(id_habitacion: int, data: HabitacionUpdateRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL actualizar_habitacion(%s, %s, %s, %s, %s);
        """, (
            id_habitacion,
            data.tipo,
            data.descripcion,
            data.precio_noche,
            data.disponibilidad
        ))
        conn.commit()
        return {"mensaje": "Habitación actualizada exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.delete("/habitaciones/{id_habitacion}")
def eliminar_habitacion(id_habitacion: int):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("CALL eliminar_habitacion(%s);", (id_habitacion,))
        conn.commit()
        return {"mensaje": "Habitación eliminada exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.get("/habitaciones")
def listar_habitaciones(
    tipo: Optional[str] = Query(None),
    precio_maximo: Optional[float] = Query(None),
    disponibilidad: Optional[str] = Query(None)
):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("SELECT * FROM filtrar_habitaciones(%s, %s, %s);", (tipo, precio_maximo, disponibilidad))
        habitaciones = cur.fetchall()
        return habitaciones
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()
