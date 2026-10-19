-- 40_funciones/05_pedidos.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace function fc_actualizar_estado_pedido() returns trigger
    language plpgsql
as
$$
DECLARE
    v_id_pedido UUID;
    v_pendientes INTEGER;
    v_listos INTEGER;
    v_retirados INTEGER;
    v_new_estado INT;
BEGIN
   IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        v_id_pedido = NEW.id_pedido;
    ELSE v_id_pedido = OLD.id_pedido;
    END IF;

   SELECT
        COUNT(*) FILTER (WHERE estado IN (1, 2, 3)),
        COUNT(*) FILTER (WHERE estado = 4),
        COUNT(*) FILTER (WHERE estado = 5)
    INTO
        v_pendientes,
        v_listos,
        v_retirados
    FROM pedido_item
    WHERE id_pedido = v_id_pedido;

   IF v_pendientes > 0 THEN
        v_new_estado := 1; -- Pendiente
    ELSIF v_listos > 0 THEN
        v_new_estado := 4; -- Listo
    ELSIF v_retirados > 0 THEN
        v_new_estado := 5; -- Retirado
    ELSE
        v_new_estado := 6; -- Cancelado
    END IF;
   UPDATE pedido SET
        estado = v_new_estado
    WHERE id = v_id_pedido;

   RETURN COALESCE(NEW, OLD);
END;
$$;

create or replace function fc_crear_pedido_item(p_id_pedido uuid, p_item tp_pedido_item) returns integer
    language plpgsql
as
$$
DECLARE
    v_id_pedido_item INTEGER;
BEGIN

    INSERT INTO pedido_item (
        cantidad,
        detalles,
        id_sede,
        id_libro,
        id_pedido
    )
    VALUES (
        p_item.cantidad,
        p_item.detalles,
        p_item.id_sede,
        p_item.id_libro,
        p_id_pedido
    )
    RETURNING id
    INTO v_id_pedido_item;

   -- Insertar todas las especificaciones de una sola vez
    INSERT INTO pedido_item_especificacion (
        id_pedido,
        nro_item,
        id_especificacion
    )
    SELECT
        p_id_pedido,
        v_id_pedido_item,
        e.id
    FROM jsonb_array_elements_text(p_item.especificaciones) esp(nombre)
    JOIN especificacion e
        ON e.nombre = esp.nombre;

    RETURN v_id_pedido_item;

END;
$$;

create or replace function fc_obtener_pedido_json(p_id_pedido uuid) returns jsonb
    language plpgsql
as
$$
DECLARE
    v_resultado jsonb;
BEGIN
    SELECT jsonb_build_object(
        'id', vp.id,
        'fechaCreacion', vp.fecha_creacion,
        'fechaActualizacion', vp.fecha_actualizacion,
        'fechaEntrega', vp.fecha_entrega,
        'importeTotal', vp.importe_total,
        'sena', vp.sena,
        'archivos', vp.archivos,
        'anillados', vp.anillados,
        'estado', vp.estado,
        'cliente', jsonb_build_object(
            'id', vp.id_cliente,
            'nombre', vp.nombre,
            'telefono', vp.telefono,
            'email', vp.email
        ),
        'items',
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', vpi.nro_pedido,
                    'cantidad', vpi.cantidad,
                    'detalles', vpi.detalles,
                    'estado', vpi.estado,
                    'sede', jsonb_build_object(
                        'id', vpi.id_sede,
                        'nombre', vpi.sede
                    ),
                    'libro', jsonb_build_object(
                        'id', vpi.id_libro,
                        'nombre', vpi.nombre,
                        'descripcion', vpi.descripcion,
                        'edicion', vpi.edicion,
                        'anio', vpi.anio,
                        'nivel', vpi.nivel,
                        'componentes', vpi.componentes,
                        'materia', vpi.materia,
                        'id_materia', vpi.id_materia,
                        'editorial', vpi.editorial
                    ),
                    'especificaciones', vpi.especificaciones
                )
                ORDER BY vpi.nro_pedido
            )
            FROM vw_pedidos_item vpi
            WHERE vpi.id_pedido = vp.id
        )
    )
    INTO v_resultado
    FROM vw_pedidos vp
    WHERE vp.id = p_id_pedido;

    RETURN v_resultado;
