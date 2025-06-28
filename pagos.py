from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from conexion_BD import get_connection

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
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()