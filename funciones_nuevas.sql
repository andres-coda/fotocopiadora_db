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
