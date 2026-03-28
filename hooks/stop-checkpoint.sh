#!/bin/bash
# Stop hook: saves timestamp of last turn for tracking

STATE_DIR="$HOME/.digitana-starter/state"
mkdir -p "$STATE_DIR"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE_DIR/.last-activity"
