# scripts/gitlab-mr.sh: a card's merge request through the GitLab REST API, against the fake HTTP server
# (tests/fakes/http.py) as GitLab; the token comes from the fake Keychain (closio-agent.gitlab-token).

TOKEN="glpat-test-123"
MRS='/projects/closio%2Fbackend%2Ffake-be/merge_requests'

# register_repo <name> <folder> [<yaml line>…]: the repo's shared file and its local_path, in the sandbox
register_repo() {
  local name="$1" dir="$2" l; shift 2
  mkdir -p "$dir" "$A/local/repos"
  printf 'name: %s\n' "$name" > "$A/config/repos/$name.yaml"
  for l in "$@"; do printf '%s\n' "$l" >> "$A/config/repos/$name.yaml"; done
  printf 'local_path: %s\n' "$dir" > "$A/local/repos/$name.yaml"
}

# The GitLab answers every test starts from; route_first puts one in front (the first route that fits answers).
setup_gitlab() {
  sandbox
  register_repo fake-be "$T/repos/fake be" "gitlab_path: closio/backend/fake-be   # the project"
  keychain_set closio-agent.gitlab-token "$TOKEN"
  cat > "$T/routes.json" <<'JSON'
[
 {"method": "GET", "path": "/merge_requests$", "query": "state=opened", "json": [{"iid": 12, "title": "SCRUM-1: Scheme filter", "web_url": "https://gitlab.test/mr/12"}]},
 {"method": "GET", "path": "/merge_requests$", "query": "state=all", "json": [{"iid": 12, "state": "merged", "merge_commit_sha": "abcdef1234567890", "merged_at": "2026-10-20T08:15:30.000Z", "web_url": "https://gitlab.test/mr/12"}]},
 {"method": "GET", "path": "^/users$", "query": "username=ana.s$", "json": [{"id": 5, "username": "ana.s"}]},
 {"method": "GET", "path": "^/users$", "query": "username=budi$", "json": [{"id": 7, "username": "budi"}]},
 {"method": "GET", "path": "^/users$", "json": []},
 {"method": "PUT", "path": "/merge_requests/12$", "json": {"iid": 12}},
 {"method": "GET", "path": "/merge_requests/12$", "json": {"iid": 12, "has_conflicts": false, "head_pipeline": null}},
 {"method": "GET", "path": "/merge_requests/12/approvals$", "json": {"approved_by": [{"user": {"username": "ana.s"}}]}},
 {"method": "GET", "path": "/merge_requests/12/discussions$", "json": [
   {"id": "aaaa1111bbbb2222", "notes": [
     {"id": 101, "system": false, "resolvable": true, "resolved": false, "author": {"username": "ana.s"}, "created_at": "2026-10-20T08:15:30.000Z", "body": "Please rename this.\nAnd add a test.", "position": {"new_path": "src/a.js", "new_line": 12}},
     {"id": 105, "system": false, "resolvable": true, "resolved": false, "author": {"username": "me.dev"}, "created_at": "2026-10-21T09:00:00.000Z", "body": "Done.", "position": {"new_path": "src/a.js", "new_line": 12}}]},
   {"id": "cccc3333dddd4444", "notes": [
     {"id": 102, "system": false, "resolvable": true, "resolved": true, "author": {"username": "ana.s"}, "created_at": "2026-10-20T08:20:00.000Z", "body": "ok", "position": {"old_path": "src/b.js", "old_line": 3, "new_path": null, "new_line": null}}]},
   {"id": "eeee5555ffff6666", "notes": [
     {"id": 103, "system": true, "resolvable": false, "author": {"username": "ana.s"}, "created_at": "2026-10-20T08:21:00.000Z", "body": "added 1 commit", "position": null}]},
   {"id": "9999aaaa0000bbbb", "notes": [
     {"id": 110, "system": false, "resolvable": false, "author": {"username": "budi"}, "created_at": "2026-10-22T10:00:00.000Z", "body": "Nice work", "position": null}]}]},
 {"method": "POST", "path": "/discussions/[0-9a-f]+/notes$", "status": 201, "json": {"id": 901}},
 {"method": "GET", "path": "/pipelines/77/jobs$", "json": [{"name": "unit-tests", "stage": "test", "web_url": "https://gitlab.test/jobs/1"}, {"name": "lint", "stage": "check", "web_url": "https://gitlab.test/jobs/2"}]}
]
JSON
  start_fake GITLAB_API_URL http "$T/routes.json"
}
route_first() { jq --argjson r "$1" '[$r] + .' "$T/routes.json" > "$T/routes.tmp" && mv "$T/routes.tmp" "$T/routes.json"; }
requests() { fake_requests GITLAB_API_URL; }

