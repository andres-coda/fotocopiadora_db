-- 30_vistas/01_base.sql
-- parte del schema modular; generado desde db_postrgres.sql
-- no editar el orden
create or replace view vw_cliente
            (id, nombre, email, telefono, fecha_creacion, fecha_actualizacion, deleted, pendiente, retirado, listo,
             cancelado) as
SELECT c.id,
       c.nombre,
       c.email,
       c.telefono,
       c.fecha_creacion,
       c.fecha_actualizacion,
       c.deleted,
       rc.pendiente,
       rc.retirado,
       rc.listo,
       rc.cancelado
FROM cliente c
         LEFT JOIN resumen_cliente rc ON rc.id_cliente = c.id;

grant delete, insert, select, update on vw_cliente to app_role;

create or replace view vw_pedidos
            (id, fecha_creacion, fecha_actualizacion, fecha_entrega, importe_total, sena, deleted, archivos, anillados,
             estado, telefono, email, nombre, id_cliente, delete_cliente)
as
SELECT p.id,
       p.fecha_creacion,
       p.fecha_actualizacion,
       p.fecha_entrega,
       p.importe_total,
       p.sena,
       p.deleted,
       p.archivos,
       p.anillados,
       p.estado,
       c.telefono,
       c.email,
       c.nombre,
       c.id      AS id_cliente,
       c.deleted AS delete_cliente
FROM pedido p
         LEFT JOIN cliente c ON c.id = p.id_cliente;

grant delete, insert, select, update on vw_pedidos to app_role;

create or replace view vw_componentes(id_libro, componentes) as
SELECT lc.id_libro,
       string_agg(DISTINCT c.nombre::text, ', '::text ORDER BY (c.nombre::text)) AS componentes
FROM libro_componente lc
         JOIN componente c ON c.id = lc.id_componente
GROUP BY lc.id_libro;

grant select on vw_componentes to app_role;

create or replace view vw_libro_busqueda
            (id, nombre, descripcion, edicion, autor, anio, img, nivel, componentes, cantidad_pg, cantidad_adhesivo,
             especificaciones_defecto, materia, editorial, pendiente, listo, retirado, cancelado, id_empresa,
             id_materia, detalle_impresion, deleted, stock, id_libro)
as
SELECT lc.id,
       l.nombre,
       lc.descripcion,
       lc.edicion,
       lc.autor,
       lc.anio,
       lc.img,
       n.nombre AS nivel,
       vw_c.componentes,
       le.cantidad_pg,
       le.cantidad_adhesivo,
       le.especificaciones_defecto,
       m.nombre AS materia,
       e.nombre AS editorial,
       rl.pendiente,
       rl.listo,
       rl.retirado,
       rl.cancelado,
       le.id_empresa,
       m.id     AS id_materia,
       le.detalle_impresion,
       le.deleted,
       s.stock,
       l.id     AS id_libro
FROM libro_empresa le
         JOIN libro_completo lc ON lc.id = le.id_libro
         LEFT JOIN nivel n ON lc.id_nivel = n.id
         JOIN libro l ON l.id = lc.id_libro
         LEFT JOIN materia m ON m.id = l.id_materia
         LEFT JOIN editorial e ON e.id = l.id_editorial
         LEFT JOIN vw_componentes vw_c ON vw_c.id_libro = lc.id
         LEFT JOIN resumen_libro rl ON rl.id_libro = le.id_libro
         LEFT JOIN stock s ON s.id_libro = le.id_libro;

grant select on vw_libro_busqueda to app_role;

create or replace view vw_libro_componentes(id_libro, componentes) as
SELECT lc.id_libro,
       string_agg(DISTINCT c.nombre::text, ', '::text) AS componentes
FROM libro_componente lc
         JOIN componente c ON c.id = lc.id_componente
GROUP BY lc.id_libro;

create or replace view vw_libro_completo
            (id, nombre, descripcion, edicion, autor, anio, img, nivel, componentes, materia, editorial) as
SELECT lc.id,
       l.nombre,
       lc.descripcion,
       lc.edicion,
       lc.autor,
       lc.anio,
       lc.img,
       n.nombre AS nivel,
       vw_c.componentes,
       m.nombre AS materia,
       e.nombre AS editorial
FROM libro_completo lc
         LEFT JOIN nivel n ON lc.id_nivel = n.id
         JOIN libro l ON l.id = lc.id_libro
         LEFT JOIN materia m ON m.id = l.id_materia
         LEFT JOIN editorial e ON e.id = l.id_editorial
         LEFT JOIN vw_componentes vw_c ON vw_c.id_libro = lc.id;

grant select on vw_libro_completo to app_role;

create or replace view vw_propuesta
            (id_libro, id_propuesta, nombre_propuesta, fecha_creacion, fecha_actualizacion, deleted_propuesta, nombre,
             descripcion, edicion, autor, anio, img, nivel, componentes, cantidad_pg, cantidad_adhesivo,
             especificaciones_defecto, materia, editorial, detalle_impresion, deleted, id_materia)
as
SELECT ple.id_libro,
       ple.id_propuesta,
       p.nombre  AS nombre_propuesta,
       p.fecha_creacion,
       p.fecha_actualizacion,
       p.deleted AS deleted_propuesta,
       vwlb.nombre,
       vwlb.descripcion,
       vwlb.edicion,
       vwlb.autor,
       vwlb.anio,
       vwlb.img,
       vwlb.nivel,
       vwlb.componentes,
       vwlb.cantidad_pg,
       vwlb.cantidad_adhesivo,
       vwlb.especificaciones_defecto,
       vwlb.materia,
       vwlb.editorial,
       vwlb.detalle_impresion,
       vwlb.deleted,
       vwlb.id_materia
FROM propuesta_libro_empresa ple
         LEFT JOIN vw_libro_busqueda vwlb ON vwlb.id = ple.id_libro
         LEFT JOIN propuesta p ON p.id = ple.id_propuesta;

grant select on vw_propuesta to app_role;

create or replace view vw_especificaciones(nro_item, id_pedido, especificaciones) as
SELECT pi.nro_item,
       pi.id_pedido,
       array_agg(DISTINCT e.nombre ORDER BY e.nombre) AS especificaciones
FROM pedido_item_especificacion pi
         JOIN especificacion e ON e.id = pi.id_especificacion
GROUP BY pi.nro_item, pi.id_pedido;

grant select on vw_especificaciones to app_role;
