-- 50_triggers/01_fechas.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create trigger tr_empresa_fecha_actualizacion
    before update
    on empresa
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_usuario_fecha_actualizacion
    before update
    on usuario
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_materia_fecha_actualizacion
    before update
    on materia
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_libro_fecha_actualizacion
    before update
    on libro
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_componente_fecha_actualizacion
    before update
    on componente
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_precio_fecha_actualizacion
    before update
    on precio_empresa
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_propuesta_fecha_actualizacion
    before update
    on propuesta
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_cliente_fecha_actualizacion
    before update
    on cliente
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_sede_fecha_actualizacion
    before update
    on sede
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_stock_fecha_actualizacion
    before update
    on stock
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_pedido_fecha_actualizacion
    before update
    on pedido
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_pedido_item_fecha_actualizacion
    before update
    on pedido_item
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_nivel_fecha_actualizacion
    before update
    on nivel
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

create trigger tr_config_fecha_actualizacion
    before update
    on configuraciones
    for each row
execute procedure fc_actualizar_fecha_actualizacion();

grant execute on function fc_actualizar_fecha_actualizacion() to app_role;
