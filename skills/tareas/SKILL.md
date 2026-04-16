---
name: tareas
description: Crear, listar y completar tareas en Notion
---

# Tareas

Gestionar tareas en la BD de Notion del usuario.

## Operaciones

### Crear tarea
```bash
source ~/.claude/express/lib/notion-api.sh
export NOTION_API_TOKEN=$(grep '^NOTION_API_TOKEN=' ~/.claude/express/.env | cut -d= -f2-)
TAREAS_DB=$(jq -r '.databases.tareas' ~/.claude/express/lib/notion-ids.json)

notion_req POST pages '{"parent":{"database_id":"'$TAREAS_DB'"},"properties":{"Tarea":{"title":[{"text":{"content":"TITULO_AQUI"}}]},"Estado":{"select":{"name":"Pendiente"}},"Prioridad":{"select":{"name":"Media"}},"Fecha Limite":{"date":{"start":"YYYY-MM-DD"}}}}'
```

### Listar tareas pendientes
```bash
notion_query_db "$TAREAS_DB" '{"filter":{"or":[{"property":"Estado","select":{"equals":"Pendiente"}},{"property":"Estado","select":{"equals":"En progreso"}}]},"sorts":[{"property":"Prioridad","direction":"ascending"}]}'
```

### Completar tarea
```bash
notion_req PATCH "pages/PAGE_ID" '{"properties":{"Estado":{"select":{"name":"Completada"}}}}'
```

### Tareas del dia
```bash
notion_query_db "$TAREAS_DB" '{"filter":{"and":[{"or":[{"property":"Estado","select":{"equals":"Pendiente"}},{"property":"Estado","select":{"equals":"En progreso"}}]},{"property":"Fecha Limite","date":{"on_or_before":"HOY"}}]}}'
```

## Comportamiento
- Al crear tarea, vincular a la sesion activa si hay una (leer PID.session)
- Confirmar siempre: "Tarea creada: [titulo]"
- Parsear el output JSON para mostrar tareas de forma legible
