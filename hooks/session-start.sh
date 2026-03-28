#!/bin/bash
# Hook SessionStart: prepares the instance for a new session
# Resets interaction counter, cleans orphan sessions

STARTER_DIR="$HOME/.digitana-starter"
SESSIONS_DIR="$STARTER_DIR/sessions"
STATE_DIR="$STARTER_DIR/state"
CONFIG_FILE="$STARTER_DIR/assistant.json"

mkdir -p "$SESSIONS_DIR" "$STATE_DIR"

INSTANCE_ID=$PPID
COUNTER_FILE="$SESSIONS_DIR/$INSTANCE_ID.count"

# Reset interaction counter
echo "0" > "$COUNTER_FILE"

# Clean orphan sessions (dead claude processes)
for f in "$SESSIONS_DIR"/*.count; do
  [ -f "$f" ] || continue
  OLD_PID=$(basename "$f" .count)
  [ "$OLD_PID" = "$INSTANCE_ID" ] && continue
  if ! ps -p "$OLD_PID" > /dev/null 2>&1; then
    rm -f "$f"
  fi
done

# Read assistant name from config
ASSISTANT_NAME="Atlas"
if [ -f "$CONFIG_FILE" ]; then
  NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['assistant_name'])" 2>/dev/null)
  [ -n "$NAME" ] && ASSISTANT_NAME="$NAME"
fi

# Log session start
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | start | instance=$INSTANCE_ID" >> "$STATE_DIR/sessions.log"

echo "$ASSISTANT_NAME ready. Session started."
