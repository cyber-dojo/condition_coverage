// Captures the README's two screenshots of fee.rb's page in the
// demo report: its first if's decision grid, and fee's method
// grid. Run by bin/capture_readme_images.sh, which mounts the
// report at /site and docs/ at /out.
const puppeteer = require('puppeteer');

const PAGE = 'file:///site/files/source/fee.rb.html';

// Waits ms milliseconds, for the rails to finish sliding.
const pause = (ms) => new Promise((done) => setTimeout(done, ms));

// Saves the code box, rails and open grid included, as a PNG at out.
async function shot(page, out) {
  await pause(800);
  const box = await page.$('.box');
  await box.screenshot({ path: out });
}

// Loads fee.rb's page anew, with nothing opened by a click.
async function fresh(page) {
  await page.goto(PAGE);
  await pause(400);
}

// Opens fee.rb's page twice, once per grid, saving each.
async function main() {
  const browser = await puppeteer.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1500, height: 640, deviceScaleFactor: 2 });

  await fresh(page);
  const hidden = await page.$eval('#tree-5', (tree) => tree.hidden);
  if (hidden) { await page.click('button.lnum[aria-controls="tree-5"]'); }
  await pause(800);
  // Hovering order.paid?'s row marks it in the code.
  const leaves = await page.$$('#tree-5 .row[data-operand]');
  await leaves[1].hover();
  await shot(page, '/out/decision.png');

  await fresh(page);
  await page.evaluate(() => {
    const number = document.querySelector('.line [data-line="3"]');
    number.closest('.line').querySelector('.src').click();
  });
  await pause(800);
  // Clicking the first column, a path never taken, pins it and
  // lights its path in the code.
  const cells = await page.$$('.pathgrid:not([hidden]) .prow .pcell');
  await cells[0].click();
  await shot(page, '/out/method.png');
  await browser.close();
}

main();
