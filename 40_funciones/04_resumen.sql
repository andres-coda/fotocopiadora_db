-- 40_funciones/04_resumen.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace function fc_sumar_resumen_libro(p_aux pedido_item) returns void
    security definer
    language plpgsql
as
$$
BEGIN
    UPDATE resumen_libro
    SET
        pendiente = pendiente + CASE WHEN p_aux.estado IN (1,2,3) THEN p_aux.cantidad ELSE 0 END,
        listo = listo + CASE WHEN p_aux.estado = 4 THEN p_aux.cantidad ELSE 0 END,
        retirado = retirado + CASE WHEN p_aux.estado = 5 THEN p_aux.cantidad ELSE 0 END,
        cancelado = cancelado + CASE WHEN p_aux.estado = 6 THEN p_aux.cantidad ELSE 0 END
    WHERE id_empresa = p_aux.id_empresa
      AND id_libro = p_aux.id_libro;
END;
$$;

grant execute on function fc_sumar_resumen_libro(pedido_item) to app_role;

create or replace function fc_restar_resumen_libro(p_aux pedido_item) returns void
    security definer
    language plpgsql
as
$$
BEGIN
    UPDATE resumen_libro SET
        pendiente = pendiente - CASE WHEN p_aux.estado IN(1,2,3) THEN p_aux.cantidad ELSE 0 END,
        listo = listo - CASE WHEN p_aux.estado = 4 THEN p_aux.cantidad ELSE 0 END,
        retirado = retirado - CASE WHEN p_aux.estado = 5 THEN p_aux.cantidad ELSE 0 END,
        cancelado = cancelado - CASE WHEN p_aux.estado = 6 THEN p_aux.cantidad ELSE 0 END
    WHERE id_empresa = p_aux.id_empresa
      AND id_libro = p_aux.id_libro;
END;
$$;

grant execute on function fc_restar_resumen_libro(pedido_item) to app_role;

create or replace function fc_actualizar_resumen() returns trigger
    language plpgsql
as
$$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM fc_sumar_resumen_libro(NEW);
        RETURN NEW;
    end if;
    IF TG_OP = 'DELETE' THEN
        PERFORM fc_restar_resumen_libro(OLD);
        RETURN OLD;
    end if;
    IF TG_OP = 'UPDATE' THEN
        PERFORM fc_sumar_resumen_libro(NEW);
        PERFORM fc_restar_resumen_libro(OLD);
        RETURN NEW;
    end if;
    RETURN NULL;
END;
$$;

create or replace function fc_sumar_resumen_cliente(p_aux pedido) returns void
    security definer
    language plpgsql
as
$$
    declare v_rows integer;
BEGIN
    UPDATE resumen_cliente SET
        pendiente = pendiente + CASE WHEN p_aux.estado IN(1,2,3) THEN 1 ELSE 0 END,
        listo = listo + CASE WHEN p_aux.estado = 4 THEN 1 ELSE 0 END,
        retirado = retirado + CASE WHEN p_aux.estado = 5 THEN 1 ELSE 0 END,
        cancelado = cancelado + CASE WHEN p_aux.estado = 6 THEN 1 ELSE 0 END
    WHERE id_cliente = p_aux.id_cliente;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
RAISE NOTICE 'Filas actualizadas: %', v_rows;
END;
$$;

grant execute on function fc_sumar_resumen_cliente(pedido) to app_role;

create or replace function fc_restar_resumen_cliente(p_aux pedido) returns void
    security definer
    language plpgsql
as
$$
BEGIN
    UPDATE resumen_cliente SET
        pendiente = pendiente - CASE WHEN p_aux.estado IN(1,2,3) THEN 1 ELSE 0 END,
        listo = listo - CASE WHEN p_aux.estado = 4 THEN 1 ELSE 0 END,
        retirado = retirado - CASE WHEN p_aux.estado = 5 THEN 1 ELSE 0 END,
        cancelado = cancelado - CASE WHEN p_aux.estado = 6 THEN 1 ELSE 0 END
    WHERE id_cliente = p_aux.id_cliente;
END;
$$;

grant execute on function fc_restar_resumen_cliente(pedido) to app_role;

create or replace function fc_actualizar_resumen_cliente() returns trigger
    language plpgsql
