set search_path to sch_reservas_hotel;

-- CLIENTES

--crear cliente
CREATE OR REPLACE PROCEDURE crear_cliente(
    p_documento_identidad VARCHAR,
    p_nombre VARCHAR,
    p_nacionalidad VARCHAR,
    p_telefono VARCHAR,
    p_correo VARCHAR,
    p_contratos TEXT,
    p_facturacion_electronica TEXT,
    p_fecha_nacimiento DATE  
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar formato de correo
    IF NOT (p_correo ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
        RAISE EXCEPTION 'Formato de correo inválido: %', p_correo;
    END IF;

    -- Validar que la fecha no sea futura
    IF p_fecha_nacimiento > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de nacimiento es inválida: %', p_fecha_nacimiento;
    END IF;

    -- Verificar existencia del cliente
    IF EXISTS (SELECT 1 FROM cliente WHERE documento_identidad = p_documento_identidad) THEN
        RAISE EXCEPTION 'Ya existe un cliente con el documento %', p_documento_identidad;
    END IF;

    -- Insertar en cliente
    INSERT INTO cliente (
        documento_identidad, nombre, nacionalidad, telefono, correo, fecha_nacimiento
    ) VALUES (
        p_documento_identidad, p_nombre, p_nacionalidad, p_telefono, p_correo, p_fecha_nacimiento
    );

    -- Insertar en documentos (usa el mismo documento como clave foránea)
    INSERT INTO documentos (
        copia_pasaporte, contratos, facturacion_electronica
    ) VALUES (
        p_documento_identidad, p_contratos, p_facturacion_electronica
    );

    RAISE NOTICE 'Cliente % creado correctamente con documentos vinculados.', p_documento_identidad;
END;
$$;

--obtener cliente
CREATE OR REPLACE FUNCTION obtener_cliente(p_documento_identidad VARCHAR)
RETURNS TABLE (
    documento_identidad VARCHAR,
    nombre VARCHAR,
    nacionalidad VARCHAR,
    telefono VARCHAR,
    correo VARCHAR,
    fecha_nacimiento DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Retorna los datos del cliente que coincida con el documento
    RETURN QUERY
    SELECT 
        c.documento_identidad,         
        c.nombre,                      
        c.nacionalidad,                
        c.telefono,                    
        c.correo,                      
        c.fecha_nacimiento
    FROM cliente c
    WHERE c.documento_identidad = p_documento_identidad;
END;
$$;

-- Actualizar cliente existente
CREATE OR REPLACE PROCEDURE actualizar_cliente(
    p_documento_identidad VARCHAR,
    p_nombre VARCHAR,
    p_nacionalidad VARCHAR,
    p_telefono VARCHAR,
    p_correo VARCHAR,
    p_fecha_nacimiento DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verificar si el cliente existe
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE documento_identidad = p_documento_identidad) THEN
        RAISE EXCEPTION 'Cliente con documento % no existe.', p_documento_identidad;
    END IF;

    -- Validar formato de correo electrónico usando expresión regular
    IF NOT (p_correo ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
        RAISE EXCEPTION 'Formato de correo invalido: %', p_correo;
    END IF;

    -- Validar que la fecha de nacimiento no sea futura
    IF p_fecha_nacimiento > CURRENT_DATE THEN
        RAISE EXCEPTION 'Fecha de nacimiento invalida: %', p_fecha_nacimiento;
    END IF;

    -- Realizar la actualización del cliente
    UPDATE cliente
    SET nombre = p_nombre,
        nacionalidad = p_nacionalidad,
        telefono = p_telefono,
        correo = p_correo,
        fecha_nacimiento = p_fecha_nacimiento
    WHERE documento_identidad = p_documento_identidad;

    -- Confirmacion 
    RAISE NOTICE 'Cliente % actualizado correctamente.', p_documento_identidad;
END;
$$;


-- Eliminar cliente si no tiene reservaciones activas
CREATE OR REPLACE PROCEDURE eliminar_cliente(
    p_documento_identidad VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verifica si el cliente tiene reservas activas
    IF EXISTS (
        SELECT 1 FROM reserva
        WHERE documento_identidad = p_documento_identidad
          AND CURRENT_DATE <= fecha_salida
    ) THEN
        RAISE EXCEPTION 'No se puede eliminar el cliente con reservas activas.';
    END IF;

    -- Elimina primero los documentos asociados
    DELETE FROM documentos
    WHERE copia_pasaporte = p_documento_identidad;

    -- Luego elimina el cliente
    DELETE FROM cliente
    WHERE documento_identidad = p_documento_identidad;

    RAISE NOTICE 'Cliente % eliminado correctamente.', p_documento_identidad;
END;
$$;

CALL sch_reservas_hotel.eliminar_cliente('1122334455');

--Filtros opcionales
CREATE OR REPLACE FUNCTION filtrar_clientes(
--parametros opcionales
    p_nombre VARCHAR DEFAULT NULL,
    p_correo VARCHAR DEFAULT NULL,
    p_nacionalidad VARCHAR DEFAULT NULL
)
--datos que devolvera
RETURNS TABLE (
    documento_identidad VARCHAR,
    nombre VARCHAR,
    nacionalidad VARCHAR,
    telefono VARCHAR,
    correo VARCHAR,
    ID_pago INT,
    fecha_nacimiento DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c.documento_identidad, c.nombre, c.nacionalidad, c.telefono, c.correo, c.ID_pago, c.fecha_nacimiento
    FROM cliente c -- Se hace alias 'c' a la tabla cliente para evitar ambigüedades
	
    -- Se aplican filtros solo si los parámetros no son NULL
    -- Se usa ILIKE para permitir búsquedas insensibles a mayúsculas/minúsculas
    WHERE (p_nombre IS NULL OR c.nombre ILIKE '%' || p_nombre || '%')
      AND (p_correo IS NULL OR c.correo ILIKE '%' || p_correo || '%')
      AND (p_nacionalidad IS NULL OR c.nacionalidad ILIKE '%' || p_nacionalidad || '%');
END;
$$;

--HABITACIONES

--Crear habitaciones
CREATE OR REPLACE PROCEDURE crear_habitacion(
    p_numero INT,
    p_tipo VARCHAR,
    p_descripcion TEXT,
    p_disponibilidad VARCHAR,
    p_caracteristicas TEXT,
    p_temporada VARCHAR,
    p_promociones_especiales VARCHAR,
    p_precio_noche NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_costos INT;
    v_id_evento INT;
BEGIN
    -- Insertar en costos usando los valores definidos por el usuario
    INSERT INTO costos (temporada, promociones_especiales, precio_noche)
    VALUES (p_temporada, p_promociones_especiales, p_precio_noche)
    RETURNING id_costos INTO v_id_costos;

    -- Insertar en eventos con valores por defecto
    INSERT INTO eventos (habitacion_VIP, bloqueo_por_eventos, grupos)
    VALUES (FALSE, FALSE, FALSE)
    RETURNING ID_evento INTO v_id_evento;

    -- Insertar en habitacion
    INSERT INTO habitacion (numero, tipo, descripcion, disponibilidad, caracteristicas, id_costos, id_evento)
    VALUES (p_numero, p_tipo, p_descripcion, p_disponibilidad, p_caracteristicas, v_id_costos, v_id_evento);

    RAISE NOTICE 'Habitación creada exitosamente con costo % y evento %', v_id_costos, v_id_evento;
END;
$$;

CALL crear_habitacion(

  777,
  'doble',
  'al frente de la casa presidencia',
  'libre',
  'rosada',
  'temporada alta',
  '2x1 para nacionales',
  120000.00
);

--Consultar habitacion 
CREATE OR REPLACE FUNCTION obtener_habitacion(p_id_habitacion INT)
RETURNS TABLE (
    id_habitacion INT,
    numero INT,
    tipo VARCHAR,
    disponibilidad VARCHAR,
    descripcion TEXT,
    caracteristicas TEXT,
    precio_noche NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.id_habitacion,
        h.numero,
        h.tipo,
        h.disponibilidad,
        h.descripcion,
        h.caracteristicas,
        c.precio_noche
    FROM habitacion h
    JOIN costos c ON h.id_costos = c.id_costos
    WHERE h.id_habitacion = p_id_habitacion;
END;
$$;

--Actualizar habitaciones:

CREATE OR REPLACE PROCEDURE actualizar_habitacion(
    p_id_habitacion INT,
    p_tipo VARCHAR,
    p_descripcion TEXT,
    p_precio_noche NUMERIC,
    p_disponibilidad VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar existencia
    IF NOT EXISTS (SELECT 1 FROM habitacion WHERE id_habitacion = p_id_habitacion) THEN
        RAISE EXCEPTION 'La habitación % no existe.', p_id_habitacion;
    END IF;

    -- Actualizar tabla habitacion
    UPDATE habitacion
    SET tipo = p_tipo,
        descripcion = p_descripcion,
        disponibilidad = p_disponibilidad
    WHERE id_habitacion = p_id_habitacion;

    -- Actualizar precio en tabla costos
    UPDATE costos
    SET precio_noche = p_precio_noche
    WHERE id_costos = (
        SELECT id_costos FROM habitacion WHERE id_habitacion = p_id_habitacion
    );
END;
$$;


--Eliminar habitacion
call eliminar_habitacion();

CREATE OR REPLACE PROCEDURE eliminar_habitacion(
    p_id_habitacion INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_costos INT;
    v_id_evento INT;
BEGIN
    -- Verificar existencia
    IF NOT EXISTS (SELECT 1 FROM habitacion WHERE id_habitacion = p_id_habitacion) THEN
        RAISE EXCEPTION 'La habitación % no existe.', p_id_habitacion;
    END IF;

    -- Obtener los IDs relacionados
    SELECT id_costos, id_evento
    INTO v_id_costos, v_id_evento
    FROM habitacion
    WHERE id_habitacion = p_id_habitacion;

    -- Eliminar la habitación
    DELETE FROM habitacion
    WHERE id_habitacion = p_id_habitacion;

    -- Eliminar el costo de la habitacion
    IF NOT EXISTS (SELECT 1 FROM habitacion WHERE id_costos = v_id_costos) THEN
        DELETE FROM costos WHERE id_costos = v_id_costos;
    END IF;

    -- Eliminar el eventos de la habitacion
    IF NOT EXISTS (SELECT 1 FROM habitacion WHERE id_evento = v_id_evento) THEN
        DELETE FROM eventos WHERE ID_evento = v_id_evento;
    END IF;

    RAISE NOTICE 'Habitación % eliminada correctamente.', p_id_habitacion;
END;
$$;

--Filtros de busqueda
CREATE OR REPLACE FUNCTION filtrar_habitaciones(
--parametros de filtro
    p_tipo VARCHAR DEFAULT NULL,
    p_precio_maximo NUMERIC DEFAULT NULL,
    p_disponibilidad VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id_habitacion INT,
    numero INT,
    tipo VARCHAR,
    disponibilidad VARCHAR,
    descripcion TEXT,
    caracteristicas TEXT,
    precio_noche NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.id_habitacion,
        h.numero,
        h.tipo,
        h.disponibilidad,
        h.descripcion,
        h.caracteristicas,
        c.precio_noche
    FROM habitacion h
    JOIN costos c ON h.id_costos = c.id_costos
    WHERE (p_tipo IS NULL OR h.tipo = p_tipo)
      AND (p_precio_maximo IS NULL OR c.precio_noche <= p_precio_maximo)
      AND (p_disponibilidad IS NULL OR h.disponibilidad = p_disponibilidad);
END;
$$;

--RESERVAS

--Consulta de reservas por ID
CREATE OR REPLACE FUNCTION obtener_reservacion(p_id_reserva INT)
RETURNS TABLE (
    id_reserva INT,
    numero_huespedes INT,
    solicitudes_especial TEXT,
    tipo_reserva VARCHAR,
    tipo_confirmacion VARCHAR,
    fecha_entrada DATE,
    fecha_salida DATE,
    id_politicas INT,
    id_habitacion INT,
    documento_identidad VARCHAR
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id_reserva,
        r.numero_huespedes,
        r.solicitudes_especial,
        r.tipo_reserva,
        r.tipo_confirmacion,
        r.fecha_entrada,
        r.fecha_salida,
        r.id_politicas,
        r.id_habitacion,
        r.documento_identidad
    FROM reserva r
    WHERE r.id_reserva = p_id_reserva;
END;
$$ LANGUAGE plpgsql;

--Actualizar reservas

CREATE OR REPLACE PROCEDURE actualizar_reservacion(
    p_id_reserva INT,
    p_fecha_entrada DATE,
    p_fecha_salida DATE,
    p_numero_huespedes INT,
    p_solicitudes_especial TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validación de existencia
    IF NOT EXISTS (SELECT 1 FROM reserva WHERE id_reserva = p_id_reserva) THEN
        RAISE EXCEPTION 'No existe la reserva con ID %', p_id_reserva;
    END IF;

    -- Actualización
    UPDATE reserva
    SET
        fecha_entrada = p_fecha_entrada,
        fecha_salida = p_fecha_salida,
        numero_huespedes = p_numero_huespedes,
        solicitudes_especial = p_solicitudes_especial
    WHERE id_reserva = p_id_reserva;
END;
$$;

--Consultar reservas filtros opcionales:

CREATE OR REPLACE FUNCTION filtrar_reservas(
    p_documento_identidad VARCHAR DEFAULT NULL,
    p_fecha_entrada DATE DEFAULT NULL
)
RETURNS TABLE (
    id_reserva INT,
    numero_huespedes INT,
    solicitudes_especial TEXT,
    tipo_reserva VARCHAR,
    tipo_confirmacion VARCHAR,
    fecha_entrada DATE,
    fecha_salida DATE,
    id_politicas INT,
    id_habitacion INT,
    documento_identidad VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id_reserva,
        r.numero_huespedes,
        r.solicitudes_especial,
        r.tipo_reserva,
        r.tipo_confirmacion,
        r.fecha_entrada,
        r.fecha_salida,
        r.id_politicas,
        r.id_habitacion,
        r.documento_identidad
    FROM reserva r
    WHERE
        (p_documento_identidad IS NULL OR r.documento_identidad = p_documento_identidad)
        AND
        (p_fecha_entrada IS NULL OR r.fecha_entrada = p_fecha_entrada);
END;
$$ LANGUAGE plpgsql;



--PAGOS

CREATE OR REPLACE PROCEDURE registrar_pago(
    p_id_reserva INT,
    p_tipo_pago VARCHAR,
    p_plataformas_integradas VARCHAR,
    p_metodo_pago VARCHAR,
    p_factura VARCHAR,
    p_recibo VARCHAR,
    p_reembolso INT,
    p_cargos_extra VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insertar el pago
    INSERT INTO pago (
        tipo_pago, plataformas_integradas, metodo_pago, factura,
        recibo, reembolso, cargos_extra, ID_reserva
    ) VALUES (
        p_tipo_pago, p_plataformas_integradas, p_metodo_pago,
        p_factura, p_recibo, p_reembolso, p_cargos_extra, p_id_reserva
    );

    -- Actualizar el estado de la reserva
    CALL ActualizarEstadoPago(p_id_reserva);
END;
$$;

call crear_servicio(

)
--SERVICIOS
CREATE OR REPLACE PROCEDURE crear_servicio(
    p_documento_identidad VARCHAR,
    p_nombre VARCHAR,
    p_disponible BOOLEAN,
    p_horario TIME,
    p_precio DECIMAL,
    p_promociones TEXT,
    p_servicios_extra TEXT,
    p_ofertas_personalizadas TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO servicios (
        documento_identidad, nombre, disponibilidad, horario,
        precio, promociones, servicios_extra, ofertas_personalizadas
    ) VALUES (
        p_documento_identidad, p_nombre, p_disponible, p_horario,
        p_precio, p_promociones, p_servicios_extra, p_ofertas_personalizadas
    );
END;
$$;

CREATE OR REPLACE PROCEDURE actualizar_servicio(
    p_id_servicio INT,
    p_nombre VARCHAR,
    p_disponible BOOLEAN,
    p_precio DECIMAL,
    p_promociones TEXT,
    p_servicios_extra TEXT,
    p_ofertas_personalizadas TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE servicios
    SET 
        nombre = p_nombre,
        disponibilidad = p_disponible,
        precio = p_precio,
        promociones = p_promociones,
        servicios_extra = p_servicios_extra,
        ofertas_personalizadas = p_ofertas_personalizadas
    WHERE id_servicio = p_id_servicio;
END;
$$;

CREATE OR REPLACE PROCEDURE eliminar_servicio(
    p_id_servicio INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM servicios
    WHERE id_servicio = p_id_servicio;
END;
$$;


CREATE OR REPLACE FUNCTION obtener_servicio(p_id_servicio INT)
RETURNS TABLE (
    id_servicio INT,
    documento_identidad VARCHAR,
    nombre VARCHAR,
    disponibilidad BOOLEAN,
    horario TIME,
    precio DECIMAL(10,2),
    promociones TEXT,
    servicios_extra TEXT,
    ofertas_personalizadas TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id_servicio,
        s.documento_identidad,
        s.nombre,
        s.disponibilidad,
        s.horario,
        s.precio,
        s.promociones,
        s.servicios_extra,
        s.ofertas_personalizadas
    FROM servicios s
    WHERE s.id_servicio = p_id_servicio;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION filtrar_servicios(p_filtro_disponible BOOLEAN DEFAULT NULL)
RETURNS TABLE (
    id_servicio INT,
    documento_identidad VARCHAR,
    nombre VARCHAR,
    disponibilidad BOOLEAN,
    horario TIME,
    precio DECIMAL(10,2),
    promociones TEXT,
    servicios_extra TEXT,
    ofertas_personalizadas TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id_servicio,
        s.documento_identidad,
        s.nombre,
        s.disponibilidad,
        s.horario,
        s.precio,
        s.promociones,
        s.servicios_extra,
        s.ofertas_personalizadas
    FROM servicios s
    WHERE p_filtro_disponible IS NULL OR s.disponibilidad = p_filtro_disponible;
END;
$$ LANGUAGE plpgsql;

