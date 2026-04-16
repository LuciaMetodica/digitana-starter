#!/bin/bash
# Post-installation verification
set -uo pipefail
EXPRESS_DIR="$HOME/.claude/express"
source "$EXPRESS_DIR/lib/notion-api.sh" 2>/dev/null
[ -f "$EXPRESS_DIR/.env" ] && export NOTION_API_TOKEN=$(grep '^NOTION_API_TOKEN=' "$EXPRESS_DIR/.env" | cut -d= -f2-)

ERRORS=0
TOTAL=0

check() {
  TOTAL=$((TOTAL + 1))
  if eval "$1" 2>/dev/null; then
    echo "  ✓ $2"
  else
    echo "  ✗ $2"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "Verificando instalacion Digitana Express..."
echo ""

echo "Archivos:"
check "[ -f $HOME/.claude/CLAUDE.md ]" "CLAUDE.md"
check "[ -f $EXPRESS_DIR/.env ]" ".env (token)"
check "[ -f $EXPRESS_DIR/lib/notion-api.sh ]" "notion-api.sh"
check "[ -f $EXPRESS_DIR/lib/notion-ids.json ]" "notion-ids.json"
check "[ -f $EXPRESS_DIR/business-profile.json ]" "business-profile.json"

echo ""
echo "Scripts:"
check "[ -x $EXPRESS_DIR/scripts/session-start.sh ]" "session-start.sh"
check "[ -x $EXPRESS_DIR/scripts/session-end.sh ]" "session-end.sh"
check "[ -x $EXPRESS_DIR/scripts/interaction-counter.sh ]" "interaction-counter.sh"
check "[ -x $EXPRESS_DIR/scripts/energy-set.sh ]" "energy-set.sh"

echo ""
echo "Skills:"
check "[ -f $HOME/.claude/skills/tareas/SKILL.md ]" "tareas"
check "[ -f $HOME/.claude/skills/notas/SKILL.md ]" "notas"
check "[ -f $HOME/.claude/skills/briefing/SKILL.md ]" "briefing"
check "[ -f $HOME/.claude/skills/contenido/SKILL.md ]" "contenido"

echo ""
echo "Hooks:"
check "python3 -c \"import json; d=json.load(open('$HOME/.claude/settings.json')); assert 'SessionStart' in d.get('hooks',{})\"" "SessionStart"
check "python3 -c \"import json; d=json.load(open('$HOME/.claude/settings.json')); assert 'SessionEnd' in d.get('hooks',{})\"" "SessionEnd"

echo ""
echo "Conexion:"
check "command -v claude" "Claude Code CLI"
check "command -v node" "Node.js"

if [ -n "${NOTION_API_TOKEN:-}" ]; then
  check "notion_req GET users/me 2>/dev/null | python3 -c 'import sys,json; assert json.load(sys.stdin).get(\"object\")'" "Notion API"

  SESIONES_DB=$(jq -r '.databases.sesiones' "$EXPRESS_DIR/lib/notion-ids.json" 2>/dev/null)
  if [ -n "$SESIONES_DB" ] && [ "$SESIONES_DB" != "null" ]; then
    check "notion_req GET databases/$SESIONES_DB 2>/dev/null | python3 -c 'import sys,json; assert json.load(sys.stdin).get(\"id\")'" "BD Sesiones"
  fi
fi

echo ""
echo "Resultado: $((TOTAL - ERRORS))/$TOTAL OK"
[ "$ERRORS" -eq 0 ] && echo "Todo listo!" || echo "$ERRORS errores encontrados."
exit $ERRORS
