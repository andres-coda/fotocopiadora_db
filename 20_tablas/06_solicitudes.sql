-- 20_tablas/06_solicitudes.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create table if not exists propuesta
(
    id                  uuid      default gen_random_uuid() not null,
    fecha_creacion      timestamp default CURRENT_TIMESTAMP not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP not null,
    deleted             boolean   default false,
    nombre              varchar(50)                         not null,
    id_empresa          uuid      default fc_empresa_actual()
);

alter table propuesta
    add constraint pk_propuesta
        primary key (id);

alter table propuesta
    add constraint uq_propuesta_nombre
        unique (id_empresa, nombre);

alter table propuesta
    add constraint fk_propuesta_empresa
        foreign key (id_empresa) references empresa
            on delete cascade;

create policy pc_propuesta_select on propuesta
    as permissive
    for select
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_propuesta_insert on propuesta
    as permissive
    for insert
    with check (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_propuesta_delete on propuesta
    as permissive
    for delete
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_propuesta_update on propuesta
    as permissive
    for update
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa))
    with check (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

grant delete, insert, references, select, trigger, truncate, update on propuesta to app_role;

create table if not exists propuesta_libro_empresa
(
    id_libro     uuid                             not null,
    id_empresa   uuid default fc_empresa_actual() not null,
    id_propuesta uuid                             not null
);

alter table propuesta_libro_empresa
    add constraint pk_propuesta_libro_empresa
        primary key (id_empresa, id_libro, id_propuesta);

alter table propuesta_libro_empresa
    add constraint fk_propuesta
        foreign key (id_propuesta) references propuesta
            on delete cascade;

alter table propuesta_libro_empresa
    add constraint fk_libro_empresa
        foreign key (id_empresa, id_libro) references libro_empresa
            on delete cascade;

create policy pc_propuesta_libro_empresa_all on propuesta_libro_empresa
    as permissive
    for all
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa))
    with check (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

grant delete, insert, select, update on propuesta_libro_empresa to app_role;

create table if not exists solicitud
(
    id                uuid      default gen_random_uuid() not null,
    id_libro_completo uuid                                not null,
    fecha_creacion    timestamp default CURRENT_TIMESTAMP not null,
    fecha_resolucion  timestamp,
    id_usuario        uuid                                not null,
    estado            integer,
    id_empresa        uuid                                not null
);

alter table solicitud
    add constraint pk_solicitud
        primary key (id);

alter table solicitud
    add constraint fk_solicitud_usuario
        foreign key (id_usuario) references usuario;

alter table solicitud
    add constraint fk_solicitud_libro_completo
        foreign key (id_libro_completo) references libro_completo;

alter table solicitud
    add constraint fk_solicitud_empresa
        foreign key (id_empresa) references empresa;

alter table solicitud
    add constraint chk_solicitud_estado
        check (estado = ANY (ARRAY [1, 2, 3]));

create policy pc_solicitud_select on solicitud
    as permissive
    for select
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_solicitud_insert on solicitud
    as permissive
    for insert
    with check fc_es_empresa_actual(id_empresa);

create policy pc_solicitud_delete on solicitud
    as permissive
    for delete
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

create policy pc_solicitud_update on solicitud
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

grant delete, insert, references, select, trigger, truncate, update on solicitud to app_role;

create table if not exists peticion
(
    id             uuid    default gen_random_uuid() not null,
    id_solicitud   uuid                              not null,
    campo          varchar(20)                       not null,
    valor_anterior varchar,
    valor_nuevo    varchar,
    observaciones  varchar,
    estado         integer default 1
);

alter table peticion
    add constraint pk_peticion
        primary key (id);

alter table peticion
    add constraint fk_peticion_solicitud
        foreign key (id_solicitud) references solicitud;

alter table peticion
    add constraint chk_peticion_estado
        check (estado = ANY (ARRAY [1, 2, 3]));

alter table peticion
    add constraint chk_peticion_campo
        check ((campo)::text = ANY
               (ARRAY [('anio'::character varying)::text, ('autor'::character varying)::text, ('img'::character varying)::text, ('edicion'::character varying)::text, ('descripcion'::character varying)::text, ('nombre'::character varying)::text, ('materia'::character varying)::text, ('nivel'::character varying)::text, ('componentes'::character varying)::text, ('editorial'::character varying)::text]));

create policy pc_peticion_update on peticion
    as permissive
    for update
    using fc_es_super_admin()
with check fc_es_super_admin();

create policy pc_peticion_insert on peticion
    as permissive
    for insert
    with check fc_es_empresa_actual(( SELECT solicitud.id_empresa
    FROM solicitud
    WHERE (solicitud.id = peticion.id_solicitud)
    LIMIT 1));

create policy pc_peticion_select on peticion
    as permissive
    for select
    using (fc_es_super_admin() OR fc_es_empresa_actual((SELECT solicitud.id_empresa
                                                        FROM solicitud
                                                        WHERE (solicitud.id = peticion.id_solicitud)
                                                        LIMIT 1)));

create policy pc_peticion_delete on peticion
    as permissive
    for delete
    using (fc_es_super_admin() OR fc_es_empresa_actual((SELECT solicitud.id_empresa
                                                        FROM solicitud
                                                        WHERE (solicitud.id = peticion.id_solicitud)
                                                        LIMIT 1)));

grant delete, insert, references, select, trigger, truncate, update on peticion to app_role;
