/**
 * Claims Appium helper (nav + page-source + screenshot).
 *
 * Manual-assisted aid: the app under test (mysdworx) is Flutter, but it exposes
 * accessibility labels via `content-desc`. Elements have NO usable `text` or
 * `resource-id`, so ALL selectors here match on content-desc (partial/contains).
 *
 * Prerequisite: Appium server running →  (from repo root)  npm run appium:start
 *
 * Usage (run from the "QA Work" folder after `npm install`):
 *   node tools/device/claims-helper.js dump [name]        # save page source + list labels (output/device/)
 *   node tools/device/claims-helper.js tap "<label part>" # tap first element whose content-desc contains the text
 *   node tools/device/claims-helper.js shot <name>        # save a screenshot PNG (output/device/)
 *
 * Env: DEVICE_UDID (default RZCX11MXGXT).
 */
const { remote } = require('webdriverio');
const fs = require('fs');
const path = require('path');

const UDID = process.env.DEVICE_UDID || 'RZCX11MXGXT';
const OUT = path.join(__dirname, '..', '..', 'output', 'device');
fs.mkdirSync(OUT, { recursive: true });

const caps = {
  platformName: 'Android',
  'appium:automationName': 'UiAutomator2',
  'appium:udid': UDID,
  'appium:appPackage': 'be.sdworx.sdwa.inhouse',
  'appium:appActivity': 'com.sdworx.sdwa.MainActivity',
  'appium:noReset': true,
  'appium:fullReset': false,
  'appium:autoLaunch': false,      // attach to the current screen, don't relaunch
  'appium:newCommandTimeout': 120,
};

function listLabels(xml) {
  return [...new Set([...xml.matchAll(/content-desc="([^"]+)"/g)].map(m => m[1]).filter(t => t.trim()))];
}

async function withSession(fn) {
  const driver = await remote({ hostname: '127.0.0.1', port: 4723, path: '/', logLevel: 'error', capabilities: caps });
  try { return await fn(driver); }
  finally { try { await driver.deleteSession(); } catch {} }
}

const [cmd, arg] = process.argv.slice(2);

(async () => {
  try {
    if (cmd === 'dump') {
      await withSession(async (d) => {
        const xml = await d.getPageSource();
        const file = path.join(OUT, `pagesource${arg ? '_' + arg : ''}.xml`);
        fs.writeFileSync(file, xml, 'utf8');
        const labels = listLabels(xml);
        console.log(`saved: ${file}`);
        console.log(`content-desc labels (${labels.length}):`);
        labels.forEach(l => console.log('  •', l.replace(/\n/g, '\\n')));
      });
    } else if (cmd === 'tap') {
      if (!arg) throw new Error('tap requires a "<label part>" argument');
      await withSession(async (d) => {
        const el = await d.$(`//*[contains(@content-desc, ${JSON.stringify(arg)})]`);
        await el.waitForExist({ timeout: 8000 });
        await el.click();
        console.log(`tapped element containing: ${arg}`);
      });
    } else if (cmd === 'shot') {
      if (!arg) throw new Error('shot requires a <name> argument');
      await withSession(async (d) => {
        const file = path.join(OUT, `${arg}.png`);
        await d.saveScreenshot(file);
        console.log(`saved: ${file}`);
      });
    } else {
      console.log('Commands: dump [name] | tap "<label part>" | shot <name>');
      console.log('Prereq: npm run appium:start (from repo root). Selectors match content-desc (contains).');
    }
  } catch (e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
