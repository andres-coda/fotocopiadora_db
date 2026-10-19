-- 40_funciones/02_catalogo.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace function fc_libro_empresa_delete() returns trigger
    security definer
    language plpgsql
as
$$
    BEGIN
        delete from resumen_libro where id_libro = OLD.id_libro and (fc_es_super_admin() and id_empresa = OLD.id_empresa or fc_es_empresa_actual(id_empresa));
        delete from stock where id_libro = OLD.id_libro and (fc_es_super_admin() and id_empresa = OLD.id_empresa or fc_es_empresa_actual(id_empresa));
        return OLD;
    END;
    $$;

create or replace function fc_crear_componente_libro(p_componentes jsonb, p_id_libro uuid) returns void
    language plpgsql
as
$$
BEGIN

    INSERT INTO componente(nombre)
    SELECT DISTINCT nombre
    FROM jsonb_array_elements_text(p_componentes) t(nombre)
    ON CONFLICT(nombre)
        DO NOTHING;

    INSERT INTO libro_componente(
        id_libro,
        id_componente
    )
    SELECT DISTINCT
        p_id_libro,
        c.id
    FROM componente c
    JOIN jsonb_array_elements_text(p_componentes) t(nombre)
        ON c.nombre=t.nombre
    ON CONFLICT(id_libro,id_componente)
        DO NOTHING;

END;
$$;

create or replace function fc_crear_libro(p_libro character varying, p_editorial character varying, p_materia character varying, p_pg integer, p_adhesivos integer, p_esp_defecto jsonb, p_id_libro_completo uuid, p_nivel character varying, p_anio character varying, p_autor character varying, p_img character varying, p_edicion integer, p_descripcion character varying, p_componentes jsonb) returns vw_libro_busqueda
    language plpgsql
as
$$
DECLARE
    v_libro_completo uuid;
    v_resultado vw_libro_busqueda;
BEGIN

    IF p_id_libro_completo IS NULL THEN
        v_libro_completo:= fc_obtener_or_crear_libro_completo(
          p_libro,
        p_editorial,
        p_materia,
        p_nivel,
        p_anio,
        p_autor,
        p_img,
        p_edicion,
        p_descripcion,
        p_componentes
        );
    ELSE
        v_libro_completo := p_id_libro_completo;
    END IF;

    INSERT INTO libro_empresa(
        id_libro,
        cantidad_pg,
        cantidad_adhesivo,
        especificaciones_defecto
    )
    VALUES(
        v_libro_completo,
        p_pg,
        p_adhesivos,
        p_esp_defecto
    );

    SELECT *
    INTO v_resultado
    FROM vw_libro_busqueda
    WHERE id = v_libro_completo;

    RETURN v_resultado;
END;
$$;

create or replace function fc_obtener_o_crear_nivel(p_nivel character varying) returns uuid
    language plpgsql
as
$$
DECLARE
    v_id uuid;
BEGIN
    IF p_nivel IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO nivel(nombre)
    VALUES (p_nivel)
    RETURNING id INTO v_id;

    RETURN v_id;

EXCEPTION
    WHEN unique_violation THEN
        SELECT id
        INTO v_id
        FROM nivel
        WHERE nombre = p_nivel;

        RETURN v_id;
END;
$$;

create or replace function fc_obtener_o_crear_editorial(p_editorial character varying) returns uuid
    language plpgsql
as
$$
DECLARE
    v_id uuid;
BEGIN
    IF p_editorial IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO editorial(nombre)
    VALUES (p_editorial)
    RETURNING id INTO v_id;

    RETURN v_id;
EXCEPTION
    WHEN unique_violation THEN
        SELECT id
        INTO v_id
        FROM editorial
        WHERE nombre = p_editorial;

        RETURN v_id;
END;
$$;

create or replace function fc_obtener_o_crear_materia(p_materia character varying) returns uuid
    language plpgsql
as
$$
DECLARE
    v_id uuid;
BEGIN
    IF p_materia IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO materia(nombre)
    VALUES (p_materia)
    RETURNING id INTO v_id;

    RETURN v_id;

EXCEPTION
    WHEN unique_violation THEN
        SELECT id
        INTO v_id
        FROM materia
        WHERE nombre = p_materia;

        RETURN v_id;
END;
$$;

create or replace function fc_obtener_o_crear_libro(p_libro character varying, p_editorial character varying, p_materia character varying) returns uuid
    language plpgsql
as
$$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO libro(
        nombre,
        id_editorial,
        id_materia
    )
    VALUES(
        p_libro,
        fc_obtener_o_crear_editorial(p_editorial),
        fc_obtener_o_crear_materia(p_materia)
    )
    RETURNING id INTO v_id;

    RETURN v_id;

