-- 40_funciones/06_solicitudes.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace function fc_obtener_propuestas(p_limite integer DEFAULT 20, p_offset integer DEFAULT 0, p_orden text DEFAULT 'ASC'::text) returns jsonb
    language plpgsql
as
$$
DECLARE
  v_total integer;
  v_resultado jsonb;
  v_sql text;
BEGIN
  -- Validar p_orden para evitar SQL injection
  IF upper(p_orden) NOT IN ('ASC', 'DESC') THEN
    p_orden := 'ASC';
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM propuesta
  WHERE deleted = false;

  v_sql := format(
    'SELECT jsonb_agg(p_data ORDER BY p_data->>''nombre'' %s)
     FROM (
       SELECT jsonb_build_object(
         ''id'',                  p.id,
         ''nombre'',              p.nombre,
         ''fechaCreacion'',       p.fecha_creacion,
         ''fechaActualizacion'',  p.fecha_actualizacion,
         ''deleted'',             p.deleted,
         ''libros'', (
           SELECT jsonb_agg(
             jsonb_build_object(
               ''id'',                      vwlb.id,
               ''nombre'',                  vwlb.nombre,
               ''nivel'',                   vwlb.nivel,
               ''materia'',                 vwlb.materia,
               ''editorial'',               vwlb.editorial,
               ''cantidadPg'',              vwlb.cantidad_pg,
               ''adhesivos'',               vwlb.cantidad_adhesivo,
               ''componentes'',             vwlb.componentes,
               ''anio'',                    vwlb.anio,
               ''autor'',                   vwlb.autor,
               ''edicion'',                 vwlb.edicion,
               ''img'',                     vwlb.img,
               ''deleted'',                 vwlb.deleted,
               ''id_materia'',              vwlb.id_materia,
               ''especificacionesDefecto'', vwlb.especificaciones_defecto
             )
             ORDER BY vwlb.nombre
           )
           FROM propuesta_libro_empresa ple
           JOIN vw_libro_busqueda vwlb ON vwlb.id = ple.id_libro
           WHERE ple.id_propuesta = p.id
         )
       ) AS p_data
       FROM propuesta p
       WHERE p.deleted = false
       ORDER BY p.nombre %s
       LIMIT %s OFFSET %s
     ) sub',
    p_orden, p_orden, p_limite, p_offset
  );

  EXECUTE v_sql INTO v_resultado;

  RETURN jsonb_build_object(
    'total', v_total,
    'datos', COALESCE(v_resultado, '[]'::jsonb)
  );
END;
$$;

create or replace function fc_verificar_peticiones_libro_relacionados(p_id_libro_completo uuid, p_id_usuario uuid, p_id_empresa uuid, p_campos jsonb, p_id_solicitud uuid)
    returns TABLE(campo character varying, accion character varying, valor_actual jsonb, valor_nuevo jsonb, id_solicitud uuid, id_peticion uuid)
    security definer
    language plpgsql
as
$$
declare
    v_libro_id uuid;
    v_actual_nivel uuid;
    v_actual_nombre varchar;
    v_actual_editorial uuid;
    v_actual_materia uuid;
    v_actual_componentes uuid[];
    v_campo text;
    v_valor_actual jsonb;
    v_valor_nuevo jsonb;
    v_diferente boolean;
    v_id_peticion uuid;
    v_comp_actual text;
    v_comp_nuevo text;
    v_id_solicitud uuid := p_id_solicitud;
begin
    -- 1. Leer valores actuales (una sola query con join)
    select lc.id_libro, lc.id_nivel, l.nombre, l.id_editorial, l.id_materia,
           coalesce(array_agg(lc2.id_componente) filter (where lc2.id_componente is not null), '{}')
    into v_libro_id, v_actual_nivel, v_actual_nombre, v_actual_editorial, v_actual_materia, v_actual_componentes
    from libro_completo lc
    join libro l on l.id = lc.id_libro
    left join libro_componente lc2 on lc2.id_libro = lc.id
    where lc.id = p_id_libro_completo
    group by lc.id_libro, lc.id_nivel, l.nombre, l.id_editorial, l.id_materia;

    if not found then
        raise exception 'libro_completo % no encontrado', p_id_libro_completo;
    end if;

    -- 2. Iterar campos recibidos
    for v_campo in select jsonb_object_keys(p_campos) loop
        v_valor_nuevo := p_campos -> v_campo;

        -- Mapear campo a valor actual
        case v_campo
            when 'nivel' then
                v_valor_actual := to_jsonb(v_actual_nivel);
            when 'nombre' then
                v_valor_actual := to_jsonb(v_actual_nombre);
            when 'editorial' then
                v_valor_actual := to_jsonb(v_actual_editorial);
            when 'materia' then
                v_valor_actual := to_jsonb(v_actual_materia);
            when 'componentes' then
                v_valor_actual := to_jsonb(v_actual_componentes);
            else
                continue; -- campo no reconocido
        end case;

        -- 3. Reglas para campos relacionados:
        -- NUNCA realiza cambios directos (no existe 'directo')
        -- Genera petición SOLO cuando valor BD ≠ valor DTO (comparación JSONB)
        -- En todos los demás casos (iguales, o uno/both null) -> sin_cambio
        --
        -- NOTA: Comparación JSONB (v_valor_actual <> v_valor_nuevo) funciona para:
        --   - UUID, texto, enteros: comparación de valor
        --   - Arrays (componentes): comparación elemento a elemento
        --   - null vs valor: true (distintos)
        --   - null vs null: false (iguales)

        if v_valor_actual <> v_valor_nuevo then
            -- Valores distintos -> generar petición, NO cambia dato
            select id_solicitud, id_peticion into v_id_solicitud, v_id_peticion
            from _fc_solicitud_registrar_peticion(
                v_id_solicitud, p_id_libro_completo, p_id_usuario, p_id_empresa,
                v_campo, v_valor_actual, v_valor_nuevo
            );
            return query select v_campo, 'peticion_creada', v_valor_actual, v_valor_nuevo, v_id_solicitud, v_id_peticion;
        else
            -- Valores iguales (incluye ambos null) -> sin petición, sin cambio
            return query select v_campo, 'sin_cambio', v_valor_actual, v_valor_nuevo, null::uuid, null::uuid;
        end if;
    end loop;
end $$;

grant execute on function fc_verificar_peticiones_libro_relacionados(uuid, uuid, uuid, jsonb, uuid) to app_role;

create or replace function _fc_solicitud_registrar_peticion(p_id_solicitud uuid, p_id_libro_completo uuid, p_campo character varying, p_valor_actual jsonb, p_valor_nuevo jsonb)
    returns TABLE(id_solicitud uuid, id_peticion uuid)
    security definer
    language plpgsql
as
$$
declare
    v_id_solicitud uuid := p_id_solicitud;
    v_id_peticion uuid;
begin
    -- Crear solicitud si no existe (primera petición de esta transacción)
    if v_id_solicitud is null then
        insert into solicitud (id_libro_completo, id_usuario, id_empresa, estado)
        values (p_id_libro_completo, fc_usuario_actual(), fc_empresa_actual(), 1)
        returning id into v_id_solicitud;
    end if;

    -- Registrar la petición
    insert into peticion (id_solicitud, campo, valor_anterior, valor_nuevo, estado)
    values (v_id_solicitud, p_campo, p_valor_actual, p_valor_nuevo, 1)
    returning id into v_id_peticion;

    -- Devolver ambos valores
    return query select v_id_solicitud, v_id_peticion;
end $$;
