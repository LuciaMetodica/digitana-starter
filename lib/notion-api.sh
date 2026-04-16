#!/bin/bash
# Notion API wrapper — bash functions for direct API usage
# Source this file: source ~/.claude/automations/lib/notion-api.sh
# Requires NOTION_API_TOKEN in env or in .env file

# IDs centralizados — leer de notion-ids.json
_notion_ids_file="$(dirname "${BASH_SOURCE[0]}")/notion-ids.json"

# notion_id <dotted.path>
# Returns UUID for the given path from notion-ids.json.
# Example: notion_id databases.sesiones
notion_id() {
  local path="$1"
  jq -r ".$path" "$_notion_ids_file" 2>/dev/null
}

_notion_version="2022-06-28"

# _notion_resolve_token
# Resolves API token: env var first, then ~/.claude/automations/.env file.
_notion_resolve_token() {
  if [ -n "${NOTION_API_TOKEN:-}" ]; then
    echo "$NOTION_API_TOKEN"
  elif [ -f "$HOME/.claude/automations/.env" ]; then
    grep '^NOTION_API_TOKEN=' "$HOME/.claude/automations/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r'
  fi
}

# notion_req <METHOD> <endpoint> [json_body]
# Base request function. Prints response body to stdout.
# Prints error details to stderr and returns exit code 1 on non-2xx HTTP status.
# Example: notion_req GET "pages/abc123"
# Example: notion_req POST "databases/abc123/query" '{"page_size":10}'
notion_req() {
  local method="$1" endpoint="$2" body="$3"
  local url="https://api.notion.com/v1/${endpoint}"
  local token
  token=$(_notion_resolve_token)

  local args=(-s -w '\n%{http_code}'
    -X "$method"
    -H "Authorization: Bearer $token"
    -H "Notion-Version: $_notion_version"
    -H "Content-Type: application/json"
  )

  if [ -n "$body" ]; then
    args+=(-d "$body")
  fi

  local response http_code response_body
  response=$(curl "${args[@]}" "$url")
  http_code=$(printf '%s' "$response" | tail -n1)
  response_body=$(printf '%s' "$response" | sed '$d')

  if [[ "$http_code" != 2* ]]; then
    local error_msg
    error_msg=$(printf '%s' "$response_body" | jq -r '.message // "unknown error"' 2>/dev/null || echo "unknown error")
    echo "notion_req error: HTTP $http_code on $method $endpoint — $error_msg" >&2
    return 1
  fi

  printf '%s' "$response_body"
}

# notion_query_db <db_id> [body_json]
# Queries a Notion database. body_json can contain filter, sorts, page_size, start_cursor.
# Defaults to {"page_size":100} if body_json is omitted or empty.
# Example: notion_query_db "abc123" '{"filter":{"property":"Estado","select":{"equals":"Activa"}}}'
notion_query_db() {
  local db_id="$1" body="${2:-{\}}"
  if [ -z "$body" ] || [ "$body" = "{}" ]; then
    body='{"page_size":100}'
  fi
  notion_req POST "databases/${db_id}/query" "$body"
}

# notion_get_page <page_id>
# Fetches a Notion page object by ID.
# Example: notion_get_page "abc123"
notion_get_page() {
  notion_req GET "pages/$1"
}

# notion_get_blocks <page_id> [page_size]
# Fetches child blocks of a page. Defaults to page_size=100.
# Example: notion_get_blocks "abc123" 50
notion_get_blocks() {
  local page_id="$1" page_size="${2:-100}"
  notion_req GET "blocks/${page_id}/children?page_size=${page_size}"
}

# notion_create_page <db_id> <properties_json> [children_json]
# Creates a new page inside a database.
# Example: notion_create_page "db123" '{"Name":{"title":[{"text":{"content":"My page"}}]}}'
notion_create_page() {
  local db_id="$1" props="$2" children="$3"
  local body="{\"parent\":{\"database_id\":\"$db_id\"}, \"properties\": $props"
  if [ -n "$children" ]; then
    body+=", \"children\": $children"
  fi
  body+="}"
  notion_req POST "pages" "$body"
}

# notion_update_page <page_id> <properties_json>
# Updates properties of an existing page.
# Example: notion_update_page "abc123" '{"Estado":{"select":{"name":"Cerrada"}}}'
notion_update_page() {
  notion_req PATCH "pages/$1" "{\"properties\": $2}"
}

