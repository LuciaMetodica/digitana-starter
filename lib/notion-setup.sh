#!/bin/bash
# Notion workspace setup — creates databases and pages via API
# Requires: notion-api.sh sourced, NOTION_API_TOKEN exported

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui.sh"

# Validate token by calling /v1/users/me
validate_notion_token() {
  local token="$1"
  NOTION_API_TOKEN="$token" notion_req GET "users/me" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('object') == 'user' or d.get('object') == 'bot':
    name = d.get('name', d.get('bot', {}).get('owner', {}).get('workspace', {}).get('name', 'OK'))
    print(f'OK:{name}')
else:
    print(f'FAIL:{d.get(\"message\", \"unknown error\")}')
" 2>/dev/null
}

# Guide the user through creating a Notion integration
guide_notion_setup() {
  header "Paso 2: Configurando Notion"

  if ! ask_yn "Ya tenes cuenta de Notion?"; then
    step "Crea una cuenta gratuita en Notion"
    echo ""
    echo -e "  1. Anda a ${BOLD}https://www.notion.so/signup${NC}"
    echo -e "  2. Crea tu cuenta (gratis)"
    echo -e "  3. Volve aca cuando termines"
    echo ""
    pause_continue
  fi

  step "Ahora vamos a crear una conexion (integration) para tu asistente"
  echo ""
  echo -e "  1. Anda a ${BOLD}https://www.notion.so/profile/integrations${NC}"
  echo -e "  2. Click en ${BOLD}\"New integration\"${NC}"
  echo -e "  3. Nombre: ${BOLD}\"Mi Asistente IA\"${NC} (o el que quieras)"
  echo -e "  4. Workspace: selecciona tu workspace"
  echo -e "  5. Deja las 3 opciones de Content marcadas (Read, Update, Insert)"
  echo -e "  6. Click ${BOLD}\"Submit\"${NC}"
  echo -e "  7. Copia el ${BOLD}\"Internal Integration Secret\"${NC} (empieza con ntn_...)"
  echo ""

  local token=""
  while true; do
    ask_secret "Pega el token aca" token
    if [ -z "$token" ]; then
      warn "Token vacio. Intenta de nuevo."
      continue
    fi

    step "Verificando token..."
    local result
    result=$(validate_notion_token "$token")
    if [[ "$result" == OK:* ]]; then
      local workspace_name="${result#OK:}"
      success "Conectado al workspace: $workspace_name"
      echo "$token"
      return 0
    else
      local error="${result#FAIL:}"
      fail "Token invalido: $error"
      warn "Verifica que copiaste el token completo (empieza con ntn_...)"
    fi
  done
}

