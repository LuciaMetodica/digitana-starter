#!/bin/bash
# Hook UserPromptSubmit: increment interaction counter, warn at checkpoints
EXPRESS_DIR="$HOME/.claude/express"
SESSIONS_DIR="$EXPRESS_DIR/state/sessions"
INSTANCE_ID=$PPID
COUNTER_FILE="$SESSIONS_DIR/$INSTANCE_ID.count"

[ -f "$COUNTER_FILE" ] || echo "0" > "$COUNTER_FILE"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Checkpoint reminder at 10 interactions
if [ "$COUNT" -eq 10 ] || [ "$COUNT" -eq 20 ] || [ "$COUNT" -eq 30 ]; then
  SESSION_FILE="$SESSIONS_DIR/$INSTANCE_ID.session"
  SESSION_ID=""
  [ -f "$SESSION_FILE" ] && SESSION_ID=$(cat "$SESSION_FILE")

  echo "CHECKPOINT OBLIGATORIO (interaccion #$COUNT): Guardar AHORA en la pagina de sesion de Notion${SESSION_ID:+ (ID: $SESSION_ID)} un resumen de todo lo trabajado hasta aqui: que se hizo, decisiones, pendientes, archivos tocados, contexto clave. NO continuar sin guardar primero."
fi
