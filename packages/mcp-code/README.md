# payfin-mcp-code

Read-only MCP server for PayFin GitLab repositories. Запускается через `npx`, Docker не нужен.

## Установка в Claude Code

```bash
claude mcp add payfin-code \
  -e GITLAB_URL=https://git.ipoint.uz \
  -e GITLAB_TOKEN=glpat_xxx \
  -e REPOS=broker-api:broker/backend/broker-api,nasiya-api:nasiya/backend/nasiya-api \
  -e AGENT_ROLE=developer \
  -- npx -y payfin-mcp-code
```

## Переменные окружения

| Имя | Обязательно | Описание |
|---|---|---|
| `GITLAB_URL` | да | `https://git.ipoint.uz` |
| `GITLAB_TOKEN` | да | GitLab PAT (scope `read_repository`) |
| `REPOS` | да | `alias:path,...` через запятую |
| `AGENT_ROLE` | нет | `pm` / `analyst` / `developer` / `tech-lead` / `qa` / `admin`. По умолчанию `developer` |
| `REPOS_PATH` | нет | Где хранить клоны. По умолчанию `%APPDATA%/payfin-code/repos` (Windows) или `~/.payfin-code/repos` (Unix) |

## Tools

- `code_read_file(repo, path)` — содержимое файла (до 100 KB)
- `code_grep(repo, pattern, path?)` — поиск по содержимому
- `code_glob(repo, pattern)` — поиск файлов по glob
- `code_find_symbol(repo, symbol)` — определения класса/функции
- `code_refresh(repo)` — git pull
- `code_list_repos()` — список доступных репозиториев

## Требования
- Node.js 20+
- Git в PATH (для `clone` / `pull`)
- VPN до `git.ipoint.uz`
