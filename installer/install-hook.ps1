#Requires -Version 5.1
<#
spec-coverage-gate hook installer (Windows).

Копирует скрипты из installer/hooks/ в ~/.claude/hooks/ и регистрирует
PreToolUse-matcher в ~/.claude/settings.json.

Запуск из корня клонированного репо payfin-mcp:
    .\installer\install-hook.ps1
#>

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok { param([string]$Msg) Write-Host "    [OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "    [WARN] $Msg" -ForegroundColor Yellow }
function Write-Err { param([string]$Msg) Write-Host "    [ERR] $Msg" -ForegroundColor Red }

function Test-Command { param([string]$Name) $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

Write-Host @"

================================================================
  spec-coverage-gate — установка PreToolUse hook
================================================================
"@ -ForegroundColor Magenta

# --- Проверки -------------------------------------------------------------
Write-Step 'Проверяю окружение'

$hasPython = Test-Command 'py'
if (-not $hasPython) {
    $hasPython = Test-Command 'python3'
}
if (-not $hasPython) {
    $hasPython = Test-Command 'python'
}
if (-not $hasPython) {
    Write-Err 'Python не найден. Установи Python 3.8+ и повтори.'
    Write-Host '    https://www.python.org/downloads/' -ForegroundColor DarkGray
    exit 1
}
Write-Ok 'Python'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$HooksSrc = Join-Path $ScriptDir 'hooks'
if (-not (Test-Path $HooksSrc)) {
    Write-Err "Не нашёл папку $HooksSrc. Запусти из корня клона payfin-mcp."
    exit 1
}
Write-Ok "Hooks source: $HooksSrc"

# --- Копирование ----------------------------------------------------------
Write-Step 'Копирую файлы хука'

$HooksDest = Join-Path $env:USERPROFILE '.claude\hooks'
New-Item -ItemType Directory -Force -Path $HooksDest | Out-Null

$files = @(
    'spec-coverage-gate.sh',
    'spec-coverage-gate.py',
    'spec-coverage.config.json'
)
foreach ($f in $files) {
    $src = Join-Path $HooksSrc $f
    $dst = Join-Path $HooksDest $f
    Copy-Item -Path $src -Destination $dst -Force
    Write-Ok $f
}

# --- Регистрация в settings.json -----------------------------------------
Write-Step 'Регистрирую hook в ~/.claude/settings.json'

$SettingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'

$pythonExe = if (Test-Command 'py') { 'py' } elseif (Test-Command 'python3') { 'python3' } else { 'python' }

# python helper для безопасного merge
$mergeScript = @"
import json, os, sys

settings_path = sys.argv[1]
hook_cmd = sys.argv[2]

if os.path.exists(settings_path):
    with open(settings_path, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except Exception:
            data = {}
else:
    data = {}

if 'hooks' not in data or not isinstance(data['hooks'], dict):
    data['hooks'] = {}
if 'PreToolUse' not in data['hooks'] or not isinstance(data['hooks']['PreToolUse'], list):
    data['hooks']['PreToolUse'] = []

# Look for existing matcher
existing = None
for entry in data['hooks']['PreToolUse']:
    if entry.get('matcher') == 'Write|Edit':
        existing = entry
        break

new_hook = {'type': 'command', 'command': hook_cmd}

if existing is None:
    data['hooks']['PreToolUse'].append({'matcher': 'Write|Edit', 'hooks': [new_hook]})
else:
    if 'hooks' not in existing or not isinstance(existing['hooks'], list):
        existing['hooks'] = []
    # avoid duplicates
    already = any(h.get('command') == hook_cmd for h in existing['hooks'])
    if not already:
        existing['hooks'].append(new_hook)

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print('OK')
"@

$HookCmd = (Join-Path $env:USERPROFILE '.claude\hooks\spec-coverage-gate.sh').Replace('\', '/')

$tmpPy = [System.IO.Path]::GetTempFileName() + '.py'
Set-Content -Path $tmpPy -Value $mergeScript -Encoding utf8
try {
    $out = & $pythonExe $tmpPy $SettingsPath $HookCmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Не удалось обновить settings.json: $out"
        exit 1
    }
    Write-Ok "settings.json обновлён → $SettingsPath"
} finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $tmpPy
}

# --- Финал ---------------------------------------------------------------
Write-Host "`n================================================================" -ForegroundColor Green
Write-Host '  HOOK УСТАНОВЛЕН' -ForegroundColor Green
Write-Host "================================================================`n" -ForegroundColor Green
Write-Host '  Что теперь происходит:' -ForegroundColor White
Write-Host '    При записи в **/specs/**/*.md — hook проверит что все упомянутые' -ForegroundColor DarkGray
Write-Host '    PHP-классы / DTO / миграции были прочитаны в текущей сессии.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Перезапусти Claude Code чтобы settings.json подхватился.' -ForegroundColor White
Write-Host ''
Write-Host '  Тест:' -ForegroundColor White
Write-Host "    py $HooksSrc\tests\test_synthetic.py" -ForegroundColor DarkGray
Write-Host ''
