---
name: briefing
description: Estado del dia — tareas pendientes, ultima sesion, energia
---

# Briefing del dia

Mostrar un resumen del estado actual al arrancar o cuando se pida.

## Al activar

1. Leer nivel de energia actual:
```bash
cat ~/.claude/express/state/energy.json 2>/dev/null
```

2. Consultar tareas pendientes y del dia:
```bash
source ~/.claude/express/lib/notion-api.sh
export NOTION_API_TOKEN=$(grep '^NOTION_API_TOKEN=' ~/.claude/express/.env | cut -d= -f2-)
TAREAS_DB=$(jq -r '.databases.tareas' ~/.claude/express/lib/notion-ids.json)
HOY=$(date +%Y-%m-%d)

# Pendientes
notion_query_db "$TAREAS_DB" '{"filter":{"or":[{"property":"Estado","select":{"equals":"Pendiente"}},{"property":"Estado","select":{"equals":"En progreso"}}]},"sorts":[{"property":"Prioridad","direction":"ascending"}],"page_size":15}'
```

3. Consultar ultima sesion:
```bash
SESIONES_DB=$(jq -r '.databases.sesiones' ~/.claude/express/lib/notion-ids.json)
notion_query_db "$SESIONES_DB" '{"filter":{"property":"Estado","select":{"equals":"Cerrada"}},"sorts":[{"property":"Fecha","direction":"descending"}],"page_size":1}'
```

## Formato de salida

```
BRIEFING | YYYY-MM-DD

ENERGIA: X/5 (label)

TAREAS PENDIENTES (N):
- [Alta] tarea 1
- [Media] tarea 2
- ...

ULTIMA SESION: titulo
  Resumen: ...

SUGERENCIA: [basada en energia y tareas]
```

## Comportamiento
- Si energia 1-2: sugerir hacer solo lo urgente
- Si no hay tareas pendientes: felicitar y sugerir revisar agenda
- Parsear JSON de Notion a formato legible
