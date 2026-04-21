#!/bin/bash
# Detect project name from cwd and remind Claude to read knowledge files.

KNOWLEDGE_BASE="$HOME/git/llm_knowledge"
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null | tr '[:upper:]' '[:lower:]')

if [ -z "$PROJECT" ]; then
  exit 0
fi

DOMAIN_DIR="$KNOWLEDGE_BASE/$PROJECT"
SHARED_DIR="$KNOWLEDGE_BASE/_shared"

files_to_read=""

if [ -d "$DOMAIN_DIR" ]; then
  for f in rules.md hypotheses.md knowledge.md; do
    [ -s "$DOMAIN_DIR/$f" ] && files_to_read="$files_to_read\n- $DOMAIN_DIR/$f"
  done
fi

if [ -d "$SHARED_DIR" ]; then
  for topic_dir in "$SHARED_DIR"/*/; do
    [ -s "${topic_dir}rules.md" ] && files_to_read="$files_to_read\n- ${topic_dir}rules.md"
  done
fi

if [ -n "$files_to_read" ]; then
  cat <<EOF
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "KNOWLEDGE TREE — Read these files before starting work:${files_to_read}\n\nApply all rules by default. Check if any hypothesis can be tested with today's work."}}
EOF
else
  if [ ! -d "$DOMAIN_DIR" ]; then
    cat <<EOF
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "KNOWLEDGE TREE — No domain folder found for project '$PROJECT'. Create $DOMAIN_DIR/ and add it to $KNOWLEDGE_BASE/index.md."}}
EOF
  fi
fi
