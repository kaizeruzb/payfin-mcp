#Requires -Version 5.1
<#
PayFin MCP — bootstrap installer.
Запуск:
    irm https://payfin-installer-production.up.railway.app/setup.ps1 | iex
#>

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok { param([string]$Msg) Write-Host "    [OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "    [WARN] $Msg" -ForegroundColor Yellow }
function Write-Err { param([string]$Msg) Write-Host "    [ERR] $Msg" -ForegroundColor Red }

function Test-Command { param([string]$Name) $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

function Read-Required {
    param([string]$Prompt, [string]$Hint = '')
    while ($true) {
        if ($Hint) { Write-Host "    $Hint" -ForegroundColor DarkGray }
        $v = Read-Host "    $Prompt"
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v.Trim() }
        Write-Err 'Значение не может быть пустым. Попробуй ещё раз.'
    }
}

function Read-Choice {
    param([string]$Prompt, [string[]]$Options, [string]$Default)
    $hint = "[$($Options -join '/')], Enter = $Default"
    while ($true) {
        $v = Read-Host "    $Prompt $hint"
        if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
        if ($Options -contains $v) { return $v }
        Write-Err "Выбери одно из: $($Options -join ', ')"
    }
}

Write-Host @"

================================================================
  PayFin MCP installer
  Подключит 4 MCP-сервера: payfin-kb, payfin-code, gitlab, atlassian
================================================================
"@ -ForegroundColor Magenta

# --- Проверки окружения ---------------------------------------------------
Write-Step 'Проверяю окружение'

if (-not (Test-Command 'node')) {
    Write-Err 'Node.js не найден. Установи Node 20+: https://nodejs.org'
    exit 1
}
$nodeVer = (& node -v).TrimStart('v')
$major = [int]($nodeVer -split '\.')[0]
if ($major -lt 20) {
    Write-Err "Node.js $nodeVer слишком старый. Нужен 20+."
    exit 1
}
Write-Ok "Node.js $nodeVer"

if (-not (Test-Command 'claude')) {
    Write-Err 'Claude Code CLI не найден. Установи: https://claude.ai/code'
    exit 1
}
Write-Ok 'Claude Code CLI'

if (-not (Test-Command 'git')) {
    Write-Err 'git не найден. Установи Git for Windows: https://git-scm.com/download/win'
    exit 1
}
Write-Ok 'Git'

if (-not (Test-Command 'uv')) {
    Write-Warn 'uv не найден — нужен для Atlassian MCP. Устанавливаю автоматически...'
    try {
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
        $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
        if (-not (Test-Command 'uv')) { throw 'uv не появился в PATH после установки' }
        Write-Ok 'uv установлен'
    } catch {
        Write-Err "Не удалось установить uv: $($_.Exception.Message)"
        Write-Host '    Установи вручную: powershell -c "irm https://astral.sh/uv/install.ps1 | iex"' -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Ok 'uv'
}

# --- Проверка VPN (мягкая) ------------------------------------------------
Write-Step 'Проверяю доступ к git.ipoint.uz (нужен VPN)'
try {
    $null = Invoke-WebRequest 'https://git.ipoint.uz' -Method Head -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-Ok 'VPN работает, git.ipoint.uz доступен'
} catch {
    Write-Warn 'git.ipoint.uz недоступен. Проверь подключение к VPN.'
    $cont = Read-Host '    Продолжить без VPN? [y/N]'
    if ($cont -ne 'y' -and $cont -ne 'Y') { exit 1 }
}

# --- Сбор токенов ---------------------------------------------------------
Write-Step 'Собираю токены (4 шт.) + роль'

Write-Host '
    1/4 KB_TOKEN — payfin-kb (формат pfk_xxx, получить у Sardorbek)' -ForegroundColor DarkGray
$KB_TOKEN = Read-Required 'KB_TOKEN' 'Начинается с pfk_'

Write-Host '
    2/4 GITLAB_TOKEN — свой PAT из git.ipoint.uz
    Путь: Edit profile -> Access Tokens -> scope read_api, read_repository' -ForegroundColor DarkGray
$GITLAB_TOKEN = Read-Required 'GITLAB_TOKEN'

Write-Host '
    3/4 CONFLUENCE_PAT — свой токен из wiki.ipoint.uz
    Путь: аватар -> Profile -> Personal Access Tokens -> Create' -ForegroundColor DarkGray
$CONFLUENCE_PAT = Read-Required 'CONFLUENCE_PAT'

Write-Host '
    4/4 JIRA_PAT — свой токен из jira.ipoint.uz
    Путь: аватар -> Profile -> Personal Access Tokens -> Create' -ForegroundColor DarkGray
$JIRA_PAT = Read-Required 'JIRA_PAT'

Write-Host '
    Твоя роль:' -ForegroundColor DarkGray
$AGENT_ROLE = Read-Choice 'AGENT_ROLE' @('pm', 'analyst', 'developer', 'tech-lead', 'qa', 'admin') 'developer'

# --- Удаление старых регистраций (чтобы переустановить чисто) -------------
Write-Step 'Удаляю старые регистрации MCP (если были)'
foreach ($name in @('payfin-kb', 'payfin-code', 'gitlab', 'atlassian')) {
    & claude mcp remove $name 2>$null | Out-Null
}
Write-Ok 'Готово к установке'

# --- Установка MCP -------------------------------------------------------
Write-Step 'Регистрирую MCP серверы в Claude Code'

& claude mcp add --transport http payfin-kb `
    'https://practical-generosity-production-cb1c.up.railway.app/mcp' `
    --header "Authorization: Bearer $KB_TOKEN"
if ($LASTEXITCODE -eq 0) { Write-Ok 'payfin-kb' } else { Write-Err 'payfin-kb: ошибка'; exit 1 }

& claude mcp add payfin-code `
    -e GITLAB_URL='https://git.ipoint.uz' `
    -e GITLAB_TOKEN=$GITLAB_TOKEN `
    -e REPOS='broker-api:broker/backend/broker-api,nasiya-api:nasiya/backend/nasiya-api' `
    -e AGENT_ROLE=$AGENT_ROLE `
    -- npx -y payfin-mcp-code@beta
if ($LASTEXITCODE -eq 0) { Write-Ok 'payfin-code' } else { Write-Err 'payfin-code: ошибка'; exit 1 }

& claude mcp add gitlab `
    -e GITLAB_API_URL='https://git.ipoint.uz/api/v4' `
    -e GITLAB_PERSONAL_ACCESS_TOKEN=$GITLAB_TOKEN `
    -- npx -y '@zereight/mcp-gitlab'
if ($LASTEXITCODE -eq 0) { Write-Ok 'gitlab' } else { Write-Err 'gitlab: ошибка'; exit 1 }

& claude mcp add atlassian `
    -e CONFLUENCE_URL='https://wiki.ipoint.uz' `
    -e JIRA_URL='https://jira.ipoint.uz' `
    -e CONFLUENCE_PERSONAL_TOKEN=$CONFLUENCE_PAT `
    -e JIRA_PERSONAL_TOKEN=$JIRA_PAT `
    -- uvx mcp-atlassian
if ($LASTEXITCODE -eq 0) { Write-Ok 'atlassian' } else { Write-Err 'atlassian: ошибка'; exit 1 }

# --- Финал ---------------------------------------------------------------
Write-Host "`n================================================================" -ForegroundColor Green
Write-Host '  ВСЁ ГОТОВО' -ForegroundColor Green
Write-Host "================================================================`n" -ForegroundColor Green
Write-Host '  Дальше:' -ForegroundColor White
Write-Host '    1. Перезапусти Claude Code (закрой и открой)' -ForegroundColor White
Write-Host '    2. Проверь: claude mcp list' -ForegroundColor White
Write-Host '    3. В любом чате попроси:' -ForegroundColor White
Write-Host '       "Покажи composer.json из broker-api"' -ForegroundColor DarkGray
Write-Host ''
