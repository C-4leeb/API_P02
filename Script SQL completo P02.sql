create schema sch_reservas_hotel; 
set search_path to sch_reservas_hotel;

-- Tabla de costos
CREATE TABLE costos (
  id_costos SERIAL PRIMARY KEY,
  temporada VARCHAR(100),
  promociones_especiales VARCHAR(100),
  precio_noche NUMERIC(10,2) NOT NULL
);


-- Tabla eventos
CREATE TABLE eventos (
  ID_evento SERIAL PRIMARY KEY,
  habitacion_VIP BOOLEAN NOT NULL,
  bloqueo_por_eventos BOOLEAN NOT NULL,
  grupos BOOLEAN NOT NULL
);

-- Tabla de habitación
CREATE TABLE habitacion (
  id_habitacion SERIAL PRIMARY KEY, 
  numero INT NOT NULL,
  id_costos INT,
  FOREIGN KEY (id_costos) REFERENCES costos(id_costos),
  id_evento INT,  
  FOREIGN KEY (id_evento) REFERENCES eventos(ID_evento),
  tipo VARCHAR(100) NOT NULL CHECK (tipo IN ('sencilla', 'doble', 'suite')),
  disponibilidad VARCHAR(50) NOT NULL CHECK (disponibilidad IN ('libre', 'ocupada', 'en limpieza', 'en mantenimiento')), 
  descripcion TEXT NOT NULL, 
  caracteristicas TEXT NOT NULL
);


-- Tabla cliente
CREATE TABLE cliente (
  documento_identidad VARCHAR(50) PRIMARY KEY,
  nombre VARCHAR(100),
  nacionalidad VARCHAR(50),
  telefono VARCHAR(20),
  correo VARCHAR(100),
  ID_pago INT,
  fecha_nacimiento DATE
);


-- Tabla documentos
CREATE TABLE documentos (
  copia_pasaporte VARCHAR(100) PRIMARY KEY,
  contratos TEXT NOT NULL,
  facturacion_electronica TEXT NOT NULL,
  CONSTRAINT documentos_copia_pasaporte_fkey
    FOREIGN KEY (copia_pasaporte) REFERENCES cliente(documento_identidad)
);


CREATE TABLE programa_fidelizacion (
  documento_identidad VARCHAR(50) PRIMARY KEY,
  nivel_puntos INT NOT NULL,
  nivel_cliente VARCHAR(50) NOT NULL,
  beneficios TEXT NOT NULL,
  FOREIGN KEY (documento_identidad) REFERENCES cliente(documento_identidad)
);



-- Tabla de políticas de reserva
CREATE TABLE politicas_reserva (
  id_politicas SERIAL PRIMARY KEY,
  minimo_noches INT NOT NULL,
  penalizaciones_cancelación VARCHAR(100), 
  upgrades_automaticos BOOLEAN
);
 
-- Tabla reserva
CREATE TABLE reserva (
  ID_reserva SERIAL PRIMARY KEY,
  numero_huespedes INT NOT NULL,
  solicitudes_especial TEXT,
  tipo_reserva VARCHAR(50) NOT NULL CHECK (tipo_reserva IN ('individual', 'grupo', 'corporativa')),
  tipo_confirmacion VARCHAR(50) NOT NULL CHECK (tipo_confirmacion IN ('correo', 'app', 'teléfono')),
  fecha_entrada DATE NOT NULL,
  fecha_salida DATE NOT NULL,
  id_politicas INT,
  FOREIGN KEY (id_politicas) REFERENCES politicas_reserva(id_politicas),
  id_habitacion INT,
  FOREIGN KEY (id_habitacion) REFERENCES habitacion(id_habitacion),
  documento_identidad VARCHAR(50),
  FOREIGN KEY (documento_identidad) REFERENCES cliente(documento_identidad)
);

-- Tabla pago
CREATE TABLE pago (
  ID_pago SERIAL PRIMARY KEY,
  tipo_pago VARCHAR(100) NOT NULL CHECK (tipo_pago IN ('tarjeta de credito', 'debito', 'transferencia', 'efectivo', 'billeteras digitales')),
  plataformas_integradas VARCHAR(100) NOT NULL,
  metodo_pago VARCHAR(100) NOT NULL,
  factura VARCHAR(100) NOT NULL,
  recibo VARCHAR(100),
  reembolso INT,
  cargos_extra VARCHAR(100),
  ID_reserva INT,
  FOREIGN KEY (ID_reserva) REFERENCES reserva(ID_reserva)
);
--Agregando la relación (1:N) en pago
ALTER TABLE cliente
ADD CONSTRAINT fk_pago
FOREIGN KEY (ID_pago) REFERENCES pago(ID_pago);