END;
$$;

create or replace function fc_crear_pedido(p_telefono character varying, p_email character varying, p_nombre character varying, p_id_cliente uuid, p_fecha_entrega date, p_importe_total numeric, p_archivos integer, p_anillados integer, p_sena numeric, p_items jsonb) returns jsonb
    language plpgsql
as
$$
    DECLARE
        v_cliente UUID;
        v_pedido UUID;
        v_item tp_pedido_item;
        v_resultado jsonb;
    BEGIN
        v_cliente := fc_crear_cliente(p_telefono, p_email, p_nombre, p_id_cliente);

        INSERT INTO pedido (fecha_entrega, importe_total, archivos, anillados, sena, id_cliente)
        VALUES (p_fecha_entrega, p_importe_total, p_archivos, p_anillados, p_sena, v_cliente)
        RETURNING id INTO v_pedido;

        FOR v_item IN
        SELECT *
        FROM jsonb_to_recordset(p_items) AS x(
            cantidad integer,
            detalles varchar(255),
            id_sede uuid,
            id_libro uuid,
            especificaciones jsonb
        )
        LOOP
        perform fc_crear_pedido_item(v_pedido, v_item);
        END LOOP;
        v_resultado:= fc_obtener_pedido_json(v_pedido);
        return v_resultado;
    END;
    $$;

create or replace function fc_buscar_pedido(p_busqueda character varying, p_estado integer, p_limite integer, p_offset integer DEFAULT 0) returns SETOF vw_pedidos_item
    language plpgsql
as
$$
declare
    v_limite integer;

BEGIN
    if (p_limite is null or p_limite < 0 or p_limite > 50) then
        v_limite = 50;
    elseif p_limite = 0 then
        v_limite = null;
    else v_limite = p_limite;
    end if;

    IF p_busqueda IS NULL
        OR length(trim(p_busqueda)) < 3 THEN
        RETURN;
    END IF;

    RETURN QUERY
        WITH palabras AS (SELECT unnest(
                                         regexp_split_to_array(
                                                 lower(trim(p_busqueda)),
                                                 '\s+'
                                         )
                                 ) palabra)
        SELECT *
        FROM vw_pedidos_item vw_pi
        WHERE NOT EXISTS (SELECT 1
          FROM palabras p
          WHERE NOT (
              (p_estado NOT BETWEEN 1 AND 6 OR p_estado = vw_pi.estado)
            AND
            ((
                p.palabra ~ '^[0-9]+$'
                AND vw_pi.telefono LIKE '%' || p.palabra
            ) OR (
                lower(
                    concat_ws(
                        ' ',
                        vw_pi.nombre,
                        vw_pi.email,
                        vw_pi.detalles,
                        vw_pi.componentes,
                        vw_pi.materia,
                        vw_pi.nivel,
                        vw_pi.fecha_entrega,
                        vw_pi.estado,
                        vw_pi.sede
                    )
                ) LIKE '%' || p.palabra || '%'
            ))))
        ORDER BY
            vw_pi.estado,
            vw_pi.fecha_entrega,
            vw_pi.nombre,
            vw_pi.nivel,
            vw_pi.fecha_creacion
        LIMIT v_limite
        OFFSET p_offset;
END;
$$;

create or replace function fc_cambiar_estado_pedido(p_estado integer, p_id_pedido uuid) returns SETOF vw_cambio_estado
    language plpgsql
as
$$
DECLARE
    v_estados integer[];
BEGIN

    SELECT ARRAY_AGG(DISTINCT estado)
    INTO v_estados
    FROM pedido_item
    WHERE id_pedido = p_id_pedido;

    -- Todos los items tienen el mismo estado
    IF CARDINALITY(v_estados) = 1
   OR (
       p_estado = ANY(v_estados)
       AND CARDINALITY(v_estados) = 2
   )
THEN
    UPDATE pedido_item
    SET estado = p_estado
    WHERE id_pedido = p_id_pedido;
ELSE
    RAISE EXCEPTION
        'No se puede cambiar el estado del pedido. Estados actuales: %, estado solicitado: %',
        v_estados,
        p_estado;
END IF;

    RETURN QUERY
    SELECT *
    FROM vw_cambio_estado vw
    WHERE vw.id = p_id_pedido;
END;
$$;
