-- 20_tablas/03_clientes.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create table if not exists cliente
(
    id                  uuid      default gen_random_uuid()   not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP   not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP   not null,
    deleted             boolean   default false,
    id_empresa          uuid      default fc_empresa_actual() not null,
    email               varchar(50),
    telefono            varchar(15),
    nombre              varchar(50)
);

alter table cliente
    add constraint pk_cliente
        primary key (id);

alter table cliente
    add constraint uq_cliente_telefono
        unique (id_empresa, telefono);

alter table cliente
    add constraint uq_cliente_email
        unique (id_empresa, email);

alter table cliente
    add constraint fk_empresa_cliente
        foreign key (id_empresa) references empresa
            on delete cascade;

alter table cliente
    add constraint chk_cliente_contacto_minimo
        check ((email IS NOT NULL) OR (telefono IS NOT NULL));

alter table cliente
    add constraint ch_telefono
        check ((telefono)::text ~ '^\+?[0-9]{10,}$'::text);

alter table cliente
    add constraint ch_cliente_email
        check ((email IS NULL) OR ((email)::text ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text));

create policy pc_cliente on cliente
    as permissive
    for all
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa))
    with check (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

grant delete, insert, select, update on cliente to app_role;

create table if not exists sede
(
    id                  uuid      default gen_random_uuid()   not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP   not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP   not null,
    deleted             boolean   default false,
    id_empresa          uuid      default fc_empresa_actual() not null,
    nombre              varchar(50)                           not null
);

alter table sede
    add constraint pk_sede
        primary key (id);

alter table sede
    add constraint uq_sede_nombre
        unique (id_empresa, nombre);

alter table sede
    add constraint fk_empresa_sede
        foreign key (id_empresa) references empresa;

create policy pc_sede_select on sede
    as permissive
    for select
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_sede_insert on sede
    as permissive
    for insert
    with check (fc_es_super_admin() OR (fc_es_empresa_actual(id_empresa) AND fc_es_admin()));

create policy pc_sede_delete on sede
    as permissive
    for delete
    using (fc_es_super_admin() OR (fc_es_empresa_actual(id_empresa) AND fc_es_admin()));

create policy pc_sede_update on sede
    as permissive
    for update
    using (fc_es_super_admin() OR (fc_es_empresa_actual(id_empresa) AND fc_es_admin()))
    with check (fc_es_super_admin() OR (fc_es_empresa_actual(id_empresa) AND fc_es_admin()));

grant delete, insert, references, select, trigger, truncate, update on sede to app_role;

create table if not exists resumen_cliente
(
    pendiente  integer default 0 not null,
    listo      integer default 0 not null,
    cancelado  integer default 0 not null,
    retirado   integer default 0 not null,
    id_cliente uuid              not null
);

alter table resumen_cliente
    add constraint pk_resumen
        primary key (id_cliente);

alter table resumen_cliente
    add constraint fk_cliente_resumen
        foreign key (id_cliente) references cliente
            on delete cascade;

alter table resumen_cliente
    add constraint ck_resumen_cliente_no_negativo
        check ((pendiente >= 0) AND (listo >= 0) AND (retirado >= 0) AND (cancelado >= 0));

create policy pc_resumen_cliente_select on resumen_cliente
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

grant select on resumen_cliente to app_role;

create table if not exists resumen_libro
(
    pendiente  integer default 0 not null,
    listo      integer default 0 not null,
    cancelado  integer default 0 not null,
    retirado   integer default 0 not null,
    id_libro   uuid              not null,
    id_empresa uuid              not null
);

alter table resumen_libro
    add constraint pk_resumen_libro
        primary key (id_empresa, id_libro);

alter table resumen_libro
    add constraint fk_resumen_libro_libro
        foreign key (id_empresa, id_libro) references libro_empresa
            on delete cascade;

alter table resumen_libro
    add constraint ck_resumen_libro_no_negativo
        check ((pendiente >= 0) AND (listo >= 0) AND (retirado >= 0) AND (cancelado >= 0));

create policy pc_resumen_libro_select on resumen_libro
    as permissive
    for select
    using (id_empresa = fc_empresa_actual());

grant select on resumen_libro to app_role;
