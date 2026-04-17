# State — payfin-mcp

**Feature:** Миграция payfin-code с Docker на npx + новый инсталлер
**Size:** L
**Started:** 2026-04-17

## Status: DONE 2026-04-17

Все задачи завершены, пилот на Mac успешно пройден.

После пилота докинули:
- Полноценный гайд-лендинг по структуре KB `/guide` (требования, роли, troubleshooting, ручная установка, откат)
- Token-gate на `/`, `/setup.ps1`, `/setup.sh` (валидация через KB)
- `X-Robots-Tag: noindex` + `robots.txt` + security headers (X-Frame-Options, referrer-policy, etc.)
- JS-автоподстановка `?token=` в копируемые команды лендинга

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Создать структуру монорепо | ✅ done |
| 2 | Портировать payfin-code → packages/mcp-code | ✅ done |
| 3 | Smoke-test через `npm link` | ✅ done |
| 4 | Опубликовать `payfin-mcp-code@0.1.0-beta.2` (unscoped) | ✅ done |
| 5 | Написать `installer/setup.ps1` + `.sh` | ✅ done |
| 6 | Написать `installer/web` лендинг | ✅ done |
| 7 | GitHub репо + Railway deploy | ✅ done |
| 8 | Security-аудит + пилот | ✅ done |

## Ключевые решения

- **npm scope:** планировали `@payfin/mcp-code`, но org настройка дала PUT 404. Перешли на unscoped `payfin-mcp-code` (опубликовано 2026-04-17)
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