import test from 'node:test';
import assert from 'node:assert/strict';

import {
  compareVersions,
  parseVersion,
  validateVersionIncrement,
} from '../scripts/validate-claude-version.mjs';

test('parseVersion aceita MAJOR.MINOR.PATCH', () => {
  assert.deepEqual(parseVersion('1.2.3'), [1, 2, 3]);
});

test('parseVersion rejeita versões fora do SemVer simples', () => {
  assert.throws(() => parseVersion('1.2'), /MAJOR\.MINOR\.PATCH/);
  assert.throws(() => parseVersion('v1.2.3'), /MAJOR\.MINOR\.PATCH/);
});

test('compareVersions ordena versões semanticamente', () => {
  assert.equal(compareVersions('1.0.1', '1.0.0'), 1);
  assert.equal(compareVersions('1.1.0', '1.0.9'), 1);
  assert.equal(compareVersions('2.0.0', '1.99.99'), 1);
  assert.equal(compareVersions('1.0.0', '1.0.0'), 0);
  assert.equal(compareVersions('0.9.9', '1.0.0'), -1);
});

test('validateVersionIncrement aceita somente uma versão maior', () => {
  assert.doesNotThrow(() => validateVersionIncrement('1.0.0', '1.0.1'));
  assert.throws(
    () => validateVersionIncrement('1.0.0', '1.0.0'),
    /não foi incrementada.*1\.0\.0/s,
  );
  assert.throws(
    () => validateVersionIncrement('1.0.0', '0.9.9'),
    /deve ser maior.*1\.0\.0/s,
  );
});
