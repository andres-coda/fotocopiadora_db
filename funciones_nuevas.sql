create or replace function fc_obtener_pedido_json(p_id_pedido uuid) returns jsonb
    language plpgsql
as
$$
DECLARE
    v_resultado jsonb;
BEGIN
    SELECT jsonb_build_object(
        'id', p.id,
        'fechaCreacion', p.fecha_creacion,
        'fechaActualizacion', p.fecha_actualizacion,
        'fechaEntrega', p.fecha_entrega,
        'importeTotal', p.importe_total,
        'sena', p.sena,
        'archivos', p.archivos,
        'anillados', p.anillados,
        'estado', p.estado,
        'cliente', jsonb_build_object(
            'id', c.id,
            'nombre', c.nombre,
            'telefono', c.telefono,
            'email', c.email
        ),
        'items',
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', pi.id,
                    'cantidad', pi.cantidad,
                    'detalles', pi.detalles,
                    'estado', pi.estado,
                    'idLibro', pi.id_libro,
                    'idSede', pi.id_sede,
                    'especificaciones',
                    COALESCE(
                        (
                            SELECT jsonb_agg(e.nombre ORDER BY e.nombre)
                            FROM pedido_item_especificacion pie
                            JOIN especificacion e
                                ON e.id = pie.id_especificacion
                            WHERE pie.id_pedido = pi.id_pedido
                              AND pie.nro_item = pi.id
                        ),
                        '[]'::jsonb
                    )
                )
                ORDER BY pi.id
            )
            FROM pedido_item pi
            WHERE pi.id_pedido = p.id
        )
    )
    INTO v_resultado
    FROM pedido p
    JOIN cliente c
      ON c.id = p.id_cliente
    WHERE p.id = p_id_pedido;

    RETURN v_resultado;
END;
$$;
