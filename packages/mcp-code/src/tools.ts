import { readFileSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';
import { spawnSync } from 'node:child_process';
import { glob } from 'node:fs/promises';
import { rgPath } from '@vscode/ripgrep';
import { getRepoPath, repoExists, listRepos } from './repos.js';
import { canReadPath, canSearch, getRole } from './acl.js';

const MAX_FILE_SIZE = 100_000;
const MAX_GREP_RESULTS = 50;
const MAX_GLOB_RESULTS = 100;

function repoError(repo: string): string {
  if (!listRepos().includes(repo)) {
    return `Unknown repo: ${repo}. Available: ${listRepos().join(', ')}`;
  }
  if (!repoExists(repo)) {
    return `Repo ${repo} not cloned yet. Waiting for sync (VPN required). Try again in a minute.`;
  }
  return '';
}

function runRipgrep(args: string[], timeoutMs: number): string {
  const result = spawnSync(rgPath, args, {
    encoding: 'utf-8',
    timeout: timeoutMs,
    maxBuffer: 10 * 1024 * 1024,
  });
  if (result.status !== 0 && result.status !== 1) {
    return '';
  }
  return (result.stdout ?? '').trim();
}

export function codeReadFile(repo: string, path: string): string {
  const err = repoError(repo);
  if (err) return `Error: ${err}`;

  const role = getRole();
  if (!canReadPath(path, role)) {
    return `Access denied: role '${role}' cannot read '${path}'`;
  }

  const repoBase = getRepoPath(repo);
  const fullPath = join(repoBase, path);
  if (!fullPath.startsWith(repoBase)) {
    return `Error: Path traversal not allowed`;
  }
  if (!existsSync(fullPath)) {
    return `Error: File not found: ${path}`;
  }

  try {
    const content = readFileSync(fullPath);
    if (content.length > MAX_FILE_SIZE) {
      return `Error: File too large (${content.length} bytes, max ${MAX_FILE_SIZE}). Use code_grep to search specific content.`;
    }
    return content.toString('utf-8');
  } catch (e) {
    return `Error: ${(e as Error).message}`;
  }
}

export function codeGrep(repo: string, pattern: string, searchPath?: string): string {
  const err = repoError(repo);
  if (err) return `Error: ${err}`;

  const role = getRole();
  if (!canSearch(role)) {
    return `Access denied: role '${role}' cannot search`;
  }

  const repoBase = getRepoPath(repo);
  const targetPath = searchPath ? join(repoBase, searchPath) : repoBase;

  const filesOutput = runRipgrep(
    ['--no-heading', '-l', '--max-count=1', pattern, targetPath],
    15_000,
  );
  if (!filesOutput) return `No matches for: ${pattern}`;

  const files = filesOutput.split(/\r?\n/).filter(Boolean).slice(0, MAX_GREP_RESULTS);
  const results: string[] = [];

  for (const file of files.slice(0, 20)) {
    const relPath = relative(repoBase, file);
    if (!canReadPath(relPath, role)) continue;

    const lines = runRipgrep(['--no-heading', '-n', '-m', '5', pattern, file], 5_000);
    results.push(lines ? `${relPath}:\n${lines}` : `${relPath}: (match found)`);
  }

  if (results.length === 0) return `No accessible matches for: ${pattern}`;
  return `Matches for "${pattern}" in ${repo}:\n\n${results.join('\n\n')}`;
}

export async function codeGlob(repo: string, pattern: string): Promise<string> {
  const err = repoError(repo);
  if (err) return `Error: ${err}`;

  const role = getRole();
  const repoBase = getRepoPath(repo);

  try {
    const matches: string[] = [];
    for await (const file of glob(pattern, { cwd: repoBase })) {
      if (matches.length >= MAX_GLOB_RESULTS) break;
      const relPath = String(file);
      if (canReadPath(relPath, role)) {
        matches.push(relPath);
      }
    }

    if (matches.length === 0) return `No files matching: ${pattern}`;
    const suffix = matches.length >= MAX_GLOB_RESULTS ? `\n(showing first ${MAX_GLOB_RESULTS})` : '';
    return `Files matching "${pattern}" in ${repo}:\n${matches.join('\n')}${suffix}`;
  } catch (e) {
    return `Error: ${(e as Error).message}`;
  }
}

export function codeFindSymbol(repo: string, symbol: string): string {
  const err = repoError(repo);
  if (err) return `Error: ${err}`;

  const role = getRole();
  const repoBase = getRepoPath(repo);

  const patterns = [
    `class ${symbol}`,
    `function ${symbol}`,
    `def ${symbol}`,
    `interface ${symbol}`,
    `trait ${symbol}`,
    `const ${symbol}`,
    `${symbol}:`,
  ];

  const results: string[] = [];

  for (const pat of patterns) {
    const output = runRipgrep(['--no-heading', '-n', '-m', '10', pat, repoBase], 10_000);
    if (!output) continue;

    for (const line of output.split(/\r?\n/).filter(Boolean)) {
      const colon = line.indexOf(':');
      if (colon < 0) continue;
      const filePath = relative(repoBase, line.slice(0, colon));
      if (!canReadPath(filePath, role)) continue;
      results.push(`${filePath}:${line.slice(colon + 1)}`);
    }
  }

  if (results.length === 0) return `Symbol '${symbol}' not found in ${repo}`;

  const unique = [...new Set(results)].slice(0, 20);
  return `Symbol '${symbol}' in ${repo}:\n${unique.join('\n')}`;
}
