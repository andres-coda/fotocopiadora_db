-- 01_tipos.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create type tp_pedido_item as
(
    cantidad         integer,
    detalles         varchar(255),
    id_sede          uuid,
    id_libro         uuid,
    especificaciones jsonb
);
