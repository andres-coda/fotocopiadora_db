-- 50_triggers/02_auditoria.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create trigger tr_empresa_auditoria
    after insert or update or delete
    on empresa
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_materia
    after insert
    on materia
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_libro
    after insert or update or delete
    on libro
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_componente
    after insert or update or delete
    on componente
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_libro_componente
    after insert or update or delete
    on libro_componente
    for each row
execute procedure fc_auditoria('id_libro', 'id_componente');

create trigger tr_auditoria_libro_empresa
    after insert or update or delete
    on libro_empresa
    for each row
execute procedure fc_auditoria('id_libro', 'id_empresa');

create trigger tr_auditoria_lprecio
    after insert or update or delete
    on precio_empresa
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_propuesta
    after insert or update or delete
    on propuesta
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_cliente
    after insert or update or delete
    on cliente
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_sede
    after insert or update or delete
    on sede
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_stock
    after insert or update or delete
    on stock
    for each row
execute procedure fc_auditoria('id_empresa', 'id_libro');

create trigger tr_auditoria_pedido
    after insert or update or delete
    on pedido
    for each row
execute procedure fc_auditoria('id');

create trigger tr_auditoria_pedido_item
    after insert or update or delete
    on pedido_item
    for each row
execute procedure fc_auditoria('id_pedido', 'id');

create trigger tr_auditoria_pedido_item_especificacion
    after insert or update or delete
    on pedido_item_especificacion
    for each row
execute procedure fc_auditoria('id_pedido', 'nro_item', 'id_especificacion');

create trigger tr_nivel_auditoria
    after insert
    on nivel
    for each row
execute procedure fc_auditoria('id');

create trigger tr_libro_completo_auditoria
    after insert or update or delete
    on libro_completo
    for each row
execute procedure fc_auditoria('id');

create trigger tr_config_auditoria
    after insert or update or delete
    on configuraciones
    for each row
execute procedure fc_auditoria('id_empresa');

grant execute on function fc_auditoria() to app_role;
