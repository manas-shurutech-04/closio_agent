# scripts/card-branch.sh: the card's branch in a code repo: check, create, update, and flow-push's rebase
# (stash, rebase onto the latest base branch, stash pop) with its rebase-continue after a conflict.

# A registered repo "fake-repo" (base branch develop): its GitLab is a bare repo ($G), a second clone pushes the
# newer commits ($U), and the clone closio-agent works in is "$R" (a folder with a space).
setup_repo() {
  sandbox
  G="$T/gitlab/fake-repo.git"; U="$T/upstream"; R="$T/repos/fake repo"
  mkdir -p "$T/gitlab" "$T/repos" "$A/local/repos"
  git init -q --bare -b develop "$G"
  git init -q -b develop "$U" && git -C "$U" remote add origin "$G"
  printf 'one\ntwo\nthree\n' > "$U/app.js"; echo "readme" > "$U/README.md"
  git -C "$U" add -A && git -C "$U" commit -q -m "first" && git -C "$U" push -q origin develop || fail "the fake GitLab"
  git clone -q "$G" "$R" || fail "the clone"
  printf 'name: fake-repo\ngitlab_url: https://gitlab.example.com/closio/fake-repo.git\nbase_branch: develop   # the base\n' > "$A/config/repos/fake-repo.yaml"
  printf 'local_path: %s\n' "$R" > "$A/local/repos/fake-repo.yaml"
}
upstream_commit() { # <file> <text> [<message>]: a newer commit on develop in GitLab
  git -C "$U" pull -q --ff-only origin develop 2>/dev/null
  printf '%s\n' "$2" > "$U/$1"; git -C "$U" add -A && git -C "$U" commit -q -m "${3:-upstream $1}" && git -C "$U" push -q origin develop || fail "upstream commit"
}
own_commit() { # <file> <text>: a commit on the clone's current branch
  printf '%s\n' "$2" > "$R/$1"; git -C "$R" add -A && git -C "$R" commit -q -m "own $1" || fail "own commit"
}
on_card_branch() { git -C "$R" checkout -q -b SCRUM-1/add-filter || fail "the card's branch"; }
head_of() { git -C "$R" rev-parse "${1:-HEAD}"; }
short() { git -C "$R" rev-parse --short "${1:-HEAD}"; }
offline() { git -C "$R" remote set-url origin "$T/nowhere.git"; }
last2() { printf '%s\n' "$OUT" | tail -2; }   # the ❌ and its fix (git's own error lines come first)
rebase_state() { cat "$A/local/rebase/fake-repo" 2>/dev/null; }
# The card's branch has its own commit on app.js, and develop has a newer one on the same line: the rebase stops.
# With "work": the card also has uncommitted work (a new file, notes.txt), stashed before the rebase.
conflicting_rebase() { # [work]
  on_card_branch; own_commit app.js "mine"
  upstream_commit app.js "theirs"
  [ "${1:-}" = work ] && echo "work" > "$R/notes.txt"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 4
}

