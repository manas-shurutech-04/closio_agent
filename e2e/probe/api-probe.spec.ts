// The API check before a web card's tests run (D69), run by: bash scripts/e2e.sh probe <CARD-KEY> [--quick] [--mock <names>]
// Logs in once, then calls each GET API of the card's api-list.json that isn't mocked in this run, through the logged-in
// browser (its cookies), and writes one line per API to E2E_PROBE_OUT: ✅ it answers, ⚠️ it looks unavailable on dev.
// Flagged: no answer; 502, 503 or 504; a 500 whose error_code says the service behind WS1 can't be reached; WS1's
// "route not found" (its catch404NotFound → 597 with GENERAL_ERROR). APIs that write are never called here.
// The web app's VITE_ values are read here from its own env files and never printed (rule A6): only paths are shown.
import fs from 'fs';
import path from 'path';
import { test } from '../fixtures';

type Api = { name: string; method: string; base?: string; path: string };

// Vite's order for `vite` in development mode: .env, .env.local, .env.development, .env.development.local (later wins).
function viteEnv(root: string, mode = 'development'): Record<string, string> {
  const env: Record<string, string> = {};
  for (const file of ['.env', '.env.local', `.env.${mode}`, `.env.${mode}.local`]) {
    const full = path.join(root, file);
    if (!fs.existsSync(full)) continue;
    for (const raw of fs.readFileSync(full, 'utf8').split('\n')) {
      const m = raw.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
      if (!m) continue;
      let v = m[2];
      if (/^(['"]).*\1$/.test(v)) v = v.slice(1, -1); else v = v.replace(/\s+#.*$/, '');
      env[m[1]] = v;
    }
  }
  return env;
}

const UNREACHABLE = ['ECONNREFUSED', 'ENOTFOUND', 'ETIMEDOUT', 'ECONNRESET', 'ECONNABORTED', 'EAI_AGAIN', 'EHOSTUNREACH'];

test('API check before the run', async ({ loggedIn: page }) => {
  const list: { apis: Api[] } = JSON.parse(fs.readFileSync(process.env.E2E_API_LIST as string, 'utf8'));
  const mocked = (process.env.E2E_MOCK_APIS || '').split(',').map((n) => n.trim()).filter(Boolean);
  const env = viteEnv(process.env.E2E_WEB_REPO as string);
  const lines: string[] = [];
  for (const api of list.apis) {
    const method = String(api.method).toUpperCase();
    if (method !== 'GET') { lines.push(`·\t${api.name}\t${method} ${api.path}\tnot called (it writes; your answer covers it)`); continue; }
    if (mocked.includes(api.name)) { lines.push(`·\t${api.name}\t${method} ${api.path}\tnot called (mocked in this run)`); continue; }
    let url: URL;
    try { url = new URL((api.base ? env[api.base] ?? '' : '') + api.path, env.VITE_API_BASE_URL); }
    catch { lines.push(`⚠️\t${api.name}\t${method} ${api.path}\tits address couldn't be built (check "base" in api-list.json)`); continue; }
    try {
      const res = await page.request.get(url.toString(), {
        headers: { accept: 'application/json', 'Content-Type': 'application/json', 'Accept-Language': 'id', 'X-Secure-Transmission-Type': '0' },
        timeout: 15_000, failOnStatusCode: false,
      });
      let code = '';
      try { const j = await res.json(); code = (j && j.error_code) || ''; } catch { /* not JSON */ }
      const s = res.status();
      const shown = `${s}${code ? ' ' + code : ''}`;
      if ([502, 503, 504].includes(s)) lines.push(`⚠️\t${api.name}\t${method} ${url.pathname}\t${shown}: the server isn't answering`);
      else if (s === 500 && UNREACHABLE.includes(code)) lines.push(`⚠️\t${api.name}\t${method} ${url.pathname}\t${shown}: WS1 can't reach the service behind it`);
      else if (s === 597 && code === 'GENERAL_ERROR') lines.push(`⚠️\t${api.name}\t${method} ${url.pathname}\t${shown}: WS1 doesn't know this route (not deployed?)`);
      else lines.push(`✅\t${api.name}\t${method} ${url.pathname}\t${shown}: it answers`);
    } catch (e) {
      lines.push(`⚠️\t${api.name}\t${method} ${url.pathname}\tno answer (${String((e as Error).message).split('\n')[0].split(url.origin).join('').slice(0, 80)})`);
    }
  }
  fs.writeFileSync(process.env.E2E_PROBE_OUT as string, lines.join('\n') + '\n');
});
