#!/bin/bash
# Generate startup context for next session
# Reads last closed session + pending tasks from Notion
EXPRESS_DIR="$HOME/.claude/express"
STATE_DIR="$EXPRESS_DIR/state"
mkdir -p "$STATE_DIR"

source "$EXPRESS_DIR/lib/notion-api.sh"
if [ -f "$EXPRESS_DIR/.env" ]; then
  export NOTION_API_TOKEN=$(grep '^NOTION_API_TOKEN=' "$EXPRESS_DIR/.env" | cut -d= -f2-)
fi

IDS_FILE="$EXPRESS_DIR/lib/notion-ids.json"
[ -f "$IDS_FILE" ] || exit 0

SESIONES_DB=$(python3 -c "import json; print(json.load(open('$IDS_FILE'))['databases']['sesiones'])" 2>/dev/null)
TAREAS_DB=$(python3 -c "import json; print(json.load(open('$IDS_FILE'))['databases']['tareas'])" 2>/dev/null)

[ -z "$SESIONES_DB" ] && exit 0

# Get last closed session
LAST_SESSION=$(notion_query_db "$SESIONES_DB" '{"filter":{"property":"Estado","select":{"equals":"Cerrada"}},"sorts":[{"property":"Fecha","direction":"descending"}],"page_size":1}' 2>/dev/null)

# Get pending tasks
PENDING_TASKS=$(notion_query_db "$TAREAS_DB" '{"filter":{"or":[{"property":"Estado","select":{"equals":"Pendiente"}},{"property":"Estado","select":{"equals":"En progreso"}}]},"page_size":10}' 2>/dev/null)

# Build context
python3 -c "
import json, sys
from datetime import date

output = []
output.append(f'Actualizado: {date.today()}')

# Last session
try:
    sessions = json.loads('''$LAST_SESSION''')
    results = sessions.get('results', [])
    if results:
        props = results[0].get('properties', {})
        title = ''
        for k, v in props.items():
            if v.get('type') == 'title':
                title = ''.join([t.get('plain_text', '') for t in v.get('title', [])])
        resumen = ''.join([t.get('plain_text', '') for t in props.get('Resumen', {}).get('rich_text', [])])
        pendientes = ''.join([t.get('plain_text', '') for t in props.get('Pendientes', {}).get('rich_text', [])])
        output.append(f'Ultima sesion: {title}')
        if resumen:
            output.append(f'Resumen: {resumen[:200]}')
        if pendientes:
            output.append(f'Pendientes sesion anterior: {pendientes[:200]}')
except:
    pass

# Pending tasks
try:
    tasks = json.loads('''$PENDING_TASKS''')
    results = tasks.get('results', [])
    if results:
        output.append(f'Tareas pendientes ({len(results)}):')
        for r in results[:5]:
            props = r.get('properties', {})
            title = ''
            for k, v in props.items():
                if v.get('type') == 'title':
                    title = ''.join([t.get('plain_text', '') for t in v.get('title', [])])
            estado = props.get('Estado', {}).get('select', {})
            estado_name = estado.get('name', '') if estado else ''
            output.append(f'  - {title} [{estado_name}]')
except:
    pass

print('\n'.join(output))
" > "$STATE_DIR/startup-context.txt" 2>/dev/null
