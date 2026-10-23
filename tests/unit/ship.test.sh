# scripts/ship.sh: commits the card's files and pushes its branch in a code repo; the first push creates the MR on
# GitLab with push options (D31), review fixes go into the same MR (push-update). Never forced.

# A registered Node repo "fake-repo" (base develop, MR target develop, Node 22): GitLab is a bare repo ($G) that
# accepts push options; its hooks note the push options in $T/push-options.txt, print the MR link when $T/mr-url
# exists, and refuse a push when $T/refuse exists. $U pushes newer commits; the clone "$R" is on the card's branch.
setup_ship() {
  sandbox
  G="$T/gitlab/fake-repo.git"; U="$T/upstream"; R="$T/repos/fake repo"
  mkdir -p "$T/gitlab" "$T/repos" "$A/local/repos"
  git init -q --bare -b develop "$G" && git -C "$G" config receive.advertisePushOptions true
  printf '#!/bin/sh\nif [ -f "%s/refuse" ]; then echo "GL-HOOK-ERR: the server refused this push" >&2; exit 1; fi\nexit 0\n' "$T" > "$G/hooks/pre-receive"
  cat > "$G/hooks/post-receive" <<EOF
#!/bin/sh
: > "$T/push-options.txt"
i=0
while [ "\$i" -lt "\${GIT_PUSH_OPTION_COUNT:-0}" ]; do
  eval "printf '%s\n' \"\\\$GIT_PUSH_OPTION_\$i\"" >> "$T/push-options.txt"
  i=\$((i + 1))
done
[ -f "$T/mr-url" ] && cat "$T/mr-url" >&2
exit 0
EOF
  chmod +x "$G/hooks/pre-receive" "$G/hooks/post-receive"
  git init -q -b develop "$U" && git -C "$U" remote add origin "$G"
  printf 'one\n' > "$U/app.js"; printf 'old\n' > "$U/old.js"
  git -C "$U" add -A && git -C "$U" commit -q -m "first" && git -C "$U" push -q origin develop || fail "the fake GitLab"
  git clone -q "$G" "$R" && git -C "$R" checkout -q -b SCRUM-1/add-filter || fail "the clone"
  printf 'name: fake-repo\nlanguage: node\nnode_version: 22\nbase_branch: develop\nmr_target_branch: develop\n' > "$A/config/repos/fake-repo.yaml"
  printf 'local_path: %s\n' "$R" > "$A/local/repos/fake-repo.yaml"
  user_settings GITLAB_USERNAME=qa.user
}
commit_here() { # <file> <text>: a commit on the card's branch
  printf '%s\n' "$2" > "$R/$1"; git -C "$R" add -A && git -C "$R" commit -q -m "SCRUM-1: $1" || fail "commit"
}
hook() { # <name> <body>: a git hook in the clone
  printf '#!/bin/sh\n%s\n' "$2" > "$R/.git/hooks/$1"; chmod +x "$R/.git/hooks/$1"
}
last2() { printf '%s\n' "$OUT" | tail -2; }
log_of() { cat "$A/local/logs/ship-fake-repo.log" 2>/dev/null; }
MR_URL="https://gitlab.example.com/closio/fake-repo/-/merge_requests/12"

