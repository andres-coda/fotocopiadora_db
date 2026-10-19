-- 20_tablas/02_catalogo.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create table if not exists materia
(
    id                  uuid      default gen_random_uuid() not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP not null,
    deleted             boolean   default false,
    nombre              varchar(50)                         not null
);

alter table materia
    add constraint pk_id_materia
        primary key (id);

alter table materia
    add constraint uq_materia_nombre
        unique (nombre);

create policy pc_materia_update on materia
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_materia_delete on materia
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_materia_select on materia
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

create policy pc_materia_insert on materia
    as permissive
    for insert
    with check (fc_usuario_actual() IS NOT NULL);

grant delete, insert, select, update on materia to app_role;

create table if not exists libro
(
    id                  uuid      default gen_random_uuid() not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP not null,
    deleted             boolean   default false,
    nombre              varchar(255)                        not null,
    id_materia          uuid                                not null,
    id_editorial        uuid
);

alter table libro
    add constraint pk_id_libro
        primary key (id);

alter table libro
    add constraint uq_libro_nombre
        unique (nombre);

alter table libro
    add constraint fk_id_materia
        foreign key (id_materia) references materia
            on delete cascade;

create policy pc_libro_update on libro
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_libro_delete on libro
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_libro_select on libro
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

create policy pc_libro_insert on libro
    as permissive
    for insert
    with check (fc_usuario_actual() IS NOT NULL);

grant delete, insert, select, update on libro to app_role;

create table if not exists componente
(
    id                  uuid      default gen_random_uuid() not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP not null,
    deleted             boolean   default false,
    nombre              varchar(30)                         not null
);

alter table componente
    add constraint pk_componente
        primary key (id);

alter table componente
    add constraint uq_componente_nombre
        unique (nombre);

create policy pc_componente_delete on componente
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_componente_update on componente
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_componente_select on componente
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

create policy pc_componente_insert on componente
    as permissive
    for insert
    with check (fc_usuario_actual() IS NOT NULL);

grant delete, insert, select, update on componente to app_role;

create table if not exists libro_componente
(
    id_libro      uuid not null,
    id_componente uuid not null
);

alter table libro_componente
    add constraint pk_libro_componente
        primary key (id_libro, id_componente);

alter table libro_componente
    add constraint fk_libro_componente_componente
        foreign key (id_componente) references componente
            on delete cascade;

create policy pc_libro_componente_update on libro_componente
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_libro_componente_delete on libro_componente
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_libro_componente_select on libro_componente
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

create policy pc_libro_componente_insert on libro_componente
    as permissive
    for insert
    with check (fc_usuario_actual() IS NOT NULL);

grant delete, insert, select, update on libro_componente to app_role;

create table if not exists libro_empresa
(
    id_empresa               uuid    default fc_empresa_actual()                   not null,
    id_libro                 uuid                                                  not null,
    deleted                  boolean default false,
    cantidad_pg              integer default 0                                     not null,
    cantidad_adhesivo        integer default 0                                     not null,
    especificaciones_defecto jsonb   default '["color", "d_f", "anillado"]'::jsonb not null,
    detalle_impresion        varchar(50)
);

alter table libro_empresa
    add constraint pk_libro_empresa
        primary key (id_empresa, id_libro);

alter table libro_empresa
    add constraint fk_libro_empresa_empresa
        foreign key (id_empresa) references empresa
            on delete cascade;

alter table libro_empresa
    add constraint ch_cantidad_pg_positiva
        check (cantidad_pg >= 0);

alter table libro_empresa
    add constraint ch_cantidad_adhesivos_positiva
        check (cantidad_adhesivo >= 0);