test_find_shows_the_open_mr_and_sends_the_token_only_in_a_header() {
  setup_gitlab
  run gitlab-mr.sh fake-be find "SCRUM-1/scheme-filter"
  assert_rc 0
  assert_eq "$OUT" "✅ fake-be: MR !12 · SCRUM-1: Scheme filter · https://gitlab.test/mr/12"
  local r; r="$(requests | head -1)"
  assert_eq "$(printf '%s' "$r" | jq -r '.p')" "$MRS"
  assert_eq "$(printf '%s' "$r" | jq -r '.q')" "state=opened&source_branch=SCRUM-1%2Fscheme-filter"
  assert_eq "$(printf '%s' "$r" | jq -r '.h["PRIVATE-TOKEN"]')" "$TOKEN" "the token goes in the PRIVATE-TOKEN header"
  assert_not_contains "$OUT" "$TOKEN"
}

test_find_when_the_branch_has_no_open_mr() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/merge_requests$", "query": "state=opened", "json": []}'
  run gitlab-mr.sh fake-be find SCRUM-1/x
  assert_rc 1
  assert_eq "$OUT" "❌ fake-be: no open MR for the branch SCRUM-1/x
   Fix: Push it first (bash scripts/ship.sh fake-be push \"<title>\"), or check the branch name."
}

test_without_a_token_nothing_is_sent() {
  setup_gitlab; rm -f "$FAKE_KEYCHAIN/closio-agent.gitlab-token"
  run gitlab-mr.sh fake-be find SCRUM-1/x
  assert_rc 1
  assert_contains "$OUT" "❌ Your GitLab token isn't in the Keychain"
  assert_contains "$OUT" "Fix: Run /flow-configure-user gitlab-token"
  assert_eq "$(requests)" "" "no request without a token"
}

test_gitlab_not_answering_says_connect_the_vpn() {
  setup_gitlab; export GITLAB_API_URL="http://127.0.0.1:1" GITLAB_API_TIMEOUT=3
  run gitlab-mr.sh fake-be find SCRUM-1/x
  assert_rc 1
  assert_eq "$OUT" "❌ GitLab didn't answer (the open MR of SCRUM-1/x)
   Fix: Connect the VPN: /flow-vpn connect (Codex: \$flow-vpn connect), then run this again."
}

test_each_refusal_has_its_own_fix() {
  setup_gitlab
  cp "$T/routes.json" "$T/routes.base"
  route_first '{"path": ".", "status": 401, "json": {"message": "401 Unauthorized"}}'
  run gitlab-mr.sh fake-be find SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ GitLab refused your token (the open MR of SCRUM-1/x: 401)"; assert_contains "$OUT" "make a new personal access token"
  cp "$T/routes.base" "$T/routes.json"; route_first '{"path": ".", "status": 403, "json": {"message": "403 Forbidden"}}'
  run gitlab-mr.sh fake-be find SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ Your token may not do this (the open MR of SCRUM-1/x: 403)"; assert_contains "$OUT" "api scope"
  cp "$T/routes.base" "$T/routes.json"; route_first '{"path": ".", "status": 404, "json": {"message": "404 Project Not Found"}}'
  run gitlab-mr.sh fake-be find SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ GitLab found nothing for the open MR of SCRUM-1/x (404)"; assert_contains "$OUT" "Check gitlab_path in config/repos/fake-be.yaml"
  cp "$T/routes.base" "$T/routes.json"; route_first '{"path": ".", "status": 500, "json": {"error": "database is down"}}'
  run gitlab-mr.sh fake-be find SCRUM-1/x
  assert_rc 1; assert_eq "$OUT" "❌ GitLab answered 500 (the open MR of SCRUM-1/x): database is down
   Fix: Read the message; fix it, then run this again."
}

