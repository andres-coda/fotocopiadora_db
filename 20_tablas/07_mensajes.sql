-- 20_tablas/07_mensajes.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create table if not exists mensaje
(
    id         uuid default gen_random_uuid() not null,
    id_empresa uuid                           not null,
    nombre     varchar(50)                    not null,
    mensaje    text,
    favorito   boolean default false          not null
);

alter table mensaje
    add constraint pk_mensaje
        primary key (id);

alter table mensaje
    add constraint uq_mensaje_nombre
        unique (id_empresa, nombre);

alter table mensaje
    add constraint fk_mensaje_empresa
        foreign key (id_empresa) references empresa
            on delete cascade;

create policy pc_msj_select on mensaje
    as permissive
    for select
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_msj_insert on mensaje
    as permissive
    for insert
    with check fc_es_empresa_actual(id_empresa);

create policy pc_msj_delete on mensaje
    as permissive
    for delete
    using (fc_es_empresa_actual(id_empresa) AND fc_es_admin());

create policy pc_msj_update on mensaje
    as permissive
    for update
    using fc_es_empresa_actual(id_empresa)
with check fc_es_empresa_actual(id_empresa);

create table if not exists dato_cobro
(
    id         uuid default gen_random_uuid() not null,
    id_empresa uuid                           not null,
    nombre     varchar(50)                    not null,
    mensaje    text
);

alter table dato_cobro
    add constraint pk_dato_cobro
        primary key (id);

alter table dato_cobro
    add constraint uq_dato_cobro_nombre
        unique (id_empresa, nombre);

alter table dato_cobro
    add constraint fk_dato_cobro_empresa
        foreign key (id_empresa) references empresa
            on delete cascade;

create policy pc_dato_cobro_select on dato_cobro
    as permissive
    for select
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_dato_cobro_insert on dato_cobro
    as permissive
    for insert
    with check (fc_es_empresa_actual(id_empresa) AND fc_es_admin());

create policy pc_dato_cobro_delete on dato_cobro
    as permissive
    for delete
    using (fc_es_empresa_actual(id_empresa) AND fc_es_admin());

create policy pc_dato_cobro_update on dato_cobro
    as permissive
    for update
    using (fc_es_empresa_actual(id_empresa) AND fc_es_admin())
    with check (fc_es_empresa_actual(id_empresa) AND fc_es_admin());

create table if not exists configuraciones
(
    id_empresa             uuid                                not null,
    fecha_actualizacion    timestamp default CURRENT_TIMESTAMP not null,
    fecha_entrega          date,
    id_dato_cobro          uuid,
    id_msj_pedido_tomado   uuid,
    id_msj_pedido_retirado uuid,
    id_sede                uuid,
    msj_retiro             boolean   default false,
    msj_envio              boolean   default false,
    hora_entrega           smallint
);

alter table configuraciones
    add constraint pk_config
        primary key (id_empresa);

alter table configuraciones
    add constraint fk_config_sede
        foreign key (id_sede) references sede;

alter table configuraciones
    add constraint fk_config_dato_cobro
        foreign key (id_dato_cobro) references dato_cobro;

alter table configuraciones
    add constraint fk_config_mensaje_tomado
        foreign key (id_msj_pedido_tomado) references mensaje;

alter table configuraciones
    add constraint fk_config_mensaje_retirado
        foreign key (id_msj_pedido_retirado) references mensaje;

alter table configuraciones
    add constraint fk_config_empresa
        foreign key (id_empresa) references empresa
            on delete cascade;

alter table configuraciones
    add constraint chk_config_hora
        check ((hora_entrega >= 0) AND (hora_entrega <= 23));

create policy pc_config_select on configuraciones
    as permissive
    for select
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_config_update on configuraciones
    as permissive
    for update
    using fc_es_empresa_actual(id_empresa)
with check fc_es_empresa_actual(id_empresa);
