# code-map — payfin-mcp

## Структура монорепо

```
D:/TECHFLOW3/payfin-mcp/
├── .claude/
│   ├── CLAUDE.md                       контекст проекта
│   └── workflow/
│       ├── state.md                    tracker задач
│       └── code-map.md                 этот файл
├── .gitignore
├── README.md                           главный README
├── package.json                        корневой monorepo с workspaces
├── packages/
│   └── mcp-code/                       npm-пакет @payfin/mcp-code
│       ├── package.json                pkg manifest (bin, deps, publishConfig)
│       ├── tsconfig.json               TS config (target ES2022, ESM)
│       ├── README.md                   публичный README для npm
│       ├── .npmignore                  исключаем src/, tests/
│       └── src/
│           ├── index.ts                MCP server + tool handlers (форк из payfin-code)
│           ├── paths.ts                [NEW] getDefaultReposPath() кроссплатформенный
│           ├── repos.ts                clone/pull/sync, использует paths.ts
│           ├── tools.ts                code_read_file, code_grep, code_glob, code_find_symbol — использует @vscode/ripgrep
│           └── acl.ts                  права по роли (копия из payfin-code)
├── installer/
│   ├── setup.ps1                       PowerShell bootstrap
│   ├── setup.sh                        Bash bootstrap (Mac/Linux)
│   └── web/
│       ├── index.html                  лендинг
│       ├── server.js                   простой static server (Railway)
│       ├── package.json
│       └── static/
│           └── setup.ps1               копия для raw download (или симлинк через сервер)
└── railway.toml                        Railway config для installer/web
```

## Ключевые модули (packages/mcp-code)

### src/paths.ts [NEW]
- `getDefaultReposPath()` — возвращает `%APPDATA%/payfin-code/repos` на win, `~/.payfin-code/repos` на unix
- Используется в `repos.ts` если `REPOS_PATH` env не задан

### src/repos.ts
- `syncRepo(alias)`, `syncAllRepos()`, `listRepos()`, `repoExists(alias)`, `getRepoPath(alias)`
- Использует `git` из PATH (требование к пользователю)
- `startCronSync()` — ежечасный pull через `node-cron`

### src/tools.ts
- `codeReadFile(repo, path)`, `codeGrep(repo, pattern, path?)`, `codeGlob(repo, pattern)`, `codeFindSymbol(repo, symbol)`
- ripgrep через `@vscode/ripgrep` (абсолютный путь, кроссплатформенно)
- Fallback на Node-based поиск если `@vscode/ripgrep` недоступен

### src/acl.ts
- `canReadPath(path, role)`, `canSearch(role)`, `getRole()`
- Копия как есть из payfin-code

### src/index.ts
- MCP server: 5 tools (read_file, grep, glob, find_symbol, refresh, list_repos)
- StdioServerTransport
- Shebang `#!/usr/bin/env node` через bin entry

## Что НЕ в этом репо

- Сам код `payfin-core`, `payfin-broker` и др. — читается runtime через GitLab
- `payfin-kb` сервер — остаётся в отдельном репо `payfin-kb-v2`
- Старый Dockerfile / docker-compose — в legacy репо `docker-mcp`