test_wrong_usage_shows_the_usage() {
  setup_gitlab
  local args
  for args in "fake-be find" "fake-be nothing SCRUM-1/x" "fake-be find a b" "fake-be status a b" "fake-be describe SCRUM-1/x" \
    "fake-be reply SCRUM-1/x aaaa1111" "fake-be pipeline a b"; do
    run gitlab-mr.sh $args
    assert_rc 2; assert_contains "$OUT" "Usage: bash scripts/gitlab-mr.sh <repo> find <branch>" "usage for: $args"
  done
  assert_eq "$(requests)" "" "wrong usage sends nothing"
}

test_an_unregistered_repo_or_one_without_a_gitlab_path() {
  setup_gitlab
  run gitlab-mr.sh nope find SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ nope isn't registered"; assert_contains "$OUT" "Fix: Fix that first"
  register_repo no-path "$T/repos/no-path" "type: BE"
  run gitlab-mr.sh no-path find SCRUM-1/x
  assert_rc 1; assert_eq "$OUT" "❌ config/repos/no-path.yaml has no gitlab_path
   Fix: Add it with /flow-configure-repo no-path."
  register_repo gone "not-cloned" "gitlab_path: x/gone"
  printf 'local_path: not-cloned\n' > "$A/local/repos/gone.yaml"
  run gitlab-mr.sh gone find SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "gone isn't cloned on this Mac"
}

test_status_of_a_merged_mr() {
  setup_gitlab
  run gitlab-mr.sh fake-be status SCRUM-1/x
  assert_rc 0
  assert_eq "$OUT" "✅ fake-be: MR !12 is merged (merge commit abcdef12), 2026-10-20 08:15 UTC · https://gitlab.test/mr/12"
  assert_contains "$(requests | head -1 | jq -r .q)" "state=all&source_branch=SCRUM-1%2Fx&order_by=created_at&sort=desc"
}

test_status_of_a_squashed_merge_without_a_time() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/merge_requests$", "query": "state=all", "json": [{"iid": 13, "state": "merged", "merge_commit_sha": null, "squash_commit_sha": "1234567890ab", "web_url": "https://gitlab.test/mr/13"}]}'
  run gitlab-mr.sh fake-be status SCRUM-1/x
  assert_rc 0; assert_eq "$OUT" "✅ fake-be: MR !13 is merged (merge commit 12345678) · https://gitlab.test/mr/13"
}

test_status_of_an_open_a_closed_and_an_odd_mr() {
  setup_gitlab
  cp "$T/routes.json" "$T/routes.base"
  route_first '{"method": "GET", "path": "/merge_requests$", "query": "state=all", "json": [{"iid": 12, "state": "opened", "web_url": "https://gitlab.test/mr/12"}]}'
  run gitlab-mr.sh fake-be status SCRUM-1/x
  assert_rc 3; assert_eq "$OUT" "⚠️ fake-be: MR !12 isn't merged yet (still open) · https://gitlab.test/mr/12
   Tip: run /flow-finish again once it's merged."
  cp "$T/routes.base" "$T/routes.json"
  route_first '{"method": "GET", "path": "/merge_requests$", "query": "state=all", "json": [{"iid": 12, "state": "closed", "web_url": "https://gitlab.test/mr/12"}]}'
  run gitlab-mr.sh fake-be status SCRUM-1/x
  assert_rc 3; assert_contains "$OUT" "⚠️ fake-be: MR !12 was closed without merging"; assert_contains "$OUT" "Tip: ask the user how to go on"
  cp "$T/routes.base" "$T/routes.json"
  route_first '{"method": "GET", "path": "/merge_requests$", "query": "state=all", "json": [{"iid": 12, "state": "weird", "web_url": "https://gitlab.test/mr/12"}]}'
  run gitlab-mr.sh fake-be status SCRUM-1/x
  assert_rc 1; assert_eq "$OUT" "❌ fake-be: MR !12 has an unknown state 'weird'
   Fix: Look at it on GitLab: https://gitlab.test/mr/12"
}

test_status_without_any_mr_or_when_gitlab_fails() {
  setup_gitlab
  cp "$T/routes.json" "$T/routes.base"
  route_first '{"method": "GET", "path": "/merge_requests$", "query": "state=all", "json": []}'
  run gitlab-mr.sh fake-be status SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ fake-be: no MR for the branch SCRUM-1/x"; assert_contains "$OUT" "Was it pushed with /flow-push?"
  cp "$T/routes.base" "$T/routes.json"
  route_first '{"method": "GET", "path": "/merge_requests$", "query": "state=all", "status": 404, "json": {"message": "404 Not found"}}'
  run gitlab-mr.sh fake-be status SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ GitLab found nothing for the MRs of SCRUM-1/x (404)"
}

