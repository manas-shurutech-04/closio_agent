// Shared pieces for every card's Playwright tests (D24, D67, D69). A card's tests in runs/<CARD-KEY>/e2e/ import from here:
//   import { test, expect, login, useApiMocks } from '../../../e2e/fixtures';
// Each test's title starts with its AC: test('AC 3 — groups collapse and expand', ...), so a run can pick one AC.
import { test as base, expect, type Page, type TestInfo } from '@playwright/test';

export { expect };

// Logs in to the web app with your FE login (from the Keychain, passed by scripts/e2e.sh; never written anywhere).
// The fields are the ones of the web app's login page (src/views/Login.vue, src/views/Login.testids.ts).
export async function login(page: Page): Promise<void> {
  const id = process.env.E2E_LOGIN_ID;
  const password = process.env.E2E_LOGIN_PASSWORD;
  if (!id || !password) throw new Error('No FE login: run the tests with bash scripts/e2e.sh run <CARD-KEY>');
  await page.goto('/login');
  await page.getByTestId('login-form-phoneInput').fill(id);
  await page.getByTestId('login-form-passwordInput').fill(password);
  await page.getByTestId('login-form-submitBtn').click();
  await page.waitForURL((url) => !url.pathname.startsWith('/login'), { timeout: 30_000 });
}

// One API's mock (D69), kept in the card's api-mocks.ts: its 200 body is the exact response object the user gave.
export type ApiMock = { method: string; path: string | RegExp; status?: number; body: unknown };

// Turns on, for this page, only the mocks named in E2E_MOCK_APIS (scripts/e2e.sh … --mock <names>: the APIs the user
// said aren't available on dev in this run); every other API stays real. Call it before the page opens the screen.
export async function useApiMocks(page: Page, mocks: Record<string, ApiMock>): Promise<string[]> {
  const on = (process.env.E2E_MOCK_APIS || '').split(',').map((n) => n.trim()).filter((n) => n in mocks);
  for (const name of on) {
    const m = mocks[name];
    await page.route(m.path, (route) =>
      route.request().method() === m.method.toUpperCase()
        ? route.fulfill({ status: m.status ?? 200, contentType: 'application/json', body: JSON.stringify(m.body) })
        : route.fallback());
    base.info().annotations.push({ type: 'api-mocked', description: name });
  }
  return on;
}

// Watches the page's API calls (D69): a call with no answer, or a 5xx from the real server (WS1's 597 included), is
// noted on the test, and scripts/e2e.sh lists it when the test fails. Answers a test gives itself are never noted.
const pathOf = (u: string): string => { try { return new URL(u).pathname; } catch { return u; } };
const isApiCall = (type: string): boolean => type === 'xhr' || type === 'fetch';
function watchApi(page: Page, info: TestInfo): void {
  page.on('requestfailed', (req) => {
    const why = req.failure()?.errorText ?? 'failed';
    if (!isApiCall(req.resourceType()) || /ABORTED/.test(why)) return; // the browser cancels calls when the page moves on
    info.annotations.push({ type: 'api-failed', description: `${req.method()} ${pathOf(req.url())} → no answer (${why})` });
  });
  page.on('response', async (res) => {
    const req = res.request();
    if (!isApiCall(req.resourceType()) || res.status() < 500) return;
    if (!(await res.serverAddr().catch(() => null))) return; // answered by the test itself (page.route)
    let code = '';
    try { const j = await res.json(); if (j && j.error_code) code = ` ${j.error_code}`; } catch { /* not JSON */ }
    info.annotations.push({ type: 'api-failed', description: `${req.method()} ${pathOf(req.url())} → ${res.status()}${code}` });
  });
}

// A test that starts already logged in, its API calls watched: test('AC 1 — …', async ({ loggedIn: page }) => { ... })
export const test = base.extend<{ loggedIn: Page }>({
  loggedIn: async ({ page }, use, testInfo) => {
    watchApi(page, testInfo);
    await login(page);
    await use(page);
  },
});
