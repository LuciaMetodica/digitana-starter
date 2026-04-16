#!/bin/bash
# Hook SessionEnd: close session, clean instance files, regenerate context
EXPRESS_DIR="$HOME/.claude/express"
STATE_DIR="$EXPRESS_DIR/state"
SESSIONS_DIR="$STATE_DIR/sessions"
INSTANCE_ID=$PPID

# Get current session page ID
SESSION_FILE="$SESSIONS_DIR/$INSTANCE_ID.session"
if [ -f "$SESSION_FILE" ]; then
  SESSION_PAGE_ID=$(cat "$SESSION_FILE")

  # Try to close session in Notion
  if [ -n "$SESSION_PAGE_ID" ] && [ -f "$EXPRESS_DIR/lib/notion-api.sh" ]; then
    source "$EXPRESS_DIR/lib/notion-api.sh"
    if [ -f "$EXPRESS_DIR/.env" ]; then
      export NOTION_API_TOKEN=$(grep '^NOTION_API_TOKEN=' "$EXPRESS_DIR/.env" | cut -d= -f2-)
    fi

    # Append closing block
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
    notion_req PATCH "blocks/$SESSION_PAGE_ID/children" "{\"children\":[{\"object\":\"block\",\"type\":\"paragraph\",\"paragraph\":{\"rich_text\":[{\"type\":\"text\",\"text\":{\"content\":\"--- Sesion cerrada — $TIMESTAMP ---\"},\"annotations\":{\"bold\":true,\"color\":\"gray\"}}]}}]}" >/dev/null 2>&1

    # Mark as closed
    notion_req PATCH "pages/$SESSION_PAGE_ID" '{"properties":{"Estado":{"select":{"name":"Cerrada"}}}}' >/dev/null 2>&1
  fi
fi

# Clean instance files
rm -f "$SESSIONS_DIR/$INSTANCE_ID.session" "$SESSIONS_DIR/$INSTANCE_ID.count" "$SESSIONS_DIR/$INSTANCE_ID.started"

# Regenerate startup context for next session (background)
if [ -f "$EXPRESS_DIR/scripts/startup-context-gen.sh" ]; then
  bash "$EXPRESS_DIR/scripts/startup-context-gen.sh" >/dev/null 2>&1 &
fi
