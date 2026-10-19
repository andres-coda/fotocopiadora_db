-- 50_triggers/03_resumen.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create trigger tr_actualizar_resumen_libro
    after insert or update or delete
    on pedido_item
    for each row
execute procedure fc_actualizar_resumen();

grant execute on function fc_actualizar_resumen() to app_role;

create trigger tr_actualiza_resumen_cliente_update_estado
    after update
        of estado
    on pedido
    for each row
    when (old.estado IS DISTINCT FROM new.estado AND
          NOT ((old.estado = ANY (ARRAY [1, 2, 3])) AND (new.estado = ANY (ARRAY [1, 2, 3]))))
execute procedure fc_actualizar_resumen_cliente();

create trigger tr_actualizar_resumen_cliente_insert_delete
    after insert or delete
    on pedido
    for each row
execute procedure fc_actualizar_resumen_cliente();

grant execute on function fc_actualizar_resumen_cliente() to app_role;

create trigger tr_crear_resumen_cliente
    after insert
    on cliente
    for each row
execute procedure fc_crear_resumen_cliente();

grant execute on function fc_crear_resumen_cliente() to app_role;

create trigger tr_crear_resumen_libro
    after insert
    on libro_empresa
    for each row
execute procedure fc_crear_resumen_libro();

grant execute on function fc_crear_resumen_libro() to app_role;

create trigger tr_crear_stock
    after insert
    on libro_empresa
    for each row
execute procedure fc_crear_stock();

grant execute on function fc_crear_stock() to app_role;