test_describe_sets_the_description_and_the_reviewers() {
  setup_gitlab
  printf '## What\n\nThe filter, "quoted" and `code`.\nLast line\n' > "$T/mr.md"
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/mr.md" --reviewers ana.s,budi
  assert_rc 0
  assert_eq "$OUT" "✅ fake-be: MR !12 description set (4 line(s)); reviewers: ana.s, budi · https://gitlab.test/mr/12"
  local put; put="$(requests | jq -c 'select(.m == "PUT")')"
  assert_eq "$(printf '%s' "$put" | jq -r .p)" "$MRS/12"
  assert_eq "$(printf '%s' "$put" | jq -c .b.reviewer_ids)" "[5,7]"
  assert_eq "$(printf '%s' "$put" | jq -r .b.description)" "$(cat "$T/mr.md")"
  assert_eq "$(requests | jq -r 'select(.p == "/users") | .q' | tr '\n' ' ')" "username=ana.s username=budi "
}

test_describe_without_reviewers_sends_only_the_description() {
  setup_gitlab
  printf 'One line\n' > "$T/mr.md"
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/mr.md"
  assert_rc 0
  assert_eq "$OUT" "✅ fake-be: MR !12 description set (1 line(s)) · https://gitlab.test/mr/12"
  assert_eq "$(requests | jq -c 'select(.m == "PUT") | .b')" '{"description":"One line\n"}'
}

test_describe_refuses_a_missing_file_bad_reviewers_and_bad_options() {
  setup_gitlab
  printf 'x\n' > "$T/mr.md"; : > "$T/empty.md"
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/empty.md"
  assert_rc 2; assert_contains "$OUT" "❌ No description file '$T/empty.md' (or it's empty)"
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/mr.md" --reviewers "@ana s"
  assert_rc 2; assert_eq "$OUT" "❌ Reviewers must be GitLab usernames, comma between them
   Fix: e.g. --reviewers ana.s,budi"
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/mr.md" --reviewers
  assert_rc 2; assert_contains "$OUT" "Usage:"
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/mr.md" --labels x
  assert_rc 2; assert_contains "$OUT" "Usage:"
  assert_eq "$(requests)" "" "nothing sent"
}

test_describe_with_an_unknown_reviewer_changes_nothing() {
  setup_gitlab
  printf 'x\n' > "$T/mr.md"
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/mr.md" --reviewers ana.s,nobody
  assert_rc 1
  assert_eq "$OUT" "❌ There's no GitLab user named nobody
   Fix: Check the username (as in their GitLab profile, without @), then run this again."
  assert_eq "$(requests | jq -r 'select(.m == "PUT")')" "" "no PUT"
}

test_describe_when_the_user_lookup_or_the_update_fails() {
  setup_gitlab
  printf 'x\n' > "$T/mr.md"
  cp "$T/routes.json" "$T/routes.base"
  route_first '{"method": "GET", "path": "^/users$", "status": 403, "json": {"message": "403 Forbidden"}}'
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/mr.md" --reviewers ana.s
  assert_rc 1; assert_contains "$OUT" "❌ Your token may not do this (the GitLab user ana.s: 403)"
  cp "$T/routes.base" "$T/routes.json"
  route_first '{"method": "PUT", "path": "/merge_requests/12$", "status": 422, "json": {"message": "description is too long"}}'
  mkdir -p "$T/tmp"
  TMPDIR="$T/tmp" run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/mr.md"
  assert_rc 1; assert_contains "$OUT" "❌ GitLab answered 422 (setting MR !12's description): description is too long"
  assert_eq "$(ls -A "$T/tmp")" "" "the request body file is removed"
}

