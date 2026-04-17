import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import cron from 'node-cron';
import { getDefaultReposPath } from './paths.js';

const REPOS_PATH = process.env.REPOS_PATH ?? getDefaultReposPath();
const GITLAB_URL = process.env.GITLAB_URL?.replace(/\/$/, '') ?? '';
const GITLAB_TOKEN = process.env.GITLAB_TOKEN ?? '';

const repoMap = new Map<string, string>();
for (const entry of (process.env.REPOS ?? '').split(',').map((r) => r.trim()).filter(Boolean)) {
  const colonIdx = entry.indexOf(':');
  if (colonIdx > 0) {
    repoMap.set(entry.slice(0, colonIdx), entry.slice(colonIdx + 1));
  } else {
    repoMap.set(entry, entry);
  }
}

export function getRepoPath(alias: string): string {
  return join(REPOS_PATH, alias);
}

export function getReposPath(): string {
  return REPOS_PATH;
}

export function listRepos(): string[] {
  return Array.from(repoMap.keys());
}

export function repoExists(alias: string): boolean {
  return existsSync(join(getRepoPath(alias), '.git'));
}

function gitUrl(alias: string): string {
  const gitlabPath = repoMap.get(alias) ?? alias;
  const url = new URL(`${GITLAB_URL}/${gitlabPath}.git`);
  url.username = 'oauth2';
  url.password = GITLAB_TOKEN;
  return url.toString();
}

function redactUrl(message: string): string {
  return message.replace(/https?:\/\/[^:/\s]+:[^@\s]+@/g, 'https://<redacted>@');
}

function cloneRepo(repo: string): { ok: boolean; error?: string } {
  const dest = getRepoPath(repo);
  mkdirSync(REPOS_PATH, { recursive: true });

  const result = spawnSync('git', ['clone', '--depth=1', gitUrl(repo), dest], {
    stdio: 'pipe',
    timeout: 60_000,
    encoding: 'utf-8',
  });
  if (result.status === 0) return { ok: true };
  const err = redactUrl((result.stderr || result.error?.message || 'unknown').slice(0, 300));
  return { ok: false, error: err };
}

function pullRepo(repo: string): { ok: boolean; error?: string } {
  const dest = getRepoPath(repo);
  const result = spawnSync('git', ['-C', dest, 'pull', '--ff-only'], {
    stdio: 'pipe',
    timeout: 30_000,
    encoding: 'utf-8',
  });
  if (result.status === 0) return { ok: true };
  const err = redactUrl((result.stderr || result.error?.message || 'unknown').slice(0, 300));
  return { ok: false, error: err };
}

export function syncRepo(alias: string): { ok: boolean; action: 'pull' | 'clone'; message: string } {
  if (!repoMap.has(alias)) {
    return { ok: false, action: 'pull', message: `Unknown repo: ${alias}. Available: ${listRepos().join(', ')}` };
  }
  if (repoExists(alias)) {
    const result = pullRepo(alias);
    const message = result.ok ? `${alias}: pulled successfully` : `${alias}: pull failed — ${result.error}`;
    process.stderr.write(`[payfin-code] ${message}\n`);
    return { ok: result.ok, action: 'pull', message };
  } else {
    const result = cloneRepo(alias);
    const message = result.ok ? `${alias}: cloned successfully` : `${alias}: clone failed — ${result.error}`;
    process.stderr.write(`[payfin-code] ${message}\n`);
    return { ok: result.ok, action: 'clone', message };
  }
}

export async function syncAllRepos(): Promise<void> {
  for (const repo of repoMap.keys()) {
    syncRepo(repo);
  }
}

export function startCronSync(): void {
  cron.schedule('0 * * * *', () => {
    process.stderr.write('[payfin-code] cron: syncing repos...\n');
    syncAllRepos().catch((e) => {
      process.stderr.write(`[payfin-code] cron error: ${(e as Error).message}\n`);
    });
  });
}
