// Name-only reading: name typed first, then the ID; and ID first.
const { chromium } = require('playwright');
const [OUT, FILES] = process.argv.slice(2);
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
  await page.waitForTimeout(1000);
}
async function choose(page, label, file) {
  const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 15000 }), click(page, label)]);
  await chooser.setFiles(file);
}
async function openForm(page) {
  await boot(page);
  const { width: w, height: h } = page.viewportSize();
  await page.mouse.click((w / 8) * 5, h - 40);
  await page.waitForTimeout(1200);
  await click(page, 'Add customer');
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

  // A: ID first on an empty form.
  await openForm(page);
  await page.screenshot({ path: `${OUT}/1-form-id-on-top.png` });
  check('ID section hint shown at top', await has(page, 'name is filled in for you'));
  await choose(page, 'Upload file', `${FILES}/eb_bill.pdf`);
  await page.waitForTimeout(3000);
  check('name filled from the ID', await has(page, 'Name filled from'));
  check('address not filled', !(await has(page, 'Gandhi Street')));
  await page.screenshot({ path: `${OUT}/2-id-first.png`, fullPage: true });

  // B: name typed first, then the ID.
  await page.evaluate(() => localStorage.clear());
  await openForm(page);
  await page.keyboard.type('Selvam', { delay: 15 }); // name field has focus
  await page.waitForTimeout(400);
  await choose(page, 'Upload file', `${FILES}/eb_bill.pdf`);
  await page.waitForTimeout(3000);
  check('typed name kept, document name offered', await has(page, 'is different'));
  check('Use button offered', await has(page, 'Use'));
  await page.screenshot({ path: `${OUT}/3-name-typed-first.png`, fullPage: true });
  await page.getByRole('button', { name: 'Use', exact: true }).click();
  await page.waitForTimeout(1000);
  check('Use applies the document name', await has(page, 'Name filled from'));
  await page.screenshot({ path: `${OUT}/4-after-use.png`, fullPage: true });

  console.log(results.join('\n'));
  console.log(errors.length ? 'PAGE ERRORS:\n' + errors.join('\n') : 'no page errors');
  await browser.close();
})();
