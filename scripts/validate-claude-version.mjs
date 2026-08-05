#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const MANIFEST_PATH = '.claude-plugin/plugin.json';
const SIMPLE_SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

export function parseVersion(version) {
  const match = SIMPLE_SEMVER.exec(String(version ?? '').trim());
  if (!match) {
    throw new Error(
      `A versão "${version ?? ''}" é inválida. Use o formato MAJOR.MINOR.PATCH, por exemplo 1.0.1.`,
    );
  }

  return match.slice(1).map(Number);
}

export function compareVersions(left, right) {
  const leftParts = parseVersion(left);
  const rightParts = parseVersion(right);

  for (let index = 0; index < 3; index += 1) {
    if (leftParts[index] > rightParts[index]) return 1;
    if (leftParts[index] < rightParts[index]) return -1;
  }

  return 0;
}

export function validateVersionIncrement(previousVersion, currentVersion) {
  const comparison = compareVersions(currentVersion, previousVersion);
  if (comparison === 0) {
    throw new Error(
      `A versão do plugin Claude Code não foi incrementada. Versão anterior: ${previousVersion}. ` +
        `Versão atual: ${currentVersion}. Atualize o campo "version" em ${MANIFEST_PATH} ` +
        'para uma versão SemVer maior (MAJOR.MINOR.PATCH) e mantenha os demais manifests sincronizados.',
    );
  }

  if (comparison < 0) {
    throw new Error(
      `A versão do plugin Claude Code deve ser maior que a versão anterior. Versão anterior: ${previousVersion}. ` +
        `Versão atual: ${currentVersion}. Atualize o campo "version" em ${MANIFEST_PATH}.`,
    );
  }
}

function readManifestVersion(content, source) {
  let manifest;
  try {
    manifest = JSON.parse(content);
  } catch (error) {
    throw new Error(`Não foi possível interpretar ${source} como JSON válido: ${error.message}`);
  }

  parseVersion(manifest.version);
  return manifest.version;
}

function workflowEscape(message) {
  return message.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');
}

function resolveBaseSha() {
  const configured = process.env.CLAUDE_VERSION_BASE_SHA?.trim();
  if (configured && !/^0+$/.test(configured)) return configured;
  return 'HEAD^';
}

function run() {
  const baseSha = resolveBaseSha();
  const currentContent = readFileSync(MANIFEST_PATH, 'utf8');
  const previousContent = execFileSync('git', ['show', `${baseSha}:${MANIFEST_PATH}`], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  const previousVersion = readManifestVersion(previousContent, `${baseSha}:${MANIFEST_PATH}`);
  const currentVersion = readManifestVersion(currentContent, MANIFEST_PATH);

  validateVersionIncrement(previousVersion, currentVersion);
  console.log(
    `Validação da versão do plugin Claude aprovada: ${previousVersion} -> ${currentVersion}.`,
  );
}

const isMainModule = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMainModule) {
  try {
    run();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(
      `::error file=${MANIFEST_PATH},title=Versão do plugin Claude inválida::${workflowEscape(message)}`,
    );
    console.error(`ERRO: ${message}`);
    process.exitCode = 1;
  }
}