test_comments_shows_the_review_state_and_every_unresolved_or_new_thread() {
  setup_gitlab; user_settings GITLAB_USERNAME=me.dev
  run gitlab-mr.sh fake-be comments SCRUM-1/x
  assert_rc 0
  assert_eq "$OUT" "MR !12 · SCRUM-1: Scheme filter · approved by: ana.s · conflicts: none · unresolved threads: 1 · https://gitlab.test/mr/12
--- Thread aaaa1111bbbb2222 · src/a.js:12 · unresolved
  [101 · ana.s · 2026-10-20 08:15 UTC] (new)
      Please rename this.
      And add a test.
  [105 · me.dev (you) · 2026-10-21 09:00 UTC] (new)
      Done.
--- Thread cccc3333dddd4444 · src/b.js:3 · resolved
  [102 · ana.s · 2026-10-20 08:20 UTC] (new)
      ok
--- Thread 9999aaaa0000bbbb · general · comment
  [110 · budi · 2026-10-22 10:00 UTC] (new)
      Nice work
3 thread(s) shown (unresolved, or new since note 0). Newest note id: 110"
  assert_contains "$(requests | jq -r 'select(.p | endswith("/discussions")) | .q')" "per_page=100&page=1"
}

test_comments_since_a_note_shows_only_unresolved_and_newer_threads() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/merge_requests/12$", "json": {"iid": 12, "has_conflicts": true}}'
  run gitlab-mr.sh fake-be comments SCRUM-1/x --since 105
  assert_rc 0
  assert_contains "$OUT" "conflicts: yes · unresolved threads: 1"
  assert_contains "$OUT" "--- Thread aaaa1111bbbb2222 · src/a.js:12 · unresolved"
  assert_contains "$OUT" "  [101 · ana.s · 2026-10-20 08:15 UTC]
"
  assert_contains "$OUT" "  [105 · me.dev · 2026-10-21 09:00 UTC]
"
  assert_contains "$OUT" "  [110 · budi · 2026-10-22 10:00 UTC] (new)"
  assert_not_contains "$OUT" "cccc3333dddd4444"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "2 thread(s) shown (unresolved, or new since note 105). Newest note id: 110"
}

test_comments_reads_every_page_of_threads() {
  setup_gitlab
  jq -n '[range(100) | {id: ("p1" + tostring), notes: [{id: (. + 1), system: false, resolvable: true, resolved: true, author: {username: "ana.s"}, created_at: "2026-10-20T08:00:00Z", body: "old", position: null}]}]' > "$T/page1.json"
  route_first "$(jq -n --slurpfile p "$T/page1.json" '{method: "GET", path: "/discussions$", query: "page=1$", json: $p[0]}')"
  route_first '{"method": "GET", "path": "/discussions$", "query": "page=2$", "json": [{"id": "abcdef0123456789", "notes": [{"id": 500, "system": false, "resolvable": true, "resolved": false, "author": {"username": "budi"}, "created_at": "2026-10-22T11:00:00Z", "body": "page two", "position": {"new_path": "x.js", "new_line": 1}}]}]}'
  run gitlab-mr.sh fake-be comments SCRUM-1/x --since 400
  assert_rc 0
  assert_contains "$OUT" "unresolved threads: 1"
  assert_contains "$OUT" "--- Thread abcdef0123456789 · x.js:1 · unresolved"
  assert_eq "$(printf '%s\n' "$OUT" | tail -1)" "1 thread(s) shown (unresolved, or new since note 400). Newest note id: 500"
  assert_eq "$(requests | jq -r 'select(.p | endswith("/discussions")) | .q' | tr '\n' ' ')" "per_page=100&page=1 per_page=100&page=2 "
}

test_comments_when_the_approvals_cannot_be_read() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/approvals$", "status": 403, "json": {"message": "403"}}'
  route_first '{"method": "GET", "path": "/discussions$", "json": []}'
  run gitlab-mr.sh fake-be comments SCRUM-1/x
  assert_rc 0
  assert_eq "$OUT" "MR !12 · SCRUM-1: Scheme filter · approved by: couldn't read (403) · conflicts: none · unresolved threads: 0 · https://gitlab.test/mr/12
0 thread(s) shown (unresolved, or new since note 0). Newest note id: 0"
}

test_comments_nobody_approved_yet() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/approvals$", "json": {"approved_by": []}}'
  run gitlab-mr.sh fake-be comments SCRUM-1/x --since 200
  assert_rc 0; assert_contains "$OUT" "approved by: nobody yet"; assert_contains "$OUT" "Newest note id: 110"
}

test_comments_wrong_options_show_the_usage() {
  setup_gitlab
  run gitlab-mr.sh fake-be comments SCRUM-1/x --since abc
  assert_rc 2; assert_contains "$OUT" "Usage:"
  run gitlab-mr.sh fake-be comments SCRUM-1/x --since
  assert_rc 2
  run gitlab-mr.sh fake-be comments SCRUM-1/x --all
  assert_rc 2
  assert_eq "$(requests)" "" "nothing sent"
}

