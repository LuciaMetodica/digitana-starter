#!/bin/bash
# Hook PreCompact: emergency save before context compaction
EXPRESS_DIR="$HOME/.claude/express"
SESSIONS_DIR="$EXPRESS_DIR/state/sessions"
INSTANCE_ID=$PPID
SESSION_FILE="$SESSIONS_DIR/$INSTANCE_ID.session"

if [ -f "$SESSION_FILE" ]; then
  SESSION_PAGE_ID=$(cat "$SESSION_FILE")
  echo "COMPACTACION INMINENTE: Ejecutar Pausa por contexto INMEDIATAMENTE. Guardar TODO en Notion (sesion $SESSION_PAGE_ID), agregar bloque 'Para retomar' con: que estabamos haciendo, donde quedamos, siguiente paso concreto. Dejar sesion en estado Activa."
else
  echo "COMPACTACION INMINENTE: Guardar todo el contexto importante antes de que se pierda."
fi
