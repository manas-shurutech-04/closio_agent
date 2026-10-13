#!/usr/bin/env bash
# Waits a few seconds (1 to 30), e.g. while the Jira connector is still loading in Claude Code.
# Usage:  bash scripts/wait-seconds.sh 10

seconds="${1:-10}"
case "$seconds" in
  [1-9] | [12][0-9] | 30) ;;
  *) echo "Usage: bash scripts/wait-seconds.sh <1-30>"; exit 1 ;;
esac
sleep "$seconds"
echo "Waited $seconds seconds."