create policy pc_libro_empresa on libro_empresa
    as permissive
    for all
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa))
    with check (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

grant delete, insert, select, update on libro_empresa to app_role;

create table if not exists precio_empresa
(
    id_precio           uuid           default gen_random_uuid()   not null,
    fecha_creacion      timestamp      default CURRENT_TIMESTAMP   not null,
    fecha_actualizacion timestamp      default CURRENT_TIMESTAMP   not null,
    deleted             boolean        default false,
    importe             numeric(10, 2) default 0                   not null,
    id_empresa          uuid           default fc_empresa_actual() not null,
    detalles            varchar(250)
);

alter table precio_empresa
    add constraint pk_precio_empresa
        primary key (id_empresa, id_precio);

alter table precio_empresa
    add constraint fk_precio_empresa
        foreign key (id_empresa) references empresa
            on delete cascade;

alter table precio_empresa
    add constraint ch_importe_positivo
        check (importe >= (0)::numeric);

create policy pc_precio_empresa on precio_empresa
    as permissive
    for all
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa))
    with check (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

grant delete, insert, select, update on precio_empresa to app_role;

create table if not exists editorial
(
    id                  uuid      default gen_random_uuid() not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP not null,
    deleted             boolean   default false,
    nombre              varchar(255)                        not null
);

alter table editorial
    add constraint pk_id_editorial
        primary key (id);

alter table libro
    add constraint fk_libro_editorial
        foreign key (id_editorial) references editorial;

alter table editorial
    add constraint uq_editorial_nombre
        unique (nombre);

create policy pc_editorial_update on editorial
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_editorial_delete on editorial
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_editorial_select on editorial
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

create policy pc_editorial_insert on editorial
    as permissive
    for insert
    with check (fc_usuario_actual() IS NOT NULL);

grant delete, insert, select, update on editorial to app_role;

create table if not exists nivel
(
    id                  uuid      default gen_random_uuid() not null,
    nombre              varchar(30)                         not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP not null,
    deleted             boolean   default false
);

alter table nivel
    add constraint pk_nivel
        primary key (id);

alter table nivel
    add constraint uq_nivel_nombre
        unique (nombre);

create policy pc_nivel_nombre on nivel
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_nivel_nombre_delete on nivel
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_nivel_insert on nivel
    as permissive
    for insert
    with check (fc_usuario_actual() IS NOT NULL);

create policy pc_nivel_select on nivel
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

grant delete, insert, select, update on nivel to app_role;

create table if not exists libro_completo
(
    id          uuid default gen_random_uuid() not null,
    id_libro    uuid                           not null,
    id_nivel    uuid,
    anio        varchar(4),
    autor       varchar(50),
    img         varchar(200),
    edicion     integer,
    descripcion varchar(250)
);

alter table libro_completo
    add constraint pk_libro_completo
        primary key (id);

alter table libro_componente
    add constraint fk_libro_componente_libro
        foreign key (id_libro) references libro_completo
            on delete cascade;

alter table libro_empresa
    add constraint fk_libro_empresa_libro
        foreign key (id_libro) references libro_completo
            on delete cascade;

alter table libro_completo
    add constraint fk_libro_completo_nivel
        foreign key (id_nivel) references nivel;

alter table libro_completo
    add constraint fk_libro_completo_libro
        foreign key (id_libro) references libro
            on delete cascade;

create policy pc_libro_completo_select on libro_completo
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

create policy pc_libro_completo_insert on libro_completo
    as permissive
    for insert
    with check (fc_usuario_actual() IS NOT NULL);

create policy pc_libro_completo_delete on libro_completo
    as permissive
    for delete
    using fc_es_super_admin();

create policy pc_libro_completo_update on libro_completo
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

grant delete, insert, select, update on libro_completo to app_role;

create table if not exists precio
(
    id          uuid default gen_random_uuid() not null,
    nombre      varchar(50)                    not null,
    descripcion varchar(250),
    abreviatura varchar(10)
);

alter table precio
    add constraint pk_precio
        primary key (id);

alter table precio_empresa
    add constraint fk_precio_empresa_precio
        foreign key (id_precio) references precio
            on delete cascade;

alter table precio
    add constraint uq_precio_nombre
        unique (nombre);

alter table precio
    add constraint uq_abreviatura
        unique (abreviatura);

alter table precio
    add constraint ch_precio_nombre_valido
        check (length((nombre)::text) >= 3);

alter table precio
    add constraint ch_abreviatura
        check ((abreviatura)::text = ANY
               ((ARRAY ['byn'::character varying, 'byn_d_f'::character varying, 'color'::character varying, 'color_d_f'::character varying, 'adhes'::character varying, 'trokelado'::character varying, 'anillado_1'::character varying, 'anillado_2'::character varying, 'anillado_3'::character varying, 'anillado_4'::character varying])::text[]));

create policy pc_precio_insert on precio
    as permissive
    for insert
    with check (fc_usuario_actual() IS NOT NULL);

create policy pc_precio_select on precio
    as permissive
    for select
    using (fc_usuario_actual() IS NOT NULL);

create policy pc_precio_update on precio
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_precio_delete on precio
    as permissive
    for delete
    using fc_es_super_admin();

grant delete, insert, select, update on precio to app_role;
