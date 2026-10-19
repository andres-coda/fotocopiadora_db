-- 50_triggers/04_dominio.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create trigger tr_actualizar_estado_pedido
    after insert or update or delete
    on pedido_item
    for each row
execute procedure fc_actualizar_estado_pedido();

grant execute on function fc_actualizar_estado_pedido() to app_role;

create trigger tr_cliente_delete
    before delete
    on cliente
    for each row
execute procedure fc_cliente_delete();

create trigger tr_libro_empresa_delete
    before delete
    on libro_empresa
    for each row
execute procedure fc_libro_empresa_delete();

create trigger tr_empresa_config_insert
    after insert
    on empresa
    for each row
execute procedure fc_crear_configuraciones();
