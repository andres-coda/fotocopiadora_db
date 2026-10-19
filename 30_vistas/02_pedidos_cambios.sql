-- 30_vistas/02_pedidos_cambios.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace view vw_pedidos_item
            (id_pedido, nro_pedido, cantidad, detalles, estado, especificaciones, cantidad_pg, cantidad_adhesivo,
             nombre, descripcion, edicion, anio, nivel, componentes, materia, editorial, pendiente, listo, retirado,
             cancelado, fecha_creacion, fecha_entrega, importe_total, sena, anillados, archivos, estado_pedido,
             telefono, email, id_cliente, sede, id_sede, id_libro, id_materia, total)
as
SELECT pi.id_pedido,
       pi.id            AS nro_pedido,
       pi.cantidad,
       pi.detalles,
       pi.estado,
       vwe.especificaciones,
       vwlb.cantidad_pg,
       vwlb.cantidad_adhesivo,
       vwlb.nombre,
       vwlb.descripcion,
       vwlb.edicion,
       vwlb.anio,
       vwlb.nivel,
       vwlb.componentes,
       vwlb.materia,
       vwlb.editorial,
       vwlb.pendiente,
       vwlb.listo,
       vwlb.retirado,
       vwlb.cancelado,
       vw_p.fecha_creacion,
       vw_p.fecha_entrega,
       vw_p.importe_total,
       vw_p.sena,
       vw_p.anillados,
       vw_p.archivos,
       vw_p.estado      AS estado_pedido,
       vw_p.telefono,
       vw_p.email,
       vw_p.id_cliente,
       s.nombre         AS sede,
       s.id             AS id_sede,
       pi.id_libro,
       vwlb.id_materia,
       count(*) OVER () AS total
FROM pedido_item pi
         LEFT JOIN vw_especificaciones vwe ON vwe.id_pedido = pi.id_pedido AND pi.id = vwe.nro_item
         LEFT JOIN vw_libro_busqueda vwlb ON vwlb.id = pi.id_libro
         JOIN vw_pedidos vw_p ON vw_p.id = pi.id_pedido
         LEFT JOIN sede s ON s.id = pi.id_sede;

grant select on vw_pedidos_item to app_role;

create or replace view vw_pedido_libro
            (id_pedido, nro_pedido, cantidad, detalles, estado, id_libro, especificaciones, fecha_creacion,
             fecha_entrega, importe_total, sena, anillados, archivos, estado_pedido, sede, id_sede, telefono, email,
             total, id_cliente)
as
SELECT pi.id_pedido,
       pi.id            AS nro_pedido,
       pi.cantidad,
       pi.detalles,
       pi.estado,
       pi.id_libro,
       vwe.especificaciones,
       p.fecha_creacion,
       p.fecha_entrega,
       p.importe_total,
       p.sena,
       p.anillados,
       p.archivos,
       p.estado         AS estado_pedido,
       s.nombre         AS sede,
       s.id             AS id_sede,
       c.telefono,
       c.email,
       count(*) OVER () AS total,
       c.id             AS id_cliente
FROM pedido_item pi
         LEFT JOIN vw_especificaciones vwe ON vwe.id_pedido = pi.id_pedido AND pi.id = vwe.nro_item
         JOIN pedido p ON p.id = pi.id_pedido
         JOIN cliente c ON c.id = p.id_cliente
         LEFT JOIN sede s ON s.id = pi.id_sede;

grant select on vw_pedido_libro to app_role;

create or replace view vw_libro_nombre(id, nombre, deleted, id_materia, materia, id_editorial, editorial) as
SELECT l.id,
       l.nombre,
       l.deleted,
       m.id     AS id_materia,
       m.nombre AS materia,
       e.id     AS id_editorial,
       e.nombre AS editorial
FROM libro l
         LEFT JOIN materia m ON l.id_materia = m.id
         LEFT JOIN editorial e ON e.id = l.id_editorial;

grant select on vw_libro_nombre to app_role;

create or replace view vw_cambio_sede
            (fecha_actualizacion, id_pedido, id, id_libro, id_empresa, id_sede, id_cliente, sede) as
