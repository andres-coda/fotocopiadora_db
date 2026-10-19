# Feature: Modularizar el schema de la base de datos

**Estado**: split generado y verificado en contenido — cadena de carga NO verificada con Postgres real
**Repo**: `DB` (sibling de `foto-app` y `foto-api`)
**Fuente**: `DB/db_postrgres.sql` (3859 líneas, artefacto de sync con la base real)

## Objetivo

Partir `db_postrgres.sql` en archivos por **capa + dominio**, con un `00_apply.sql`
que los carga en orden, para poder tocar un dominio sin scrollear 3800 líneas.

## Problema / hallazgos (verificados)

1. El archivo **no se puede cargar de cero**: `fc_es_super_admin()` se define en
   L2362 pero se usa en una policy de L45. Postgres valida la expresión de la policy
   al crearla -> error en base vacía. Igual `fc_es_admin` (L2332/usa L50) y
   `fc_es_empresa_actual` (L2454/usa L364).
2. **Nunca se ejecuta `alter table ... enable row level security`** -> en base nueva
   las ~79 policies quedan inertes.
3. `funciones_nuevas.sql` (61 líneas) es un **duplicado viejo** de
   `fc_obtener_pedido_json`: le falta `'id_materia', vpi.id_materia` que SÍ está en
   la copia de `db_postrgres.sql`. -> borrar.
4. El orden de tablas usa **FKs diferidas a propósito** (`libro -> editorial` se
   agrega en el bloque de `editorial`; `precio_empresa -> precio` en el de `precio`;
   `libro_componente`/`libro_empresa -> libro_completo` en el de `libro_completo`).
   Ese orden hay que respetarlo.

## Scope

- Sólo se MUEVE SQL existente. No se reescribe lógica de negocio.
- Único reordenamiento: las **funciones core RLS/contexto** pasan ANTES de las
  tablas, para que el set sí cargue de cero.
- Dentro de cada archivo se preserva el **orden relativo original** de los bloques.

## Fuera de scope (reportar, no arreglar acá)

- Agregar los `enable row level security` faltantes.
- Crear el rol `app_role` / extensiones.
- Unificar el copy de `fc_obtener_pedido_json`.

## Estructura destino

```
00_apply.sql
01_tipos.sql
10_funciones_core.sql            <- movidas antes de las tablas
20_tablas/01_core.sql
20_tablas/02_catalogo.sql
20_tablas/03_clientes.sql
20_tablas/04_stock_especificacion.sql
20_tablas/05_pedidos.sql
20_tablas/06_solicitudes.sql
20_tablas/07_mensajes.sql
30_vistas/01_base.sql
30_vistas/02_pedidos_cambios.sql
40_funciones/01_infra_auditoria.sql
40_funciones/02_catalogo.sql
40_funciones/03_clientes.sql
40_funciones/04_resumen.sql
40_funciones/05_pedidos.sql
40_funciones/06_solicitudes.sql
40_funciones/09_extension_uuid.sql
50_triggers/01_fechas.sql
50_triggers/02_auditoria.sql
50_triggers/03_resumen.sql
50_triggers/04_dominio.sql
```

## Regla de extraccion

Un "bloque" empieza en una linea que matchea:
`^create (type|table|or replace view|or replace function|trigger)\b`
y termina donde empieza el siguiente bloque (sin las lineas en blanco finales).
Los `create index`, `create policy`, `alter table` y `grant` **pertenecen al bloque
anterior** (su tabla / su funcion).

## Mapeo bloque -> archivo

### 01_tipos.sql
`create type tp_pedido_item`

### 10_funciones_core.sql  (orden: como estan)
`fc_usuario_actual`, `fc_empresa_actual`, `fc_es_admin`, `fc_es_super_admin`,
`fc_es_empresa_actual`, `fc_cargar_contexto_usuario`

### 20_tablas/01_core.sql
`empresa`, `usuario`, `auditoria`

### 20_tablas/02_catalogo.sql   (orden relativo original)
`materia`, `libro`, `componente`, `libro_componente`, `libro_empresa`,
`precio_empresa`, `editorial`, `nivel`, `libro_completo`, `precio`

### 20_tablas/03_clientes.sql
`cliente`, `sede`, `resumen_cliente`, `resumen_libro`

### 20_tablas/04_stock_especificacion.sql
`stock`, `especificacion`

### 20_tablas/05_pedidos.sql
`pedido`, `pedido_item`, `pedido_item_especificacion`

### 20_tablas/06_solicitudes.sql   (orden relativo original)
`propuesta`, `propuesta_libro_empresa`, `solicitud`, `peticion`

### 20_tablas/07_mensajes.sql
`mensaje`, `dato_cobro`, `configuraciones`

### 30_vistas/01_base.sql
`vw_cliente`, `vw_pedidos`, `vw_componentes`, `vw_libro_busqueda`,
`vw_libro_componentes`, `vw_libro_completo`, `vw_propuesta`, `vw_especificaciones`

### 30_vistas/02_pedidos_cambios.sql
`vw_pedidos_item`, `vw_pedido_libro`, `vw_libro_nombre`, `vw_cambio_sede`,
`vw_cambio_estado_pedido`, `vw_cambio_estado`, `vw_empresa_completa`

