// Runs one SQL file against the database a repo's own sequelize-cli config names (C4, scripts/db-run.sh; D67).
// Started by scripts/db-run.sh in the repo's folder, on the repo's Node version. It reads the repo's .sequelizerc and
// config with the repo's own packages (dotenv, pg), so closio-agent never needs the repo's variable names, and it never
// prints a connection value (rule A6). Runs the whole file in one transaction; on an error nothing is kept.
// With the second argument "query" the transaction is READ ONLY: the database itself refuses any change (D68).
'use strict';
const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const sqlFile = process.argv[2];
const readOnly = process.argv[3] === 'query';
const repoRequire = createRequire(path.join(process.cwd(), 'package.json'));

const fail = (msg) => { console.log(`❌ ${msg}`); process.exit(1); };

(async () => {
  let rc;
  try { rc = require(path.join(process.cwd(), '.sequelizerc')); } catch (e) { fail('This repo has no .sequelizerc (no sequelize-cli database config)'); }
  let cfgAll;
  try { cfgAll = require(rc.config); } catch (e) { fail(`Couldn't load the repo's database config: ${e.message}`); }
  const env = process.env.NODE_ENV || 'development';
  const cfg = cfgAll[env];
  if (!cfg) fail(`The repo's database config has no "${env}" block`);
  let pg;
  try { pg = repoRequire('pg'); } catch (e) { fail("The repo's packages aren't installed (pg missing): run /flow-setup-repo <repo> install"); }
  const sql = fs.readFileSync(sqlFile, 'utf8');
  // A read-only query may not end or change its transaction (COMMIT, SET …), or a later statement could write.
  const words = sql.replace(/--[^\n]*/g, ' ').replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/'(?:[^']|'')*'/g, "''");
  if (readOnly && /\b(commit|rollback|begin|start\s+transaction|abort|set|reset|savepoint|release|prepare|deallocate|discard|lock|copy|call|do)\b/i.test(words)) {
    fail('A query may only read (SELECT / WITH): no COMMIT, ROLLBACK, BEGIN, SET, COPY, CALL, DO or LOCK. Rewrite it, then run it again.');
  }
  const client = new pg.Client({
    host: cfg.host, port: Number(cfg.port || 5432), user: cfg.username, password: cfg.password, database: cfg.database,
    ssl: cfg.dialectOptions && cfg.dialectOptions.ssl ? cfg.dialectOptions.ssl : false,
    connectionTimeoutMillis: 15000,
  });
  try { await client.connect(); } catch (e) { fail(`Couldn't connect to the database (${e.code || e.message}). On the dev database: connect the VPN (/flow-vpn connect)`); }
  try {
    if (readOnly) await client.query('SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY');
    await client.query(readOnly ? 'BEGIN TRANSACTION READ ONLY' : 'BEGIN');
    const res = await client.query(sql);
    await client.query(readOnly ? 'ROLLBACK' : 'COMMIT');
    const list = Array.isArray(res) ? res : [res];
    list.forEach((r, i) => {
      const what = r.command || 'statement';
      if (what === 'SELECT') {
        console.log(`   ${i + 1}. SELECT: ${r.rowCount} row(s)`);
        r.rows.slice(0, 20).forEach((row) => console.log(`      ${JSON.stringify(row)}`));
        if (r.rowCount > 20) console.log('      … (first 20 rows shown)');
      } else {
        console.log(`   ${i + 1}. ${what}: ${r.rowCount === null ? '-' : r.rowCount} row(s)`);
      }
    });
    console.log(readOnly ? `✅ Read ${list.length} statement(s) in a read-only transaction (nothing changed)` : `✅ Ran ${list.length} statement(s) in one transaction`);
  } catch (e) {
    try { await client.query('ROLLBACK'); } catch (_) { /* already gone */ }
    console.log(readOnly ? `❌ The query failed (read only: a statement that changes data is refused): ${e.message}` : `❌ The SQL failed, nothing was kept (rolled back): ${e.message}`);
    process.exitCode = 1;
  } finally {
    await client.end().catch(() => {});
  }
})();