EXCEPTION
    WHEN unique_violation THEN
        SELECT id
        INTO v_id
        FROM libro
        WHERE nombre = p_libro;

        RETURN v_id;
END;
$$;

create or replace function fc_obtener_or_crear_libro_completo(p_libro character varying, p_editorial character varying, p_materia character varying, p_nivel character varying, p_anio character varying, p_autor character varying, p_img character varying, p_edicion integer, p_descripcion character varying, p_componentes jsonb) returns uuid
    language plpgsql
as
$$
DECLARE
    v_id_libro uuid;
    v_id_nivel uuid;
    v_id_libro_completo uuid;
    v_componentes_texto text;
BEGIN
    -- 1. Obtener o crear los IDs de las tablas maestras base
    v_id_libro := fc_obtener_o_crear_libro(p_libro, p_editorial, p_materia);
    v_id_nivel := fc_obtener_o_crear_nivel(p_nivel);

    -- 2. Convertir el JSONB de entrada a una cadena de texto normalizada y ordenada.
    -- Ej: si pasan ["Activity", "Student"] o ["Student", "Activity"], ambos se vuelven "Activity, Student"
    SELECT COALESCE(string_agg(DISTINCT c_nombre, ', ' ORDER BY c_nombre), '')
    INTO v_componentes_texto
    FROM jsonb_array_elements_text(p_componentes) AS c_nombre;

    -- 3. Buscar si existe un libro completo que coincida en todo, INCLUYENDO el set de componentes
    SELECT lc.id INTO v_id_libro_completo
    FROM libro_completo lc
    -- Usamos LEFT JOIN con tu vista para traer los componentes ya concatenados de los libros existentes
    LEFT JOIN vw_componentes vwc ON vwc.id_libro = lc.id
    WHERE lc.id_libro = v_id_libro
      AND (lc.id_nivel = v_id_nivel OR (lc.id_nivel IS NULL AND v_id_nivel IS NULL))
      AND (lc.anio = p_anio OR (lc.anio IS NULL AND p_anio IS NULL))
      AND (lc.edicion = p_edicion OR (lc.edicion IS NULL AND p_edicion IS NULL))
      -- Comparamos la combinación exacta de componentes (ej: "Activity, Student" = "Activity, Student")
      AND (COALESCE(vwc.componentes, '') = v_componentes_texto);

    -- 4. Si se encontró la combinación exacta, la devolvemos sin duplicar nada
    IF v_id_libro_completo IS NOT NULL THEN
        RETURN v_id_libro_completo;
    END IF;

    -- 5. Si no existe esa combinación, creamos el nuevo registro en libro_completo
    INSERT INTO libro_completo(id_libro, id_nivel, anio, autor, img, edicion, descripcion)
    VALUES(v_id_libro, v_id_nivel, p_anio, p_autor, p_img, p_edicion, p_descripcion)
    RETURNING id INTO v_id_libro_completo;

    -- 6. Insertamos los componentes en la tabla intermedia para este nuevo libro específico
    PERFORM fc_crear_componente_libro(p_componentes, v_id_libro_completo);

    -- 7. Retornamos el ID del nuevo libro completo con su set único de componentes
    RETURN v_id_libro_completo;
END;
$$;

create or replace function fc_busqueda_libro_completo(p_busqueda text, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0)
    returns TABLE(id uuid, nombre character varying, descripcion character varying, edicion integer, autor character varying, anio character varying, img character varying, nivel character varying, componentes text, materia character varying, editorial character varying, total bigint)
    language plpgsql
as
$$
BEGIN
    IF p_busqueda IS NULL
       OR length(trim(p_busqueda)) < 3 THEN
        RETURN;
    END IF;

    p_limite := LEAST(
                    GREATEST(p_limite, 1),
                    50
                 );

    RETURN QUERY
    WITH palabras AS (
        SELECT unnest(
            regexp_split_to_array(
                lower(trim(p_busqueda)),
                '\s+'
            )
        ) AS palabra
    )
    SELECT
        vw_c.*,
        COUNT(*) OVER() AS total
    FROM vw_libro_completo vw_c
    WHERE NOT EXISTS (
        SELECT 1
        FROM palabras p
        WHERE NOT (
            (
                p.palabra ~ '^[0-9]{4}$'
                AND vw_c.anio::text = p.palabra
            )
            OR
            (
                lower(
                    concat_ws(
                        ' ',
                        vw_c.nombre,
                        vw_c.nivel,
                        vw_c.componentes,
                        vw_c.editorial,
                        vw_c.materia,
                        vw_c.edicion
                    )
                ) LIKE '%' || p.palabra || '%'
            )
        )
    )
    ORDER BY
        vw_c.nombre,
        vw_c.nivel,
        vw_c.componentes,
        vw_c.anio
    LIMIT p_limite
    OFFSET p_offset;