# ---------------------------------------------------------------- check and the repo lookup
test_check_shows_the_branch_and_the_changes() {
  setup_repo
  run card-branch.sh check fake-repo
  assert_rc 0; assert_eq "$OUT" "✅ fake-repo: on branch develop, base branch develop, 0 uncommitted change(s) to tracked files ($R)"
  echo "x" >> "$R/app.js"; echo "new" > "$R/untracked.txt"
  run card-branch.sh check fake-repo
  assert_contains "$OUT" "1 uncommitted change(s) to tracked files"
}
test_a_bad_repo_name() {
  setup_repo
  run card-branch.sh check Bad_Repo
  assert_rc 1
  assert_eq "$OUT" "❌ 'Bad_Repo' isn't a repo name
   Fix: Use the name of a registered repo (see /flow-configure-repo)."
}
test_a_repo_that_is_not_registered() {
  setup_repo
  run card-branch.sh check nope
  assert_rc 1
  assert_eq "$OUT" "❌ nope isn't registered
   Fix: Register it with /flow-configure-repo <path of your clone> (Codex: \$flow-configure-repo …)."
}
test_a_repo_without_a_base_branch() {
  setup_repo
  printf 'name: fake-repo\n' > "$A/config/repos/fake-repo.yaml"
  run card-branch.sh check fake-repo
  assert_rc 1
  assert_eq "$OUT" "❌ config/repos/fake-repo.yaml has no base_branch
   Fix: Add the line base_branch: <branch> (e.g. develop) and commit it."
}
test_a_repo_that_is_not_cloned() {
  setup_repo
  local p
  for p in "not-cloned" "$T/missing"; do
    printf 'local_path: %s\n' "$p" > "$A/local/repos/fake-repo.yaml"
    run card-branch.sh check fake-repo
    assert_rc 1
    assert_eq "$OUT" "❌ fake-repo isn't cloned on this Mac (cloning is manual)
   Fix: On the VPN: git clone https://gitlab.example.com/closio/fake-repo.git <your workspace folder>/fake-repo, then run /flow-configure-repo fake-repo path <that folder>."
  done
  rm -f "$A/local/repos/fake-repo.yaml"
  run card-branch.sh check fake-repo
  assert_rc 1; assert_contains "$OUT" "isn't cloned on this Mac"
}
test_the_clone_gitlab_project_is_matched_in_every_url_form() {
  setup_repo
  printf 'gitlab_path: closio/backend/fake-repo\n' >> "$A/config/repos/fake-repo.yaml"
  local url
  for url in "https://oauth2:tok@gitlab.example.com/closio/backend/fake-repo.git" "git@gitlab.example.com:closio/backend/fake-repo.git" \
             "https://gitlab.example.com/closio/backend/fake-repo"; do
    git -C "$R" remote set-url origin "$url"
    run card-branch.sh check fake-repo
    assert_rc 0
  done
  git -C "$R" remote set-url origin "https://gitlab.example.com/closio/other.git"
  run card-branch.sh check fake-repo
  assert_rc 1
  assert_eq "$OUT" "❌ The clone at $R is a different project (closio/other, expected closio/backend/fake-repo)
   Fix: Point closio-agent at the right clone: /flow-configure-repo fake-repo path <folder>."
}

