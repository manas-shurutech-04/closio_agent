# scripts/db-run.sh (and scripts/lib/db-run.js): a card's SQL on the database a repo's .env names. Never a real
# database: either a stand-in node (fake_cmd node), or the real db-run.js with a fake "pg" package in the fake repo.

register_repo() { # <name> <folder> [<yaml line>…]
  local name="$1" dir="$2" l; shift 2
  mkdir -p "$dir" "$A/local/repos"
  printf 'name: %s\n' "$name" > "$A/config/repos/$name.yaml"
  for l in "$@"; do printf '%s\n' "$l" >> "$A/config/repos/$name.yaml"; done
  printf 'local_path: %s\n' "$dir" > "$A/local/repos/$name.yaml"
}

setup_db() {
  sandbox
  R="$T/repos/fake db"
  register_repo fake-db "$R" "language: node" "node_version: 18.20.8   # from the Dockerfile" "env_file: .env"
  : > "$R/.sequelizerc"
  mkdir -p "$A/runs/SCRUM-3"
  printf "INSERT INTO t (a) VALUES ('x');\nSELECT a FROM t;\n" > "$A/runs/SCRUM-3/test-data.sql"
  SQL_REL="runs/SCRUM-3/test-data.sql"
  LOG="$A/local/logs/db-run-fake-db.log"
}

# The repo's own sequelize-cli config and a fake "pg" (it logs every call to $FAKE_PG_LOG; FAKE_PG_FAIL: a query that
# throws; FAKE_PG_CONNECT_FAIL: the connection fails), for the real scripts/lib/db-run.js
setup_fake_pg() {
  setup_db
  printf "const path = require('path');\nmodule.exports = { config: path.resolve('config', 'config.js') };\n" > "$R/.sequelizerc"
  mkdir -p "$R/config" "$R/node_modules/pg"
  printf "module.exports = { development: { host: 'db.local', port: '6543', username: 'u', password: 'pw-secret-1', database: 'closio', dialectOptions: { ssl: { rejectUnauthorized: false } } } };\n" > "$R/config/config.js"
  cat > "$R/node_modules/pg/index.js" <<'JS'
const fs = require('fs');
const log = (s) => fs.appendFileSync(process.env.FAKE_PG_LOG, s + '\n');
class Client {
  constructor(c) { log(`client ${c.host}:${c.port}/${c.database} ssl=${JSON.stringify(c.ssl)}`); }
  async connect() {
    if (process.env.FAKE_PG_CONNECT_FAIL) { const e = new Error('connect failed'); e.code = 'ECONNREFUSED'; throw e; }
  }
  async query(sql) {
    log('query ' + sql.replace(/\n/g, ' ').trim());
    if (process.env.FAKE_PG_FAIL && new RegExp(process.env.FAKE_PG_FAIL).test(sql)) throw new Error('relation "t" does not exist');
    if (/^(BEGIN|COMMIT|ROLLBACK|SET)/.test(sql)) return { command: sql.split(' ')[0], rowCount: null, rows: [] };
    if (/^SELECT 1/.test(sql)) return { command: 'SELECT', rowCount: 1, rows: [{ one: 1 }] };
    return [{ command: 'INSERT', rowCount: 1, rows: [] }, { command: 'UPDATE', rowCount: null, rows: [] },
            { command: 'SELECT', rowCount: 25, rows: Array.from({ length: 25 }, (_, i) => ({ n: i })) }];
  }
  async end() { log('end'); }
}
module.exports = { Client };
JS
  export FAKE_PG_LOG="$T/pg.log"
  : > "$FAKE_PG_LOG"
}

test_wrong_usage_shows_the_usage() {
  setup_db
  local args
  for args in "" "fake-db show" "fake-db drop $SQL_REL" "fake-db show $SQL_REL extra" "fake-db query $SQL_REL extra"; do
    run db-run.sh $args
    assert_rc 2; assert_eq "$OUT" "Usage: bash scripts/db-run.sh <repo> show <sql file> | <repo> run <sql file> confirmed | <repo> query <sql file>" "usage for: $args"
  done
}

test_an_unregistered_repo_a_missing_sql_file_or_no_database_config() {
  setup_db
  run db-run.sh nope show "$SQL_REL"
  assert_rc 1; assert_eq "$OUT" "❌ nope isn't registered (run /flow-configure-repo <path of your clone>)
   Fix: Fix that first, then run this again."
  run db-run.sh fake-db show runs/SCRUM-3/none.sql
  assert_rc 2; assert_contains "$OUT" "❌ No SQL file 'runs/SCRUM-3/none.sql'"
  rm "$R/.sequelizerc"
  run db-run.sh fake-db show "$SQL_REL"
  assert_rc 1; assert_eq "$OUT" "❌ fake-db has no .sequelizerc, so there's no database config to use
   Fix: Run this for a repo that owns the tables (a WS2 repo with migrations)."
}

