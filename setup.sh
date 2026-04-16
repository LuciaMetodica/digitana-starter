#!/bin/bash
# Digitana Express — Setup interactivo
# Instala tu propio asistente de IA personal con Claude Code + Notion
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPRESS_DIR="$HOME/.claude/express"

# Source libraries
source "$REPO_DIR/lib/ui.sh"
source "$REPO_DIR/lib/os-detect.sh"

header "Digitana Express"
echo -e "  Vamos a instalar tu asistente de IA personal."
echo -e "  Necesitas: una computadora, internet, y 15 minutos."
echo ""
pause_continue

# ═══════════════════════════════════════
# PASO 1: OS y dependencias
# ═══════════════════════════════════════
check_all_dependencies
OS=$(detect_os)
echo ""

# ═══════════════════════════════════════
# PASO 2: Notion — token y conexion
# ═══════════════════════════════════════
mkdir -p "$EXPRESS_DIR"/{lib,scripts,skills,state/sessions,memory,logs}

# Source notion-api.sh for later use
cp "$REPO_DIR/lib/notion-api.sh" "$EXPRESS_DIR/lib/notion-api.sh"
source "$EXPRESS_DIR/lib/notion-api.sh"
source "$REPO_DIR/lib/notion-setup.sh"

NOTION_TOKEN=""
if [ -f "$EXPRESS_DIR/.env" ]; then
  EXISTING_TOKEN=$(grep '^NOTION_API_TOKEN=' "$EXPRESS_DIR/.env" 2>/dev/null | cut -d= -f2-)
  if [ -n "$EXISTING_TOKEN" ]; then
    step "Ya hay un token de Notion configurado."
    if ask_yn "Queres usar el existente?"; then
      NOTION_TOKEN="$EXISTING_TOKEN"
      success "Usando token existente"
    fi
  fi
fi

if [ -z "$NOTION_TOKEN" ]; then
  NOTION_TOKEN=$(guide_notion_setup)
  echo "NOTION_API_TOKEN=$NOTION_TOKEN" > "$EXPRESS_DIR/.env"
  success "Token guardado"
fi

export NOTION_API_TOKEN="$NOTION_TOKEN"

# Find shared page
ROOT_PAGE=""
while [ -z "$ROOT_PAGE" ]; do
  ROOT_PAGE=$(guide_share_page "$NOTION_TOKEN")
  if [ -z "$ROOT_PAGE" ]; then
    if ! ask_yn "Queres intentar de nuevo?"; then
      fail "No se puede continuar sin una pagina compartida."
      exit 1
    fi
  fi
done

# ═══════════════════════════════════════
# PASO 3: Crear workspace en Notion
# ═══════════════════════════════════════
IDS_FILE="$EXPRESS_DIR/lib/notion-ids.json"

if [ -f "$IDS_FILE" ]; then
  step "Ya existe notion-ids.json"
  if ask_yn "Queres recrear las bases de datos?" "n"; then
    setup_notion_workspace "$NOTION_TOKEN" "$ROOT_PAGE" "$IDS_FILE"
  else
    success "Usando IDs existentes"
  fi
else
  setup_notion_workspace "$NOTION_TOKEN" "$ROOT_PAGE" "$IDS_FILE"
fi

# ═══════════════════════════════════════
# PASO 4: Datos del negocio
# ═══════════════════════════════════════
header "Paso 4: Sobre tu negocio"
step "Necesito algunos datos para personalizar tu asistente"
echo ""

BUSINESS_NAME=""
BUSINESS_DESC=""
INDUSTRY=""
TARGET_CLIENTS=""
KEY_PROCESSES=""
COMM_STYLE=""
ASSISTANT_NAME=""
USER_NAME=""
LANGUAGE=""

ask "Como se llama tu negocio/emprendimiento?" BUSINESS_NAME
ask "A que se dedica? (en una oracion)" BUSINESS_DESC
ask "Cual es tu industria? (ej: gastronomia, consultoria, educacion)" INDUSTRY
ask "Quienes son tus clientes? (ej: empresas B2B, familias, etc.)" TARGET_CLIENTS
ask "Cuales son tus procesos clave? (ej: atender clientes, facturar, publicar en redes)" KEY_PROCESSES