# ---------------------------------------------------------------- status
test_status_shows_the_files_and_the_commits_to_ship() {
  setup_ship; commit_here feature.js "f"
  echo "x" >> "$R/app.js"; echo "new" > "$R/new.js"
  run ship.sh fake-repo status
  assert_rc 0
  assert_eq "$OUT" "✅ fake-repo: on SCRUM-1/add-filter; MR target develop; 2 uncommitted file(s) ($R)
    M app.js
   ?? new.js
   Commits develop doesn't have yet: 1
   $(git -C "$R" rev-parse --short HEAD) SCRUM-1: feature.js"
}
test_status_of_a_clean_branch() {
  setup_ship
  run ship.sh fake-repo status
  assert_rc 0
  assert_eq "$OUT" "✅ fake-repo: on SCRUM-1/add-filter; MR target develop; 0 uncommitted file(s) ($R)
   Commits develop doesn't have yet: 0"
}
test_status_when_the_mr_target_is_not_fetched_or_not_set() {
  setup_ship
  sed -i '' 's/^mr_target_branch: .*/mr_target_branch: release/' "$A/config/repos/fake-repo.yaml"
  run ship.sh fake-repo status
  assert_rc 0
  assert_contains "$OUT" "MR target release;"
  assert_contains "$OUT" "   (origin/release not fetched yet: the rebase step fetches it)"
  sed -i '' 's/^mr_target_branch: .*/mr_target_branch: none/' "$A/config/repos/fake-repo.yaml"
  run ship.sh fake-repo status
  assert_contains "$OUT" "MR target develop;"
}
test_a_repo_that_is_not_ready() {
  setup_ship
  run ship.sh nope status
  assert_rc 1
  assert_eq "$OUT" "❌ nope isn't registered (run /flow-configure-repo <path of your clone>)
   Fix: Fix that first, then run this again."
  mkdir -p "$T/plain folder"; printf 'local_path: %s\n' "$T/plain folder" > "$A/local/repos/fake-repo.yaml"
  run ship.sh fake-repo status
  assert_rc 1
  assert_eq "$OUT" "❌ $T/plain folder isn't a git clone
   Fix: Point closio-agent at the clone: /flow-configure-repo fake-repo path <folder>."
}
test_never_on_the_base_branch_or_a_branch_without_the_card_key() {
  setup_ship
  local b
  for b in develop feature/x; do
    git -C "$R" checkout -q -B "$b"
    run ship.sh fake-repo status
    assert_rc 1
    assert_eq "$OUT" "❌ fake-repo is on '$b', not on a card's branch
   Fix: Switch to the card's branch (bash scripts/run.sh get <CARD-KEY> branch); closio-agent never commits to develop."
  done
}
test_not_while_a_rebase_is_in_progress() {
  setup_ship; mkdir -p "$R/.git/rebase-apply"
  run ship.sh fake-repo status
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: a rebase is in progress
   Fix: Finish it first: bash scripts/card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter"
}

