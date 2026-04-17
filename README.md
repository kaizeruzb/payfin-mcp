# payfin-mcp

Новый способ установки MCP-серверов PayFin для Claude Code — **без Docker**.

## Для сотрудника (установка)

1. Подключиться к VPN (`git.ipoint.uz`).
2. Запустить одну команду в PowerShell:
   ```powershell
   irm https://payfin-installer.up.railway.app/setup.ps1 | iex
   ```
3. Скрипт попросит 4 токена (инструкция — на странице https://payfin-installer.up.railway.app).
4. Перезапустить Claude Code.

Готово.

## Структура монорепо

- `packages/mcp-code/` — npm-пакет `payfin-mcp-code` (форк `payfin-code` без Docker)
- `installer/setup.ps1` — bootstrap-скрипт для сотрудника
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