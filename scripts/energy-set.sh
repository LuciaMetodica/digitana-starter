#!/bin/bash
# Set energy level manually (replaces ICC)
EXPRESS_DIR="$HOME/.claude/express"
STATE_DIR="$EXPRESS_DIR/state"
mkdir -p "$STATE_DIR"

LEVEL="${1:-}"
if [ -z "$LEVEL" ]; then
  echo "Nivel de energia (1=muy baja, 2=baja, 3=normal, 4=alta, 5=muy alta):"
  read -r LEVEL
fi

case "$LEVEL" in
  1) LABEL="muy baja" ;;
  2) LABEL="baja" ;;
  3) LABEL="normal" ;;
  4) LABEL="alta" ;;
  5) LABEL="muy alta" ;;
  *) echo "Nivel invalido (1-5)"; exit 1 ;;
esac

python3 -c "
import json
from datetime import date
data = {'level': $LEVEL, 'label': '$LABEL', 'date': str(date.today())}
with open('$STATE_DIR/energy.json', 'w') as f:
    json.dump(data, f)
print(f'Energia: $LEVEL/5 ($LABEL)')
"
