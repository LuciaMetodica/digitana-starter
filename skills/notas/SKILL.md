---
name: notas
description: Guardar y buscar informacion en Notion (BD Aprendizajes)
---

# Notas y Aprendizajes

Guardar conocimiento del negocio en la BD Aprendizajes de Notion.

## Operaciones

### Guardar nota/aprendizaje
```bash
source ~/.claude/express/lib/notion-api.sh
export NOTION_API_TOKEN=$(grep '^NOTION_API_TOKEN=' ~/.claude/express/.env | cut -d= -f2-)
APREND_DB=$(jq -r '.databases.aprendizajes' ~/.claude/express/lib/notion-ids.json)

notion_req POST pages '{"parent":{"database_id":"'$APREND_DB'"},"properties":{"Titulo":{"title":[{"text":{"content":"TITULO"}}]},"Leccion":{"rich_text":[{"text":{"content":"CONTENIDO"}}]},"Categoria":{"select":{"name":"CATEGORIA"}},"Fecha":{"date":{"start":"YYYY-MM-DD"}}}}'
```

Categorias: negocio, proceso, cliente, tecnico, personal

### Buscar notas
```bash
notion_query_db "$APREND_DB" '{"filter":{"property":"Titulo","title":{"contains":"BUSQUEDA"}},"sorts":[{"property":"Fecha","direction":"descending"}],"page_size":10}'
```

### Listar recientes
```bash
notion_query_db "$APREND_DB" '{"sorts":[{"property":"Fecha","direction":"descending"}],"page_size":10}'
```

## Comportamiento
- Categorizar automaticamente segun contexto
- Al guardar, confirmar: "Guardado: [titulo] en [categoria]"
- Al buscar, mostrar resultados de forma legible con fecha y extracto
