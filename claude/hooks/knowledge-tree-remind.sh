#!/bin/bash
# Lightweight reminder to consider extracting knowledge tree insights.
# Only triggers if we're in a git repo with a knowledge tree domain.

KNOWLEDGE_BASE="$HOME/git/llm_knowledge"
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null | tr '[:upper:]' '[:lower:]')

if [ -z "$PROJECT" ]; then
  exit 0
fi

DOMAIN_DIR="$KNOWLEDGE_BASE/$PROJECT"

if [ -d "$DOMAIN_DIR" ] || [ -d "$KNOWLEDGE_BASE/_shared" ]; then
  cat <<EOF
{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "If this task revealed a non-obvious insight (surprising bug cause, undocumented pattern, gotcha), update the knowledge tree at $KNOWLEDGE_BASE/$PROJECT/ or _shared/. Skip for trivial work."}}
EOF
fi