# notion_update_page_raw <page_id> <full_json>
# Updates a page with arbitrary top-level fields (cover, icon, properties, etc.)
# Example: notion_update_page_raw "abc123" '{"cover":{"type":"external","external":{"url":"..."}},"icon":{"type":"emoji","emoji":"X"}}'
notion_update_page_raw() {
  notion_req PATCH "pages/$1" "$2"
}

# notion_append_blocks <page_id> <children_json>
# Appends block content to a page.
# Example: notion_append_blocks "abc123" "[$(notion_paragraph 'Hello')]"
notion_append_blocks() {
  notion_req PATCH "blocks/$1/children" "{\"children\": $2}"
}

# notion_search <query_string> [filter_object_type]
# Searches Notion. First param must be a plain string, NOT JSON.
# filter_object_type: "page" or "database" (optional).
# Example: notion_search "SES-42" "page"
notion_search() {
  local query="$1" obj_type="$2"

  # Guard: detect accidental JSON object passed as query
  if [[ "$query" == "{"* ]]; then
    echo "notion_search error: first param must be a query string, not JSON. Got: $query" >&2
    return 1
  fi

  local body="{\"query\": \"$query\""
  if [ -n "$obj_type" ]; then
    body+=", \"filter\": {\"value\": \"$obj_type\", \"property\": \"object\"}"
  fi
  body+="}"
  notion_req POST "search" "$body"
}

# notion_delete_block <block_id>
# Deletes (archives) a block by ID.
# Example: notion_delete_block "block123"
notion_delete_block() {
  notion_req DELETE "blocks/$1"
}

# notion_archive_page <page_id>
# Archives a page (soft delete in Notion).
# Example: notion_archive_page "abc123"
notion_archive_page() {
  notion_req PATCH "pages/$1" '{"archived": true}'
}

# --- Helper: DB schema lookup ---

_notion_schemas_file="$HOME/.claude/automations/lib/notion-db-schemas.json"

# notion_db_schema <db_name>
# Shows property names and types for a database from local cache.
# Use BEFORE calling notion_create_page to avoid wrong property names.
# Example: notion_db_schema sesiones
# Example: notion_db_schema proyectos
notion_db_schema() {
  local db_name="$1"
  if [ -z "$db_name" ]; then
    echo "Usage: notion_db_schema <db_name>" >&2
    echo "Available: $(jq -r 'keys[] | select(startswith("_") | not)' "$_notion_schemas_file" | tr '\n' ' ')" >&2
    return 1
  fi
  local schema
  schema=$(jq -r --arg db "$db_name" '.[$db] // empty' "$_notion_schemas_file" 2>/dev/null)
  if [ -z "$schema" ]; then
    echo "DB '$db_name' not in cache. Fetching live schema..." >&2
    local dbid
    dbid=$(notion_id "databases.$db_name")
    if [ -z "$dbid" ] || [ "$dbid" = "null" ]; then
      echo "DB '$db_name' not found in notion-ids.json either." >&2
      return 1
    fi
    notion_req GET "databases/$dbid" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
props = d.get('properties', {})
title_field = next((k for k, v in props.items() if v.get('type') == 'title'), '?')
print(f'TITLE field: {title_field}')
for name, info in sorted(props.items()):
    print(f'  {name}: {info.get(\"type\", \"?\")}')" 2>&1
    return
  fi
  local title_field
  title_field=$(echo "$schema" | jq -r '.TITLE')
  echo "=== $db_name === (TITLE: $title_field)"
  echo "$schema" | jq -r '.properties | to_entries[] | "  \(.key): \(.value)"'
}

# notion_title_field <db_name>
# Returns just the title property name for a database.
# Example: notion_title_field sesiones  → "Sesion"
notion_title_field() {
  jq -r --arg db "$1" '.[$db].TITLE // empty' "$_notion_schemas_file" 2>/dev/null
}

