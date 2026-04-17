# State — payfin-mcp

**Feature:** Миграция payfin-code с Docker на npx + новый инсталлер
**Size:** L
**Started:** 2026-04-17

## Tasks

| # | Task | Status |
|---|---|---|
| 0 | Проверить `@payfin` scope на npm | ✅ done (свободен) |
| 1 | Создать структуру монорепо | 🔄 in_progress |
| 2 | Портировать payfin-code → packages/mcp-code | ⬜ pending |
| 3 | Smoke-test через `npm link` | ⬜ pending |
| 4 | Опубликовать `@payfin/mcp-code@0.1.0-beta.1` | ⬜ pending |
| 5 | Написать `installer/setup.ps1` | ⬜ pending |
| 6 | Написать `installer/web` лендинг | ⬜ pending |
| 7 | Git-репо + Railway deploy | ⬜ pending |
| 8 | Security-аудит + пилот | ⬜ pending |

## Ключевые решения

- **npm scope:** `@payfin/mcp-code` (свободен, подтверждено 2026-04-17)
- **Кроссплатформенный rg:** пакет `@vscode/ripgrep` (содержит бинарь для win/mac/linux)
- **Путь кэша репо:** по умолчанию `%APPDATA%/payfin-code/repos` (win) или `~/.payfin-code/repos` (unix), override через `REPOS_PATH`
- **Никаких изменений в живом Railway** — новый проект `payfin-installer` параллельно

## Docker-зависимости в payfin-code (надо убрать)

- ❌ `REPOS_PATH = '/repos'` дефолт → кроссплатформенный (`paths.ts`)
- ❌ `execSync('rg ...')` с fallback на `grep` → `@vscode/ripgrep`
- ❌ `execSync('which ...')` → проверка через абсолютный путь
- ❌ `apk add git ripgrep` из Dockerfile → требование: git в PATH, rg из пакета

## Next

Продолжить task #1 — создание файлов структуры.
Запустить в новом чате: `/resume`