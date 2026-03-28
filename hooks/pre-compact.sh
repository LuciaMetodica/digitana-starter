#!/bin/bash
# PreCompact hook: warns that context is about to be compressed
# Critical: unsaved work will be lost after compaction

echo "CRITICAL: Context is about to be compacted. BEFORE continuing: 1) Save ALL progress to memory files (summary, decisions, pending items, files touched, key context) 2) Update MEMORY.md index 3) Consider closing this session and opening a new one to avoid context loss."