test_comments_when_gitlab_fails_on_the_mr_the_threads_or_their_content() {
  setup_gitlab
  cp "$T/routes.json" "$T/routes.base"
  route_first '{"method": "GET", "path": "/merge_requests/12$", "status": 500, "json": {"message": "boom"}}'
  run gitlab-mr.sh fake-be comments SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ GitLab answered 500 (MR !12): boom"
  cp "$T/routes.base" "$T/routes.json"
  route_first '{"method": "GET", "path": "/discussions$", "status": 502, "text": "bad gateway"}'
  run gitlab-mr.sh fake-be comments SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ GitLab answered 502 (the threads of MR !12): "
  cp "$T/routes.base" "$T/routes.json"
  route_first '{"method": "GET", "path": "/discussions$", "json": [{"id": "x", "notes": null}]}'
  run gitlab-mr.sh fake-be comments SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ Couldn't read the threads GitLab sent"; assert_contains "$OUT" "look at the MR on GitLab: https://gitlab.test/mr/12"
}

test_comments_when_a_threads_page_is_not_json() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/discussions$", "text": "<html>proxy error</html>"}'
  run gitlab-mr.sh fake-be comments SCRUM-1/x
  assert_rc 1
  assert_eq "$OUT" "❌ GitLab's answer for the threads of MR !12 isn't a list (page 1)
   Fix: Check GitLab is reachable and the token is valid, then run this again."
  assert_eq "$(requests | jq -r 'select(.p | endswith("/discussions")) | .q' | grep -c .)" "1" "no more pages are asked for"
}

test_reply_posts_the_file_as_a_note_in_the_thread() {
  setup_gitlab
  printf 'Renamed it.\nAnd added the test.\n' > "$T/reply.md"
  run gitlab-mr.sh fake-be reply SCRUM-1/x aaaa1111bbbb2222 "$T/reply.md"
  assert_rc 0
  assert_eq "$OUT" "✅ fake-be: reply posted in MR !12, thread aaaa1111bbbb2222 (note 901); the thread stays open for the reviewer · https://gitlab.test/mr/12"
  local post; post="$(requests | jq -c 'select(.m == "POST")')"
  assert_eq "$(printf '%s' "$post" | jq -r .p)" "$MRS/12/discussions/aaaa1111bbbb2222/notes"
  assert_eq "$(printf '%s' "$post" | jq -c .b)" '{"body":"Renamed it.\nAnd added the test.\n"}'
  assert_eq "$(requests | jq -r 'select(.m == "PUT")')" "" "never resolves (no PUT)"
}

test_reply_refuses_a_bad_thread_id_or_an_empty_file() {
  setup_gitlab
  printf 'x\n' > "$T/reply.md"; : > "$T/empty.md"
  run gitlab-mr.sh fake-be reply SCRUM-1/x "THREAD-1" "$T/reply.md"
  assert_rc 2; assert_eq "$OUT" "❌ 'THREAD-1' isn't a thread id
   Fix: Use the id after \"Thread\" in: bash scripts/gitlab-mr.sh fake-be comments SCRUM-1/x"
  run gitlab-mr.sh fake-be reply SCRUM-1/x aaaa1111bbbb2222 "$T/empty.md"
  assert_rc 2; assert_contains "$OUT" "❌ No reply file '$T/empty.md' (or it's empty)"
  assert_eq "$(requests)" "" "nothing sent"
}

test_reply_when_gitlab_refuses_it() {
  setup_gitlab
  printf 'x\n' > "$T/reply.md"
  route_first '{"method": "POST", "path": "/notes$", "status": 404, "json": {"message": "404 Discussion Not Found"}}'
  run gitlab-mr.sh fake-be reply SCRUM-1/x aaaa1111bbbb2222 "$T/reply.md"
  assert_rc 1; assert_contains "$OUT" "❌ GitLab found nothing for the reply in thread aaaa1111bbbb2222 of MR !12 (404)"
}

test_pipeline_without_one_is_a_tip() {
  setup_gitlab
  run gitlab-mr.sh fake-be pipeline SCRUM-1/x
  assert_rc 0
  assert_eq "$OUT" "⚠️ fake-be: MR !12 has no pipeline
   Tip: this repo may not run CI on its MRs; nothing to wait for."
}

