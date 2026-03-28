#!/bin/bash
# digitana-starter setup script
# Installs a cognitive AI assistant with persistent identity and memory
# Works with Claude Code (full experience) + Cursor/Aider (basic)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/assistant.json"
STARTER_HOME="$HOME/.digitana-starter"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   digitana-starter — setup wizard    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# --- Step 1: Configure assistant identity ---

if [ -f "$CONFIG_FILE" ]; then
  ASSISTANT_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['assistant_name'])" 2>/dev/null)
  USER_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['user_name'])" 2>/dev/null)
  echo -e "Found existing config: ${GREEN}$ASSISTANT_NAME${NC} for ${GREEN}$USER_NAME${NC}"
  read -p "Use this config? (Y/n): " USE_EXISTING
  if [[ "$USE_EXISTING" =~ ^[Nn] ]]; then
    rm "$CONFIG_FILE"
  fi
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Let's set up your assistant."
  echo ""

  read -p "Assistant name (default: Atlas): " INPUT_NAME
  ASSISTANT_NAME="${INPUT_NAME:-Atlas}"

  read -p "Your name: " USER_NAME
  if [ -z "$USER_NAME" ]; then
    echo "Error: Your name is required."
    exit 1
  fi

  read -p "Assistant personality (default: direct, warm, proactive, structured, honest): " INPUT_PERSONALITY
  PERSONALITY="${INPUT_PERSONALITY:-direct, warm, proactive, structured, honest}"

  read -p "Purpose (default: Enhance your capabilities and optimize your workflow): " INPUT_PURPOSE
  PURPOSE="${INPUT_PURPOSE:-Enhance your capabilities and optimize your workflow}"

  read -p "Communication language (default: en): " INPUT_LANG
  LANGUAGE="${INPUT_LANG:-en}"

  read -p "Code language (default: en): " INPUT_CODE_LANG
  CODE_LANGUAGE="${INPUT_CODE_LANG:-en}"

  echo ""
  echo "Autonomy level:"
  echo "  1) Conservative — asks before most actions"
  echo "  2) Balanced — acts on safe things, asks for risky ones (recommended)"
  echo "  3) Autonomous — acts on most things, asks only for destructive ops"
  read -p "Choose (1/2/3, default: 2): " INPUT_AUTONOMY
  case "$INPUT_AUTONOMY" in
    1) AUTONOMY="conservative" ;;
    3) AUTONOMY="autonomous" ;;
    *) AUTONOMY="balanced" ;;
  esac

  # Save config
  cat > "$CONFIG_FILE" << EOF
{
  "assistant_name": "$ASSISTANT_NAME",
  "user_name": "$USER_NAME",
  "personality": "$PERSONALITY",
  "purpose": "$PURPOSE",
  "language": "$LANGUAGE",
  "code_language": "$CODE_LANGUAGE",
  "autonomy": "$AUTONOMY"
}
EOF

  echo -e "${GREEN}Config saved.${NC}"
else
  # Read existing config
  PERSONALITY=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['personality'])" 2>/dev/null)
  PURPOSE=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['purpose'])" 2>/dev/null)
  LANGUAGE=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['language'])" 2>/dev/null)
  CODE_LANGUAGE=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['code_language'])" 2>/dev/null)
  AUTONOMY=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['autonomy'])" 2>/dev/null)
fi

TODAY=$(date +%Y-%m-%d)

# --- Step 2: Create starter home directory ---

echo ""
echo "Creating $STARTER_HOME..."
mkdir -p "$STARTER_HOME"/{sessions,state}
cp "$CONFIG_FILE" "$STARTER_HOME/assistant.json"

# --- Step 3: Process templates ---

