#!/usr/bin/env bash
# spec-coverage-gate hook installer (Mac/Linux).
#
# Копирует скрипты из installer/hooks/ в ~/.claude/hooks/ и регистрирует
# PreToolUse-matcher в ~/.claude/settings.json.
#
# Запуск из корня клонированного репо payfin-mcp:
#     ./installer/install-hook.sh

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
GREY='\033[0;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'

step() { printf "\n${CYAN}==> %s${NC}\n" "$1"; }
ok()   { printf "    ${GREEN}[OK]${NC} %s\n" "$1"; }
warn() { printf "    ${YELLOW}[WARN]${NC} %s\n" "$1"; }
err()  { printf "    ${RED}[ERR]${NC} %s\n" "$1"; }

cat <<EOF

${MAGENTA}================================================================
  spec-coverage-gate — установка PreToolUse hook
================================================================${NC}
EOF

# --- Проверки -----------------------------------------------------------
step "Проверяю окружение"

if command -v python3 >/dev/null 2>&1; then
    PY=python3
elif command -v python >/dev/null 2>&1; then
    PY=python
else
    err "Python не найден. Установи Python 3.8+ и повтори."
    exit 1
fi
ok "Python: $($PY --version 2>&1)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SRC="$SCRIPT_DIR/hooks"
if [ ! -d "$HOOKS_SRC" ]; then
    err "Не нашёл папку $HOOKS_SRC. Запусти из корня клона payfin-mcp."
    exit 1
fi
ok "Hooks source: $HOOKS_SRC"

# --- Копирование --------------------------------------------------------
step "Копирую файлы хука"

HOOKS_DEST="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DEST"

for f in spec-coverage-gate.sh spec-coverage-gate.py spec-coverage.config.json; do
    cp "$HOOKS_SRC/$f" "$HOOKS_DEST/$f"
    ok "$f"
done
chmod +x "$HOOKS_DEST/spec-coverage-gate.sh"
ok "executable bit set on .sh"

# --- Регистрация в settings.json ----------------------------------------
step "Регистрирую hook в ~/.claude/settings.json"

SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="$HOOKS_DEST/spec-coverage-gate.sh"

TMP_PY="$(mktemp -t spec-gate-merge.XXXXXX).py"
cat > "$TMP_PY" <<'PYEOF'
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
    already = any(h.get('command') == hook_cmd for h in existing['hooks'])
    if not already:
        existing['hooks'].append(new_hook)

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print('OK')
PYEOF

if "$PY" "$TMP_PY" "$SETTINGS" "$HOOK_CMD"; then
    ok "settings.json обновлён → $SETTINGS"
else
    err "Не удалось обновить settings.json"
    rm -f "$TMP_PY"
    exit 1
fi

rm -f "$TMP_PY"

# --- Финал --------------------------------------------------------------
cat <<EOF

${GREEN}================================================================
  HOOK УСТАНОВЛЕН
================================================================${NC}

  Что теперь происходит:
    При записи в **/specs/**/*.md — hook проверит что все упомянутые
    PHP-классы / DTO / миграции были прочитаны в текущей сессии.

  Перезапусти Claude Code чтобы settings.json подхватился.

  Тест:
    $PY $HOOKS_SRC/tests/test_synthetic.py

EOF