# notion_refresh_schemas
# Regenerates the local schema cache by fetching all DBs from Notion API.
notion_refresh_schemas() {
  echo "Refreshing DB schemas from Notion API..."
  local ids_file="$(dirname "${BASH_SOURCE[0]}")/notion-ids.json"
  local out_file="$_notion_schemas_file"
  python3 -c "
import subprocess, json, sys

ids = json.load(open('$ids_file'))
dbs = ids.get('databases', {})
result = {'_generated': '$(date +%Y-%m-%d)', '_note': 'Auto-generated. Refresh with: notion_refresh_schemas'}

for name, dbid in dbs.items():
    try:
        raw = subprocess.run(
            ['bash', '-c', f'source $HOME/.claude/automations/lib/notion-api.sh && notion_req GET databases/{dbid}'],
            capture_output=True, text=True, timeout=15
        )
        if raw.returncode != 0:
            continue
        d = json.loads(raw.stdout)
        props = d.get('properties', {})
        title_field = next((k for k, v in props.items() if v.get('type') == 'title'), '?')
        schema = {'TITLE': title_field, 'properties': {}}
        for pname, pinfo in sorted(props.items()):
            ptype = pinfo.get('type', '?')
            extra = ''
            if ptype == 'select':
                opts = [o['name'] for o in pinfo.get('select', {}).get('options', [])]
                if opts: extra = f' [{chr(44).join(opts[:8])}]'
            elif ptype == 'status':
                opts = [o['name'] for o in pinfo.get('status', {}).get('options', [])]
                if opts: extra = f' [{chr(44).join(opts[:8])}]'
            elif ptype == 'unique_id':
                prefix = pinfo.get('unique_id', {}).get('prefix', '')
                if prefix: extra = f' ({prefix})'
            elif ptype == 'relation':
                rel_db = pinfo.get('relation', {}).get('database_id', '')[:8]
                if rel_db: extra = f' (-> {rel_db}...)'
            schema['properties'][pname] = f'{ptype}{extra}'
        result[name] = schema
        print(f'  OK: {name} ({len(props)} props, title={title_field})', file=sys.stderr)
    except Exception as e:
        print(f'  SKIP: {name} ({e})', file=sys.stderr)

json.dump(result, open('$out_file', 'w'), indent=2, ensure_ascii=False)
print(f'Done. {len(result)-2} databases cached to {\"$out_file\"}.', file=sys.stderr)
" 2>&1
}

# --- Helper: extract plain text from blocks ---
# Usage: notion_get_blocks <id> | notion_blocks_to_text
notion_blocks_to_text() {
  jq -r '.results[] |
    if .type == "heading_1" then "\n# " + (.heading_1.rich_text | map(.plain_text) | join(""))
    elif .type == "heading_2" then "\n## " + (.heading_2.rich_text | map(.plain_text) | join(""))
    elif .type == "heading_3" then "\n### " + (.heading_3.rich_text | map(.plain_text) | join(""))
    elif .type == "paragraph" then (.paragraph.rich_text | map(.plain_text) | join(""))
    elif .type == "bulleted_list_item" then "- " + (.bulleted_list_item.rich_text | map(.plain_text) | join(""))
    elif .type == "numbered_list_item" then "1. " + (.numbered_list_item.rich_text | map(.plain_text) | join(""))
    elif .type == "to_do" then "- [" + (if .to_do.checked then "x" else " " end) + "] " + (.to_do.rich_text | map(.plain_text) | join(""))
    elif .type == "callout" then "> " + (.callout.rich_text | map(.plain_text) | join(""))
    elif .type == "quote" then "> " + (.quote.rich_text | map(.plain_text) | join(""))
    elif .type == "code" then "```\n" + (.code.rich_text | map(.plain_text) | join("")) + "\n```"
    elif .type == "divider" then "---"
    elif .type == "toggle" then "▸ " + (.toggle.rich_text | map(.plain_text) | join(""))
    else .type
    end'
}

# --- Helper: build rich text block JSON ---

# notion_paragraph "text here"
# Returns a paragraph block JSON object.
notion_paragraph() {
  local text
  text=$(printf '%s' "$1" | jq -Rs '.')
  printf '{"object":"block","type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":%s}}]}}' "$text"
}

# notion_heading2 "text here"
# Returns a heading_2 block JSON object.
notion_heading2() {
  local text
  text=$(printf '%s' "$1" | jq -Rs '.')
  printf '{"object":"block","type":"heading_2","heading_2":{"rich_text":[{"type":"text","text":{"content":%s}}]}}' "$text"
}

# notion_bulleted "text here"
# Returns a bulleted_list_item block JSON object.
notion_bulleted() {
  local text
  text=$(printf '%s' "$1" | jq -Rs '.')
  printf '{"object":"block","type":"bulleted_list_item","bulleted_list_item":{"rich_text":[{"type":"text","text":{"content":%s}}]}}' "$text"
}