process_template() {
  local input="$1"
  local output="$2"

  python3 -c "
import re, sys

with open('$input') as f:
    content = f.read()

# Replace variables
replacements = {
    '{{ASSISTANT_NAME}}': '''$ASSISTANT_NAME''',
    '{{USER_NAME}}': '''$USER_NAME''',
    '{{PERSONALITY}}': '''$PERSONALITY''',
    '{{PURPOSE}}': '''$PURPOSE''',
    '{{LANGUAGE}}': '''$LANGUAGE''',
    '{{CODE_LANGUAGE}}': '''$CODE_LANGUAGE''',
    '{{TODAY}}': '''$TODAY''',
}
for key, val in replacements.items():
    content = content.replace(key, val)

# Handle conditionals: keep matching autonomy, remove others
autonomy = '$AUTONOMY'
# Find all conditional blocks
pattern = r'\{\{#if (autonomy_\w+)\}\}\n(.*?)\{\{/if\}\}'
def replace_conditional(match):
    condition = match.group(1)
    body = match.group(2)
    if condition == f'autonomy_{autonomy}':
        return body.rstrip('\n')
    return ''

content = re.sub(pattern, replace_conditional, content, flags=re.DOTALL)

# Clean up extra blank lines
content = re.sub(r'\n{3,}', '\n\n', content)

with open('$output', 'w') as f:
    f.write(content)
"
}

# --- Step 4: Install for Claude Code ---