END;
$$;

create or replace function fc_busqueda_libro(p_busqueda text, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0, p_deleted boolean DEFAULT false)
    returns TABLE(id uuid, nombre character varying, descripcion character varying, edicion integer, autor character varying, anio character varying, img character varying, nivel character varying, componentes text, cantidad_pg integer, cantidad_adhesivo integer, especificaciones_defecto jsonb, materia character varying, editorial character varying, pendiente integer, listo integer, retirado integer, cancelado integer, id_empresa uuid, id_materia uuid, detalle_impresion character varying, deleted boolean, stock integer, id_libro uuid, total bigint)
    language plpgsql
as
$$
BEGIN
    IF p_busqueda IS NULL
       OR length(trim(p_busqueda)) < 3 THEN
        RETURN;
    END IF;

    p_limite := LEAST(
                    GREATEST(p_limite, 1),
                    50
                 );

    RETURN QUERY
    WITH palabras AS (
        SELECT unnest(
            regexp_split_to_array(
                lower(trim(p_busqueda)),
                '\s+'
            )
        ) AS palabra
    )
    SELECT
        vw_lb.*,
        COUNT(*) OVER() AS total
    FROM vw_libro_busqueda vw_lb
    WHERE vw_lb.deleted = p_deleted and NOT EXISTS (
        SELECT 1
        FROM palabras p
        WHERE NOT (
            (
                p.palabra ~ '^[0-9]{4}$'
                AND vw_lb.anio::text = p.palabra
            )
            OR
            (
                lower(
                    concat_ws(
                        ' ',
                        vw_lb.nombre,
                        vw_lb.nivel,
                        vw_lb.componentes,
                        vw_lb.editorial,
                        vw_lb.materia
                    )
                ) LIKE '%' || p.palabra || '%'
            )
        )
    )
    ORDER BY
        vw_lb.nombre,
        vw_lb.nivel
    LIMIT p_limite
    OFFSET p_offset;

END;
$$;

create or replace function _fc_verificar_actualizacion_libro_completo(p_actual anyelement, p_nuevo anyelement)
    returns TABLE(v_actualizar boolean, v_peticion boolean)
    immutable
    language plpgsql
as
$$
DECLARE
    v_actual_normalizado jsonb :=
        NULLIF(to_jsonb(p_actual), '""'::jsonb);

    v_nuevo_normalizado jsonb :=
        NULLIF(to_jsonb(p_nuevo), '""'::jsonb);
BEGIN
    v_actualizar := false;
    v_peticion := false;

    IF v_actual_normalizado IS NULL THEN
        -- BD NULL y nuevo NULL: no hace nada.
        -- BD NULL y nuevo con valor: actualización directa.
        v_actualizar := v_nuevo_normalizado IS NOT NULL;
    ELSE
        -- BD con valor y nuevo NULL o distinto: petición.
        -- BD con valor y nuevo igual: no hace nada.
        v_peticion :=
            v_actual_normalizado IS DISTINCT FROM v_nuevo_normalizado;
    END IF;

    RETURN NEXT;
END;
$$;

create or replace function fc_procesar_actualizacion_libro_completo(p_id_libro_completo uuid, p_autor character varying, p_edicion integer, p_anio character varying, p_img character varying, p_descripcion character varying) returns boolean
    security definer
    language plpgsql
as
$$
declare
    v_actual record;
    v_id_solicitud uuid := null;
    v_autor boolean default  false;
    v_edicion boolean default false;
    v_anio boolean default false;
    v_img boolean default false;
    v_descripcion boolean default false;
    v_actualizar_autor boolean default  false;
    v_actualizar_edicion boolean default false;
    v_actualizar_anio boolean default false;
    v_actualizar_img boolean default false;
    v_actualizar_descripcion boolean default false;
