from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from conexion_BD import get_connection
from fastapi import APIRouter, HTTPException, Query
from typing import Optional
from datetime import date


router = APIRouter()

class PagoRequest(BaseModel):
    id_reserva: int
    tipo_pago: str  # tarjeta de credito, debito, transferencia, efectivo, billeteras digitales
    plataformas_integradas: str
    metodo_pago: str  # tarjeta, efectivo, transferencia
    factura: str
    recibo: str
    reembolso: int
    cargos_extra: str

@router.post("/pagos")
def registrar_pago(data: PagoRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            CALL registrar_pago(%s, %s, %s, %s, %s, %s, %s, %s);
        """, (
            data.id_reserva,
            data.tipo_pago,
            data.plataformas_integradas,
            data.metodo_pago,
            data.factura,
            data.recibo,
            data.reembolso,
            data.cargos_extra
        ))
        conn.commit()
        return {"mensaje": f"Pago registrado y reserva {data.id_reserva} actualizada a 'Confirmada'"}
    except Exception as e:
        conn.rollback()
        if 'No se encontró cliente asociado' in str(e):
            raise HTTPException(status_code=404, detail="Reserva sin cliente asociado")
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

router = APIRouter()

@router.get("/pagos/{id}")
def obtener_pago_por_id(id: int):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("SELECT * FROM obtener_pago(%s);", (id,))
        pago = cur.fetchone()
        if not pago:
            raise HTTPException(status_code=404, detail="Pago no encontrado")
        
        columnas = [desc[0] for desc in cur.description]
        resultado = dict(zip(columnas, pago))
        return resultado
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@router.get("/pagos")
def obtener_pagos(
    id_cliente: Optional[str] = Query(None, alias="id_cliente"),
    fecha_pago: Optional[date] = Query(None),
    metodo_pago: Optional[str] = Query(None)
):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SET search_path TO sch_reservas_hotel;")
        cur.execute("""
            SELECT * FROM filtrar_pagos(%s, %s, %s);
        """, (id_cliente, fecha_pago, metodo_pago))
        pagos = cur.fetchall()
        columnas = [desc[0] for desc in cur.description]
        resultados = [dict(zip(columnas, fila)) for fila in pagos]
        return resultados
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()