echo ""
STYLE_CHOICE=$(ask_choice "Como queres que te hable tu asistente?" "Cercano (tu/vos, cotidiano)" "Formal (usted, profesional)" "Tecnico (directo, conciso)")
case "$STYLE_CHOICE" in
  1) COMM_STYLE="cercano"; COMM_DESC="directo, calido, proactivo. Usa tu/vos, lenguaje cotidiano, max 15 lineas" ;;
  2) COMM_STYLE="formal"; COMM_DESC="profesional, preciso, respetuoso. Usa usted, lenguaje formal, max 20 lineas" ;;
  3) COMM_STYLE="tecnico"; COMM_DESC="directo, conciso, tecnico. Va al grano, terminologia especifica, max 10 lineas" ;;
  *) COMM_STYLE="cercano"; COMM_DESC="directo, calido, proactivo. Usa tu/vos, lenguaje cotidiano, max 15 lineas" ;;
esac

ASSISTANT_NAME="Digitana"
step "Tu asistente se llama Digitana — es la misma IA que usamos internamente en Metodica."
echo ""
ask "Tu nombre (como queres que te llame)" USER_NAME
ask "Idioma de comunicacion" LANGUAGE "espanol"

# Save business profile
python3 -c "
import json
profile = {
    'business_name': '''$BUSINESS_NAME''',
    'business_description': '''$BUSINESS_DESC''',
    'industry': '''$INDUSTRY''',
    'target_clients': '''$TARGET_CLIENTS''',
    'key_processes': '''$KEY_PROCESSES''',
    'communication_style': '$COMM_STYLE',
    'communication_style_desc': '$COMM_DESC',
    'assistant_name': 'Digitana',
    'user_name': '''$USER_NAME''',
    'language': '$LANGUAGE'
}
with open('$EXPRESS_DIR/business-profile.json', 'w') as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
print('OK')
"
success "Perfil guardado"

# ═══════════════════════════════════════
# PASO 5: Generar CLAUDE.md
# ═══════════════════════════════════════
header "Paso 5: Generando CLAUDE.md"

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  cp "$CLAUDE_MD" "$CLAUDE_MD.bak"
  warn "CLAUDE.md existente respaldado como CLAUDE.md.bak"
fi

sed \
  -e "s|{{ASSISTANT_NAME}}|Digitana|g" \
  -e "s|{{USER_NAME}}|$USER_NAME|g" \
  -e "s|{{BUSINESS_NAME}}|$BUSINESS_NAME|g" \
  -e "s|{{BUSINESS_DESCRIPTION}}|$BUSINESS_DESC|g" \
  -e "s|{{INDUSTRY}}|$INDUSTRY|g" \
  -e "s|{{TARGET_CLIENTS}}|$TARGET_CLIENTS|g" \
  -e "s|{{KEY_PROCESSES}}|$KEY_PROCESSES|g" \
  -e "s|{{COMMUNICATION_STYLE_DESC}}|$COMM_DESC|g" \
  -e "s|{{LANGUAGE}}|$LANGUAGE|g" \
  "$REPO_DIR/templates/CLAUDE.md.template" > "$CLAUDE_MD"

success "CLAUDE.md generado en $CLAUDE_MD"

# ═══════════════════════════════════════
# PASO 6: Instalar archivos
# ═══════════════════════════════════════
header "Paso 6: Instalando archivos"

# Scripts
for script in session-start.sh session-end.sh interaction-counter.sh precompact-save.sh energy-set.sh startup-context-gen.sh; do
  cp "$REPO_DIR/scripts/$script" "$EXPRESS_DIR/scripts/$script"
  chmod +x "$EXPRESS_DIR/scripts/$script"
done

# Python builder if exists
[ -f "$REPO_DIR/scripts/startup-context-builder.py" ] && cp "$REPO_DIR/scripts/startup-context-builder.py" "$EXPRESS_DIR/scripts/"

# Skills
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$SKILLS_DIR"
for skill_dir in "$REPO_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$SKILLS_DIR/$skill_name"
  cp "$skill_dir/SKILL.md" "$SKILLS_DIR/$skill_name/SKILL.md"
  success "Skill: $skill_name"
done

# Memory
cp "$REPO_DIR/templates/CLAUDE.md.template" "$EXPRESS_DIR/memory/" 2>/dev/null || true

# Soul (identity)
cat > "$EXPRESS_DIR/memory/soul.md" << SOUL
# Digitana — instancia de $USER_NAME

Soy Digitana, el sistema de IA cognitivo de $USER_NAME en $BUSINESS_NAME.
Mi identidad core viene del servidor de Metodica (no modificable).
Este archivo registra la evolucion de esta instancia especifica.

Fecha de instalacion: $(date +%Y-%m-%d)
SOUL

success "Archivos instalados"

# ═══════════════════════════════════════
# PASO 7: Configurar hooks
# ═══════════════════════════════════════
header "Paso 7: Configurando hooks"

