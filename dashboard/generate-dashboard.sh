#!/bin/bash
# Generates dashboard state from current files
# Run this to refresh the dashboard data

STARTER_HOME="$HOME/.digitana-starter"
STATE_DIR="$STARTER_HOME/state"
CONFIG_FILE="$STARTER_HOME/assistant.json"
MEMORY_DIR="$HOME/.claude/projects/-Users-$(whoami)/memory"
SESSIONS_LOG="$STATE_DIR/sessions.log"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: assistant.json not found. Run setup.sh first."
  exit 1
fi

python3 -c "
import json, os, glob
from datetime import datetime

config = json.load(open('$CONFIG_FILE'))

# Parse sessions log
sessions = []
log_file = '$SESSIONS_LOG'
if os.path.isfile(log_file):
    with open(log_file) as f:
        for line in f:
            parts = line.strip().split(' | ')
            if len(parts) >= 3:
                date = parts[0].strip()
                event = parts[1].strip()
                meta = parts[2].strip() if len(parts) > 2 else ''
                interactions = ''
                if 'interactions=' in meta:
                    interactions = meta.split('interactions=')[1]
                sessions.append({
                    'date': date,
                    'event': event,
                    'interactions': interactions
                })

# Count memory files
memory_files = []
memory_dir = '$MEMORY_DIR'
if os.path.isdir(memory_dir):
    for f in sorted(os.listdir(memory_dir)):
        if f.endswith('.md'):
            memory_files.append(f)

state = {
    'assistant_name': config['assistant_name'],
    'user_name': config['user_name'],
    'config': {
        'purpose': config.get('purpose', ''),
        'personality': config.get('personality', '')
    },
    'installed_at': datetime.now().isoformat(),
    'sessions': sessions,
    'memory_files': memory_files
}

# Write state.json next to dashboard.html
script_dir = os.path.dirname(os.path.abspath('$0'))
out_dir = '$STARTER_HOME'
with open(os.path.join(out_dir, 'state.json'), 'w') as f:
    json.dump(state, f, indent=2)

print(f'Dashboard state updated: {len(sessions)} sessions, {len(memory_files)} memory files')
"

echo "Open $STARTER_HOME/dashboard.html in your browser"
echo "Or run: python3 -m http.server 8787 -d $STARTER_HOME"
