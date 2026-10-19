import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPT_DIR, '..', '..');
const SOURCE = path.join(ROOT, 'db_postrgres.sql');

const START_RE = /^create (type|table|or replace view|or replace function|trigger)\b/;

const MAPPING = [
  {
    file: '01_tipos.sql',
    patterns: [/^create type tp_pedido_item\b/],
  },
  {
    file: '10_funciones_core.sql',
    patterns: [
      /^create or replace function fc_usuario_actual\b/,
      /^create or replace function fc_empresa_actual\b/,
      /^create or replace function fc_es_admin\b/,
      /^create or replace function fc_es_super_admin\b/,
      /^create or replace function fc_es_empresa_actual\b/,
      /^create or replace function fc_cargar_contexto_usuario\b/,
    ],
  },
  {
    file: '20_tablas/01_core.sql',
    patterns: [
      /^create table if not exists empresa\b/,
      /^create table if not exists usuario\b/,
      /^create table if not exists auditoria\b/,
    ],
  },
  {
    file: '20_tablas/02_catalogo.sql',
    patterns: [
      /^create table if not exists materia\b/,
      /^create table if not exists libro\b/,
      /^create table if not exists componente\b/,
      /^create table if not exists libro_componente\b/,
      /^create table if not exists libro_empresa\b/,
      /^create table if not exists precio_empresa\b/,
      /^create table if not exists editorial\b/,
      /^create table if not exists nivel\b/,
      /^create table if not exists libro_completo\b/,
      /^create table if not exists precio\b/,
    ],
  },
  {
    file: '20_tablas/03_clientes.sql',
    patterns: [
      /^create table if not exists cliente\b/,
      /^create table if not exists sede\b/,
      /^create table if not exists resumen_cliente\b/,
      /^create table if not exists resumen_libro\b/,
    ],
  },
  {
    file: '20_tablas/04_stock_especificacion.sql',
    patterns: [
      /^create table if not exists stock\b/,
      /^create table if not exists especificacion\b/,
    ],
  },
  {
    file: '20_tablas/05_pedidos.sql',
    patterns: [
      /^create table if not exists pedido\b/,
      /^create table if not exists pedido_item\b/,
      /^create table if not exists pedido_item_especificacion\b/,
    ],
  },
  {
    file: '20_tablas/06_solicitudes.sql',
    patterns: [
      /^create table if not exists propuesta\b/,
      /^create table if not exists propuesta_libro_empresa\b/,
      /^create table if not exists solicitud\b/,
      /^create table if not exists peticion\b/,
    ],
  },
  {
    file: '20_tablas/07_mensajes.sql',
    patterns: [
      /^create table if not exists mensaje\b/,
      /^create table if not exists dato_cobro\b/,
      /^create table if not exists configuraciones\b/,
    ],
  },
  {
    file: '30_vistas/01_base.sql',
    patterns: [
      /^create or replace view vw_cliente\b/,
      /^create or replace view vw_pedidos\b/,
      /^create or replace view vw_componentes\b/,
      /^create or replace view vw_libro_busqueda\b/,
      /^create or replace view vw_libro_componentes\b/,
      /^create or replace view vw_libro_completo\b/,
      /^create or replace view vw_propuesta\b/,
      /^create or replace view vw_especificaciones\b/,
    ],
  },
  {
    file: '30_vistas/02_pedidos_cambios.sql',
    patterns: [
      /^create or replace view vw_pedidos_item\b/,
      /^create or replace view vw_pedido_libro\b/,
      /^create or replace view vw_libro_nombre\b/,
      /^create or replace view vw_cambio_sede\b/,
      /^create or replace view vw_cambio_estado_pedido\b/,
      /^create or replace view vw_cambio_estado\b/,
      /^create or replace view vw_empresa_completa\b/,
    ],
  },
  {
    file: '40_funciones/01_infra_auditoria.sql',
    patterns: [
      /^create or replace function fc_actualizar_fecha_actualizacion\b/,
      /^create or replace function fc_prohibir_modificacion\b/,
      /^create or replace function fc_login\b/,
      /^create or replace function fc_extraer_clave\b/,
      /^create or replace function fc_extraer_cambios\b/,
      /^create or replace function fc_auditoria\b/,
      /^create or replace function fc_crear_configuraciones\b/,
    ],
  },
  {
    file: '40_funciones/02_catalogo.sql',
    patterns: [
      /^create or replace function fc_libro_empresa_delete\b/,
      /^create or replace function fc_crear_componente_libro\b/,
      /^create or replace function fc_crear_libro\b/,
      /^create or replace function fc_obtener_o_crear_nivel\b/,
      /^create or replace function fc_obtener_o_crear_editorial\b/,
      /^create or replace function fc_obtener_o_crear_materia\b/,
      /^create or replace function fc_obtener_o_crear_libro\b/,
      /^create or replace function fc_obtener_or_crear_libro_completo\b/,
      /^create or replace function fc_busqueda_libro_completo\b/,
      /^create or replace function fc_busqueda_libro\b/,
      /^create or replace function _fc_verificar_actualizacion_libro_completo\b/,
      /^create or replace function fc_procesar_actualizacion_libro_completo\b/,
      /^create or replace function _fc_verificar_actualizacion_libro\b/,
      /^create or replace function fc_procesar_actualizacion_libro\b/,
    ],
  },
  {
    file: '40_funciones/03_clientes.sql',
    patterns: [
      /^create or replace function fc_busqueda_cliente\b/,
      /^create or replace function fc_cliente_delete\b/,
      /^create or replace function fc_crear_cliente\b/,
    ],
  },
  {
    file: '40_funciones/04_resumen.sql',
    patterns: [
      /^create or replace function fc_sumar_resumen_libro\b/,
      /^create or replace function fc_restar_resumen_libro\b/,
      /^create or replace function fc_actualizar_resumen\b/,
      /^create or replace function fc_sumar_resumen_cliente\b/,
      /^create or replace function fc_restar_resumen_cliente\b/,
      /^create or replace function fc_actualizar_resumen_cliente\b/,
      /^create or replace function fc_crear_resumen_cliente\b/,
      /^create or replace function fc_crear_resumen_libro\b/,
      /^create or replace function fc_crear_stock\b/,
      /^create or replace function fc_recalcular_resumen_cliente\b/,
      /^create or replace function fc_recalcular_resumen_libro\b/,
    ],
  },
  {
    file: '40_funciones/05_pedidos.sql',
    patterns: [
      /^create or replace function fc_actualizar_estado_pedido\b/,
      /^create or replace function fc_crear_pedido_item\b/,
      /^create or replace function fc_obtener_pedido_json\b/,
      /^create or replace function fc_crear_pedido\b/,
      /^create or replace function fc_buscar_pedido\b/,
      /^create or replace function fc_cambiar_estado_pedido\b/,
    ],
  },
  {
    file: '40_funciones/06_solicitudes.sql',
    patterns: [
      /^create or replace function fc_obtener_propuestas\b/,
      /^create or replace function fc_verificar_peticiones_libro_relacionados\b/,
      /^create or replace function _fc_solicitud_registrar_peticion\b/,
    ],
  },
  {
    file: '40_funciones/09_extension_uuid.sql',
    patterns: [
      /^create or replace function uuid_nil\b/,
      /^create or replace function uuid_ns_dns\b/,
      /^create or replace function uuid_ns_url\b/,
      /^create or replace function uuid_ns_oid\b/,
      /^create or replace function uuid_ns_x500\b/,
      /^create or replace function uuid_generate_v1\b/,
      /^create or replace function uuid_generate_v1mc\b/,
      /^create or replace function uuid_generate_v3\b/,
      /^create or replace function uuid_generate_v4\b/,
      /^create or replace function uuid_generate_v5\b/,
    ],
  },
  {
    file: '50_triggers/01_fechas.sql',
    patterns: [
      /^create trigger tr_empresa_fecha_actualizacion\b/,
      /^create trigger tr_usuario_fecha_actualizacion\b/,
      /^create trigger tr_materia_fecha_actualizacion\b/,
      /^create trigger tr_libro_fecha_actualizacion\b/,
      /^create trigger tr_componente_fecha_actualizacion\b/,
      /^create trigger tr_precio_fecha_actualizacion\b/,
      /^create trigger tr_propuesta_fecha_actualizacion\b/,
      /^create trigger tr_cliente_fecha_actualizacion\b/,
      /^create trigger tr_sede_fecha_actualizacion\b/,
      /^create trigger tr_stock_fecha_actualizacion\b/,
      /^create trigger tr_pedido_fecha_actualizacion\b/,
      /^create trigger tr_pedido_item_fecha_actualizacion\b/,
      /^create trigger tr_nivel_fecha_actualizacion\b/,
      /^create trigger tr_config_fecha_actualizacion\b/,
    ],
  },
  {
    file: '50_triggers/02_auditoria.sql',
    patterns: [
      /^create trigger tr_empresa_auditoria\b/,
      /^create trigger tr_auditoria_materia\b/,
      /^create trigger tr_auditoria_libro\b/,
      /^create trigger tr_auditoria_componente\b/,
      /^create trigger tr_auditoria_libro_componente\b/,
      /^create trigger tr_auditoria_libro_empresa\b/,
      /^create trigger tr_auditoria_lprecio\b/,
      /^create trigger tr_auditoria_propuesta\b/,
      /^create trigger tr_auditoria_cliente\b/,
      /^create trigger tr_auditoria_sede\b/,
      /^create trigger tr_auditoria_stock\b/,
      /^create trigger tr_auditoria_pedido\b/,
      /^create trigger tr_auditoria_pedido_item\b/,
      /^create trigger tr_auditoria_pedido_item_especificacion\b/,
      /^create trigger tr_nivel_auditoria\b/,
      /^create trigger tr_libro_completo_auditoria\b/,
      /^create trigger tr_config_auditoria\b/,
    ],
  },
  {
    file: '50_triggers/03_resumen.sql',
    patterns: [
      /^create trigger tr_actualizar_resumen_libro\b/,
      /^create trigger tr_crear_resumen_libro\b/,
      /^create trigger tr_actualiza_resumen_cliente_update_estado\b/,
      /^create trigger tr_actualizar_resumen_cliente_insert_delete\b/,
      /^create trigger tr_crear_resumen_cliente\b/,
      /^create trigger tr_crear_stock\b/,
    ],
  },
  {
    file: '50_triggers/04_dominio.sql',
    patterns: [
      /^create trigger tr_actualizar_estado_pedido\b/,
      /^create trigger tr_cliente_delete\b/,
      /^create trigger tr_libro_empresa_delete\b/,
      /^create trigger tr_empresa_config_insert\b/,
    ],
  },
];

