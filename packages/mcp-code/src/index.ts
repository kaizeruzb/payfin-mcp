#!/usr/bin/env node
// payfin-mcp-code — Read-only code access MCP server for PayFin repositories.
//
// Env:
//   GITLAB_URL      e.g. https://git.ipoint.uz
//   GITLAB_TOKEN    GitLab PAT (scope read_repository)
//   REPOS           alias:path,... (например broker-api:broker/backend/broker-api)
//   AGENT_ROLE      pm | analyst | developer | tech-lead | qa | admin  (default: developer)
//   REPOS_PATH      override кэша репо (default: %APPDATA%/payfin-code/repos | ~/.payfin-code/repos)

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { syncAllRepos, startCronSync, listRepos, syncRepo, getReposPath } from './repos.js';
import { codeReadFile, codeGrep, codeGlob, codeFindSymbol } from './tools.js';
import { getRole } from './acl.js';

const role = getRole();
const repos = listRepos();

if (repos.length === 0) {
  process.stderr.write('Warning: REPOS env variable is empty. No repositories configured.\n');
}

process.stderr.write(`[payfin-code] starting. role=${role}, repos=${repos.join(',') || 'none'}, cache=${getReposPath()}\n`);

syncAllRepos().catch((e) => {
  process.stderr.write(`[payfin-code] initial sync failed: ${(e as Error).message}\n`);
});

startCronSync();

const server = new McpServer({
  name: 'payfin-code',
  version: '0.1.0-beta.1',
});

const repoEnum = repos.length > 0
  ? z.enum(repos as [string, ...string[]])
  : z.string();

server.tool(
  'code_read_file',
  'Read a file from a PayFin repository. Returns file content. Max 100KB.',
  {
    repo: repoEnum.describe('Repository name'),
    path: z.string().describe('File path relative to repo root, e.g. app/Services/KatmService.php'),
  },
  async ({ repo, path }) => {
    const content = codeReadFile(repo, path);
    return { content: [{ type: 'text' as const, text: content }] };
  },
);

server.tool(
  'code_grep',
  'Search for a pattern in repository files. Returns file paths and matching lines.',
  {
    repo: repoEnum.describe('Repository name'),
    pattern: z.string().describe('Search pattern (string or regex)'),
    path: z.string().optional().describe('Limit search to this subdirectory, e.g. app/Services'),
  },
  async ({ repo, pattern, path }) => {
    const result = codeGrep(repo, pattern, path);
    return { content: [{ type: 'text' as const, text: result }] };
  },
);

server.tool(
  'code_glob',
  'Find files by glob pattern in a repository.',
  {
    repo: repoEnum.describe('Repository name'),
    pattern: z.string().describe('Glob pattern, e.g. app/Services/**/*.php or **/*Katm*.php'),
  },
  async ({ repo, pattern }) => {
    const result = await codeGlob(repo, pattern);
    return { content: [{ type: 'text' as const, text: result }] };
  },
);

server.tool(
  'code_find_symbol',
  'Find where a class, function, method, or interface is defined in a repository.',
  {
    repo: repoEnum.describe('Repository name'),
    symbol: z.string().describe('Symbol name, e.g. KatmService, createClaim, UserRepository'),
  },
  async ({ repo, symbol }) => {
    const result = codeFindSymbol(repo, symbol);
    return { content: [{ type: 'text' as const, text: result }] };
  },
);

server.tool(
  'code_refresh',
  'Pull latest code for a repository (git pull). Use when you need up-to-date code.',
  {
    repo: repoEnum.describe('Repository name to refresh'),
  },
  async ({ repo }) => {
    const result = syncRepo(repo);
    return { content: [{ type: 'text' as const, text: result.message }] };
  },
);

server.tool(
  'code_list_repos',
  'List all repositories available in this MCP server.',
  {},
  async () => {
    const available = listRepos();
    return {
      content: [{
        type: 'text' as const,
        text: available.length > 0
          ? `Available repos: ${available.join(', ')}`
          : 'No repositories configured. Set REPOS env variable.',
      }],
    };
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