begin
    -- 1. Leer valores actuales de una sola vez
    select autor, edicion, anio, img, descripcion
    into v_actual
    from libro_completo
    where id = p_id_libro_completo;

    if not found then
        raise exception 'libro_completo % no encontrado', p_id_libro_completo;
    end if;

    -- 2. Verificar y crear variables de actualización directa y peticiones

    select v.v_actualizar, v.v_peticion
    into v_actualizar_autor, v_autor
    from _fc_verificar_actualizacion_libro_completo(v_actual.autor, p_autor) AS v;

    select v.v_actualizar, v.v_peticion
    into v_actualizar_anio, v_anio
    from _fc_verificar_actualizacion_libro_completo(v_actual.anio, p_anio) AS v;

    select v.v_actualizar, v.v_peticion
    into v_actualizar_edicion, v_edicion
    from _fc_verificar_actualizacion_libro_completo(v_actual.edicion, p_edicion) AS v;

    select v.v_actualizar, v.v_peticion
    into v_actualizar_img, v_img
    from _fc_verificar_actualizacion_libro_completo(v_actual.img, p_img) AS v;

    select v.v_actualizar, v.v_peticion
    into v_actualizar_descripcion, v_descripcion
    from _fc_verificar_actualizacion_libro_completo(v_actual.descripcion, p_descripcion) AS v;

    -- 3. Crear solicitud si es necesario

    if(v_autor or v_anio or v_img or v_edicion or v_descripcion) then
        insert into solicitud(id_libro_completo, id_usuario, estado, id_empresa)
            values (p_id_libro_completo, fc_usuario_actual(), 1, fc_empresa_actual())
            returning id into v_id_solicitud;
    end if;

    -- 4. Crear petición si es necesario

    IF v_id_solicitud IS NOT NULL THEN

        INSERT INTO peticion (
            id_solicitud,
            campo,
            valor_anterior,
            valor_nuevo,
            observaciones,
            estado
        )
        SELECT
            v_id_solicitud,
            p.campo,
            p.valor_anterior,
            p.valor_nuevo,
            NULL,
            1
        FROM (
            VALUES
                (
                    'autor',
                    COALESCE(to_jsonb(NULLIF(v_actual.autor, '')), 'null'::jsonb),
                    COALESCE(to_jsonb(NULLIF(p_autor, '')), 'null'::jsonb),
                    v_autor
                ),
                (
                    'anio',
                    COALESCE(to_jsonb(NULLIF(v_actual.anio, '')), 'null'::jsonb),
                    COALESCE(to_jsonb(NULLIF(p_anio, '')), 'null'::jsonb),
                    v_anio
                ),
                (
                    'img',
                    COALESCE(to_jsonb(NULLIF(v_actual.img, '')), 'null'::jsonb),
                    COALESCE(to_jsonb(NULLIF(p_img, '')), 'null'::jsonb),
                    v_img
                ),
                (
                    'edicion',
                    COALESCE(to_jsonb(v_actual.edicion), 'null'::jsonb),
                    COALESCE(to_jsonb(p_edicion), 'null'::jsonb),
                    v_edicion
                ),
                (
                    'descripcion',
                    COALESCE(to_jsonb(NULLIF(v_actual.descripcion, '')), 'null'::jsonb),
                    COALESCE(to_jsonb(NULLIF(p_descripcion, '')), 'null'::jsonb),
                    v_descripcion
                )
        ) AS p(campo, valor_anterior, valor_nuevo, crear)
        WHERE p.crear;

    END IF;

    -- 5. Actualizar libro completo

    UPDATE libro_completo
        SET
            autor       = CASE WHEN v_actualizar_autor       THEN p_autor       ELSE autor       END,
            edicion     = CASE WHEN v_actualizar_edicion     THEN p_edicion     ELSE edicion     END,
            anio        = CASE WHEN v_actualizar_anio        THEN p_anio        ELSE anio        END,
            img         = CASE WHEN v_actualizar_img         THEN p_img         ELSE img         END,
            descripcion = CASE WHEN v_actualizar_descripcion THEN p_descripcion ELSE descripcion END
        WHERE id = p_id_libro_completo
          AND (
              v_actualizar_autor OR
              v_actualizar_edicion OR
              v_actualizar_anio OR
              v_actualizar_img OR
              v_actualizar_descripcion
          );

    -- Retornar true si se ejecutó sin errores (incluye peticiones registradas)
    return true;
end $$;

create or replace function _fc_verificar_actualizacion_libro(p_actual character varying, p_nuevo character varying) returns boolean
    immutable
    language plpgsql
as
$$
DECLARE
    v_actual_normalizado jsonb :=
        NULLIF(to_jsonb(p_actual), '""'::jsonb);

    v_nuevo_normalizado jsonb :=
        NULLIF(to_jsonb(p_nuevo), '""'::jsonb);
BEGIN
    return v_actual_normalizado IS DISTINCT FROM v_nuevo_normalizado;
END;
$$;