test_show_prints_the_sql_and_where_it_would_run() {
  setup_db
  run db-run.sh fake-db show "$SQL_REL"
  assert_rc 0
  assert_eq "$OUT" "SQL to review (test-data.sql, 2 line(s)):
\`\`\`sql
INSERT INTO t (a) VALUES ('x');
SELECT a FROM t;

\`\`\`
It would run on: the database fake-db's own sequelize-cli config names (its .env, NODE_ENV development), in one transaction.
Nothing runs until the user says yes; then: bash scripts/db-run.sh fake-db run runs/SCRUM-3/test-data.sql confirmed"
  assert_no_file "$LOG"
  assert_eq "$(fake_calls node)" "" "show runs nothing"
}

test_show_names_the_env_file_and_node_env() {
  setup_db
  printf 'env_file: .env.local\n' > "$T/y"; sed -i '' 's/^env_file: .env$/env_file: .env.local/' "$A/config/repos/fake-db.yaml"
  NODE_ENV=test run db-run.sh fake-db show "$A/$SQL_REL"
  assert_contains "$OUT" "(its .env.local, NODE_ENV test)"
  assert_contains "$OUT" "bash scripts/db-run.sh fake-db run runs/SCRUM-3/test-data.sql confirmed"
}

test_run_without_the_users_yes_is_refused() {
  setup_db
  run db-run.sh fake-db run "$SQL_REL"
  assert_rc 1
  assert_eq "$OUT" "❌ Running SQL needs the user's yes first
   Fix: Show it with: bash scripts/db-run.sh fake-db show <sql file>, ask the user, and only after their yes add the word confirmed."
  run db-run.sh fake-db run "$SQL_REL" yes
  assert_rc 1
  run db-run.sh fake-db run "$SQL_REL" confirmed again
  assert_rc 1
  assert_eq "$(fake_calls node)" "" "nothing ran"
  assert_no_file "$LOG"
}

test_run_confirmed_runs_db_run_js_on_the_repos_node_and_logs_it() {
  setup_db
  fake_cmd node 'echo "[dotenv@16.4.5] injecting env (3) from .env"; echo "in: $(basename "$PWD") args: $(basename "$1") $2 $3"; echo "✅ Ran 2 statement(s) in one transaction"'
  run db-run.sh fake-db run "$SQL_REL" confirmed
  assert_rc 0
  assert_eq "$OUT" "in: fake db args: db-run.js $(cd "$A/runs/SCRUM-3" && pwd -P)/test-data.sql run
✅ Ran 2 statement(s) in one transaction"
  assert_contains "$(fake_calls nvm)" "nvm use 18.20.8"
  assert_match "$(cat "$LOG")" '\$ db-run fake-db run test-data\.sql   \([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8}\)'
  assert_contains "$(cat "$LOG")" "✅ Ran 2 statement(s) in one transaction"
  assert_not_contains "$(cat "$LOG")" "[dotenv@"
}

test_query_needs_no_yes_and_passes_the_exit_code_on() {
  setup_db
  fake_cmd node 'echo "❌ The query failed: $3"; exit 1'
  run db-run.sh fake-db query "$SQL_REL"
  assert_rc 1
  assert_eq "$OUT" "❌ The query failed: query"
  assert_contains "$(cat "$LOG")" "\$ db-run fake-db query test-data.sql"
}

test_node_not_installed_or_nvm_not_loading() {
  setup_db
  FAKE_NVM_MISSING=18.20.8 run db-run.sh fake-db query "$SQL_REL"
  assert_rc 1; assert_eq "$OUT" "❌ Node 18.20.8 is not installed (nvm install 18.20.8)"
  mkdir -p "$T/broken nvm"; printf 'return 1\n' > "$T/broken nvm/nvm.sh"
  NVM_DIR="$T/broken nvm" run db-run.sh fake-db query "$SQL_REL"
  assert_rc 1; assert_eq "$OUT" "❌ nvm could not be loaded"
}

test_a_repo_that_is_not_node_runs_without_nvm() {
  setup_db
  sed -i '' 's/^node_version: .*/node_version: none/' "$A/config/repos/fake-db.yaml"
  fake_cmd node 'echo ran'
  run db-run.sh fake-db query "$SQL_REL"
  assert_rc 0; assert_eq "$OUT" "ran"
  assert_eq "$(fake_calls nvm)" "" "no nvm"
}

# ---------------------------------------------------------------- the real db-run.js, with a fake pg

test_db_run_js_runs_the_file_in_one_transaction() {
  setup_fake_pg
  run db-run.sh fake-db run "$SQL_REL" confirmed
  assert_rc 0
  assert_contains "$OUT" "   1. INSERT: 1 row(s)
   2. UPDATE: - row(s)
   3. SELECT: 25 row(s)
      {\"n\":0}"
  assert_eq "$(printf '%s\n' "$OUT" | grep -c '^      {"n"')" "20" "the first 20 rows"
  assert_contains "$OUT" "      … (first 20 rows shown)
✅ Ran 3 statement(s) in one transaction"
  assert_eq "$(cat "$FAKE_PG_LOG")" "client db.local:6543/closio ssl={\"rejectUnauthorized\":false}
query BEGIN
query INSERT INTO t (a) VALUES ('x'); SELECT a FROM t;
query COMMIT
end"
  assert_not_contains "$OUT$(cat "$LOG")" "pw-secret-1"
}

test_db_run_js_query_is_read_only() {
  setup_fake_pg
  printf 'SELECT 1;\n' > "$A/runs/SCRUM-3/check.sql"
  run db-run.sh fake-db query runs/SCRUM-3/check.sql
  assert_rc 0
  assert_eq "$OUT" '   1. SELECT: 1 row(s)
      {"one":1}
✅ Read 1 statement(s) in a read-only transaction (nothing changed)'
  assert_eq "$(sed -n '2,5p' "$FAKE_PG_LOG")" "query SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY
query BEGIN TRANSACTION READ ONLY
query SELECT 1;
query ROLLBACK"
}

test_db_run_js_refuses_a_query_that_could_write() {
  setup_fake_pg
  printf "SELECT 'commit; set x' AS words; -- set y\n/* commit */ COMMIT; UPDATE t SET a = 1;\n" > "$A/runs/SCRUM-3/q.sql"
  run db-run.sh fake-db query runs/SCRUM-3/q.sql
  assert_rc 1
  assert_eq "$OUT" "❌ A query may only read (SELECT / WITH): no COMMIT, ROLLBACK, BEGIN, SET, COPY, CALL, DO or LOCK. Rewrite it, then run it again."
  assert_not_contains "$(cat "$FAKE_PG_LOG")" "query"
  printf "SELECT 'commit; set x' AS words; -- set y\n/* commit */\n" > "$A/runs/SCRUM-3/q.sql"
  FAKE_PG_FAIL=x run db-run.sh fake-db query runs/SCRUM-3/q.sql
  assert_contains "$OUT" "❌ The query failed (read only: a statement that changes data is refused): relation \"t\" does not exist"
}

test_db_run_js_rolls_back_a_failing_file() {
  setup_fake_pg
  FAKE_PG_FAIL='^INSERT' run db-run.sh fake-db run "$SQL_REL" confirmed
  assert_rc 1
  assert_eq "$OUT" "❌ The SQL failed, nothing was kept (rolled back): relation \"t\" does not exist"
  assert_eq "$(tail -2 "$FAKE_PG_LOG")" "query ROLLBACK
end"
}

test_db_run_js_explains_what_is_missing() {
  setup_fake_pg
  FAKE_PG_CONNECT_FAIL=1 run db-run.sh fake-db run "$SQL_REL" confirmed
  assert_rc 1
  assert_eq "$OUT" "❌ Couldn't connect to the database (ECONNREFUSED). On the dev database: connect the VPN (/flow-vpn connect)"
  NODE_ENV=staging run db-run.sh fake-db run "$SQL_REL" confirmed
  assert_rc 1; assert_eq "$OUT" "❌ The repo's database config has no \"staging\" block"
  rm -rf "$R/node_modules"
  run db-run.sh fake-db run "$SQL_REL" confirmed
  assert_rc 1; assert_eq "$OUT" "❌ The repo's packages aren't installed (pg missing): run /flow-setup-repo <repo> install"
  rm "$R/config/config.js"
  run db-run.sh fake-db run "$SQL_REL" confirmed
  assert_rc 1; assert_contains "$OUT" "❌ Couldn't load the repo's database config: Cannot find module"
}
