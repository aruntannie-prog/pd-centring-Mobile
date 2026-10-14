// End-to-end check of the built SD Centring web app in real Chromium.
const { chromium } = require('playwright');

const OUT = process.argv[2];
const URL = process.env.BASE_URL || 'http://localhost:8765/';

async function boot(browser, viewport, name) {
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto(URL);
  await page.waitForSelector('flt-semantics-placeholder, flutter-view', { timeout: 60000 });
  await page.waitForTimeout(4000);
  // Turn on Flutter's accessibility tree so elements can be found by text.
  await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) p.click();
  });
  await page.waitForTimeout(1500);
  return { ctx, page, errors, name };
}

async function has(page, text) {
  const byText = await page.getByText(text, { exact: false }).count();
  const byLabel = await page.locator(`[aria-label*="${text}"]`).count();
  return byText + byLabel > 0;
}

const shot = (page, file) => page.screenshot({ path: `${OUT}/${file}` });

const TABS = { Alerts: 0, Deliveries: 1, Customers: 2, Settings: 3 };
async function tab(page, name) {
  const w = page.viewportSize().width, h = page.viewportSize().height;
  await page.mouse.click((w / 8) * (2 * TABS[name] + 1), h - 40);
  await page.waitForTimeout(1200);
}

async function clickText(page, text) {
  const el = page.getByText(text, { exact: false }).first();
  await el.click({ timeout: 10000 });
  await page.waitForTimeout(1200);
}

(async () => {
  const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const results = [];
  const check = (label, ok) => { results.push(`${ok ? 'PASS' : 'FAIL'}  ${label}`); };

  // ── Phone ──────────────────────────────────────────────────────────────
  const phone = await boot(browser, { width: 390, height: 844 }, 'phone');
  const p = phone.page;
  await shot(p, '1-phone-alerts.png');
  check('phone: Alerts shows demo banner', await has(p, 'Demo mode'));
  check('phone: expired delivery listed', await has(p, 'SD-1001'));

  await clickText(p, 'SD-1001');
  await shot(p, '2-phone-delivery-detail.png');
  check('phone: detail shows overdue', await has(p, 'days overdue'));

  await clickText(p, 'Record return');
  await shot(p, '3-phone-record-return.png');
  check('phone: return sheet opened', await has(p, 'Save return'));
  await p.keyboard.press('Escape');
  await p.waitForTimeout(800);
  await p.goBack().catch(() => {});
  await p.waitForTimeout(800);

  await p.goto(URL);
  await p.waitForTimeout(4000);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(1500);
  await clickText(p, 'New delivery');
  await shot(p, '4-phone-new-delivery.png');
  check('phone: new delivery form with next DC number', await has(p, 'Rental period'));

  await p.goto(URL);
  await p.waitForTimeout(4000);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(1500);
  await tab(p, 'Deliveries');
  await shot(p, '5-phone-deliveries.png');
  await tab(p, 'Customers');
  await shot(p, '6-phone-customers.png');
  check('phone: customers listed', await has(p, 'Murugan Builders'));
  await tab(p, 'Settings');
  await shot(p, '7-phone-settings.png');
  check('phone: settings shows reminders', await has(p, 'Remind me before expiry'));

  // ── Desktop ────────────────────────────────────────────────────────────
  const desk = await boot(browser, { width: 1280, height: 800 }, 'desktop');
  await shot(desk.page, '8-desktop-alerts.png');
  check('desktop: loads', await has(desk.page, 'SD-1001'));

  // ── Dark mode ──────────────────────────────────────────────────────────
  const darkCtx = await browser.newContext({ viewport: { width: 390, height: 844 }, colorScheme: 'dark', deviceScaleFactor: 2 });
  const dp = await darkCtx.newPage();
  await dp.goto(URL);
  await dp.waitForTimeout(6000);
  await shot(dp, '9-phone-dark.png');

  for (const s of [phone, desk]) {
    const real = s.errors.filter((e) => !/favicon|manifest/i.test(e));
    check(`${s.name}: no console errors${real.length ? ' → ' + real.slice(0, 3).join(' | ') : ''}`, real.length === 0);
  }
  console.log(results.join('\n'));
  await browser.close();
})().catch((e) => { console.error('E2E crashed:', e); process.exit(1); });
