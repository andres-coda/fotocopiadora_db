-- 40_funciones/01_infra_auditoria.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace function fc_actualizar_fecha_actualizacion() returns trigger
    language plpgsql
as
$$
BEGIN
    NEW.fecha_actualizacion := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

create or replace function fc_extraer_clave(fila jsonb, VARIADIC columnas text[]) returns jsonb
    immutable
    language plpgsql
as
$$
DECLARE
    clave   JSONB := '{}'::jsonb;
    columna TEXT;
BEGIN
    FOREACH columna IN ARRAY columnas
        LOOP
            clave := clave || jsonb_build_object(
                    columna,
                    fila -> columna
                              );
        END LOOP;
    RETURN clave;
END;
$$;

grant execute on function fc_extraer_clave(jsonb, text[]) to app_role;

create or replace function fc_extraer_cambios(old_row jsonb, new_row jsonb)
    returns TABLE(datos_anteriores jsonb, datos_nuevos jsonb)
    immutable
    language plpgsql
as
$$
DECLARE
    anteriores JSONB := '{}'::jsonb;
    nuevos JSONB := '{}'::jsonb;
    campo TEXT;
BEGIN

    FOR campo IN
        SELECT jsonb_object_keys(new_row)
    LOOP

        IF old_row -> campo IS DISTINCT FROM new_row -> campo THEN

            anteriores := anteriores ||
                jsonb_build_object(
                    campo,
                    old_row -> campo
                );

            nuevos := nuevos ||
                jsonb_build_object(
                    campo,
                    new_row -> campo
                );

        END IF;

    END LOOP;

    RETURN QUERY
    SELECT anteriores, nuevos;

END;
$$;

grant execute on function fc_extraer_cambios(jsonb, jsonb) to app_role;

create or replace function fc_auditoria() returns trigger
    security definer
    language plpgsql
as
$$
DECLARE
    v_anteriores JSONB;
    v_nuevos JSONB;
    v_fila JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_fila := to_jsonb(NEW);
        INSERT INTO auditoria(operacion,tabla, clave,datos_nuevos,id_empresa, id_usuario)
        VALUES (
            TG_OP,
            TG_TABLE_NAME,
            fc_extraer_clave(v_fila, VARIADIC TG_ARGV),
            v_fila,
            fc_empresa_actual(),
            fc_usuario_actual()
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        v_fila := to_jsonb(OLD);
        INSERT INTO auditoria(operacion,tabla, clave,datos_anteriores,id_empresa, id_usuario)
        VALUES (
            TG_OP,
            TG_TABLE_NAME,
            fc_extraer_clave(v_fila, VARIADIC TG_ARGV),
            v_fila,
            fc_empresa_actual(),
            fc_usuario_actual()
        );
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        SELECT
            datos_anteriores,
            datos_nuevos
        INTO
            v_anteriores,
            v_nuevos
        FROM fc_extraer_cambios(
            to_jsonb(OLD),
            to_jsonb(NEW)
        );
        IF v_anteriores = '{}'::jsonb THEN
            RETURN NEW;
        END IF;
        INSERT INTO auditoria(operacion,tabla, clave, datos_anteriores,datos_nuevos,id_empresa, id_usuario)
        VALUES (
            TG_OP,
            TG_TABLE_NAME,
            fc_extraer_clave(to_jsonb(NEW),VARIADIC TG_ARGV),
            v_anteriores,
            v_nuevos,
            fc_empresa_actual(),
            fc_usuario_actual()
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

create or replace function fc_prohibir_modificacion() returns trigger
    language plpgsql
as
$$
BEGIN
    IF pg_trigger_depth() = 0 THEN
        RAISE EXCEPTION
            'La tabla % solo puede modificarse mediante triggers.',
            TG_TABLE_NAME;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

grant execute on function fc_prohibir_modificacion() to app_role;

create or replace function fc_login(p_nombre character varying, p_pass character varying)
    returns TABLE(id uuid, nombre character varying, rol character varying, id_empresa uuid)
    security definer
    language plpgsql
as
$$
DECLARE
    v_id UUID;
    v_rol varchar;
    v_id_empresa UUID;
BEGIN
    select u.id, u.rol, u.id_empresa
    INTO v_id, v_rol, v_id_empresa
    from usuario u where u.nombre = p_nombre and u.password_hash = p_pass;
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Error al tratar de iniciar sesión. El usuario o la contraseña son incorrectas';
    END IF;
     PERFORM set_config('app.user_id', v_id::text, false);
    RETURN QUERY
    SELECT v_id, p_nombre, v_rol, v_id_empresa;
END;
$$;

create or replace function fc_crear_configuraciones() returns trigger
    security definer
    language plpgsql
as
$$
    begin
        insert into configuraciones (id_empresa) values (NEW.id);
        return new;
    end;
$$;
