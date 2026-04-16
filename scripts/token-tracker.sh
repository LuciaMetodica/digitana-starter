#!/bin/bash
# Token usage tracker — counts sessions and warns when approaching limits
# Called by session-start.sh to check monthly usage
EXPRESS_DIR="$HOME/.claude/express"
STATE_DIR="$EXPRESS_DIR/state"
TRACKER_FILE="$STATE_DIR/usage-tracker.json"

mkdir -p "$STATE_DIR"

CURRENT_MONTH=$(date +%Y-%m)

# Initialize or read tracker
if [ -f "$TRACKER_FILE" ]; then
  TRACKED_MONTH=$(python3 -c "import json; print(json.load(open('$TRACKER_FILE')).get('month',''))" 2>/dev/null)
  if [ "$TRACKED_MONTH" != "$CURRENT_MONTH" ]; then
    # New month — reset counter
    python3 -c "
import json
data = {'month': '$CURRENT_MONTH', 'sessions': 0, 'warned': False}
with open('$TRACKER_FILE', 'w') as f:
    json.dump(data, f)
"
  fi
else
  python3 -c "
import json
data = {'month': '$CURRENT_MONTH', 'sessions': 0, 'warned': False}
with open('$TRACKER_FILE', 'w') as f:
    json.dump(data, f)
"
fi

# Increment session count
python3 -c "
import json

with open('$TRACKER_FILE') as f:
    data = json.load(f)

data['sessions'] = data.get('sessions', 0) + 1
sessions = data['sessions']

# Estimate: ~30 sessions/month = moderate use (~\$25 in tokens)
# Warn at 25 sessions, alert at 35
warning = ''
if sessions >= 35 and not data.get('alerted', False):
    warning = 'ALERTA: Uso alto este mes (' + str(sessions) + ' sesiones). Los tokens incluidos tienen un limite mensual. Si necesitas mas uso, contacta a Metodica.'
    data['alerted'] = True
elif sessions >= 25 and not data.get('warned', False):
    warning = 'INFO: Llevas ' + str(sessions) + ' sesiones este mes. Si tu uso es intensivo, recordá que los tokens incluidos cubren uso moderado (1-2 horas diarias).'
    data['warned'] = True

with open('$TRACKER_FILE', 'w') as f:
    json.dump(data, f)

if warning:
    print(warning)
"