const HEADER = (rel) =>
  `-- ${rel}\n` +
  '-- parte del schema modular; generado desde db_postrgres.sql\n' +
  '-- no editar el orden\n';

const results = [];
function check(name, pass, detail) {
  results.push({ name, pass, detail });
  console.log(`${pass ? '[PASS]' : '[FAIL]'} ${name}${detail ? ` :: ${detail}` : ''}`);
}

function blockType(firstLine) {
  if (/^create type\b/.test(firstLine)) return 'type';
  if (/^create table\b/.test(firstLine)) return 'table';
  if (/^create or replace view\b/.test(firstLine)) return 'view';
  if (/^create or replace function\b/.test(firstLine)) return 'function';
  if (/^create trigger\b/.test(firstLine)) return 'trigger';
  throw new Error(`Unknown block type: ${firstLine}`);
}

// --- Read and split source -------------------------------------------------
const raw = fs.readFileSync(SOURCE, 'utf8');
const lines = raw.split(/\r?\n/);
if (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();

check('source line count is 3859', lines.length === 3859, `found ${lines.length}`);

const starts = [];
for (let i = 0; i < lines.length; i++) {
  if (START_RE.test(lines[i])) starts.push(i);
}

const blocks = starts.map((start, idx) => {
  const end = idx + 1 < starts.length ? starts[idx + 1] : lines.length;
  const slice = lines.slice(start, end);
  while (slice.length > 0 && slice[slice.length - 1].trim() === '') slice.pop();
  const text = slice.join('\n');
  return {
    startLine: start + 1,
    text,
    firstLine: slice[0],
    type: blockType(slice[0]),
  };
});

const counts = {
  type: blocks.filter((b) => b.type === 'type').length,
  table: blocks.filter((b) => b.type === 'table').length,
  view: blocks.filter((b) => b.type === 'view').length,
  function: blocks.filter((b) => b.type === 'function').length,
  trigger: blocks.filter((b) => b.type === 'trigger').length,
  total: blocks.length,
};

console.log('--- block counts ---');
console.log(JSON.stringify(counts));

check('no empty blocks', blocks.every((b) => b.text.length > 0));
check(
  'total block count matches plan (148)',
  counts.total === 148,
  `found ${counts.total}`,
);
check(
  'type count matches plan (1)',
  counts.type === 1,
  `found ${counts.type}`,
);
check(
  'table count matches plan (29)',
  counts.table === 29,
  `found ${counts.table}`,
);
check(
  'view count matches plan (15)',
  counts.view === 15,
  `found ${counts.view}`,
);
check(
  'function count matches plan (62)',
  counts.function === 62,
  `found ${counts.function}`,
);
check(
  'trigger count matches plan (41)',
  counts.trigger === 41,
  `found ${counts.trigger}`,
);

// --- Assign every block to exactly one destination --------------------------
const patternUse = new Map();
for (const entry of MAPPING) {
  for (const re of entry.patterns) patternUse.set(re, 0);
}

const assigned = [];
const unassigned = [];
const ambiguous = [];

for (const block of blocks) {
  const matches = [];
  for (const entry of MAPPING) {
    for (const re of entry.patterns) {
      if (re.test(block.firstLine)) {
        matches.push({ file: entry.file, re });
      }
    }
  }
  // A block must match exactly one predicate. Multiple matches are ambiguous.
  if (matches.length === 0) {
    unassigned.push(block);
  } else if (matches.length > 1) {
    ambiguous.push({ block, matches });
  } else {
    const m = matches[0];
    patternUse.set(m.re, patternUse.get(m.re) + 1);
    assigned.push({ ...block, file: m.file });
  }
}

check(
  'every source block matched exactly one predicate',
  unassigned.length === 0 && ambiguous.length === 0,
  `unassigned=${unassigned.length}, ambiguous=${ambiguous.length}`,
);
if (unassigned.length > 0) {
  for (const b of unassigned) {
    console.log(`  UNASSIGNED line ${b.startLine}: ${b.firstLine}`);
  }
}
if (ambiguous.length > 0) {
  for (const a of ambiguous) {
    console.log(
      `  AMBIGUOUS line ${a.block.startLine}: ${a.block.firstLine} -> ` +
        a.matches.map((m) => m.file).join(', '),
    );
  }
}

const unusedPatterns = [...patternUse.entries()]
  .filter(([, n]) => n === 0)
  .map(([re]) => re.source);
check(
  'every mapping predicate matched at least one block',
  unusedPatterns.length === 0,
  unusedPatterns.length === 0 ? '' : unusedPatterns.join(' | '),
);

check(
  'every block assigned exactly once',
  assigned.length === blocks.length,
  `assigned=${assigned.length}, source=${blocks.length}`,
);

// --- Generate destination files --------------------------------------------
const byFile = new Map();
for (const block of assigned) {
  if (!byFile.has(block.file)) byFile.set(block.file, []);
  byFile.get(block.file).push(block);
}

const writtenFiles = [];
for (const entry of MAPPING) {
  const fileBlocks = byFile.get(entry.file);
  if (!fileBlocks || fileBlocks.length === 0) continue;
  const rel = entry.file.split(path.sep).join('/');
  const content = HEADER(rel) + fileBlocks.map((b) => b.text).join('\n\n') + '\n';
  const outPath = path.join(ROOT, ...entry.file.split('/'));
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, content, 'utf8');
  writtenFiles.push({ file: rel, blocks: fileBlocks.length, lines: content.split('\n').length - 1 });
}

