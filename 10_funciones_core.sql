-- 10_funciones_core.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace function fc_usuario_actual() returns uuid
    stable
    language plpgsql
as
$$
DECLARE
    user_id UUID;

BEGIN
    RETURN current_setting('app.user_id', true)::UUID;
    EXCEPTION WHEN OTHERS THEN RETURN NULL;
END;
$$;

grant execute on function fc_usuario_actual() to app_role;

create or replace function fc_empresa_actual() returns uuid
    stable
    language plpgsql
as
$$
BEGIN
    PERFORM fc_cargar_contexto_usuario();
    RETURN NULLIF(
        current_setting('app.empresa_id', true),
        ''
    )::uuid;
END;
$$;

grant execute on function fc_empresa_actual() to app_role;

create or replace function fc_es_admin() returns boolean
    stable
    language plpgsql
as
$$
BEGIN
    PERFORM fc_cargar_contexto_usuario();
    RETURN current_setting('app.rol', true) IN ('admin', 'super_admin');
END;
$$;

grant execute on function fc_es_admin() to app_role;

create or replace function fc_es_super_admin() returns boolean
    stable
    language plpgsql
as
$$
BEGIN
    PERFORM fc_cargar_contexto_usuario();
    RETURN current_setting('app.rol', true) = 'super_admin';
END;
$$;

grant execute on function fc_es_super_admin() to app_role;

create or replace function fc_es_empresa_actual(p_id_empresa uuid) returns boolean
    stable
    language plpgsql
as
$$
BEGIN
    PERFORM fc_cargar_contexto_usuario();

    IF current_setting('app.empresa_id', true)::UUID <> p_id_empresa THEN
        RETURN false;
    END IF;

    RETURN TRUE;
END;
$$;

grant execute on function fc_es_empresa_actual(uuid) to app_role;

create or replace function fc_cargar_contexto_usuario() returns void
    security definer
    language plpgsql
as
$$
DECLARE
    v_rol     VARCHAR(20);
    v_empresa UUID;
BEGIN
    -- Si ya fue cargado en esta transacción, no hacer nada
    IF current_setting('app.contexto_cargado', true) = 'true' THEN
        RETURN;
    END IF;

    SELECT rol, id_empresa
    INTO v_rol, v_empresa
    FROM usuario
    WHERE id = fc_usuario_actual();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario % no encontrado', fc_usuario_actual();
    END IF;

    -- Guardar en GUCs locales (duran solo la transacción con SET LOCAL)
    PERFORM set_config('app.rol',        v_rol,                true);
    PERFORM set_config('app.empresa_id', v_empresa::text,      true);
    PERFORM set_config('app.contexto_cargado', 'true',         true);
END;
$$;

grant execute on function fc_cargar_contexto_usuario() to app_role;