as
$$
BEGIN
    RAISE NOTICE 'Se ejecutó el trigger. Operación: %', TG_OP;
    IF TG_OP = 'INSERT' THEN
        RAISE NOTICE 'Estado: %', NEW.estado;
        RAISE NOTICE 'id cliente: %', NEW.id_cliente;
        PERFORM fc_sumar_resumen_cliente(NEW);
        RAISE NOTICE 'Después de sumar';
        RETURN NEW;
    end if;
    IF TG_OP = 'DELETE' THEN
        PERFORM fc_restar_resumen_cliente(OLD);
        RETURN OLD;
    end if;
    IF TG_OP = 'UPDATE' THEN
        RAISE NOTICE 'Estado: % -> %', OLD.estado, NEW.estado;
        PERFORM fc_sumar_resumen_cliente(NEW);
        PERFORM fc_restar_resumen_cliente(OLD);
        RETURN NEW;
    end if;
    RETURN NULL;
END;
$$;

create or replace function fc_crear_resumen_cliente() returns trigger
    security definer
    language plpgsql
as
$$
    BEGIN
        INSERT INTO resumen_cliente (id_cliente)
        values (NEW.id);
        RETURN NEW;
    END;
    $$;

create or replace function fc_crear_resumen_libro() returns trigger
    security definer
    language plpgsql
as
$$
    BEGIN
        INSERT INTO resumen_libro (id_libro, id_empresa)
        values (NEW.id_libro, NEW.id_empresa);
        RETURN NEW;
    END;
    $$;

create or replace function fc_crear_stock() returns trigger
    security definer
    language plpgsql
as
$$
    BEGIN
        INSERT INTO stock (id_libro, id_empresa)
        values (NEW.id_libro, NEW.id_empresa);
        RETURN NEW;
    END;
    $$;

create or replace function fc_recalcular_resumen_cliente() returns void
    security definer
    language plpgsql
as
$$
BEGIN
    -- Reinicia los contadores
    UPDATE resumen_cliente
    SET
        pendiente = 0,
        listo = 0,
        retirado = 0,
        cancelado = 0;

    -- Recalcula desde la tabla pedido
    UPDATE resumen_cliente rc
    SET
        pendiente = x.pendiente,
        listo = x.listo,
        retirado = x.retirado,
        cancelado = x.cancelado
    FROM (
        SELECT
            p.id_cliente,
            COUNT(*) FILTER (WHERE p.estado IN (1,2,3)) AS pendiente,
            COUNT(*) FILTER (WHERE p.estado = 4) AS listo,
            COUNT(*) FILTER (WHERE p.estado = 5) AS retirado,
            COUNT(*) FILTER (WHERE p.estado = 6) AS cancelado
        FROM pedido p
        GROUP BY p.id_cliente
    ) x
    JOIN cliente c
        ON c.id = x.id_cliente
    WHERE rc.id_cliente = x.id_cliente
      AND c.id_empresa = fc_empresa_actual();

END;
$$;

grant execute on function fc_recalcular_resumen_cliente() to app_role;

create or replace function fc_recalcular_resumen_libro() returns void
    security definer
    language plpgsql
as
$$
BEGIN
    -- Reinicia los contadores
    UPDATE resumen_libro
    SET
        pendiente = 0,
        listo = 0,
        retirado = 0,
        cancelado = 0;

    -- Recalcula sumando la cantidad de cada item
    UPDATE resumen_libro rl
    SET
        pendiente = x.pendiente,
        listo = x.listo,
        retirado = x.retirado,
        cancelado = x.cancelado
    FROM (
        SELECT
            pi.id_libro, pi.id_empresa,
            COALESCE(SUM(pi.cantidad) FILTER (WHERE pi.estado IN (1,2,3)), 0) AS pendiente,
            COALESCE(SUM(pi.cantidad) FILTER (WHERE pi.estado = 4), 0) AS listo,
            COALESCE(SUM(pi.cantidad) FILTER (WHERE pi.estado = 5), 0) AS retirado,
            COALESCE(SUM(pi.cantidad) FILTER (WHERE pi.estado = 6), 0) AS cancelado
        FROM pedido_item pi
        GROUP BY pi.id_libro, pi.id_empresa
    ) x
    WHERE rl.id_libro = x.id_libro
      AND rl.id_empresa = fc_empresa_actual();
END;
$$;

grant execute on function fc_recalcular_resumen_libro() to app_role;
