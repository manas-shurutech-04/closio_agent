# Loaded by every bash the tests start (BASH_ENV), only with "bash tests/run.sh --coverage" (D92): records each line of
# closio-agent's scripts that runs, as <file>:<line>, in $COV_FILE. functrace carries it into functions, command
# substitutions and subshells; BASH_ENV carries it into every script a script starts. Works in the Mac's bash 3.2.
set -o functrace
trap 'case "${BASH_SOURCE[0]:-}" in scripts/*.sh|*/scripts/*.sh|config/project-settings.sh|*/config/project-settings.sh) printf "%s:%s\n" "${BASH_SOURCE[0]}" "$LINENO" >> "$COV_FILE" ;; esac' DEBUG
