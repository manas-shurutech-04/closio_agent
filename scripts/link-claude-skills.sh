#!/usr/bin/env bash
# Gives Claude Code access to every flow command (D8).
# Each command is written once, in .agents/skills/<name>/ (Codex reads it there).
# Claude Code reads .claude/skills/<name>, so this script makes that a link to the same folder.
# Safe to run again: existing correct links are left alone.
# Run it from anywhere:  bash scripts/link-claude-skills.sh

set -eu

AGENT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$AGENT_ROOT"
mkdir -p .claude/skills

for dir in .agents/skills/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  link=".claude/skills/$name"
  target="../../.agents/skills/$name"

  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    echo "ok:      $link"
  elif [ -e "$link" ] || [ -L "$link" ]; then
    echo "skipped: $link already exists but isn't the expected link. Check it by hand."
  else
    ln -s "$target" "$link"
    echo "created: $link -> $target"
  fi
done