// --- 00_apply.sql -----------------------------------------------------------
const applyOrder = [
  '01_tipos.sql',
  '10_funciones_core.sql',
  ...writtenFiles
    .map((f) => f.file)
    .filter((f) => f.startsWith('20_tablas/'))
    .sort(),
  ...writtenFiles
    .map((f) => f.file)
    .filter((f) => f.startsWith('30_vistas/'))
    .sort(),
  ...writtenFiles
    .map((f) => f.file)
    .filter((f) => f.startsWith('40_funciones/'))
    .sort(),
  ...writtenFiles
    .map((f) => f.file)
    .filter((f) => f.startsWith('50_triggers/'))
    .sort(),
];

let applyContent = '';
for (const file of applyOrder) {
  applyContent += `-- ${file}\n\\i ${file}\n`;
}
const applyPath = path.join(ROOT, '00_apply.sql');
fs.writeFileSync(applyPath, applyContent, 'utf8');
writtenFiles.push({
  file: '00_apply.sql',
  blocks: 0,
  lines: applyContent.split('\n').length - 1,
});

// --- Content verification: reread outputs and compare multiset -------------
function extractWrittenBlocks(content, header, fileBlocks) {
  if (!content.startsWith(header)) {
    throw new Error('output header mismatch');
  }
  let rest = content.slice(header.length);
  const out = [];
  for (let i = 0; i < fileBlocks.length; i++) {
    const text = fileBlocks[i].text;
    if (!rest.startsWith(text)) {
      throw new Error(`block ${i + 1} does not match byte-for-byte`);
    }
    rest = rest.slice(text.length);
    out.push(text);
    if (i < fileBlocks.length - 1) {
      if (!rest.startsWith('\n\n')) {
        throw new Error(`missing blank line after block ${i + 1}`);
      }
      rest = rest.slice(2);
    } else if (rest !== '\n') {
      throw new Error('missing trailing newline');
    }
  }
  return out;
}

