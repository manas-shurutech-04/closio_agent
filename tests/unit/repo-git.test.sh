# scripts/repo-git.sh: read-only git in a registered repo (log, diff, status, show), never showing a .env file.

# A registered repo "fake-repo" with a clone in "$R" (a folder with a space): app.js, a tracked .env.dev with a secret
setup_repo() {
  sandbox
  R="$T/fake repo"
  mkdir -p "$R" "$A/local/repos"
  git init -q -b develop "$R"
  printf 'SECRET_X=s3cr3t\n' > "$R/.env.dev"
  mkdir -p "$R/sub"; printf 'SUB_SECRET=deep\n' > "$R/sub/.env"
  echo "one" > "$R/app.js"
  git -C "$R" add -A && git -C "$R" commit -q -m "first commit" || fail "the fake repo"
  printf 'name: fake-repo\nlanguage: node\nbase_branch: develop\n' > "$A/config/repos/fake-repo.yaml"
  printf 'local_path: %s\n' "$R" > "$A/local/repos/fake-repo.yaml"
}

test_log_runs_in_the_repo_folder() {
  setup_repo
  run repo-git.sh fake-repo log --oneline
  assert_rc 0; assert_match "$OUT" '^[0-9a-f]+ first commit$'
}
test_diff_shows_the_code_but_never_a_tracked_env_file() {
  setup_repo
  echo "two" >> "$R/app.js"; echo "SECRET_X=changed" > "$R/.env.dev"; echo "SUB_SECRET=new" > "$R/sub/.env"
  run repo-git.sh fake-repo diff
  assert_rc 0; assert_contains "$OUT" "+two"
  assert_not_contains "$OUT" "SECRET"; assert_not_contains "$OUT" ".env"
}
test_diff_stat_leaves_env_files_out() {
  setup_repo
  echo "two" >> "$R/app.js"; echo "SECRET_X=changed" > "$R/.env.dev"
  run repo-git.sh fake-repo diff --stat
  assert_rc 0; assert_contains "$OUT" "app.js"; assert_not_contains "$OUT" ".env"
}
test_diff_with_a_path_after_dashes() {
  setup_repo
  echo "two" >> "$R/app.js"; echo "SECRET_X=changed" > "$R/.env.dev"
  run repo-git.sh fake-repo diff -- app.js
  assert_rc 0; assert_contains "$OUT" "+two"; assert_not_contains "$OUT" "SECRET"
}
test_show_of_a_commit_leaves_its_env_files_out() {
  setup_repo
  run repo-git.sh fake-repo show HEAD
  assert_rc 0; assert_contains "$OUT" "first commit"; assert_contains "$OUT" "+one"
  assert_not_contains "$OUT" "s3cr3t"; assert_not_contains "$OUT" "deep"
}
test_status_works() {
  setup_repo
  echo "two" >> "$R/app.js"
  run repo-git.sh fake-repo status --short
  assert_rc 0; assert_eq "$OUT" " M app.js"
}
test_an_argument_naming_an_env_file_is_refused() {
  setup_repo
  local a
  for a in "HEAD:.env.dev" ".env" "sub/.env" "config.env" ".env.local" "HEAD:sub/.env"; do
    run repo-git.sh fake-repo show "$a"
    assert_rc 1
    assert_eq "$OUT" "❌ An argument names a .env file ($a)
   Fix: Its values are never shown (rule A6). Leave it out."
  done
  run repo-git.sh fake-repo diff -- .env.dev
  assert_rc 1; assert_not_contains "$OUT" "s3cr3t"
}
test_output_and_ext_diff_are_refused() {
  setup_repo
  run repo-git.sh fake-repo diff --output=x.txt
  assert_rc 1; assert_contains "$OUT" "❌ --output writes a file"; assert_contains "$OUT" "Fix: Leave it out: the output is shown here."
  assert_no_file "$R/x.txt"
  run repo-git.sh fake-repo diff --output
  assert_rc 1; assert_contains "$OUT" "--output writes a file"
  run repo-git.sh fake-repo log --ext-diff
  assert_rc 1; assert_eq "$OUT" "❌ --ext-diff runs another program
   Fix: Leave it out."
}
test_a_command_that_changes_the_repo_is_refused() {
  setup_repo
  run repo-git.sh fake-repo push
  assert_rc 2
  assert_eq "$OUT" "❌ 'push' isn't a read-only git command here
   Fix: Use log, diff, status or show. Anything that changes a repo goes through the commands' own scripts."
}
test_an_unknown_repo() {
  setup_repo
  run repo-git.sh nope log
  assert_rc 1
  assert_contains "$OUT" "❌ nope isn't registered (run /flow-configure-repo <path of your clone>)"
  assert_contains "$OUT" "   Fix: Register or clone it first: /flow-configure-repo (Codex: \$flow-configure-repo)."
}
test_a_repo_that_is_not_cloned() {
  setup_repo
  printf 'local_path: not-cloned\n' > "$A/local/repos/fake-repo.yaml"
  run repo-git.sh fake-repo log
  assert_rc 1; assert_contains "$OUT" "❌ fake-repo isn't cloned on this Mac"
}
test_too_few_arguments_shows_the_usage() {
  setup_repo
  run repo-git.sh fake-repo
  assert_rc 2; assert_eq "$OUT" "Usage: bash scripts/repo-git.sh <repo> log | diff | status | show [git arguments…]"
}