# ---------------------------------------------------------------- create
test_create_makes_the_branch_from_the_latest_base() {
  setup_repo
  upstream_commit app.js "newer"
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "✅ fake-repo: branch SCRUM-1/add-filter created from the latest develop ($(short))"
  assert_eq "$(git -C "$R" rev-parse --abbrev-ref HEAD)" "SCRUM-1/add-filter"
  assert_eq "$(head_of)" "$(git -C "$G" rev-parse develop)"
  assert_eq "$(head_of develop)" "$(git -C "$G" rev-parse develop)" "the base branch was pulled too"
}
test_create_with_a_name_that_breaks_the_rule() {
  setup_repo
  run card-branch.sh create fake-repo feature/Add_Filter
  assert_rc 1
  assert_eq "$OUT" "❌ 'feature/Add_Filter' doesn't follow the branch-naming rule
   Fix: Make one with: bash scripts/branch-name.sh make <CARD-KEY> \"<card title>\"."
}
test_create_stops_on_uncommitted_changes() {
  setup_repo
  echo "x" >> "$R/app.js"
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 3
  assert_eq "$OUT" "⚠️ fake-repo has 1 uncommitted change(s) to tracked files on develop
   Tip: Stop here and ask the user: commit or stash them (git -C \"$R\" stash), then run this again. The agent never throws changes away."
  assert_eq "$(git -C "$R" rev-parse --abbrev-ref HEAD)" "develop"
}
test_create_without_gitlab() {
  setup_repo; offline
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: can't reach GitLab to fetch
   Fix: Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."
}
test_create_reuses_a_branch_on_this_mac_and_brings_it_up_to_date() {
  setup_repo
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  own_commit feature.js "f1"; git -C "$R" push -q -u origin SCRUM-1/add-filter
  git -C "$U" fetch -q origin && git -C "$U" checkout -q -b SCRUM-1/add-filter origin/SCRUM-1/add-filter
  printf 'f2\n' > "$U/feature.js"; git -C "$U" commit -q -am "teammate" && git -C "$U" push -q origin SCRUM-1/add-filter
  git -C "$U" checkout -q develop
  git -C "$R" checkout -q develop
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "⚠️ fake-repo: the branch SCRUM-1/add-filter already existed; it's checked out and reused (resuming)
   Tip: If that's not what you want, delete it first: git -C \"$R\" branch -D SCRUM-1/add-filter"
  assert_eq "$(git -C "$R" rev-parse --abbrev-ref HEAD)" "SCRUM-1/add-filter"
  assert_eq "$(cat "$R/feature.js")" "f2"
}
test_create_reuses_a_branch_whose_upstream_moved_on() {
  setup_repo
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  own_commit feature.js "f1"; git -C "$R" push -q -u origin SCRUM-1/add-filter
  git -C "$U" fetch -q origin && git -C "$U" checkout -q -b SCRUM-1/add-filter origin/SCRUM-1/add-filter
  printf 'theirs\n' > "$U/feature.js"; git -C "$U" commit -q -am "teammate" && git -C "$U" push -q origin SCRUM-1/add-filter
  own_commit feature.js "mine"
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_contains "$OUT" "⚠️ fake-repo: SCRUM-1/add-filter has an upstream but couldn't fast-forward
   Tip: Look at git -C \"$R\" status when you get to pushing."
  assert_contains "$OUT" "already existed; it's checked out and reused"
  assert_eq "$(cat "$R/feature.js")" "mine"
}
test_create_reuses_a_branch_that_is_only_on_gitlab() {
  setup_repo
  git -C "$U" checkout -q -b SCRUM-1/add-filter && own="$(git -C "$U" rev-parse HEAD)" && git -C "$U" push -q origin SCRUM-1/add-filter
  git -C "$U" checkout -q develop
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "⚠️ fake-repo: the branch SCRUM-1/add-filter already existed on GitLab; it's checked out and reused (resuming)
   Tip: If that's not what you want, pick another name."
  assert_eq "$(git -C "$R" rev-parse --abbrev-ref '@{u}')" "origin/SCRUM-1/add-filter"
}
test_create_when_the_base_branch_is_not_on_this_mac_yet() {
  setup_repo
  git -C "$R" checkout -q -b scratch && git -C "$R" branch -q -D develop
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_contains "$OUT" "✅ fake-repo: branch SCRUM-1/add-filter created from the latest develop"
  assert_eq "$(git -C "$R" rev-parse --abbrev-ref 'develop@{u}')" "origin/develop"
}
test_create_when_the_base_branch_is_not_on_gitlab() {
  setup_repo
  sed -i '' 's/^base_branch: .*/base_branch: release/' "$A/config/repos/fake-repo.yaml"
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$(last2)" "❌ fake-repo: the base branch release isn't on GitLab
   Fix: Check base_branch in config/repos/fake-repo.yaml."
}
test_create_when_the_base_branch_cannot_be_pulled() {
  setup_repo
  own_commit local.js "a local commit on develop"
  upstream_commit app.js "newer"
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_contains "$OUT" "❌ fake-repo: couldn't pull the latest develop (not a fast-forward?)
   Fix: In the clone: git -C \"$R\" status; fix the base branch by hand, then run this again."
}
test_create_when_git_cannot_switch_branches() {
  setup_repo
  # An untracked file in the way of the branch it switches to: git refuses (and the agent never overwrites it)
  git -C "$R" checkout -q -b SCRUM-1/add-filter && own_commit blocker.txt "tracked on the branch"
  git -C "$R" checkout -q develop; echo "untracked" > "$R/blocker.txt"
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$(last2)" "❌ fake-repo: couldn't switch to SCRUM-1/add-filter
   Fix: Check git -C \"$R\" status."
  git -C "$R" push -q origin SCRUM-1/add-filter; git -C "$R" branch -q -D SCRUM-1/add-filter
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$(last2)" "❌ fake-repo: couldn't create SCRUM-1/add-filter from origin/SCRUM-1/add-filter
   Fix: Check git -C \"$R\" status."
  assert_eq "$(cat "$R/blocker.txt")" "untracked"
}
test_create_when_git_cannot_switch_to_the_base_branch() {
  setup_repo
  git -C "$R" checkout -q -b scratch && git -C "$R" rm -q README.md && git -C "$R" commit -q -m "no readme"
  echo "untracked readme" > "$R/README.md"
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$(last2)" "❌ fake-repo: couldn't switch to the base branch develop
   Fix: Check git -C \"$R\" status."
}
test_create_when_git_cannot_make_the_branch() {
  setup_repo
  git -C "$R" branch -q SCRUM-1   # a branch named like the card's key: SCRUM-1/… can't be made next to it
  run card-branch.sh create fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$(last2)" "❌ fake-repo: couldn't create the branch SCRUM-1/add-filter
   Fix: Check git -C \"$R\" status."
}

# ---------------------------------------------------------------- update
test_update_a_branch_that_is_up_to_date() {
  setup_repo; on_card_branch
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 0; assert_eq "$OUT" "✅ fake-repo: SCRUM-1/add-filter is up to date with the latest develop ($(short))"
}
test_update_moves_a_branch_without_own_commits_forward() {
  setup_repo; on_card_branch; git -C "$R" checkout -q develop
  upstream_commit app.js "newer"; upstream_commit lib.js "newest"
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "✅ fake-repo: SCRUM-1/add-filter moved forward to the latest develop: 2 new commit(s) ($(short))"
  assert_eq "$(git -C "$R" rev-parse --abbrev-ref HEAD)" "SCRUM-1/add-filter"
  assert_eq "$(head_of)" "$(git -C "$G" rev-parse develop)"
  assert_eq "$(head_of develop)" "$(git -C "$G" rev-parse develop)" "the local base branch too"
}
test_update_leaves_a_branch_with_its_own_commits_alone() {
  setup_repo; on_card_branch; own_commit feature.js "f"
  before="$(head_of)"
  upstream_commit app.js "newer"
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "⚠️ fake-repo: SCRUM-1/add-filter has 1 commit(s) of its own and develop has 1 newer one(s); left as it is
   Tip: The latest develop comes in with the rebase in flow-push (stash, rebase, stash pop). Read the newer develop code with: git -C \"$R\" diff SCRUM-1/add-filter...origin/develop"
  assert_eq "$(head_of)" "$before"
}
test_update_checks_before_it_changes_anything() {
  setup_repo
  run card-branch.sh update fake-repo Bad_Name
  assert_rc 1; assert_contains "$OUT" "❌ 'Bad_Name' doesn't follow the branch-naming rule"
  assert_contains "$OUT" "Fix: Use the card's branch name from its folder: bash scripts/run.sh get <CARD-KEY> branch."
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: there's no branch SCRUM-1/add-filter on this Mac
   Fix: Create it first: bash scripts/card-branch.sh create fake-repo SCRUM-1/add-filter"
  on_card_branch; echo "x" >> "$R/app.js"
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 3; assert_contains "$OUT" "⚠️ fake-repo has 1 uncommitted change(s) to tracked files on SCRUM-1/add-filter"
  git -C "$R" checkout -q -- app.js; offline
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 1; assert_contains "$OUT" "❌ fake-repo: can't reach GitLab to fetch"
}
test_update_when_the_base_branch_is_not_on_gitlab() {
  setup_repo; on_card_branch
  sed -i '' 's/^base_branch: .*/base_branch: release/' "$A/config/repos/fake-repo.yaml"
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 1; assert_contains "$OUT" "❌ fake-repo: the base branch release isn't on GitLab"
}
test_update_when_git_cannot_switch_or_move_forward() {
  setup_repo; on_card_branch; own_commit blocker.txt "tracked"
  git -C "$R" checkout -q develop; echo "untracked" > "$R/blocker.txt"
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 1; assert_eq "$(last2)" "❌ fake-repo: couldn't switch to SCRUM-1/add-filter
   Fix: Check git -C \"$R\" status."
  rm "$R/blocker.txt"; git -C "$R" checkout -q SCRUM-1/add-filter; git -C "$R" reset -q --hard develop
  upstream_commit incoming.txt "from develop"; echo "untracked" > "$R/incoming.txt"
  run card-branch.sh update fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$(last2)" "❌ fake-repo: couldn't move SCRUM-1/add-filter forward to the latest develop
   Fix: Check git -C \"$R\" status, then run this again."
}

# ---------------------------------------------------------------- rebase
test_rebase_without_uncommitted_changes() {
  setup_repo; on_card_branch; own_commit feature.js "f"
  upstream_commit app.js "newer"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "✅ fake-repo: SCRUM-1/add-filter is rebased onto the latest develop ($(short)); there were no uncommitted changes
✅ fake-repo: 1 newer commit(s) from develop came in"
  assert_eq "$(head_of HEAD^)" "$(git -C "$G" rev-parse develop)"
  assert_no_file "$A/local/rebase/fake-repo"
}
test_rebase_with_nothing_new_on_the_base() {
  setup_repo; on_card_branch; own_commit feature.js "f"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 0; assert_contains "$OUT" "✅ fake-repo: nothing new on develop"
}
test_rebase_stashes_the_card_changes_and_puts_them_back() {
  setup_repo; on_card_branch; own_commit feature.js "f"
  upstream_commit lib.js "newer"
  echo "work" >> "$R/feature.js"; echo "brand new" > "$R/new-file.js"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "✅ fake-repo: SCRUM-1/add-filter is rebased onto the latest develop ($(short)); the card's changes are back (2 file(s))
✅ fake-repo: 1 newer commit(s) from develop came in"
  assert_eq "$(cat "$R/new-file.js")" "brand new"; assert_contains "$(cat "$R/feature.js")" "work"
  assert_eq "$(git -C "$R" stash list)" ""
}
test_rebase_checks_before_it_changes_anything() {
  setup_repo
  run card-branch.sh rebase fake-repo Bad_Name
  assert_rc 1; assert_contains "$OUT" "❌ 'Bad_Name' doesn't follow the branch-naming rule"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo is on develop, not on the card's branch SCRUM-1/add-filter
   Fix: Ask the user: switch with git -C \"$R\" switch SCRUM-1/add-filter (their uncommitted work must come along), then run this again."
  on_card_branch; offline
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 1; assert_contains "$OUT" "❌ fake-repo: can't reach GitLab to fetch"
  assert_no_file "$A/local/rebase/fake-repo"
}
test_rebase_when_the_base_branch_is_not_on_gitlab() {
  setup_repo; on_card_branch
  sed -i '' 's/^base_branch: .*/base_branch: release/' "$A/config/repos/fake-repo.yaml"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 1; assert_contains "$OUT" "❌ fake-repo: the base branch release isn't on GitLab"
}
test_rebase_when_git_is_already_rebasing() {
  setup_repo; on_card_branch
  mkdir -p "$R/.git/rebase-merge"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: a git rebase is already in progress (not started by closio-agent)
   Fix: Finish or undo it by hand (git -C \"$R\" rebase --continue or --abort), then run this again."
}
test_rebase_that_fails_without_a_conflict() {
  setup_repo; on_card_branch; own_commit feature.js "f"
  upstream_commit app.js "newer"
  printf '#!/bin/sh\nexit 1\n' > "$R/.git/hooks/pre-rebase"; chmod +x "$R/.git/hooks/pre-rebase"
  echo "work" >> "$R/feature.js"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: the rebase onto develop failed
   Fix: Look at git -C \"$R\" status. The card's changes are safe in the stash (git stash list). Then: bash scripts/card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter"
  assert_contains "$(git -C "$R" stash list)" "closio-agent: SCRUM-1/add-filter before the rebase onto develop"
}
test_a_rebase_conflict_stops_and_says_which_files() {
  setup_repo
  conflicting_rebase work
  assert_eq "$OUT" "⚠️ fake-repo: a conflict in the rebase (the branch's own commits against the newer develop); resolve these files (keep the right code, remove the <<<<<<< ======= >>>>>>> lines):
   app.js
   Tip: when they're resolved, run: bash scripts/card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
   To undo the rebase instead: git -C \"$R\" rebase --abort, then the same rebase-continue (it puts your changes back)."
  assert_match "$(rebase_state)" "^branch=SCRUM-1/add-filter
stash=[0-9a-f]{40}
stage=rebase
files=
newer=1\$"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 4
  assert_eq "$OUT" "⚠️ fake-repo: a rebase is already half-way (rebase)
   Tip: Finish it first: bash scripts/card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter"
}
test_rebase_continue_with_conflict_markers_left() {
  setup_repo; conflicting_rebase
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 4
  assert_contains "$OUT" "⚠️ fake-repo: a conflict in the rebase; resolve these files"
  assert_contains "$OUT" "   app.js"
  assert_contains "$OUT" "   To undo the rebase instead: git -C \"$R\" rebase --abort, then the same rebase-continue (it puts your changes back)."
}
test_rebase_continue_after_the_conflict_is_resolved() {
  setup_repo
  conflicting_rebase work
  echo "resolved" > "$R/app.js"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "✅ fake-repo: SCRUM-1/add-filter is rebased onto the latest develop ($(short)); the card's changes are back (1 file(s))
✅ fake-repo: 1 newer commit(s) from develop came in"
  assert_eq "$(cat "$R/app.js")" "resolved"; assert_eq "$(cat "$R/notes.txt")" "work"
  assert_eq "$(head_of HEAD^)" "$(git -C "$G" rev-parse develop)"
  assert_no_file "$A/local/rebase/fake-repo"
}
test_rebase_continue_when_the_next_commit_conflicts_too() {
  setup_repo; on_card_branch
  own_commit app.js "mine 1"; own_commit app.js "mine 2"
  upstream_commit app.js "theirs"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 4
  echo "theirs and mine 1" > "$R/app.js"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 4
  assert_contains "$OUT" "⚠️ fake-repo: a conflict in the rebase (the next commit); resolve these files"
  assert_contains "$OUT" "   To undo the rebase instead: git -C \"$R\" rebase --abort" "the undo tip at the next commit's conflict too"
  assert_contains "$OUT" "   app.js"
}
test_rebase_continue_when_git_stops_again_without_a_conflict() {
  setup_repo; on_card_branch
  own_commit app.js "mine"; own_commit feature.js "f"
  upstream_commit app.js "theirs"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 4
  # A "break" in git's own to-do list: --continue succeeds, but the rebase stops again
  todo="$R/.git/rebase-merge/git-rebase-todo"; { echo "break"; cat "$todo"; } > "$todo.new" && mv "$todo.new" "$todo"
  echo "resolved" > "$R/app.js"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 4; assert_contains "$OUT" "⚠️ fake-repo: a conflict in the rebase (the next commit)"
}
test_rebase_continue_when_git_rebase_continue_fails() {
  setup_repo; on_card_branch
  own_commit app.js "mine"
  upstream_commit app.js "theirs"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 4
  echo "resolved" > "$R/app.js"; echo "an unstaged edit" >> "$R/README.md"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: git rebase --continue failed
   Fix: Look at git -C \"$R\" status; then run this again."
}
test_rebase_continue_after_the_rebase_was_undone() {
  setup_repo
  conflicting_rebase work
  git -C "$R" rebase --abort
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "⚠️ fake-repo: the rebase was undone (git rebase --abort): the card's changes are back, but SCRUM-1/add-filter isn't on the latest develop
   Tip: Ask the user how to go on; to try again: bash scripts/card-branch.sh rebase fake-repo SCRUM-1/add-filter"
  assert_eq "$(cat "$R/notes.txt")" "work"; assert_no_file "$A/local/rebase/fake-repo"
}
test_rebase_continue_after_an_undone_rebase_without_changes() {
  setup_repo; conflicting_rebase
  git -C "$R" rebase --abort
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 1; assert_contains "$OUT" "⚠️ fake-repo: the rebase was undone (git rebase --abort)"
}
test_a_stash_pop_conflict_stops_and_continues_once_resolved() {
  setup_repo; on_card_branch
  upstream_commit app.js "theirs"
  echo "my uncommitted line" > "$R/app.js"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 4
  assert_contains "$OUT" "⚠️ fake-repo: a conflict in the stash pop (the card's changes against the newer develop); resolve these files"
  assert_not_contains "$OUT" "To undo the rebase instead"
  assert_contains "$(rebase_state)" "stage=pop-conflict
files=app.js
"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 4; assert_contains "$OUT" "a conflict in the stash pop; resolve these files"
  echo "theirs and mine" > "$R/app.js"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 0
  assert_eq "$OUT" "✅ fake-repo: conflicts resolved; SCRUM-1/add-filter is on the latest develop ($(short)) with the card's changes on top
✅ fake-repo: 1 newer commit(s) from develop came in"
  assert_eq "$(git -C "$R" stash list)" ""; assert_eq "$(git -C "$R" diff --cached --name-only)" ""
  assert_no_file "$A/local/rebase/fake-repo"
}
test_a_stash_that_cannot_be_put_back() {
  setup_repo; on_card_branch
  upstream_commit new-file.js "from develop"
  echo "my new file" > "$R/new-file.js"
  run card-branch.sh rebase fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: the card's changes couldn't be put back (git stash pop failed)
   Fix: They're safe in the stash: git -C \"$R\" stash list (look for \"closio-agent\"). Ask the user."
  assert_contains "$(git -C "$R" stash list)" "closio-agent"
}
test_rebase_continue_when_the_stash_is_gone() {
  setup_repo; on_card_branch
  mkdir -p "$A/local/rebase"
  printf 'branch=SCRUM-1/add-filter\nstash=0123456789abcdef0123456789abcdef01234567\nstage=rebase\nfiles=\nnewer=0\n' > "$A/local/rebase/fake-repo"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: the stash with the card's changes (0123456789abcdef0123456789abcdef01234567) is gone
   Fix: Look for it: git -C \"$R\" stash list; git -C \"$R\" fsck --unreachable | grep commit. Ask the user before doing anything else."
}
test_rebase_continue_with_nothing_stopped_or_another_branch_or_an_odd_state() {
  setup_repo; on_card_branch
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 0; assert_eq "$OUT" "✅ fake-repo: nothing to continue (no rebase was stopped)"
  mkdir -p "$A/local/rebase"
  printf 'branch=SCRUM-2/other\nstash=none\nstage=rebase\n' > "$A/local/rebase/fake-repo"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: the stopped rebase is for SCRUM-2/other, not SCRUM-1/add-filter
   Fix: Run: bash scripts/card-branch.sh rebase-continue fake-repo SCRUM-2/other"
  printf 'branch=SCRUM-1/add-filter\nstash=none\nstage=odd\n' > "$A/local/rebase/fake-repo"
  run card-branch.sh rebase-continue fake-repo SCRUM-1/add-filter
  assert_rc 1
  assert_eq "$OUT" "❌ fake-repo: unknown rebase state in local/rebase/fake-repo
   Fix: Look at git -C \"$R\" status and git stash list, then delete local/rebase/fake-repo."
  run card-branch.sh rebase-continue nope SCRUM-1/add-filter
  assert_rc 1; assert_contains "$OUT" "❌ nope isn't registered"
}

# ---------------------------------------------------------------- usage
test_wrong_usage_shows_the_usage() {
  setup_repo
  local a
  for a in "" check create update rebase rebase-continue help nothing; do
    run card-branch.sh $a
    assert_rc 2; assert_contains "$OUT" "Usage: bash scripts/card-branch.sh check <repo>"
  done
  run card-branch.sh create fake-repo
  assert_rc 2
}
