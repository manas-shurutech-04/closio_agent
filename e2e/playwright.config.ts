// closio-agent's Playwright settings (D24, D67). Run through scripts/e2e.sh, which sets the variables below:
// E2E_TEST_DIR (the card's runs/<CARD-KEY>/e2e/), E2E_BASE_URL (the web app on this Mac), E2E_OUTPUT and E2E_JSON (results),
// and the FE login (read from the Keychain into the test run only; never into a file).
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: process.env.E2E_TEST_DIR || './tests',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  retries: 0,
  workers: 1,
  reporter: [['list'], ['json', { outputFile: process.env.E2E_JSON || 'test-results/results.json' }]],
  outputDir: process.env.E2E_OUTPUT || 'test-results',
  use: {
    baseURL: process.env.E2E_BASE_URL,
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
