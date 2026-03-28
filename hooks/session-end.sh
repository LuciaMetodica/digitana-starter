#!/bin/bash
# Hook SessionEnd: clean close of session
# Logs duration and cleans instance files

STARTER_DIR="$HOME/.digitana-starter"
SESSIONS_DIR="$STARTER_DIR/sessions"
STATE_DIR="$STARTER_DIR/state"

INSTANCE_ID=$PPID
COUNTER_FILE="$SESSIONS_DIR/$INSTANCE_ID.count"

# Read interaction count
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
fi

# Log session end
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | end   | instance=$INSTANCE_ID | interactions=$COUNT" >> "$STATE_DIR/sessions.log"

# Clean instance files
rm -f "$COUNTER_FILE"

echo "Session closed. $COUNT interactions."