# ---------------------------------------------------------------- commit
test_commit_stages_exactly_the_files_given_on_the_repo_node_version() {
  setup_ship
  echo "two" >> "$R/app.js"; echo "new" > "$R/new.js"; rm "$R/old.js"; echo "other" > "$R/other.js"
  hook pre-commit 'echo "hook ran on $(pwd)"'
  run ship.sh fake-repo commit "SCRUM-1: add the filter" app.js new.js old.js
  assert_rc 0
  assert_eq "$OUT" "   fake-repo: committing 3 file(s); the repo's git hooks run (time limit 900 s)...
✅ fake-repo: $(git -C "$R" rev-parse --short HEAD) SCRUM-1: add the filter (3 files changed, 2 insertions(+), 1 deletion(-))"
  assert_eq "$(git -C "$R" show --name-only --format= HEAD | sort | tr '\n' ' ')" "app.js new.js old.js "
  assert_eq "$(git -C "$R" status --porcelain)" "?? other.js"
  assert_contains "$(fake_calls nvm)" "nvm use 22"
  assert_contains "$(log_of)" "hook ran on"
}
test_commit_message_must_be_one_line_starting_with_the_card_key() {
  setup_ship; echo "two" >> "$R/app.js"
  run ship.sh fake-repo commit "SCRUM-1: add
the filter" app.js
  assert_rc 2
  assert_eq "$OUT" "❌ The commit message must be one line
   Fix: Write it as \"SCRUM-1: <what this commit does>\"."
  local m
  for m in "add the filter" "SCRUM-2: add the filter" "SCRUM-1: ab"; do
    run ship.sh fake-repo commit "$m" app.js
    assert_rc 2
    assert_eq "$OUT" "❌ The commit message must start with the card's key: \"SCRUM-1: <what this commit does>\"
   Fix: Write it like that, e.g. \"SCRUM-1: add the ageing config model and migration\"."
  done
  assert_eq "$(git -C "$R" log -1 --format=%s)" "first"
}
test_commit_refuses_when_files_are_already_staged() {
  setup_ship; echo "two" >> "$R/app.js"; echo "x" > "$R/staged.js"; git -C "$R" add staged.js
  run ship.sh fake-repo commit "SCRUM-1: add the filter" app.js
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo already has staged files: staged.js
   Fix: Ask the user: unstage them (git -C \"$R\" reset) or commit them first, then run this again."
}
test_commit_a_file_that_is_not_there() {
  setup_ship
  run ship.sh fake-repo commit "SCRUM-1: add the filter" nothing.js
  assert_rc 2
  assert_eq "$OUT" "❌ fake-repo has no file nothing.js (and it isn't a deleted tracked file)
   Fix: Use paths from the repo's root, as git status shows them."
}
test_commit_a_deleted_tracked_file() {
  setup_ship; rm "$R/old.js"
  run ship.sh fake-repo commit "SCRUM-1: remove the old file" old.js
  assert_rc 0; assert_contains "$OUT" "SCRUM-1: remove the old file (1 file changed, 1 deletion(-))"
}
test_commit_files_that_did_not_change() {
  setup_ship
  run ship.sh fake-repo commit "SCRUM-1: add the filter" app.js
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: nothing changed in those files
   Fix: Check the file list against git -C \"$R\" status."
}
test_commit_when_a_file_cannot_be_staged() {
  setup_ship; echo "new" > "$R/locked.js"; chmod 000 "$R/locked.js"
  run ship.sh fake-repo commit "SCRUM-1: add the filter" locked.js
  chmod 644 "$R/locked.js"
  assert_rc 1
  assert_eq "$(last2)" "❌ fake-repo: couldn't stage the files
   Fix: Check git -C \"$R\" status."
}
test_a_failing_hook_commits_nothing_and_unstages_the_files() {
  setup_ship; echo "two" >> "$R/app.js"
  hook pre-commit 'echo "  3 passing"; echo "  1 failing"; echo "ERROR: Coverage for lines (50%) does not meet global threshold (90%)"; exit 1'
  run ship.sh fake-repo commit "SCRUM-1: add the filter" app.js
  assert_rc 1
  assert_contains "$OUT" "❌ fake-repo: the commit failed (a git hook, e.g. the coverage gate); nothing is committed, the files are unstaged again
   Fix: Read the end below (full: local/logs/ship-fake-repo.log); fix the code or tests (/flow-develop SCRUM-1), then run this again."
  assert_contains "$OUT" "   1 failing"
  assert_contains "$OUT" "        ERROR: Coverage for lines (50%) does not meet global threshold (90%)"
  assert_eq "$(git -C "$R" log -1 --format=%s)" "first"
  assert_eq "$(git -C "$R" status --porcelain)" " M app.js"
}
test_a_hook_over_the_time_limit_is_stopped() {
  setup_ship; echo "two" >> "$R/app.js"
  hook pre-commit 'sleep 8'
  export REPO_RUN_TIMEOUT=1
  run ship.sh fake-repo commit "SCRUM-1: add the filter" app.js
  assert_rc 1
  assert_eq "$(last2)" "❌ fake-repo: the commit took longer than 1 s (its hook) and was stopped; nothing is committed
   Fix: Read local/logs/ship-fake-repo.log, then try again."
  assert_eq "$(git -C "$R" diff --cached --name-only)" ""
}

# ---------------------------------------------------------------- push
test_push_creates_the_mr_with_push_options_and_prints_its_link() {
  setup_ship; commit_here feature.js "f"
  echo "To create a merge request: $MR_URL" > "$T/mr-url"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter" --label backend --label "needs review"
  assert_rc 0
  assert_eq "$OUT" "   fake-repo: pushing SCRUM-1/add-filter (1 commit(s)) and creating the MR into develop, assigned to qa.user; the pre-push hook runs (time limit 900 s)...
✅ fake-repo: SCRUM-1/add-filter pushed (1 commit(s), $(git -C "$R" rev-parse --short HEAD))
   MR: $MR_URL"
  assert_eq "$(cat "$T/push-options.txt")" "merge_request.create
merge_request.target=develop
merge_request.title=SCRUM-1: Scheme list filter
merge_request.assign=qa.user
merge_request.label=backend
merge_request.label=needs review"
  assert_eq "$(git -C "$G" rev-parse SCRUM-1/add-filter)" "$(git -C "$R" rev-parse HEAD)"
  assert_eq "$(git -C "$R" rev-parse --abbrev-ref '@{u}')" "origin/SCRUM-1/add-filter"
}
test_push_without_an_mr_link_and_with_untracked_files() {
  setup_ship; commit_here feature.js "f"; echo "scratch" > "$R/scratch.txt"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 0
  assert_contains "$OUT" "⚠️ fake-repo has files git doesn't track; they won't be pushed: scratch.txt
   Tip: If one belongs to the card, commit it first."
  assert_contains "$OUT" "✅ fake-repo: SCRUM-1/add-filter pushed (1 commit(s)"
  assert_contains "$OUT" "⚠️ fake-repo: GitLab printed no MR link
   Tip: Check it: bash scripts/gitlab-mr.sh fake-repo find SCRUM-1/add-filter"
}
test_push_options_and_title_are_checked() {
  setup_ship; commit_here feature.js "f"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter" --label
  assert_rc 2; assert_contains "$OUT" "Usage:"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter" --force
  assert_rc 2; assert_contains "$OUT" "Usage:"
  run ship.sh fake-repo push "SCRUM-1: Scheme
list filter"
  assert_rc 2
  assert_eq "$OUT" "❌ The MR title must be one line
   Fix: Write it as \"SCRUM-1: <card title>\"."
  run ship.sh fake-repo push "Scheme list filter"
  assert_rc 2
  assert_eq "$OUT" "❌ The MR title must read \"SCRUM-1: <card title>\"
   Fix: Write it like that."
  assert_eq "$(git -C "$G" rev-parse -q --verify SCRUM-1/add-filter)" ""
}
test_push_needs_the_gitlab_username() {
  setup_ship; commit_here feature.js "f"; user_settings JIRA_EMAIL=x@example.com
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  assert_eq "$OUT" "❌ Your GitLab username isn't set
   Fix: Run /flow-configure-user gitlab-username (Codex: \$flow-configure-user gitlab-username), then run this again."
}
test_push_with_uncommitted_changes() {
  setup_ship; commit_here feature.js "f"; echo "x" >> "$R/app.js"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo has uncommitted changes to tracked files
   Fix: Commit them first (bash scripts/ship.sh fake-repo commit …), or ask the user what they are."
}
test_push_without_gitlab() {
  setup_ship; commit_here feature.js "f"; git -C "$R" remote set-url origin "$T/nowhere.git"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: can't reach GitLab
   Fix: Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."
}
test_push_when_the_mr_target_is_not_on_gitlab() {
  setup_ship; commit_here feature.js "f"
  sed -i '' 's/^mr_target_branch: .*/mr_target_branch: release/' "$A/config/repos/fake-repo.yaml"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: the MR target branch release isn't on GitLab
   Fix: Check mr_target_branch in config/repos/fake-repo.yaml."
}
test_push_without_commits_of_the_card() {
  setup_ship
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: SCRUM-1/add-filter has no commits that develop doesn't have
   Fix: Commit the card's work first (bash scripts/ship.sh fake-repo commit …)."
}
test_push_refused_because_someone_else_pushed_is_never_forced() {
  setup_ship
  git -C "$U" checkout -q -b SCRUM-1/add-filter && printf 'theirs\n' > "$U/feature.js" && git -C "$U" add -A &&
    git -C "$U" commit -q -m "SCRUM-1: theirs" && git -C "$U" push -q origin SCRUM-1/add-filter || fail "their push"
  commit_here feature.js "mine"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  assert_contains "$OUT" "❌ fake-repo: GitLab refused the push: the branch there has commits this Mac doesn't have
   Fix: Ask the user: someone else pushed to SCRUM-1/add-filter. Look with git -C \"$R\" log HEAD..origin/SCRUM-1/add-filter; closio-agent never forces a push."
  assert_contains "$OUT" "rejected"
  assert_eq "$(git -C "$G" log -1 --format=%s SCRUM-1/add-filter)" "SCRUM-1: theirs"
}
test_push_that_fails_for_another_reason() {
  setup_ship; commit_here feature.js "f"
  hook pre-push 'echo "lint failed: 2 problems"; exit 1'
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  assert_contains "$OUT" "❌ fake-repo: the push failed (the pre-push hook, the VPN or GitLab)
   Fix: Read the end below (full: local/logs/ship-fake-repo.log), fix it, then run this again."
  assert_contains "$OUT" "        lint failed: 2 problems"
  assert_eq "$(git -C "$G" rev-parse -q --verify SCRUM-1/add-filter)" ""
}
test_a_push_gitlab_declines_is_reported_as_someone_else_pushed() {
  setup_ship; commit_here feature.js "f"; touch "$T/refuse"
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  # Today's behaviour (a bug): push_failed takes any "rejected" in git's output as "someone else pushed", so a push
  # GitLab's own hook declines ("! [remote rejected] … (pre-receive hook declined)") gets that ❌ and its fix.
  assert_contains "$OUT" "❌ fake-repo: GitLab refused the push: the branch there has commits this Mac doesn't have"
  assert_contains "$OUT" "        remote: GL-HOOK-ERR: the server refused this push"
}
test_a_push_over_the_time_limit_is_stopped() {
  setup_ship; commit_here feature.js "f"
  hook pre-push 'sleep 8'
  export REPO_RUN_TIMEOUT=1
  run ship.sh fake-repo push "SCRUM-1: Scheme list filter"
  assert_rc 1
  assert_contains "$OUT" "❌ fake-repo: the push took longer than 1 s and was stopped
   Fix: Read local/logs/ship-fake-repo.log; check on GitLab whether the branch arrived, then run this again."
  assert_contains "$(log_of)" "closio-agent: stopped after 1 seconds (time limit)"
}

# ---------------------------------------------------------------- push-update (review fixes)
pushed_branch() { # the card's branch is on GitLab with its MR
  commit_here feature.js "f"; git -C "$R" push -q -u origin SCRUM-1/add-filter || fail "the first push"
}
test_push_update_pushes_review_fixes_into_the_same_mr() {
  setup_ship; pushed_branch; commit_here feature.js "fixed"; commit_here other.js "o"
  rm -f "$T/push-options.txt"
  run ship.sh fake-repo push-update
  assert_rc 0
  assert_eq "$OUT" "   fake-repo: pushing 2 review-fix commit(s) to SCRUM-1/add-filter, into its open MR; the pre-push hook runs (time limit 900 s)...
✅ fake-repo: 2 commit(s) pushed to SCRUM-1/add-filter ($(git -C "$R" rev-parse --short HEAD)); the MR shows them"
  assert_eq "$(git -C "$G" rev-parse SCRUM-1/add-filter)" "$(git -C "$R" rev-parse HEAD)"
  assert_eq "$(cat "$T/push-options.txt")" "" "no push options"
}
test_push_update_with_untracked_files_still_pushes() {
  setup_ship; pushed_branch; commit_here feature.js "fixed"; echo "s" > "$R/scratch.txt"
  run ship.sh fake-repo push-update
  assert_rc 0
  assert_contains "$OUT" "⚠️ fake-repo has files git doesn't track; they won't be pushed: scratch.txt
   Tip: If one belongs to the fix, commit it first."
}
test_push_update_checks_before_it_pushes() {
  setup_ship; commit_here feature.js "f"
  run ship.sh fake-repo push-update
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: SCRUM-1/add-filter isn't on GitLab yet
   Fix: This is for review fixes on a pushed MR; the first push is /flow-push."
  git -C "$R" push -q -u origin SCRUM-1/add-filter
  run ship.sh fake-repo push-update
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: nothing new to push to the MR
   Fix: Commit the review fix first (bash scripts/ship.sh fake-repo commit …)."
  echo "x" >> "$R/app.js"
  run ship.sh fake-repo push-update
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo has uncommitted changes to tracked files
   Fix: Commit the fix first (bash scripts/ship.sh fake-repo commit …), or ask the user what they are."
  git -C "$R" checkout -q -- app.js; git -C "$R" remote set-url origin "$T/nowhere.git"
  run ship.sh fake-repo push-update
  assert_rc 1; assert_contains "$OUT" "❌ fake-repo: can't reach GitLab"
}
test_push_update_when_someone_else_pushed() {
  setup_ship; pushed_branch
  git -C "$U" fetch -q origin && git -C "$U" checkout -q -b SCRUM-1/add-filter origin/SCRUM-1/add-filter &&
    printf 'theirs\n' > "$U/theirs.js" && git -C "$U" add -A && git -C "$U" commit -q -m "SCRUM-1: theirs" && git -C "$U" push -q origin SCRUM-1/add-filter || fail "their push"
  commit_here feature.js "fixed"
  run ship.sh fake-repo push-update
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: the branch on GitLab has commits this Mac doesn't have (or history that differs)
   Fix: Ask the user: someone else pushed to SCRUM-1/add-filter. Look with git -C \"$R\" log HEAD..origin/SCRUM-1/add-filter; closio-agent never forces a push or rebases during review."
  assert_eq "$(git -C "$G" log -1 --format=%s SCRUM-1/add-filter)" "SCRUM-1: theirs"
}
test_push_update_that_fails() {
  setup_ship; pushed_branch; commit_here feature.js "fixed"
  hook pre-push 'echo "lint failed"; exit 1'
  run ship.sh fake-repo push-update
  assert_rc 1
  assert_contains "$OUT" "❌ fake-repo: the push failed (the pre-push hook, the VPN or GitLab)"
  assert_contains "$OUT" "        lint failed"
}

# ---------------------------------------------------------------- usage
test_wrong_usage_shows_the_usage() {
  setup_ship
  local args
  for args in "" "fake-repo" "fake-repo status extra" "fake-repo commit SCRUM-1:_x" "fake-repo push" "fake-repo push-update x" "fake-repo deploy"; do
    run ship.sh $args
    assert_rc 2
    assert_eq "$OUT" "Usage: bash scripts/ship.sh <repo> status | <repo> commit \"<message>\" <file>... | <repo> push \"<MR title>\" [--label <label>]... | <repo> push-update"
  done
}