-- Tabla servicios
CREATE TABLE servicios (
  id_servicio SERIAL PRIMARY KEY,
  documento_identidad VARCHAR(50) not null,
  nombre VARCHAR(100) not null,
  disponibilidad BOOLEAN not null,
  horario TIME not null,
  precio DECIMAL(10,2) not null,
  promociones TEXT not null,
  servicios_extra TEXT not null,
  ofertas_personalizadas TEXT not null,
  FOREIGN KEY (documento_identidad) REFERENCES cliente (documento_identidad)
);


--Relación 1:1 de clientes con preferencias (En el diagrama lo trabajamos diferente pero revisando nos parece más optimo así)
-- Tabla preferencias
CREATE TABLE preferencias (
  documento_identidad VARCHAR(50) PRIMARY KEY,
  tipo_habitacion_favorita VARCHAR(50) not null,
  alergias_alimenticias TEXT not null,
  solicitudes_especiales TEXT not null,
  FOREIGN KEY (documento_identidad) REFERENCES cliente(documento_identidad)
);

ALTER TABLE reserva
ADD COLUMN estado_reserva VARCHAR(50) DEFAULT 'Pendiente'
CHECK (estado_reserva IN ('Pendiente', 'Confirmada', 'Cancelada'));


-- Índice para búsquedas por documento del cliente
CREATE INDEX idx_reserva_documento_identidad ON reserva(documento_identidad);

-- Índice para búsquedas por fechas (para disponibilidad, filtros, reportes)
CREATE INDEX idx_reserva_fechas ON reserva(fecha_entrada, fecha_salida);

-- Índice por estado de la reserva (pendiente, confirmada, cancelada, etc.)
CREATE INDEX idx_reserva_estado ON reserva(estado_reserva);

-- Índice por habitación (útil para evitar overbooking y búsquedas por habitación)
CREATE INDEX idx_reserva_id_habitacion ON reserva(id_habitacion);

-- Creación de una tabla para registrar eventos importantes sobre las reservaciones.
-- Esto nos permitirá llevar trazabilidad de acciones como creación, cancelación, etc.
CREATE TABLE tabla_log_reservaciones (
    id_log SERIAL PRIMARY KEY, 

    id_reserva INT NOT NULL,   

    accion TEXT NOT NULL,      

    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    
    usuario TEXT,              

    detalle JSONB              
);


