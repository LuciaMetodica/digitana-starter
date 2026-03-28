#!/bin/bash
# Hook UserPromptSubmit: counts interactions and reminds to save progress
# Runs every time the user sends a message

STARTER_DIR="$HOME/.digitana-starter"
SESSIONS_DIR="$STARTER_DIR/sessions"
INSTANCE_ID=$PPID
COUNTER_FILE="$SESSIONS_DIR/$INSTANCE_ID.count"

# Read current counter (0 if missing)
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
fi

# Increment
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Every 10 interactions, remind to save progress
if [ $((COUNT % 10)) -eq 0 ]; then
  echo "SAVE CHECKPOINT (interaction #$COUNT): Save your progress now. Update MEMORY.md or relevant memory files with: what was done, decisions made, pending items, key context. Don't continue without saving first."
fi
