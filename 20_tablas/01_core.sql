-- 20_tablas/01_core.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create table if not exists empresa
(
    id                  uuid      default gen_random_uuid() not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP not null,
    deleted             boolean   default false,
    nombre              varchar(50)                         not null,
    email               varchar(150)                        not null,
    telefono            varchar(15)                         not null
);

alter table empresa
    add constraint pk_empresa
        primary key (id);

alter table empresa
    add constraint uq_empresa_nombre
        unique (nombre);

alter table empresa
    add constraint uq_empresa_telefono
        unique (telefono);

alter table empresa
    add constraint uq_empresa_email
        unique (email);

alter table empresa
    add constraint ch_telefono
        check ((telefono)::text ~ '^\+?[0-9]{10,}$'::text);

alter table empresa
    add constraint ch_email
        check ((email)::text ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text);

create policy pc_empresa_insert on empresa
    as permissive
    for insert
    with check fc_es_super_admin();

create policy pc_empresa_delete on empresa
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_empresa_update on empresa
    as permissive
    for update
    using (fc_es_super_admin() OR (fc_es_admin() AND fc_es_empresa_actual(id)))
    with check (fc_es_super_admin() OR (fc_es_admin() AND fc_es_empresa_actual(id)));

create policy pc_empresa_select on empresa
    as permissive
    for select
    using (fc_es_super_admin() OR fc_es_empresa_actual(id));

grant delete, insert, select, update on empresa to app_role;

create table if not exists usuario
(
    id                  uuid        default gen_random_uuid()             not null,
    fecha_creacion      timestamp   default CURRENT_TIMESTAMP             not null,
    fecha_actualizacion timestamp   default CURRENT_TIMESTAMP             not null,
    deleted             boolean     default false,
    nombre              varchar(50)                                       not null,
    password_hash       varchar(255)                                      not null,
    id_empresa          uuid        default fc_empresa_actual(),
    rol                 varchar(20) default 'operador'::character varying not null,
    email               varchar(50)                                       not null
);

create unique index if not exists uq_super_admin
    on usuario (rol)
    where ((rol)::text = 'super_admin'::text);

alter table usuario
    add constraint pk_usuario
        primary key (id);

alter table usuario
    add constraint uq_nombre
        unique (id_empresa, nombre);

alter table usuario
    add constraint uk_email
        unique (email);

alter table usuario
    add constraint fk_empresa
        foreign key (id_empresa) references empresa
            on delete cascade;

alter table usuario
    add constraint ch_tipos_rol
        check ((rol)::text = ANY
               ((ARRAY ['super_admin'::character varying, 'admin'::character varying, 'operador'::character varying])::text[]));

alter table usuario
    add constraint ck_super_admin_empresa
        check ((((rol)::text <> 'super_admin'::text) AND (id_empresa IS NOT NULL)) OR
               (((rol)::text = 'super_admin'::text) AND (id_empresa IS NULL)));

create policy pc_usuario_select on usuario
    as permissive
    for select
    using
    CASE
    WHEN fc_es_super_admin() THEN true
    WHEN fc_es_admin() THEN (id_empresa = fc_empresa_actual())
    ELSE (id = fc_usuario_actual())
END;

create policy pc_usuario_update on usuario
    as permissive
    for update
    using (fc_es_super_admin() OR (fc_es_admin() AND (id_empresa = fc_empresa_actual())))
    with check (fc_es_super_admin() OR
                (fc_es_admin() AND (id_empresa = fc_empresa_actual()) AND ((rol)::text <> 'super_admin'::text)));

create policy pc_usuario_insert on usuario
    as permissive
    for insert
    with check (fc_es_super_admin() OR
                (fc_es_admin() AND (id_empresa = fc_empresa_actual()) AND ((rol)::text <> 'super_admin'::text)));

grant delete, insert, select, update on usuario to app_role;

create table if not exists auditoria
(
    id               bigserial,
    fecha_creacion   timestamp default CURRENT_TIMESTAMP not null,
    operacion        varchar(10)                         not null,
    tabla            varchar(50)                         not null,
    datos_anteriores jsonb,
    datos_nuevos     jsonb,
    id_usuario       uuid                                not null,
    id_empresa       uuid,
    clave            jsonb
);

grant select, usage on sequence auditoria_id_seq to app_role;

alter table auditoria
    add constraint pk_auditoria
        primary key (id);

alter table auditoria
    add constraint fk_auditoria_empresa
        foreign key (id_empresa) references empresa;

alter table auditoria
    add constraint fk_auditoria_usuario
        foreign key (id_usuario) references usuario;

create policy pc_auditoria_select on auditoria
    as permissive
    for select
    using (fc_es_super_admin() OR (fc_es_admin() AND fc_es_empresa_actual(id_empresa)));

grant select on auditoria to app_role;
