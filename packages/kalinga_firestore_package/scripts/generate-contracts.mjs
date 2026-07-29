#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const checkOnly = process.argv.includes('--check');

const readJson = async (relative) => JSON.parse(await fs.readFile(path.join(root, relative), 'utf8'));

function splitTopLevel(value, delimiter) {
  const parts = [];
  let depth = 0;
  let current = '';
  for (const char of value) {
    if (char === '<') depth += 1;
    if (char === '>') depth -= 1;
    if (char === delimiter && depth === 0) {
      parts.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  if (current.trim()) parts.push(current.trim());
  return parts;
}

function quoteLiteral(value) {
  return `'${value.replaceAll("'", "\\'")}'`;
}

function typeFor(spec, enumNames) {
  const value = spec.trim();
  const unionParts = splitTopLevel(value, '|');
  if (unionParts.length > 1) {
    const converted = [...new Set(unionParts.map((part) => typeFor(part, enumNames)))];
    return converted.join(' | ');
  }

  if (enumNames.has(value)) return value;
  if (value === 'TranslationValue') return 'TranslationValue';
  if (value === 'null') return 'null';
  if (value === 'boolean') return 'boolean';
  if (value === 'string' || value === 'uid' || value === 'localeCode' || value === 'semanticVersion') {
    return value === 'localeCode' ? 'LocaleCode' : 'string';
  }
  if (value === 'timestamp') return 'TimestampLike';
  if (value === 'date' || value === 'YYYY-MM-DD' || value === 'ISOYear-Www') return 'string';
  if (value === 'integer' || value === 'integer>=1' || value === 'number' || value === 'number[0..100]') return 'number';
  if (value === 'map') return 'Record<string, unknown>';

  if (value.startsWith('array<') && value.endsWith('>')) {
    const inner = value.slice(6, -1).trim();
    const converted = typeFor(inner, enumNames);
    return converted.includes(' | ') ? `Array<${converted}>` : `${converted}[]`;
  }

  if (value.startsWith('map<') && value.endsWith('>')) {
    const inner = value.slice(4, -1);
    const pieces = splitTopLevel(inner, ',');
    assert.equal(pieces.length, 2, `Unsupported map type: ${value}`);
    const [keySpec, valueSpec] = pieces;
    const convertedValue = typeFor(valueSpec, enumNames);
    if (keySpec === 'localeCode') return `Partial<Record<LocaleCode, ${convertedValue}>>`;
    if (keySpec === 'string') return `Record<string, ${convertedValue}>`;
    return `Record<string, ${convertedValue}>`;
  }

  if (value.includes('-') || value.includes('[') || value.includes(']')) return 'string';
  if (/^[A-Za-z][A-Za-z0-9]*$/.test(value)) return quoteLiteral(value);
  throw new Error(`Unsupported field type specification: ${value}`);
}

function mixinInterfaceName(mixinName) {
  return `${mixinName[0].toUpperCase()}${mixinName.slice(1)}Fields`;
}

function renderFields(fields, enumNames, indent = '  ') {
  return Object.entries(fields)
    .map(([name, spec]) => `${indent}${name}: ${typeFor(spec, enumNames)};`)
    .join('\n');
}

function renderDomainTypes(schema, enums, manifest) {
  const enumNames = new Set(Object.keys(enums));
  const lines = [
    '/**',
    ' * GENERATED FILE. Source: kalinga-firestore-schema.json + enums.json + contracts-manifest.json.',
    ' * Run `npm run generate:contracts` after changing the authoritative schema.',
    ' */',
    '',
    'export type TimestampLike = unknown;',
    ''
  ];

  for (const [name, values] of Object.entries(enums)) {
    lines.push(`export type ${name} = ${values.map(quoteLiteral).join(' | ')};`);
  }
  lines.push('');

  for (const [name, fields] of Object.entries(schema.sharedTypes ?? {})) {
    lines.push(`export interface ${name} {`);
    lines.push(renderFields(fields, enumNames));
    lines.push('}', '');
  }

  for (const [name, fields] of Object.entries(schema.mixins ?? {})) {
    lines.push(`export interface ${mixinInterfaceName(name)} {`);
    lines.push(renderFields(fields, enumNames));
    lines.push('}', '');
  }

  const schemaByPath = new Map(schema.collections.map((collection) => [collection.path, collection]));
  const manifestPaths = Object.keys(manifest.documents);
  assert.equal(manifestPaths.length, schema.collections.length, 'Contract manifest must cover every schema path.');
  for (const collection of schema.collections) {
    assert.ok(manifest.documents[collection.path], `Missing contract manifest entry for ${collection.path}`);
  }
  for (const documentPath of manifestPaths) {
    assert.ok(schemaByPath.has(documentPath), `Contract manifest contains an unknown schema path: ${documentPath}`);
  }

  for (const collection of schema.collections) {
    const contract = manifest.documents[collection.path];
    const mixins = collection.mixins?.map(mixinInterfaceName) ?? [];
    const extension = mixins.length ? ` extends ${mixins.join(', ')}` : '';
    lines.push('/**');
    lines.push(` * Firestore path: ${collection.path}`);
    lines.push(` * ${collection.purpose}`);
    lines.push(` * Client read policy: ${collection.clientReadPolicy}; client write policy: ${collection.clientWritePolicy}.`);
    lines.push(' */');
    lines.push(`export interface ${contract.interface}${extension} {`);
    lines.push(renderFields(collection.fields, enumNames));
    lines.push('}', '');
  }

  lines.push('export interface DocumentByPathPattern {');
  for (const collection of schema.collections) {
    const contract = manifest.documents[collection.path];
    lines.push(`  ${JSON.stringify(collection.path)}: ${contract.interface};`);
  }
  lines.push('}', '');
  lines.push('export type FirestoreDocumentPathPattern = keyof DocumentByPathPattern;');
  lines.push('export type DocumentForPathPattern<P extends FirestoreDocumentPathPattern> = DocumentByPathPattern[P];');
  lines.push('export type CreateDocumentInput<T> = Omit<T, keyof AuditFields | keyof SoftDeleteFields | keyof RetentionFields | keyof SyncFields>;');
  lines.push('export type PatchDocumentInput<T> = Partial<CreateDocumentInput<T>>;');
  lines.push('');
  return `${lines.join('\n')}\n`;
}

function placeholders(pattern) {
  return [...pattern.matchAll(/\{([^}]+)\}/g)].map((match) => match[1]);
}

function templateFor(pattern) {
  return `\`${pattern.replace(/\{([^}]+)\}/g, '${$1}')}\``;
}

function collectionPattern(documentPattern) {
  return documentPattern.replace(/\/\{[^/{}]+\}$/, '');
}

function renderFunction(name, pattern, isDocument) {
  const allParams = placeholders(pattern);
  const params = isDocument ? allParams : allParams.slice(0, -1);
  const renderedPattern = isDocument ? pattern : collectionPattern(pattern);
  return `  ${name}: (${params.map((param) => `${param}: string`).join(', ')}) => ${templateFor(renderedPattern)},`;
}

function renderFirestorePaths(schema, manifest) {
  const lines = [
    '/**',
    ' * GENERATED FILE. Exhaustive, type-safe Firestore path helpers.',
    ' * This is not a substitute for authorization or runtime validation.',
    ' * Run `npm run generate:contracts` after changing the authoritative schema.',
    ' */',
    '',
    'export const documentPatterns = {'
  ];

  for (const collection of schema.collections) {
    const contract = manifest.documents[collection.path];
    lines.push(`  ${contract.interface}: ${JSON.stringify(collection.path)},`);
  }
  lines.push('} as const;', '', 'export const collectionPatterns = {');
  for (const collection of schema.collections) {
    const contract = manifest.documents[collection.path];
    lines.push(`  ${contract.interface}: ${JSON.stringify(collectionPattern(collection.path))},`);
  }
  lines.push('} as const;', '', 'const canonicalPaths = {');

  const helperNames = new Set();
  for (const collection of schema.collections) {
    const contract = manifest.documents[collection.path];
    for (const helperName of [contract.documentHelper, contract.collectionHelper]) {
      assert.ok(!helperNames.has(helperName), `Duplicate path helper name: ${helperName}`);
      helperNames.add(helperName);
    }
    lines.push(renderFunction(contract.documentHelper, collection.path, true));
    lines.push(renderFunction(contract.collectionHelper, collection.path, false));
  }
  lines.push('} as const;', '', 'export const paths = {', '  ...canonicalPaths,');
  for (const [alias, target] of Object.entries(manifest.aliases ?? {})) {
    assert.ok(helperNames.has(target), `Alias target does not exist: ${target}`);
    lines.push(`  ${alias}: canonicalPaths.${target},`);
  }
  lines.push('} as const;', '');
  lines.push('export type PathHelperName = keyof typeof paths;');
  lines.push('export type FirestoreDocumentPattern = typeof documentPatterns[keyof typeof documentPatterns];');
  lines.push('export type FirestoreCollectionPattern = typeof collectionPatterns[keyof typeof collectionPatterns];');
  lines.push('');
  return `${lines.join('\n')}\n`;
}

async function writeOrCheck(relative, expected) {
  const absolute = path.join(root, relative);
  if (checkOnly) {
    const actual = await fs.readFile(absolute, 'utf8');
    assert.equal(actual, expected, `${relative} is out of sync. Run npm run generate:contracts.`);
  } else {
    await fs.writeFile(absolute, expected);
  }
}

async function main() {
  const schema = await readJson('schema/kalinga-firestore-schema.json');
  const enums = await readJson('schema/enums.json');
  const manifest = await readJson('schema/contracts-manifest.json');
  assert.equal(manifest.version, schema.version, 'Contract manifest version must equal schema version.');

  const domainTypes = renderDomainTypes(schema, enums, manifest);
  const firestorePaths = renderFirestorePaths(schema, manifest);
  await writeOrCheck('schema/domain-types.ts', domainTypes);
  await writeOrCheck('schema/firestore-paths.ts', firestorePaths);
  console.log(checkOnly ? 'Generated contracts are synchronized.' : 'Generated contracts updated.');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack : error);
  process.exitCode = 1;
});