SELECT pi.fecha_actualizacion,
       pi.id_pedido,
       pi.id,
       pi.id_libro,
       pi.id_empresa,
       pi.id_sede,
       p.id_cliente,
       s.nombre AS sede
FROM pedido_item pi
         JOIN pedido p ON p.id = pi.id_pedido
         JOIN sede s ON pi.id_sede = s.id;

grant select on vw_cambio_sede to app_role;

create or replace view vw_cambio_estado_pedido
            (id, estado, fecha_actualizacion, id_cliente, retirado, listo, pendiente, cancelado, id_libro, id_empresa,
             nro_pedido, libro_retirado, libro_listo, libro_pendiente, libro_cancelado)
as
SELECT p.id,
       p.estado,
       p.fecha_actualizacion,
       p.id_cliente,
       rc.retirado,
       rc.listo,
       rc.pendiente,
       rc.cancelado,
       pi.id_libro,
       pi.id_empresa,
       pi.id        AS nro_pedido,
       rl.retirado  AS libro_retirado,
       rl.listo     AS libro_listo,
       rl.pendiente AS libro_pendiente,
       rl.cancelado AS libro_cancelado
FROM pedido p
         JOIN pedido_item pi ON pi.id_pedido = p.id
         JOIN resumen_libro rl ON rl.id_libro = pi.id_libro AND rl.id_empresa = pi.id_empresa
         JOIN resumen_cliente rc ON rc.id_cliente = p.id_cliente;

grant select on vw_cambio_estado_pedido to app_role;

create or replace view vw_cambio_estado
            (estado, fecha_actualizacion, id, nro_pedido, id_libro, id_empresa, pendiente, listo, cancelado, retirado,
             id_cliente, libro_pendiente, libro_retirado, libro_cancelado, libro_listo, estado_pedido, stock_libro)
as
SELECT pi.estado,
       pi.fecha_actualizacion,
       pi.id_pedido AS id,
       pi.id        AS nro_pedido,
       pi.id_libro,
       pi.id_empresa,
       rc.pendiente,
       rc.listo,
       rc.cancelado,
       rc.retirado,
       rc.id_cliente,
       rl.pendiente AS libro_pendiente,
       rl.retirado  AS libro_retirado,
       rl.cancelado AS libro_cancelado,
       rl.listo     AS libro_listo,
       p.estado     AS estado_pedido,
       s.stock      AS stock_libro
FROM pedido_item pi
         JOIN pedido p ON p.id = pi.id_pedido
         JOIN resumen_cliente rc ON rc.id_cliente = p.id_cliente
         JOIN stock s ON s.id_libro = pi.id_libro AND s.id_empresa = pi.id_empresa
         JOIN resumen_libro rl ON rl.id_libro = pi.id_libro AND rl.id_empresa = pi.id_empresa;

grant select on vw_cambio_estado to app_role;

drop view if exists vw_empresa_completa;

create or replace view vw_empresa_completa  as
    select
        e.id, e.fecha_creacion, e.fecha_actualizacion, e.deleted, e.nombre, e.email, e.telefono,
        c.fecha_entrega, c.id_dato_cobro, c.id_msj_pedido_tomado, c.id_msj_pedido_retirado, c.id_sede, c.msj_retiro, c.msj_envio, c.hora_entrega,
        dc.nombre as dato_cobro_nombre, dc.mensaje as dato_cobro_mensaje,
        mr.nombre as retirado_nombre, mr.mensaje as retirado_mensaje,
        mt.nombre as tomado_nombre, mt.mensaje as tomado_mensaje,
        s.nombre as sede, c.fecha_actualizacion as config_fecha_actualizacion
    from empresa e
    left join configuraciones c on c.id_empresa = e.id
    left join dato_cobro dc on dc.id = c.id_dato_cobro
    left join mensaje mr on mr.id = c.id_msj_pedido_retirado
    left join mensaje mt on mt.id = c.id_msj_pedido_tomado
    left join sede s on s.id = c.id_sede;