const reread = [];
let verifyError = null;
try {
  for (const entry of MAPPING) {
    const fileBlocks = byFile.get(entry.file);
    if (!fileBlocks || fileBlocks.length === 0) continue;
    const rel = entry.file.split(path.sep).join('/');
    const outPath = path.join(ROOT, ...entry.file.split('/'));
    const content = fs.readFileSync(outPath, 'utf8');
    reread.push(...extractWrittenBlocks(content, HEADER(rel), fileBlocks));
  }
} catch (err) {
  verifyError = err;
}

function multiset(items) {
  const m = new Map();
  for (const item of items) m.set(item, (m.get(item) ?? 0) + 1);
  return m;
}

function sameMultiset(a, b) {
  if (a.size !== b.size) return false;
  for (const [key, n] of a) {
    if (b.get(key) !== n) return false;
  }
  return true;
}

const sourceMultiset = multiset(blocks.map((b) => b.text));
const outputMultiset = multiset(reread);

check(
  'destination block content matches source byte-for-byte (multiset)',
  verifyError === null && sameMultiset(sourceMultiset, outputMultiset),
  verifyError ? verifyError.message : `blocks=${reread.length}`,
);

check(
  'no block lost or duplicated across destination files',
  reread.length === blocks.length,
  `reread=${reread.length}, source=${blocks.length}`,
);

console.log('--- files written ---');
console.log(JSON.stringify(writtenFiles, null, 2));

const failed = results.filter((r) => !r.pass);
console.log('--- summary ---');
console.log(`${results.length - failed.length}/${results.length} checks passed`);
if (failed.length > 0) {
  console.log(`FAILED: ${failed.map((r) => r.name).join(' | ')}`);
  process.exitCode = 1;
}