CLAUDE_DIR="$HOME/.claude"
if [ -d "$CLAUDE_DIR" ]; then
  echo ""
  echo -e "${GREEN}Claude Code detected.${NC} Installing full experience..."

  # Backup existing CLAUDE.md
  if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup-$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Backed up existing CLAUDE.md${NC}"
  fi

  # Generate CLAUDE.md
  process_template "$SCRIPT_DIR/config/claude-md.template" "$CLAUDE_DIR/CLAUDE.md"
  echo "  CLAUDE.md installed"

  # Install hooks
  HOOKS_DIR="$STARTER_HOME/hooks"
  mkdir -p "$HOOKS_DIR"
  cp "$SCRIPT_DIR/hooks/"*.sh "$HOOKS_DIR/"
  chmod +x "$HOOKS_DIR/"*.sh
  echo "  Hooks installed"

  # Configure settings.json with hooks
  SETTINGS_FILE="$CLAUDE_DIR/settings.json"
  if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$CLAUDE_DIR/settings.json.backup-$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Backed up existing settings.json${NC}"
  fi

  # Generate settings.json preserving existing permissions
  EXISTING_ALLOW="[]"
  EXISTING_DENY="[]"
  if [ -f "$SETTINGS_FILE" ]; then
    EXISTING_ALLOW=$(python3 -c "
import json
try:
    d = json.load(open('$SETTINGS_FILE'))
    print(json.dumps(d.get('permissions',{}).get('allow',[])))
except: print('[]')
" 2>/dev/null)
    EXISTING_DENY=$(python3 -c "
import json
try:
    d = json.load(open('$SETTINGS_FILE'))
    print(json.dumps(d.get('permissions',{}).get('deny',[])))
except: print('[]')
" 2>/dev/null)
  fi

  python3 -c "
import json

settings = {
  'permissions': {
    'allow': json.loads('$EXISTING_ALLOW'),
    'deny': json.loads('$EXISTING_DENY')
  },
  'hooks': {
    'SessionStart': [{'hooks': [{'type': 'command', 'command': '$HOOKS_DIR/session-start.sh', 'timeout': 10000}]}],
    'SessionEnd': [{'hooks': [{'type': 'command', 'command': '$HOOKS_DIR/session-end.sh', 'timeout': 10000}]}],
    'Stop': [{'hooks': [{'type': 'command', 'command': '$HOOKS_DIR/stop-checkpoint.sh', 'timeout': 5000}]}],
    'UserPromptSubmit': [{'hooks': [{'type': 'command', 'command': '$HOOKS_DIR/interaction-counter.sh', 'timeout': 3000}]}],
    'PreCompact': [{'hooks': [{'type': 'command', 'command': '$HOOKS_DIR/pre-compact.sh', 'timeout': 5000}]}]
  }
}

with open('$SETTINGS_FILE', 'w') as f:
  json.dump(settings, f, indent=2)
" 2>/dev/null
  echo "  settings.json configured with hooks"

  # Set up memory directory
  # Use the home directory project scope
  MEMORY_DIR="$CLAUDE_DIR/projects/-Users-$(whoami)/memory"
  mkdir -p "$MEMORY_DIR"

  if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
    process_template "$SCRIPT_DIR/memory/MEMORY.md.template" "$MEMORY_DIR/MEMORY.md"
    echo "  MEMORY.md created"
  else
    echo -e "  ${YELLOW}MEMORY.md already exists, skipping${NC}"
  fi

  if [ ! -f "$MEMORY_DIR/soul.md" ]; then
    process_template "$SCRIPT_DIR/memory/soul.md.template" "$MEMORY_DIR/soul.md"
    echo "  soul.md created"
  else
    echo -e "  ${YELLOW}soul.md already exists, skipping${NC}"
  fi

  echo -e "${GREEN}Claude Code setup complete!${NC}"
else
  echo ""
  echo -e "${YELLOW}Claude Code not detected. Skipping Claude Code setup.${NC}"
  echo "Install Claude Code (https://claude.ai/claude-code) and run this script again for the full experience."
fi

# --- Step 5: Install for Cursor (optional) ---

if command -v cursor &> /dev/null || [ -d "$HOME/.cursor" ]; then
  echo ""
  read -p "Cursor detected. Generate .cursorrules? (Y/n): " INSTALL_CURSOR
  if [[ ! "$INSTALL_CURSOR" =~ ^[Nn] ]]; then
    process_template "$SCRIPT_DIR/config/claude-md.template" "$HOME/.cursorrules"
    echo -e "${GREEN}.cursorrules installed${NC}"
  fi
fi

# --- Step 6: Generate dashboard ---

echo ""
echo "Generating dashboard..."
cp "$SCRIPT_DIR/dashboard/index.html" "$STARTER_HOME/dashboard.html"
cp "$SCRIPT_DIR/dashboard/generate-dashboard.sh" "$STARTER_HOME/generate-dashboard.sh"
chmod +x "$STARTER_HOME/generate-dashboard.sh"
# Generate initial state for dashboard
python3 -c "
import json, os
from datetime import datetime

config = json.load(open('$CONFIG_FILE'))
state = {
  'assistant_name': config['assistant_name'],
  'user_name': config['user_name'],
  'config': {
    'purpose': config.get('purpose', ''),
    'personality': config.get('personality', '')
  },
  'installed_at': datetime.now().isoformat(),
  'sessions': [],
  'memory_files': []
}

# Count memory files if they exist
memory_dir = os.path.join(os.environ['HOME'], '.claude/projects/-Users-' + os.environ.get('USER','user') + '/memory')
if os.path.isdir(memory_dir):
  for f in sorted(os.listdir(memory_dir)):
    if f.endswith('.md'):
      state['memory_files'].append(f)

with open(os.path.join('$STARTER_HOME', 'state.json'), 'w') as f:
  json.dump(state, f, indent=2)
" 2>/dev/null || true
echo -e "  Dashboard at: ${CYAN}$STARTER_HOME/dashboard.html${NC}"

# --- Done ---

echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Setup complete!                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "Your assistant ${CYAN}$ASSISTANT_NAME${NC} is ready."
echo ""
echo "Next steps:"
echo "  1. Open a new terminal and run: claude"
echo "  2. $ASSISTANT_NAME will greet you with awareness of its identity"
echo "  3. Tell it about yourself — it will remember across sessions"
echo ""
echo "Files installed:"
echo "  ~/.claude/CLAUDE.md          — assistant instructions"
echo "  ~/.claude/settings.json      — hooks configuration"
echo "  ~/.digitana-starter/         — hooks, state, dashboard"
echo ""
echo "To open the dashboard:"
echo "  open $STARTER_HOME/dashboard.html"
echo ""
echo "To uninstall:"
echo "  bash $SCRIPT_DIR/uninstall.sh"
