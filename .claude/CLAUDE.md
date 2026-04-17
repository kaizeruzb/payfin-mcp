# payfin-mcp — контекст для Claude Code

## Цель
Заменить текущую Docker-установку MCP-серверов PayFin на npx-подход, чтобы сотрудникам не надо было ставить Docker Desktop и проходить 9 шагов.

## Что трогаем
- **Создаём:** packages/mcp-code (npm @payfin/mcp-code), installer/setup.ps1, installer/web (лендинг на Railway)

## Что НЕ трогаем
- `D:/TECHFLOW3/payfin-kb-v2/` (Railway, работает)
- `D:/TECHFLOW3/payfin-kb-proxy/` (legacy, не используется с переходом KB на HTTP)
- `D:/TECHFLOW3/payfin-code/` (legacy, будет форкнут в packages/mcp-code)
- `D:/TECHFLOW3/docker-mcp/` (legacy, остаётся для тех кто уже поставил)
- Live Railway `payfin-kb-v2` (`practical-generosity-production-cb1c.up.railway.app`)

## Архитектура нового подхода

| MCP | Как подключается |
|---|---|
| payfin-kb | HTTP Bearer (не меняется) |
| payfin-code | **новое:** `npx -y @payfin/mcp-code` вместо Docker |
| gitlab | `npx -y @zereight/mcp-gitlab` (не меняется) |
| atlassian | `uvx mcp-atlassian` (не меняется) |

## Стек
- TypeScript 5 + Node.js 20+ ESM
- `@modelcontextprotocol/sdk` 1.12+
- `zod`, `node-cron`, `@vscode/ripgrep` (кроссплатформенный rg)
- Build через `tsc` в `dist/`

## Конвенции
- Русский в комментариях допустим (как в оригинальном payfin-code)
- ESM имports (`.js` в путях для TypeScript/ESM совместимости)
- Нет комментариев в коде без реальной причины
- Пути через `node:path`, `node:os` — никаких `/repos` хардкодов

## Workflow
- `.claude/workflow/state.md` — текущий tracker
- `.claude/workflow/code-map.md` — структура файлов
- Git commits после каждой завершённой задачи