### 40_funciones/01_infra_auditoria.sql
`fc_actualizar_fecha_actualizacion`, `fc_prohibir_modificacion`, `fc_login`,
`fc_extraer_clave`, `fc_extraer_cambios`, `fc_auditoria`,
`fc_crear_configuraciones`

### 40_funciones/02_catalogo.sql
`fc_libro_empresa_delete`, `fc_crear_componente_libro`, `fc_crear_libro`,
`fc_obtener_o_crear_nivel`, `fc_obtener_o_crear_editorial`,
`fc_obtener_o_crear_materia`, `fc_obtener_o_crear_libro`,
`fc_obtener_or_crear_libro_completo`, `fc_busqueda_libro_completo`,
`fc_busqueda_libro`, `_fc_verificar_actualizacion_libro_completo`,
`fc_procesar_actualizacion_libro_completo`, `_fc_verificar_actualizacion_libro`,
`fc_procesar_actualizacion_libro`

### 40_funciones/03_clientes.sql
`fc_busqueda_cliente` (AMBAS sobrecargas: la de `returns SETOF vw_cliente` y la de
`returns TABLE`), `fc_cliente_delete`, `fc_crear_cliente`

### 40_funciones/04_resumen.sql
`fc_sumar_resumen_libro`, `fc_restar_resumen_libro`, `fc_actualizar_resumen`,
`fc_sumar_resumen_cliente`, `fc_restar_resumen_cliente`,
`fc_actualizar_resumen_cliente`, `fc_crear_resumen_cliente`,
`fc_crear_resumen_libro`, `fc_crear_stock`, `fc_recalcular_resumen_cliente`,
`fc_recalcular_resumen_libro`

### 40_funciones/05_pedidos.sql
`fc_actualizar_estado_pedido`, `fc_crear_pedido_item`, `fc_obtener_pedido_json`,
`fc_crear_pedido`, `fc_buscar_pedido`, `fc_cambiar_estado_pedido`

### 40_funciones/06_solicitudes.sql
`fc_obtener_propuestas`, `fc_verificar_peticiones_libro_relacionados`,
`_fc_solicitud_registrar_peticion`

### 40_funciones/09_extension_uuid.sql
`uuid_nil`, `uuid_ns_dns`, `uuid_ns_url`, `uuid_ns_oid`, `uuid_ns_x500`,
`uuid_generate_v1`, `uuid_generate_v1mc`, `uuid_generate_v3`,
`uuid_generate_v4`, `uuid_generate_v5`

### 50_triggers/01_fechas.sql
`tr_empresa_fecha_actualizacion`, `tr_usuario_fecha_actualizacion`,
`tr_materia_fecha_actualizacion`, `tr_libro_fecha_actualizacion`,
`tr_componente_fecha_actualizacion`, `tr_precio_fecha_actualizacion`,
`tr_propuesta_fecha_actualizacion`, `tr_cliente_fecha_actualizacion`,
`tr_sede_fecha_actualizacion`, `tr_stock_fecha_actualizacion`,
`tr_pedido_fecha_actualizacion`, `tr_pedido_item_fecha_actualizacion`,
`tr_nivel_fecha_actualizacion`, `tr_config_fecha_actualizacion`

### 50_triggers/02_auditoria.sql
`tr_empresa_auditoria`, `tr_auditoria_materia`, `tr_auditoria_libro`,
`tr_auditoria_componente`, `tr_auditoria_libro_componente`,
`tr_auditoria_libro_empresa`, `tr_auditoria_lprecio`, `tr_auditoria_propuesta`,
`tr_auditoria_cliente`, `tr_auditoria_sede`, `tr_auditoria_stock`,
`tr_auditoria_pedido`, `tr_auditoria_pedido_item`,
`tr_auditoria_pedido_item_especificacion`, `tr_nivel_auditoria`,
`tr_libro_completo_auditoria`, `tr_config_auditoria`

### 50_triggers/03_resumen.sql
`tr_actualizar_resumen_libro`, `tr_crear_resumen_libro`,
`tr_actualiza_resumen_cliente_update_estado`,
`tr_actualizar_resumen_cliente_insert_delete`, `tr_crear_resumen_cliente`,
`tr_crear_stock`

### 50_triggers/04_dominio.sql
`tr_actualizar_estado_pedido`, `tr_cliente_delete`, `tr_libro_empresa_delete`,
`tr_empresa_config_insert`

## Verificacion

1. **Cobertura**: la multiset de bloques del set nuevo == la del archivo original
   (148 bloques: 1 tipo + 29 tablas + 15 vistas + 62 funciones + 41 triggers), y el
   texto de cada bloque debe ser **idéntico** al original (byte a byte).
2. **Carga real**: `docker run postgres:16` descartable, crear rol `app_role`,
   aplicar `00_apply.sql` -> debe terminar sin errores.
3. **Diff**: `pg_dump --schema-only` del resultado.

## Rollback

`git checkout -- db_postrgres.sql` y borrar los archivos nuevos. El original queda
intacto hasta confirmar.