test_pipeline_passed_running_and_other_states() {
  setup_gitlab
  cp "$T/routes.json" "$T/routes.base"
  route_first '{"method": "GET", "path": "/merge_requests/12$", "json": {"iid": 12, "head_pipeline": {"id": 77, "status": "success", "web_url": "https://gitlab.test/p/77"}}}'
  run gitlab-mr.sh fake-be pipeline SCRUM-1/x
  assert_rc 0; assert_eq "$OUT" "✅ fake-be: MR !12's pipeline passed · https://gitlab.test/p/77"
  cp "$T/routes.base" "$T/routes.json"
  route_first '{"method": "GET", "path": "/merge_requests/12$", "json": {"iid": 12, "head_pipeline": {"id": 77, "status": "running", "web_url": "https://gitlab.test/p/77"}}}'
  run gitlab-mr.sh fake-be pipeline SCRUM-1/x
  assert_rc 0; assert_eq "$OUT" "⚠️ fake-be: MR !12's pipeline is still running · https://gitlab.test/p/77
   Tip: look again later: /flow-review <CARD-KEY> check"
  cp "$T/routes.base" "$T/routes.json"
  route_first '{"method": "GET", "path": "/merge_requests/12$", "json": {"iid": 12, "head_pipeline": {"id": 77, "status": "canceled", "web_url": "https://gitlab.test/p/77"}}}'
  run gitlab-mr.sh fake-be pipeline SCRUM-1/x
  assert_rc 0; assert_eq "$OUT" "⚠️ fake-be: MR !12's pipeline is canceled · https://gitlab.test/p/77
   Tip: look at it on GitLab."
}

test_pipeline_failed_lists_its_failed_jobs() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/merge_requests/12$", "json": {"iid": 12, "head_pipeline": {"id": 77, "status": "failed", "web_url": "https://gitlab.test/p/77"}}}'
  run gitlab-mr.sh fake-be pipeline SCRUM-1/x
  assert_rc 3
  assert_eq "$OUT" "❌ fake-be: MR !12's pipeline failed · https://gitlab.test/p/77
   failed job: unit-tests (stage test) · https://gitlab.test/jobs/1
   failed job: lint (stage check) · https://gitlab.test/jobs/2
   Fix: open the failed job's log; /flow-review treats it like a finding (a fix, its tests, your yes, then a push)."
  assert_eq "$(requests | jq -r 'select(.p | endswith("/jobs")) | .q')" "scope%5B%5D=failed&per_page=100"
}

test_pipeline_failed_when_its_jobs_cannot_be_read() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/merge_requests/12$", "json": {"iid": 12, "head_pipeline": {"id": 78, "status": "failed", "web_url": "https://gitlab.test/p/78"}}}'
  run gitlab-mr.sh fake-be pipeline SCRUM-1/x
  assert_rc 3
  assert_not_contains "$OUT" "failed job:"
  assert_contains "$OUT" "Fix: open the failed job's log"
}

test_pipeline_when_the_mr_cannot_be_read() {
  setup_gitlab
  route_first '{"method": "GET", "path": "/merge_requests/12$", "status": 401, "json": {"message": "401"}}'
  run gitlab-mr.sh fake-be pipeline SCRUM-1/x
  assert_rc 1; assert_contains "$OUT" "❌ GitLab refused your token (MR !12: 401)"
}

test_the_token_is_never_printed_or_put_in_a_body() {
  setup_gitlab
  printf 'x\n' > "$T/f.md"
  local all=""
  run gitlab-mr.sh fake-be describe SCRUM-1/x "$T/f.md" --reviewers ana.s; all="$all$OUT"
  run gitlab-mr.sh fake-be reply SCRUM-1/x aaaa1111bbbb2222 "$T/f.md"; all="$all$OUT"
  run gitlab-mr.sh fake-be comments SCRUM-1/x; all="$all$OUT"
  assert_not_contains "$all" "$TOKEN"
  assert_not_contains "$(requests | jq -c '[.p, .q, .b]')" "$TOKEN"
  assert_eq "$(requests | jq -r '.h["PRIVATE-TOKEN"]' | sort -u)" "$TOKEN" "every call carries the token header"
}