CREATE OR REPLACE PROCEDURE registrar_evento_reserva(
    p_id_reserva INT,
    p_accion TEXT,
    p_usuario TEXT,
    p_detalle JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO tabla_log_reservaciones (id_reserva, accion, usuario, detalle)
    VALUES (p_id_reserva, p_accion, p_usuario, p_detalle);
END;
$$;

--Procedimiento para crear nueva reservación
CREATE OR REPLACE PROCEDURE crear_reservacion(
    p_numero_huespedes INT,
    p_tipo_habitacion VARCHAR,
    p_id_politicas INT,
    p_documento_identidad VARCHAR,
    p_fecha_entrada DATE,
    p_fecha_salida DATE,
    p_tipo_reserva VARCHAR,
    p_tipo_confirmacion VARCHAR,
    p_solicitudes_especial TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_habitacion INT;
    v_id_reserva INT;
BEGIN
    -- Buscar una habitacion libre del tipo solicitado
    SELECT id_habitacion INTO v_id_habitacion
    FROM habitacion
    WHERE tipo = p_tipo_habitacion
      AND disponibilidad = 'libre'
    LIMIT 1;

    -- Si no hay habitaciones disponibles, lanzar error
    IF v_id_habitacion IS NULL THEN
        RAISE EXCEPTION 'No hay habitaciones disponibles de tipo %', p_tipo_habitacion;
    END IF;

    -- Insertar la nueva reserva
    INSERT INTO reserva(
        numero_huespedes, 
        solicitudes_especial,
        tipo_reserva,
        tipo_confirmacion,
        fecha_entrada,
        fecha_salida,
        id_politicas, 
        id_habitacion, 
        documento_identidad
    )
    VALUES (
        p_numero_huespedes, 
        p_solicitudes_especial,
        p_tipo_reserva,
        p_tipo_confirmacion,
        p_fecha_entrada,
        p_fecha_salida,
        p_id_politicas, 
        v_id_habitacion, 
        p_documento_identidad
    );

    -- Marcar habitacion como ocupada
    UPDATE habitacion
    SET disponibilidad = 'ocupada'
    WHERE id_habitacion = v_id_habitacion;

    -- Obtener el ID de la reserva recién creada
    SELECT id_reserva INTO v_id_reserva
	FROM reserva
	WHERE id_habitacion = v_id_habitacion
	  AND documento_identidad = p_documento_identidad
	ORDER BY id_reserva DESC
	LIMIT 1;
    -- Registrar en la bitácora
    CALL registrar_evento_reserva(
        v_id_reserva,
        'creación de reserva',
        p_documento_identidad,
        jsonb_build_object(
            'tipo_reserva', p_tipo_reserva,
            'tipo_confirmacion', p_tipo_confirmacion,
            'fecha_entrada', p_fecha_entrada,
            'fecha_salida', p_fecha_salida,
            'solicitudes', p_solicitudes_especial
        )
    );

    RAISE NOTICE 'Reserva creada exitosamente en habitacion %', v_id_habitacion;
END;
$$;


--Procedimiento para cancerlar una reservacion
CREATE OR REPLACE PROCEDURE cancelar_reservacion(p_id_reserva INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_habitacion INT;
BEGIN
    -- Verificar si la reserva existe y obtener la habitacion
    SELECT id_habitacion INTO v_id_habitacion
    FROM reserva
    WHERE ID_reserva = p_id_reserva;

    IF v_id_habitacion IS NULL THEN
        RAISE EXCEPTION 'No se encontro una reserva con el ID %', p_id_reserva;
    END IF;

    -- Eliminar pagos asociados 
    DELETE FROM pago WHERE ID_reserva = p_id_reserva;

    -- Marcar la reserva como cancelada
    UPDATE reserva
    SET estado_reserva = 'Cancelada'
    WHERE ID_reserva = p_id_reserva;

    -- Liberar la habitacion 
    UPDATE habitacion
    SET disponibilidad = 'libre'
    WHERE id_habitacion = v_id_habitacion;

 
    RAISE NOTICE 'Reserva % cancelada.', p_id_reserva;
	CALL registrar_evento_reserva(
    p_id_reserva,
    'cancelación de reserva',
    'sistema', -- o puedes pasar un parámetro si deseas registrar el usuario real
    jsonb_build_object(
        'accion', 'Reserva cancelada',
        'habitacion_liberada', v_id_habitacion
    )
);
END;
$$;


--Procedimieto que cambia el estado de la reservación una vez registrado el pago realizado
CREATE OR REPLACE PROCEDURE ActualizarEstadoPago(p_id_reserva INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_pago_existente INT;
BEGIN
    -- Verificar si existe el pago 
    SELECT COUNT(*) INTO v_pago_existente
    FROM pago
    WHERE ID_reserva = p_id_reserva;

    -- Si no hay pago, lanzar excepción
    IF v_pago_existente = 0 THEN
        RAISE EXCEPTION 'No hay un pago registrado para la reserva %', p_id_reserva;
    END IF;

    -- Actualizar estado de la reserva a Confirmada
    UPDATE reserva
    SET estado_reserva = 'Confirmada'
    WHERE ID_reserva = p_id_reserva;

    -- Registrar en la bitácora
    CALL registrar_evento_reserva(
        p_id_reserva,
        'confirmación de pago',
        'sistema',
        jsonb_build_object(
            'mensaje', 'Pago registrado y reserva confirmada'
        )
    );

    RAISE NOTICE 'Reserva % confirmada.', p_id_reserva;
END;
$$;


CREATE OR REPLACE FUNCTION log_eliminacion_reserva()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO tabla_log_reservaciones (id_reserva, accion, usuario, detalle)
    VALUES (
        OLD.id_reserva,
        'DELETE',
        current_user,
        to_jsonb(OLD)
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_delete_reserva
BEFORE DELETE ON reserva
FOR EACH ROW
EXECUTE FUNCTION log_eliminacion_reserva();


CREATE OR REPLACE PROCEDURE restaurar_reservas_desde_bitacora(
    p_id_reserva INT DEFAULT NULL  -- Si no se indica, se restauran todas
)
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT * 
        FROM tabla_log_reservaciones
        WHERE accion = 'DELETE'
          AND (p_id_reserva IS NULL OR id_reserva = p_id_reserva)
        ORDER BY fecha_hora
    LOOP
        -- Verificar que la reserva no exista antes de insertarla
        IF NOT EXISTS (
            SELECT 1 FROM reserva WHERE id_reserva = (r.detalle->>'id_reserva')::INT
        ) THEN
            INSERT INTO reserva (
                id_reserva, numero_huespedes, solicitudes_especial,
                tipo_reserva, tipo_confirmacion, fecha_entrada,
                fecha_salida, id_politicas, id_habitacion,
                documento_identidad, estado_reserva
            )
            SELECT
                (r.detalle->>'id_reserva')::INT,
                (r.detalle->>'numero_huespedes')::INT,
                r.detalle->>'solicitudes_especial',
                r.detalle->>'tipo_reserva',
                r.detalle->>'tipo_confirmacion',
                (r.detalle->>'fecha_entrada')::DATE,
                (r.detalle->>'fecha_salida')::DATE,
                (r.detalle->>'id_politicas')::INT,
                (r.detalle->>'id_habitacion')::INT,
                r.detalle->>'documento_identidad',
                r.detalle->>'estado_reserva';
                
            RAISE NOTICE 'Reserva % restaurada.', (r.detalle->>'id_reserva')::INT;
        ELSE
            RAISE NOTICE 'Reserva % ya existe. No se restauró.', (r.detalle->>'id_reserva')::INT;
        END IF;
    END LOOP;
END;
$$;

