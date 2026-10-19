-- 40_funciones/03_clientes.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace function fc_busqueda_cliente(p_busqueda character varying, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0) returns SETOF vw_cliente
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
        WITH palabras AS (SELECT unnest(
                                         regexp_split_to_array(
                                                 lower(trim(p_busqueda)),
                                                 '\s+'
                                         )
                                 ) palabra)
        SELECT *
        FROM vw_cliente c
        WHERE NOT EXISTS (SELECT 1
          FROM palabras p
          WHERE NOT (
            (
                p.palabra ~ '^[0-9]+$'
                AND c.telefono LIKE '%' || p.palabra
            ) OR (
                lower(
                    concat_ws(
                        ' ',
                        c.nombre,
                        c.email
                    )
                ) LIKE '%' || p.palabra || '%'
            )))
        ORDER BY
            c.pendiente,
            c.listo
        LIMIT p_limite
        OFFSET p_offset;
END;
$$;

grant execute on function fc_busqueda_cliente(varchar, integer, integer) to app_role;

create or replace function fc_cliente_delete() returns trigger
    security definer
    language plpgsql
as
$$
    BEGIN
        delete from resumen_cliente where id_cliente = OLD.id;
        return OLD;
    END;
    $$;

create or replace function fc_crear_cliente(p_telefono character varying, p_email character varying, p_nombre character varying, p_id_cliente uuid) returns uuid
    language plpgsql
as
$$
    DECLARE
        v_cliente UUID;
    BEGIN
    IF p_id_cliente IS NOT NULL THEN
        RETURN p_id_cliente;
    END IF;
        SELECT id
        INTO v_cliente
        FROM cliente c
        WHERE ((c.telefono IS NOT NULL AND c.telefono = p_telefono)  OR (c.email IS NOT NULL AND c.email = p_email));
        IF v_cliente IS NULL THEN
            INSERT INTO cliente (nombre, telefono, email)
            VALUES (p_nombre, p_telefono, p_email)
            RETURNING id INTO v_cliente;
        END IF;
    RETURN v_cliente;
    END;
$$;

create or replace function fc_busqueda_cliente(p_busqueda text, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0, p_deleted boolean DEFAULT false)
    returns TABLE(id uuid, nombre character varying, email character varying, telefono character varying, fecha_creacion timestamp without time zone, fecha_actualizacion timestamp without time zone, deleted boolean, pendiente integer, retirado integer, listo integer, cancelado integer, total bigint)
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
        WITH palabras AS (SELECT unnest(
                                         regexp_split_to_array(
                                                 lower(trim(p_busqueda)),
                                                 '\s+'
                                         )
                                 ) palabra)
        SELECT
            c.*,
            COUNT(*) OVER() AS total
        FROM vw_cliente c
        WHERE c.deleted = p_deleted and NOT EXISTS (SELECT 1
          FROM palabras p
          WHERE NOT (
            (
                p.palabra ~ '^[0-9]+$'
                AND c.telefono LIKE '%' || p.palabra
            ) OR (
                lower(
                    concat_ws(
                        ' ',
                        c.nombre,
                        c.email
                    )
                ) LIKE '%' || p.palabra || '%'
            )))
        ORDER BY
            c.pendiente,
            c.listo
        LIMIT p_limite
        OFFSET p_offset;
END;
$$;
