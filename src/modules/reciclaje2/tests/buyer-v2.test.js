import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (relativePath) => readFileSync(new URL(`../../../${relativePath}`, import.meta.url), 'utf8');
const nuevaCompra = read('src/modules/NuevaCompra.tsx');
const comprasCargadas = read('src/modules/MisCompras.tsx');
const proveedores = read('src/modules/SociosBuyer.tsx');
const buyerApp = read('src/modules/BuyerApp.tsx');
const api = read('src/lib/api.ts');
const flujoActivo = [nuevaCompra, comprasCargadas, proveedores, buyerApp].join('\n');

test('Buyer activo no consume compras rapidas ni ordenes de compra V1', () => {
  assert.doesNotMatch(flujoActivo, /compras-rapidas|ordenes-compra|compraRapida|ordenesCompraApi|legacyApiFetch/);
});

test('Nueva Compra registra una COMPRA V2 antes de actualizar preferenciales', () => {
  assert.match(nuevaCompra, /operacionesApi\.save\(\{\s*tipo: 'COMPRA'/);
  assert.match(nuevaCompra, /materiales: lineas\.map/);
  assert.ok(nuevaCompra.indexOf('await operacionesApi.save') < nuevaCompra.indexOf('Promise.allSettled'));
});

test('Nueva Compra soporta varias lineas y una unica moneda comercial', () => {
  assert.match(nuevaCompra, /setLineas\(\(prev\) => \[\.\.\.prev/);
  assert.match(nuevaCompra, /const total = lineas\.reduce/);
  assert.match(nuevaCompra, /No se convierten automáticamente/);
});

test('solo los precios marcados se guardan como preferenciales y pueden reintentarse', () => {
  assert.match(nuevaCompra, /lineas\.filter\(\(l\) => l\.guardarPrecio\)/);
  assert.match(nuevaCompra, /actualizarPreferencial/);
  assert.match(nuevaCompra, /Compra registrada correctamente, pero no se pudo actualizar/);
});

test('proveedores Buyer son activos y estan habilitados para compra', () => {
  assert.match(nuevaCompra, /s\.activo !== false && s\.es_socio_compra === true/);
  assert.match(proveedores, /s\.activo!==false&&s\.es_socio_compra===true/);
  assert.match(api, /\/socios\?activo=true&compra=true/);
});

test('crear y editar proveedor conserva la relacion de venta', () => {
  assert.match(nuevaCompra, /es_socio_compra: true/);
  assert.match(proveedores, /es_socio_venta:editing\?\.es_socio_venta/);
  assert.match(api, /es_socio_venta: socio\.es_socio_venta \?\? false/);
});

test('precios preferenciales usan GET y PUT V2 con moneda explicita', () => {
  assert.match(api, /precios\/socio\/\$\{socioId\}\/material\/\$\{materialId\}/);
  assert.match(api, /method: 'PUT'/);
  assert.match(api, /moneda_id: string/);
  assert.doesNotMatch(api.slice(api.indexOf('export async function savePrecioSocio'), api.indexOf('export interface CompraRapidaItem')), /company_id|precio_socio_id/);
});

test('Compras cargadas consume operaciones V2 y presenta etapas V2', () => {
  assert.match(comprasCargadas, /operacionesApi\.list/);
  assert.match(comprasCargadas, /operacionesApi\.get/);
  assert.match(comprasCargadas, /Pendiente|En proceso|Completada|Cancelada/);
});
