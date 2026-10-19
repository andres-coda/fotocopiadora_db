-- 20_tablas/04_stock_especificacion.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create table if not exists stock
(
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP not null,
    stock               integer   default 0                 not null,
    id_libro            uuid                                not null,
    id_empresa          uuid                                not null
);

alter table stock
    add constraint pk_stock
        primary key (id_empresa, id_libro);

alter table stock
    add constraint fk_stock_libro_empresa
        foreign key (id_empresa, id_libro) references libro_empresa
            on delete cascade;

alter table stock
    add constraint ch_stock_positiva
        check (stock >= 0);

create policy pc_stock_all on stock
    as permissive
    for all
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

grant references, select, trigger, truncate, update on stock to app_role;

create table if not exists especificacion
(
    id      uuid    default gen_random_uuid() not null,
    deleted boolean default false,
    nombre  varchar(10)                       not null
);

alter table especificacion
    add constraint pk_especificacion
        primary key (id);

alter table especificacion
    add constraint uq_esp_nombre
        unique (nombre);

create policy pc_especificacion_update on especificacion
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_especificacion_delete on especificacion
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_especificacion_insert on especificacion
    as permissive
    for insert
    with check fc_es_super_admin();

create policy pc_especificacion_select on especificacion
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

grant delete, insert, select, update on especificacion to app_role;
