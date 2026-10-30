import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(new URL('../../../src/modules/OperacionesModule.tsx', import.meta.url), 'utf8');
const helper = source.slice(source.indexOf('function consolidarResultadoFisico'), source.indexOf('export function OperacionesModule'));
const finalizadas = source.slice(source.indexOf("etapaCodigo === 'finalizada'"), source.indexOf("etapaCodigo === 'en_proceso' ? gruposTransportista.map"));

test('tarjeta finalizada usa precio y monto historicos de la operacion', () => {
  assert.match(helper, /linea\.precio_unitario/);
  assert.match(helper, /carga\.monto/);
  assert.match(helper, /carga\.moneda_codigo/);
  assert.match(helper, /movimiento\.operacion_material_id===linea\.id/);
  assert.doesNotMatch(helper, /materialesCatalogo|precio_base|precio_mayorista/);
});

test('tarjeta finalizada oculta placa y conserva cantidades e importes', () => {
  assert.doesNotMatch(finalizadas, /transportista_placa/);
  assert.match(finalizadas, /Precio unit\./);
  assert.match(finalizadas, /Subtotal/);
  assert.match(finalizadas, /Acordado/);
  assert.match(finalizadas, /Recibido/);
  assert.match(finalizadas, /TOTAL:/);
});