create or replace function fc_procesar_actualizacion_libro(p_id_libro_completo uuid, p_nombre character varying, p_materia character varying, p_editorial character varying, p_nivel character varying, p_componentes text[]) returns boolean
    security definer
    language plpgsql
as
$$
declare
    v_actual record;
    v_id_solicitud uuid := null;
    v_nombre boolean default  false;
    v_materia boolean default false;
    v_editorial boolean default false;
    v_nivel boolean default false;
    v_componentes boolean default false;
    v_comp_actual text[];
    v_comp_nuevos text[];
begin
    -- 1. Leer valores actuales de una sola vez (vista para campos simples)
    select nombre, nivel, materia, editorial, componentes
    into v_actual
    from vw_libro_completo
    where id = p_id_libro_completo;

    if not found then
        raise exception 'libro_completo % no encontrado', p_id_libro_completo;
    end if;

    -- 2. Leer componentes actuales por NOMBRE (para comparar con p_componentes que viene por nombre)
    select array_agg(c.nombre order by c.nombre)
    into v_comp_actual
    from libro_componente lc
    join componente c on c.id = lc.id_componente
    where lc.id_libro = (select id_libro from libro_completo where id = p_id_libro_completo);

    v_comp_actual := coalesce(v_comp_actual, '{}');

    -- 3. Normalizar componentes entrantes: trim, quitar vacíos, dedup, ordenar
    if p_componentes is not null then
        v_comp_nuevos := array(
            select distinct trim(elem)
            from unnest(p_componentes) as elem
            where trim(elem) <> ''
            order by 1
        );
    else
        v_comp_nuevos := '{}';
    end if;

    -- 4. Verificar cambios en campos simples (helper ya trata null='' como igual)
    v_nombre := _fc_verificar_actualizacion_libro(v_actual.nombre, p_nombre);
    v_materia := _fc_verificar_actualizacion_libro(v_actual.materia, p_materia);
    v_editorial := _fc_verificar_actualizacion_libro(v_actual.editorial, p_editorial);
    v_nivel := _fc_verificar_actualizacion_libro(v_actual.nivel, p_nivel);

    -- 5. Verificar componentes: comparar arrays de nombres ordenados
    v_componentes := v_comp_actual <> v_comp_nuevos;

    -- 6. Crear solicitud si hay algún cambio
    if (v_nombre or v_materia or v_editorial or v_nivel or v_componentes) then
        insert into solicitud(id_libro_completo, id_usuario, estado, id_empresa)
            values (p_id_libro_completo, fc_usuario_actual(), 1, fc_empresa_actual())
            returning id into v_id_solicitud;
    end if;

    -- 7. Crear peticiones por cada campo que cambió
    IF v_id_solicitud IS NOT NULL THEN
        INSERT INTO peticion (
            id_solicitud,
            campo,
            valor_anterior,
            valor_nuevo,
            observaciones,
            estado
        )
        SELECT
            v_id_solicitud,
            p.campo,
            p.valor_anterior,
            p.valor_nuevo,
            NULL,
            1
        FROM (
            VALUES
                (
                    'nombre',
                    COALESCE(to_jsonb(NULLIF(v_actual.nombre, '')), 'null'::jsonb),
                    COALESCE(to_jsonb(NULLIF(p_nombre, '')), 'null'::jsonb),
                    v_nombre
                ),
                (
                    'editorial',
                    COALESCE(to_jsonb(NULLIF(v_actual.editorial, '')), 'null'::jsonb),
                    COALESCE(to_jsonb(NULLIF(p_editorial, '')), 'null'::jsonb),
                    v_editorial
                ),
                (
                    'materia',
                    COALESCE(to_jsonb(NULLIF(v_actual.materia, '')), 'null'::jsonb),
                    COALESCE(to_jsonb(NULLIF(p_materia, '')), 'null'::jsonb),
                    v_materia
                ),
                (
                    'nivel',
                    COALESCE(to_jsonb(v_actual.nivel), 'null'::jsonb),
                    COALESCE(to_jsonb(p_nivel), 'null'::jsonb),
                    v_nivel
                ),
                (
                    'componentes',
                    to_jsonb(v_comp_actual),
                    to_jsonb(v_comp_nuevos),
                    v_componentes
                )
        ) AS p(campo, valor_anterior, valor_nuevo, crear)
        WHERE p.crear;
    END IF;

    -- 8. Retornar true si se ejecutó sin errores (excepción si falla)
    return true;
end $$;

grant execute on function fc_procesar_actualizacion_libro(uuid, varchar, varchar, varchar, varchar, text[]) to app_role;
