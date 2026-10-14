// End-to-end: photo + PDF upload, compression and document reading in the
// built web app (demo mode), using the real browser file choosers.
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
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser', { timeout: 15000 }),
    click(page, label),
  ]);
  await chooser.setFiles(file);
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
  const { width: w, height: h } = page.viewportSize();
  await page.mouse.click((w / 8) * 5, h - 40); // Customers tab
  await page.waitForTimeout(1200);
  await click(page, 'Add customer');

  // Profile photo from "gallery": a 4000x3000 camera-size JPEG.
  await click(page, 'Customer photo');
  await choose(page, 'Choose from gallery', `${FILES}/face-4000.jpg`);
  await page.waitForTimeout(5000);
  check('photo shows in the form', await has(page, 'Change'));
  await page.screenshot({ path: `${OUT}/1-photo-picked.png` });

  // PDF bill: uploads at once and is read for name and address.
  await choose(page, 'Upload file', `${FILES}/eb_bill.pdf`);
  await page.waitForTimeout(800);
  await page.screenshot({ path: `${OUT}/2-reading.png` });
  await page.waitForTimeout(2500);
  check('document row shows uploaded', await has(page, 'uploaded'));
  check('name filled from the document', await has(page, 'Name filled from'));
  check('demo value is labelled as a sample', await has(page, 'sample name'));
  await page.screenshot({ path: `${OUT}/3-filled.png`, fullPage: true });

  // Phone, then save.
  const phone = page.locator('input[aria-label*="Phone"]').first();
  if (await phone.count()) await phone.click(); else await click(page, 'Phone');
  await page.keyboard.type('9876500001', { delay: 15 });
  await click(page, 'Save customer');
  await page.waitForTimeout(1500);
  check('saved', await has(page, 'Selvam Kumar added'));
  await page.screenshot({ path: `${OUT}/4-list-with-photo.png` });

  await click(page, 'VIEW');
  check('customer page shows the bill', await has(page, 'Aadhaar') || await has(page, 'Utility bill'));
  await page.screenshot({ path: `${OUT}/5-customer-page.png` });

  console.log(results.join('\n'));
  console.log(errors.length ? 'PAGE ERRORS:\n' + errors.join('\n') : 'no page errors');
  await browser.close();
})();