# Guide user to share a page with the integration
guide_share_page() {
  local token="$1"
  step "Ultimo paso de Notion: compartir una pagina con tu integracion"
  echo ""
  echo -e "  1. En Notion, crea una pagina nueva (puede estar vacia)"
  echo -e "  2. Llamala ${BOLD}\"Asistente IA\"${NC} o como quieras"
  echo -e "  3. Click en ${BOLD}\"...\"${NC} (arriba a la derecha)"
  echo -e "  4. Click en ${BOLD}\"Connections\"${NC} o ${BOLD}\"Conexiones\"${NC}"
  echo -e "  5. Busca y selecciona ${BOLD}\"Mi Asistente IA\"${NC} (tu integracion)"
  echo -e "  6. Confirma"
  echo ""
  pause_continue

  step "Buscando la pagina compartida..."
  local result
  result=$(NOTION_API_TOKEN="$token" notion_req POST "search" '{"query":"","page_size":5}' 2>/dev/null)
  local page_id
  page_id=$(echo "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('results', [])
# Find first page (not database)
for r in results:
    if r.get('object') == 'page' and r.get('parent', {}).get('type') == 'workspace':
        print(r['id'])
        break
" 2>/dev/null)

  if [ -n "$page_id" ]; then
    local page_title
    page_title=$(echo "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for r in data.get('results', []):
    if r['id'] == '$page_id':
        props = r.get('properties', {})
        for k, v in props.items():
            if v.get('type') == 'title':
                print(''.join([t.get('plain_text', '') for t in v.get('title', [])]))
                break
" 2>/dev/null)
    success "Pagina encontrada: \"$page_title\" ($page_id)"
    echo "$page_id"
    return 0
  else
    fail "No encontre ninguna pagina compartida."
    warn "Verifica que compartiste la pagina con la integracion y volve a intentar."
    return 1
  fi
}

# Create a database inside a parent page
create_database() {
  local token="$1"
  local parent_id="$2"
  local title="$3"
  local properties_json="$4"
  local icon="${5:-📋}"

  local payload
  payload=$(python3 -c "
import json
props = json.loads('$properties_json')
payload = {
    'parent': {'page_id': '$parent_id'},
    'icon': {'type': 'emoji', 'emoji': '$icon'},
    'title': [{'type': 'text', 'text': {'content': '$title'}}],
    'properties': props
}
print(json.dumps(payload))
")

  local result
  result=$(NOTION_API_TOKEN="$token" notion_req POST "databases" "$payload" 2>/dev/null)
  local db_id
  db_id=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  if [ -n "$db_id" ]; then
    success "BD \"$title\" creada: $db_id"
    echo "$db_id"
  else
    local err
    err=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)
    fail "Error creando BD \"$title\": $err"
    echo ""
  fi
}

# Create a page inside a parent
create_child_page() {
  local token="$1"
  local parent_id="$2"
  local title="$3"
  local icon="${4:-📝}"

  local payload="{\"parent\":{\"page_id\":\"$parent_id\"},\"icon\":{\"type\":\"emoji\",\"emoji\":\"$icon\"},\"properties\":{\"title\":{\"title\":[{\"text\":{\"content\":\"$title\"}}]}}}"

  local result
  result=$(NOTION_API_TOKEN="$token" notion_req POST "pages" "$payload" 2>/dev/null)
  local page_id
  page_id=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  if [ -n "$page_id" ]; then
    success "Pagina \"$title\" creada: $page_id"
    echo "$page_id"
  else
    fail "Error creando pagina \"$title\""
    echo ""
  fi
}

# Main: create the full Notion workspace
setup_notion_workspace() {
  local token="$1"
  local parent_id="$2"
  local ids_file="$3"

  header "Paso 3: Creando workspace en Notion"
  step "Creando bases de datos..."

  # BD Sesiones
  local sesiones_props='{"Sesion":{"title":{}},"Estado":{"select":{"options":[{"name":"Activa","color":"green"},{"name":"Cerrada","color":"default"},{"name":"Pausada","color":"yellow"}]}},"Tipo":{"select":{"options":[{"name":"trabajo","color":"blue"},{"name":"planificacion","color":"purple"},{"name":"admin","color":"gray"},{"name":"mixta","color":"orange"}]}},"Fecha":{"date":{}},"Resumen":{"rich_text":{}},"Pendientes":{"rich_text":{}}}'
  local sesiones_id
  sesiones_id=$(create_database "$token" "$parent_id" "Sesiones" "$sesiones_props" "📋")

  # BD Tareas (relation to Sesiones added after creation)
  local tareas_props='{"Tarea":{"title":{}},"Estado":{"select":{"options":[{"name":"Pendiente","color":"red"},{"name":"En progreso","color":"yellow"},{"name":"Completada","color":"green"},{"name":"Cancelada","color":"default"}]}},"Prioridad":{"select":{"options":[{"name":"Alta","color":"red"},{"name":"Media","color":"yellow"},{"name":"Baja","color":"blue"}]}},"Fecha Limite":{"date":{}},"Notas":{"rich_text":{}}}'
  local tareas_id
  tareas_id=$(create_database "$token" "$parent_id" "Tareas" "$tareas_props" "✅")

  # BD Aprendizajes
  local aprend_props='{"Titulo":{"title":{}},"Leccion":{"rich_text":{}},"Categoria":{"select":{"options":[{"name":"negocio","color":"blue"},{"name":"proceso","color":"purple"},{"name":"cliente","color":"green"},{"name":"tecnico","color":"gray"},{"name":"personal","color":"yellow"}]}},"Fecha":{"date":{}}}'
  local aprend_id
  aprend_id=$(create_database "$token" "$parent_id" "Aprendizajes" "$aprend_props" "💡")

  # BD Contactos
  local contactos_props='{"Nombre":{"title":{}},"Email":{"email":{}},"Telefono":{"phone_number":{}},"Empresa":{"rich_text":{}},"Notas":{"rich_text":{}}}'
  local contactos_id
  contactos_id=$(create_database "$token" "$parent_id" "Contactos" "$contactos_props" "👥")

  step "Creando paginas..."

  local home_id
  home_id=$(create_child_page "$token" "$parent_id" "Home" "🏠")

  local diario_id
  diario_id=$(create_child_page "$token" "$parent_id" "Diario" "📓")

  # Write notion-ids.json
  step "Guardando IDs..."
  python3 -c "
import json
ids = {
    'databases': {
        'sesiones': '$sesiones_id',
        'tareas': '$tareas_id',
        'aprendizajes': '$aprend_id',
        'contactos': '$contactos_id'
    },
    'pages': {
        'home': '$home_id',
        'diario': '$diario_id',
        'root': '$parent_id'
    }
}
with open('$ids_file', 'w') as f:
    json.dump(ids, f, indent=2)
print('OK')
"
  success "IDs guardados en $ids_file"

  # Add welcome content to Home page
  if [ -n "$home_id" ]; then
    NOTION_API_TOKEN="$token" notion_req PATCH "blocks/$home_id/children" '{
      "children": [
        {"object":"block","type":"heading_2","heading_2":{"rich_text":[{"type":"text","text":{"content":"Bienvenido a tu Asistente IA"}}]}},
        {"object":"block","type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"Este workspace es el cerebro de tu asistente. Aca se guardan tus sesiones, tareas, aprendizajes y contactos."}}]}},
        {"object":"block","type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":"Como empezar"}}]}},
        {"object":"block","type":"bulleted_list_item","bulleted_list_item":{"rich_text":[{"type":"text","text":{"content":"Abri la terminal y escribi: claude"}}]}},
        {"object":"block","type":"bulleted_list_item","bulleted_list_item":{"rich_text":[{"type":"text","text":{"content":"Tu asistente se conecta automaticamente a este workspace"}}]}},
        {"object":"block","type":"bulleted_list_item","bulleted_list_item":{"rich_text":[{"type":"text","text":{"content":"Comandos rapidos: /g (guardar), /r (cerrar sesion), /p (pausar)"}}]}}
      ]
    }' >/dev/null 2>&1
  fi
}
