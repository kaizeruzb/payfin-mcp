# payfin-mcp

Новый способ установки MCP-серверов PayFin для Claude Code — **без Docker**.

## Для сотрудника (установка)

1. Подключиться к VPN (`git.ipoint.uz`).
2. Запустить одну команду в PowerShell:

   _Если PowerShell блокирует выполнение удалённых скриптов — запускать с`Set-ExecutionPolicy -Scope Process Bypass -Force;`._

   ```powershell
   irm https://payfin-installer-production.up.railway.app/setup.ps1 | iex
   ```
3. Скрипт попросит 4 токена (инструкция — на странице https://payfin-installer.up.railway.app).
4. Перезапустить Claude Code.

Готово.

## Опционально: spec-coverage hook

PreToolUse hook для Claude Code. Блокирует запись `**/specs/**/*.md`, если упомянутые в спеке PHP-классы / DTO / миграции **не были прочитаны** в текущей сессии. Защита от instruction drift на длинных сессиях `/spec`.

Установка (требует Python 3.8+):

```powershell
# Windows
git clone https://github.com/kaizeruzb/payfin-mcp.git
cd payfin-mcp
.\installer\install-hook.ps1
```

```bash
# Mac/Linux
git clone https://github.com/kaizeruzb/payfin-mcp.git
cd payfin-mcp
./installer/install-hook.sh
```

Подробности и конфигурация — `installer/hooks/README.md`.

## Структура монорепо

- `packages/mcp-code/` — npm-пакет `payfin-mcp-code` (форк `payfin-code` без Docker)
- `installer/setup.ps1` — bootstrap-скрипт для сотрудника
- `installer/install-hook.{ps1,sh}` — установка spec-coverage hook (отдельно от MCP)
- `installer/hooks/` — исходники hook-скрипта
- `installer/web/` — лендинг на Railway

## Для разработчика (этого репо)

```bash
npm install
npm run build
```

## Релиз npm

```bash
npm run publish:beta
```

## Что было раньше

Старая установка через Docker — см. `D:/TECHFLOW3/docker-mcp/README.md`. Продолжает работать, но новых сотрудников онбордим уже через этот репо.