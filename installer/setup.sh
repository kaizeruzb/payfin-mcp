#!/usr/bin/env bash
# PayFin MCP — bootstrap installer (Mac / Linux / WSL).
# Запуск: curl -fsSL https://payfin-installer-production.up.railway.app/setup.sh | bash

set -e

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
step() { printf "\n${CYAN}==> %s${NC}\n" "$1"; }
ok()   { printf "    ${GREEN}[OK] %s${NC}\n" "$1"; }
warn() { printf "    ${YELLOW}[WARN] %s${NC}\n" "$1"; }
err()  { printf "    ${RED}[ERR] %s${NC}\n" "$1"; }

need() { command -v "$1" >/dev/null 2>&1; }

read_required() {
  local prompt="$1" hint="$2" v
  while true; do
    [ -n "$hint" ] && printf "    %s\n" "$hint"
    read -r -p "    $prompt: " v
    [ -n "$v" ] && { echo "$v"; return; }
    err 'Значение не может быть пустым.'
  done
}

read_choice() {
  local prompt="$1" default="$2"; shift 2
  local opts=("$@") hint="[$(IFS=/; echo "${opts[*]}")], Enter = $default" v
  while true; do
    read -r -p "    $prompt $hint: " v
    [ -z "$v" ] && { echo "$default"; return; }
    for o in "${opts[@]}"; do [ "$o" = "$v" ] && { echo "$v"; return; }; done
    err "Выбери одно из: ${opts[*]}"
  done
}

cat <<'BANNER'

================================================================
  PayFin MCP installer
  Подключит 4 MCP-сервера: payfin-kb, payfin-code, gitlab, atlassian
================================================================
BANNER

step 'Проверяю окружение'
need node || { err 'Node.js не найден. Установи 20+: https://nodejs.org'; exit 1; }
node_ver=$(node -v | sed 's/v//'); node_major=${node_ver%%.*}
[ "$node_major" -lt 20 ] && { err "Node.js $node_ver слишком старый. Нужен 20+."; exit 1; }
ok "Node.js $node_ver"

need claude || { err 'Claude Code CLI не найден.'; exit 1; }; ok 'Claude Code CLI'
need git || { err 'git не найден.'; exit 1; }; ok 'git'

if ! need uv; then
  warn 'uv не найден, устанавливаю...'
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  need uv || { err 'uv так и не появился в PATH'; exit 1; }
fi
ok 'uv'

step 'Проверяю доступ к git.ipoint.uz (нужен VPN)'
if curl -sSf -m 5 -I https://git.ipoint.uz >/dev/null 2>&1; then
  ok 'VPN работает'
else
  warn 'git.ipoint.uz недоступен. Проверь VPN.'
  read -r -p '    Продолжить? [y/N]: ' c
  [ "$c" = "y" ] || [ "$c" = "Y" ] || exit 1
fi

step 'Собираю токены (4 шт.) + роль'
KB_TOKEN=$(read_required 'KB_TOKEN' '1/4 KB_TOKEN (pfk_xxx, получить у Sardorbek)')
GITLAB_TOKEN=$(read_required 'GITLAB_TOKEN' '2/4 GITLAB_TOKEN (git.ipoint.uz -> Access Tokens, scope: read_api, read_repository)')
CONFLUENCE_PAT=$(read_required 'CONFLUENCE_PAT' '3/4 CONFLUENCE_PAT (wiki.ipoint.uz -> Personal Access Tokens)')
JIRA_PAT=$(read_required 'JIRA_PAT' '4/4 JIRA_PAT (jira.ipoint.uz -> Personal Access Tokens)')
AGENT_ROLE=$(read_choice 'AGENT_ROLE' 'developer' pm analyst developer tech-lead qa admin)

step 'Удаляю старые регистрации MCP'
for n in payfin-kb payfin-code gitlab atlassian; do claude mcp remove "$n" 2>/dev/null || true; done
ok 'Готово'

step 'Регистрирую MCP серверы в Claude Code'

claude mcp add payfin-kb --transport http \
  --header "Authorization=Bearer $KB_TOKEN" \
  'https://practical-generosity-production-cb1c.up.railway.app/mcp' && ok 'payfin-kb' || { err 'payfin-kb'; exit 1; }

claude mcp add payfin-code \
  -e GITLAB_URL='https://git.ipoint.uz' \
  -e GITLAB_TOKEN="$GITLAB_TOKEN" \
  -e REPOS='broker-api:broker/backend/broker-api,nasiya-api:nasiya/backend/nasiya-api' \
  -e AGENT_ROLE="$AGENT_ROLE" \
  -- npx -y payfin-mcp-code@beta && ok 'payfin-code' || { err 'payfin-code'; exit 1; }

claude mcp add gitlab \
  -e GITLAB_API_URL='https://git.ipoint.uz/api/v4' \
  -e GITLAB_PERSONAL_ACCESS_TOKEN="$GITLAB_TOKEN" \
  -- npx -y '@zereight/mcp-gitlab' && ok 'gitlab' || { err 'gitlab'; exit 1; }

claude mcp add atlassian \
  -e CONFLUENCE_URL='https://wiki.ipoint.uz' \
  -e JIRA_URL='https://jira.ipoint.uz' \
  -e CONFLUENCE_PERSONAL_TOKEN="$CONFLUENCE_PAT" \
  -e JIRA_PERSONAL_TOKEN="$JIRA_PAT" \
  -- uvx mcp-atlassian && ok 'atlassian' || { err 'atlassian'; exit 1; }

cat <<'DONE'

================================================================
  ВСЁ ГОТОВО
================================================================
  Дальше:
    1. Перезапусти Claude Code
    2. Проверь: claude mcp list
    3. В любом чате попроси: "Покажи composer.json из broker-api"

DONE
