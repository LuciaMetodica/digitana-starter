#!/bin/bash
# Hook SessionStart: prepare instance + inject startup context
EXPRESS_DIR="$HOME/.claude/express"
STATE_DIR="$EXPRESS_DIR/state"
SESSIONS_DIR="$STATE_DIR/sessions"
mkdir -p "$SESSIONS_DIR"

INSTANCE_ID=$PPID

# Reset interaction counter
echo "0" > "$SESSIONS_DIR/$INSTANCE_ID.count"

# Clean orphan sessions (dead PIDs)
for f in "$SESSIONS_DIR"/*.session; do
  [ -f "$f" ] || continue
  OLD_PID=$(basename "$f" .session)
  if ! ps -p "$OLD_PID" > /dev/null 2>&1; then
    rm -f "$f" "$SESSIONS_DIR/$OLD_PID.count" "$SESSIONS_DIR/$OLD_PID.started"
  fi
done

# Energy level
ENERGY="3"
ENERGY_LABEL="normal"
if [ -f "$STATE_DIR/energy.json" ]; then
  ENERGY=$(python3 -c "import json; print(json.load(open('$STATE_DIR/energy.json')).get('level',3))" 2>/dev/null || echo "3")
  ENERGY_LABEL=$(python3 -c "import json; print(json.load(open('$STATE_DIR/energy.json')).get('label','normal'))" 2>/dev/null || echo "normal")
fi

# Guard: only inject once per instance
if [ -f "$SESSIONS_DIR/$INSTANCE_ID.started" ]; then
  echo "Instancia $INSTANCE_ID reconectada."
  exit 0
fi
touch "$SESSIONS_DIR/$INSTANCE_ID.started"

# Startup context
STARTUP_CTX=""
if [ -f "$STATE_DIR/startup-context.txt" ]; then
  STARTUP_CTX=$(head -30 "$STATE_DIR/startup-context.txt")
fi

# Token usage tracking
TOKEN_WARNING=""
if [ -f "$EXPRESS_DIR/scripts/token-tracker.sh" ]; then
  TOKEN_WARNING=$(bash "$EXPRESS_DIR/scripts/token-tracker.sh" 2>/dev/null)
fi

# Fetch Digitana identity (cached, refreshed weekly)
IDENTITY_CACHE="$STATE_DIR/digitana-identity.md"
IDENTITY_URL="https://raw.githubusercontent.com/luciametodica/digitana-express/main/identity/digitana-identity.md"
REFRESH_DAYS=7

should_refresh=false
if [ ! -f "$IDENTITY_CACHE" ]; then
  should_refresh=true
elif [ -f "$IDENTITY_CACHE" ]; then
  last_mod=$(stat -f %m "$IDENTITY_CACHE" 2>/dev/null || stat -c %Y "$IDENTITY_CACHE" 2>/dev/null || echo 0)
  now=$(date +%s)
  age=$(( (now - last_mod) / 86400 ))
  [ "$age" -ge "$REFRESH_DAYS" ] && should_refresh=true
fi

if $should_refresh; then
  curl -sf --max-time 5 "$IDENTITY_URL" -o "$IDENTITY_CACHE.tmp" 2>/dev/null && mv "$IDENTITY_CACHE.tmp" "$IDENTITY_CACHE" || true
fi

IDENTITY=""
[ -f "$IDENTITY_CACHE" ] && IDENTITY=$(cat "$IDENTITY_CACHE")

# Build output
OUTPUT="Instancia lista. Energia: $ENERGY/5 ($ENERGY_LABEL)."
if [ -n "$IDENTITY" ]; then
  OUTPUT="$OUTPUT
IDENTIDAD DIGITANA (NO MODIFICABLE):
$IDENTITY"
fi

if [ -n "$STARTUP_CTX" ]; then
  OUTPUT="$OUTPUT
CONTEXTO DE ARRANQUE:
$STARTUP_CTX"
fi

if [ -n "$TOKEN_WARNING" ]; then
  OUTPUT="$OUTPUT
$TOKEN_WARNING"
fi

echo "$OUTPUT"
