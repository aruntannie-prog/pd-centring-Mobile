// End-to-end: adding a customer in the built web app (demo mode), in Chromium.
const { chromium } = require('playwright');
const OUT = process.argv[2];
const URL = process.env.BASE_URL || 'http://localhost:8765/';

async function boot(page) {
  await page.goto(URL);
  await page.waitForSelector('flutter-view', { timeout: 60000 });
  await page.waitForTimeout(4000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);
}
const has = async (page, t) =>
  (await page.getByText(t, { exact: false }).count()) +
  (await page.locator(`[aria-label*="${t}"]`).count()) > 0;
async function click(page, t) {
  const byLabel = page.locator(`[aria-label*="${t}"]`);
  const el = (await byLabel.count()) ? byLabel.first() : page.getByText(t, { exact: false }).first();
  await el.click({ timeout: 10000 });
  await page.waitForTimeout(1200);
}
async function type(page, label, text) {
  const input = page.locator(`input[aria-label*="${label}"], textarea[aria-label*="${label}"]`).first();
  if (await input.count()) {
    await input.click();
  } else {
    await click(page, label);
  }
  await page.waitForTimeout(400);
  await page.keyboard.type(text, { delay: 20 });
  await page.waitForTimeout(400);
}
async function tab(page, i) {
  const { width: w, height: h } = page.viewportSize();
  await page.mouse.click((w / 8) * (2 * i + 1), h - 40);
  await page.waitForTimeout(1200);
}

(async () => {
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  const results = [];
  const check = (label, ok) => results.push(`${ok ? 'PASS' : 'FAIL'}  ${label}`);

  await boot(page);
  await tab(page, 2);
  check('Customers tab has Add customer button', await has(page, 'Add customer'));
  check('list shows ID proof status', await has(page, 'No ID proof'));

  // 1. Empty save shows what is missing.
  await click(page, 'Add customer');
  check('form opened', await has(page, 'New customer'));
  await click(page, 'Save customer');
  check('empty save: name error', await has(page, 'Enter the customer name'));
  check('empty save: phone error', await has(page, 'Enter a phone number'));
  await page.screenshot({ path: `${OUT}/1-empty-errors.png` });

  // 2. Draft survives a full page reload (like Android closing the app).
  await type(page, 'Name', 'Selvam Traders');
  await type(page, 'Address', 'Selaiyur');
  await page.waitForTimeout(800);
  await boot(page);
  await tab(page, 2);
  await click(page, 'Add customer');
  check('draft restored after reload', await has(page, 'Restored what you typed earlier'));
  await page.screenshot({ path: `${OUT}/2-draft-restored.png` });

  // 3. Duplicate number is caught (Murugan Builders has 9840012345).
  await type(page, 'Phone', '98400 12345');
  await click(page, 'Save customer');
  check('duplicate number dialog', await has(page, 'Number already saved'));
  await page.screenshot({ path: `${OUT}/3-duplicate.png` });
  await click(page, 'Go back');

  // 4. Fix the number and save.
  const phone = page.locator('input[aria-label*="Phone"]').first();
  if (await phone.count()) {
    await phone.click();
    await page.keyboard.press('Control+A');
    await page.keyboard.type('9876501234', { delay: 20 });
  }
  await page.waitForTimeout(400);
  await click(page, 'Save customer');
  await page.waitForTimeout(800);
  check('saved: confirmation shown', await has(page, 'Selvam Traders added'));
  await page.screenshot({ path: `${OUT}/4-added.png` });
  await click(page, 'VIEW');
  check('customer page opens', await has(page, '9876501234'));
  check('customer page shows added date', await has(page, 'Added '));
  await page.screenshot({ path: `${OUT}/5-customer-page.png` });

  // 5. The draft is gone after saving.
  await boot(page);
  await tab(page, 2);
  await click(page, 'Add customer');
  check('no stale draft after save', !(await has(page, 'Restored what you typed earlier')));

  console.log(results.join('\n'));
  console.log(errors.length ? 'PAGE ERRORS:\n' + errors.join('\n') : 'no page errors');
  await browser.close();
})();
