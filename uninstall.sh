#!/bin/bash
# digitana-starter uninstaller
# Restores backups and removes installed files

set -e

STARTER_HOME="$HOME/.digitana-starter"
CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo -e "${RED}Uninstalling digitana-starter...${NC}"
echo ""

# Restore CLAUDE.md backup
LATEST_BACKUP=$(ls -t "$CLAUDE_DIR"/CLAUDE.md.backup-* 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CLAUDE_DIR/CLAUDE.md"
  echo "  Restored CLAUDE.md from backup"
else
  rm -f "$CLAUDE_DIR/CLAUDE.md"
  echo "  Removed CLAUDE.md (no backup found)"
fi

# Restore settings.json backup
LATEST_SETTINGS=$(ls -t "$CLAUDE_DIR"/settings.json.backup-* 2>/dev/null | head -1)
if [ -n "$LATEST_SETTINGS" ]; then
  cp "$LATEST_SETTINGS" "$CLAUDE_DIR/settings.json"
  echo "  Restored settings.json from backup"
else
  rm -f "$CLAUDE_DIR/settings.json"
  echo "  Removed settings.json (no backup found)"
fi

# Remove starter home
if [ -d "$STARTER_HOME" ]; then
  rm -rf "$STARTER_HOME"
  echo "  Removed $STARTER_HOME"
fi

# Remove .cursorrules if it was ours
if [ -f "$HOME/.cursorrules" ]; then
  read -p "  Remove ~/.cursorrules? (y/N): " REMOVE_CURSOR
  if [[ "$REMOVE_CURSOR" =~ ^[Yy] ]]; then
    rm -f "$HOME/.cursorrules"
    echo "  Removed .cursorrules"
  fi
fi

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
echo "Note: Memory files in ~/.claude/projects/ were NOT removed (your data is safe)."
