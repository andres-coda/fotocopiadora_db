-- 20_tablas/05_pedidos.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create table if not exists pedido
(
    id                  uuid           default gen_random_uuid()   not null,
    fecha_creacion      timestamp      default CURRENT_TIMESTAMP   not null,
    fecha_actualizacion timestamp      default CURRENT_TIMESTAMP   not null,
    deleted             boolean        default false,
    fecha_entrega       date           default now()               not null,
    importe_total       numeric(10, 2) default 0                   not null,
    archivos            integer        default 1                   not null,
    anillados           integer        default 0                   not null,
    sena                numeric(10, 2) default 0                   not null,
    id_cliente          uuid                                       not null,
    id_empresa          uuid           default fc_empresa_actual() not null,
    estado              integer        default 1                   not null
);

create index if not exists ix_pedido_cliente
    on pedido (id_cliente);

create index if not exists ix_pedido_estado
    on pedido (estado);

create index if not exists ix_pedido_fecha
    on pedido (fecha_entrega);

alter table pedido
    add constraint pk_pedido
        primary key (id);

alter table pedido
    add constraint fk_cliente_pedido
        foreign key (id_cliente) references cliente
            on delete cascade;

alter table pedido
    add constraint fk_empresa_pedido
        foreign key (id_empresa) references empresa
            on delete cascade;

alter table pedido
    add constraint ck_estado_pedido
        check ((estado >= 1) AND (estado <= 7));

alter table pedido
    add constraint ch_anillado_positiva
        check (anillados >= 0);

alter table pedido
    add constraint ch_archivos_positiva
        check (archivos > 0);

alter table pedido
    add constraint ch_sena_positiva
        check (sena >= (0)::numeric);

alter table pedido
    add constraint ch_importe_total_positiva
        check (importe_total >= (0)::numeric);

create policy pc_pedido_all on pedido
    as permissive
    for all
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa))
    with check (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

grant delete, insert, references, select, trigger, truncate, update on pedido to app_role;

create table if not exists pedido_item
(
    fecha_creacion      timestamp default CURRENT_TIMESTAMP   not null,
    fecha_actualizacion timestamp default CURRENT_TIMESTAMP   not null,
    deleted             boolean   default false,
    cantidad            integer   default 0                   not null,
    detalles            varchar(255),
    estado              integer   default 1                   not null,
    id_sede             uuid                                  not null,
    id_pedido           uuid                                  not null,
    id_libro            uuid                                  not null,
    id_empresa          uuid      default fc_empresa_actual() not null,
    id                  serial
);

grant select, usage on sequence pedido_item_id_seq to app_role;

create index if not exists ix_pedido_item_estado
    on pedido_item (id_pedido, id, estado);

alter table pedido_item
    add constraint pk_pedido_item
        primary key (id_pedido, id);

alter table pedido_item
    add constraint fk_item_pedido
        foreign key (id_pedido) references pedido
            on delete cascade;

alter table pedido_item
    add constraint fk_item_libro_empresa
        foreign key (id_empresa, id_libro) references libro_empresa
            on delete cascade;

alter table pedido_item
    add constraint fk_item_sede
        foreign key (id_sede) references sede
            on delete cascade;

alter table pedido_item
    add constraint ck_estado_pedido_item
        check ((estado >= 1) AND (estado <= 7));

alter table pedido_item
    add constraint ch_cantidad_positiva
        check (cantidad > 0);

create policy pc_pedido_item_all on pedido_item
    as permissive
    for all
    using (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa))
    with check (fc_es_super_admin() OR fc_es_empresa_actual(id_empresa));

grant delete, insert, references, select, trigger, truncate, update on pedido_item to app_role;

create table if not exists pedido_item_especificacion
(
    id_pedido         uuid    not null,
    id_especificacion uuid    not null,
    nro_item          integer not null
);

alter table pedido_item_especificacion
    add constraint pk_pedido_item_especificacion
        primary key (id_pedido, nro_item, id_especificacion);

alter table pedido_item_especificacion
    add constraint fk_especificacion
        foreign key (id_especificacion) references especificacion
            on delete cascade;

alter table pedido_item_especificacion
    add constraint fk_pie_pedido_items
        foreign key (id_pedido, nro_item) references pedido_item
            on delete cascade;

create policy pedido_item_especificacion_all on pedido_item_especificacion
    as permissive
    for all
    using (fc_usuario_actual() IS NOT NULL)
    with check (fc_usuario_actual() IS NOT NULL);

grant delete, insert, references, select, trigger, truncate, update on pedido_item_especificacion to app_role;