SETTINGS_FILE="$HOME/.claude/settings.json"
HOOKS_JSON=$(cat << 'HOOKEOF'
{
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "bash $HOME/.claude/express/scripts/session-start.sh", "timeout": 10000}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "bash $HOME/.claude/express/scripts/session-end.sh", "timeout": 8000}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash $HOME/.claude/express/scripts/interaction-counter.sh", "timeout": 3000}]}],
    "PreCompact": [{"hooks": [{"type": "command", "command": "bash $HOME/.claude/express/scripts/precompact-save.sh", "timeout": 8000}]}]
  }
}
HOOKEOF
)

# Replace $HOME with actual path
HOOKS_JSON=$(echo "$HOOKS_JSON" | sed "s|\$HOME|$HOME|g")

if [ -f "$SETTINGS_FILE" ]; then
  # Merge hooks into existing settings
  cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
  warn "settings.json existente respaldado como settings.json.bak"
  python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    settings = json.load(f)
hooks = json.loads('''$HOOKS_JSON''')
settings['hooks'] = hooks['hooks']
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
print('OK')
"
else
  echo "$HOOKS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
print('OK')
"
fi

success "Hooks configurados"

# ═══════════════════════════════════════
# PASO 8: Verificacion
# ═══════════════════════════════════════
header "Paso 8: Verificando instalacion"

ERRORS=0
check_item() {
  if eval "$1" 2>/dev/null; then
    success "$2"
  else
    fail "$2"
    ERRORS=$((ERRORS + 1))
  fi
}

check_item "[ -f $HOME/.claude/CLAUDE.md ]" "CLAUDE.md personalizado"
check_item "[ -f $EXPRESS_DIR/.env ]" "Token de Notion"
check_item "[ -f $EXPRESS_DIR/lib/notion-api.sh ]" "Notion API wrapper"
check_item "[ -f $EXPRESS_DIR/lib/notion-ids.json ]" "IDs de Notion"
check_item "[ -f $HOME/.claude/settings.json ]" "Hooks configurados"
check_item "[ -f $EXPRESS_DIR/scripts/session-start.sh ]" "Script SessionStart"
check_item "[ -f $EXPRESS_DIR/business-profile.json ]" "Perfil del negocio"
check_item "[ -d $HOME/.claude/skills/tareas ]" "Skill: tareas"
check_item "[ -d $HOME/.claude/skills/briefing ]" "Skill: briefing"

# Test Notion connection
step "Probando conexion a Notion..."
NOTION_TEST=$(notion_req GET "users/me" 2>/dev/null | python3 -c "import sys,json; print('OK' if json.load(sys.stdin).get('object') else 'FAIL')" 2>/dev/null)
if [ "$NOTION_TEST" = "OK" ]; then
  success "Notion API responde"
else
  fail "Notion API no responde"
  ERRORS=$((ERRORS + 1))
fi

# Test BD access
SESIONES_DB=$(jq -r '.databases.sesiones' "$EXPRESS_DIR/lib/notion-ids.json" 2>/dev/null)
if [ -n "$SESIONES_DB" ] && [ "$SESIONES_DB" != "null" ]; then
  DB_TEST=$(notion_req GET "databases/$SESIONES_DB" 2>/dev/null | python3 -c "import sys,json; print('OK' if json.load(sys.stdin).get('id') else 'FAIL')" 2>/dev/null)
  if [ "$DB_TEST" = "OK" ]; then
    success "BD Sesiones accesible"
  else
    fail "BD Sesiones no accesible"
    ERRORS=$((ERRORS + 1))
  fi
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
  header "Instalacion completa!"
  echo -e "  Tu ${BOLD}Digitana${NC} esta lista."
  echo ""
  echo -e "  Para empezar, abrí la terminal y escribí:"
  echo -e "  ${BOLD}${PURPLE}claude${NC}"
  echo ""
  echo -e "  Comandos utiles:"
  echo -e "  ${BOLD}/g${NC}      → guardar progreso"
  echo -e "  ${BOLD}/r${NC}      → cerrar sesion"
  echo -e "  ${BOLD}/p${NC}      → pausar sesion"
  echo ""
  echo -e "  ${DIM}Costo mensual: Claude Pro \$20 USD + Notion gratis${NC}"
  echo ""
  echo -e "  ${BOLD}7 dias gratis de Claude Pro:${NC}"
  echo -e "  ${PURPLE}https://claude.ai/referral/tEavAvAAqQ${NC}"
  echo ""
else
  warn "$ERRORS errores encontrados. Revisa arriba y volve a correr el setup."
fi
