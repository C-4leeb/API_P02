from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from conexion_BD import get_connection
from datetime import date
import psycopg2.extras
from fastapi import Query
from typing import Optional

router = APIRouter()

class ReservacionRequest(BaseModel):
    numero_huespedes: int
    tipo_habitacion: str
    id_politicas: int
    documento_identidad: str
    fecha_entrada: date
    fecha_salida: date
    tipo_reserva: str
    tipo_confirmacion: str
    solicitudes_especial: str = None



@router.post("/reservaciones")
def crear_reservacion(data: ReservacionRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;") 
        cur.execute("""
            CALL sch_reservas_hotel.crear_reservacion(%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            data.numero_huespedes,
            data.tipo_habitacion,
            data.id_politicas,
            data.documento_identidad,
            data.fecha_entrada,
            data.fecha_salida,
            data.tipo_reserva,
            data.tipo_confirmacion,
            data.solicitudes_especial
        ))
        conn.commit()
        print(f"Reserva creada para {data.documento_identidad} del {data.fecha_entrada} al {data.fecha_salida}")
        return {"mensaje": "Reservación creada exitosamente"}
    except Exception as e:
        conn.rollback()
        print("ERROR:", str(e))
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.get("/reservaciones/{id_reserva}")
def obtener_reservacion(id_reserva: int):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("SELECT * FROM obtener_reservacion(%s);", (id_reserva,))
        reservacion = cur.fetchone()
        if not reservacion:
            raise HTTPException(status_code=404, detail="Reservación no encontrada")
        return reservacion
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

class ReservacionUpdateRequest(BaseModel):
    fecha_entrada: date
    fecha_salida: date
    numero_huespedes: int
    solicitudes_especial: str = None

@router.put("/reservaciones/{id_reserva}")
def actualizar_reservacion(id_reserva: int, data: ReservacionUpdateRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL actualizar_reservacion(%s, %s, %s, %s, %s);
        """, (
            id_reserva,
            data.fecha_entrada,
            data.fecha_salida,
            data.numero_huespedes,
            data.solicitudes_especial
        ))
        conn.commit()
        return {"mensaje": f"Reservación {id_reserva} actualizada exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()


@router.delete("/reservaciones/{id_reserva}")
def cancelar_reservacion(id_reserva: int):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("CALL cancelar_reservacion(%s);", (id_reserva,))
        conn.commit()
        return {"mensaje": f"Reservación {id_reserva} cancelada exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()


@router.get("/reservaciones")
def listar_reservaciones(
    documento_identidad: Optional[str] = Query(None),
    fecha_entrada: Optional[date] = Query(None)
):
    print("Documento:", documento_identidad)
    print("Fecha:", fecha_entrada)
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            SELECT * FROM filtrar_reservas(%s, %s);
        """, (documento_identidad, fecha_entrada))
        resultados = cur.fetchall()
        return resultados
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()