from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from datetime import date
from conexion_BD import get_connection
import psycopg2.extras

router = APIRouter()

# Modelo de entrada para POST y PUT
class ClienteRequest(BaseModel):
    nombre: str
    email: str         
    telefono: str
    documento_identidad: str
    nacionalidad: str
    fecha_nacimiento: date 
    contratos: str
    facturacion_electronica: str

# Crear cliente
@router.post("/cliente")
def crear_cliente(data: ClienteRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL crear_cliente(%s, %s, %s, %s, %s, %s, %s, %s);
        """, (
            data.documento_identidad,
            data.nombre,
            data.nacionalidad,
            data.telefono,
            data.email,
            data.contratos,
            data.facturacion_electronica,
            data.fecha_nacimiento
        ))
        conn.commit()
        return {"mensaje": "Cliente creado exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

# Obtener cliente individual
@router.get("/cliente/{id_cliente}")
def obtener_cliente(id_cliente: str):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("SELECT * FROM obtener_cliente(%s);", (id_cliente,))
        cliente = cur.fetchone()
        if not cliente:
            raise HTTPException(status_code=404, detail="Cliente no encontrado")
        return cliente
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

# Actualizar cliente
@router.put("/cliente/{id_cliente}")
def actualizar_cliente(id_cliente: str, data: ClienteRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL actualizar_cliente(%s, %s, %s, %s, %s, %s);
        """, (
            id_cliente,
            data.nombre,
            data.nacionalidad,
            data.telefono,
            data.email,
            data.fecha_nacimiento
        ))
        conn.commit()
        return {"mensaje": "Cliente actualizado exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

# Eliminar cliente (solo si no tiene reservas activas)
@router.delete("/cliente/{id_cliente}")
def eliminar_cliente(id_cliente: str):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL eliminar_cliente(%s);
        """, (id_cliente,))
        conn.commit()
        return {"mensaje": "Cliente eliminado exitosamente"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

# Buscar clientes con filtros opcionales
@router.get("/cliente")
def listar_clientes(nombre: str = None, email: str = None, nacionalidad: str = None):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("SELECT * FROM filtrar_clientes(%s, %s, %s);", (nombre, email, nacionalidad))
        return cur.fetchall()
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()
