// Captures one popout per kind of cell from cells.rb's page in
// the popouts report, for the README's Reading the HTML report.
// Run by bin/capture_popout_images.sh, which mounts the report at
// /report and docs/ at /out.
const puppeteer = require('puppeteer');

// Each popout to save: the covered file its site is in, the line
// it is on, and the PNG it is saved as.
const SHOTS = [
  ['cells.rb', 5, 'cell-true-false'],
  ['remember.rb', 2, 'cell-blank'],
  ['cells.rb', 11, 'cell-items'],
  ['cells.rb', 14, 'cell-answers'],
  ['cells.rb', 17, 'cell-nil'],
  ['cells.rb', 21, 'cell-tick']
];

// Waits ms milliseconds, for a popout to finish opening.
const pause = (ms) => new Promise((done) => setTimeout(done, ms));

// Opens the popout of the site on line of file, if closed, and
// saves it alone as /out/<name>.png.
async function shot(page, file, line, name) {
  await page.goto(`file:///report/files/${file}.html`);
  await pause(400);
  const id = `tree-${line}`;
  const hidden = await page.$eval(`#${id}`, (tree) => tree.hidden);
  if (hidden) { await page.click(`button.lnum[aria-controls="${id}"]`); }
  await pause(800);
  const tree = await page.$(`#${id}`);
  await tree.screenshot({ path: `/out/${name}.png` });
}

// Opens long.rb's page, presses the button of line 2, its &&, and
// saves the code box, popout open beside it, exactly as a reader
// sees it, as /out/<name>.png.
async function pageShot(page, file, line, name) {
  await page.goto(`file:///report/files/${file}.html`);
  await pause(400);
  const id = `tree-${line}`;
  const hidden = await page.$eval(`#${id}`, (tree) => tree.hidden);
  if (hidden) { await page.click(`button.lnum[aria-controls="${id}"]`); }
  // Moves the mouse off the popout, so no row is lit by hovering.
  await page.mouse.move(0, 0);
  await pause(800);
  const clip = await page.evaluate((tree) => {
    const rects = ['.box', `#${tree}`].map((selector) =>
      document.querySelector(selector).getBoundingClientRect());
    // The rects are relative to the viewport, a clip to the page.
    const x = Math.min(...rects.map((r) => r.left)) + window.scrollX;
    const y = Math.min(...rects.map((r) => r.top)) + window.scrollY;
    const right = Math.max(...rects.map((r) => r.right)) + window.scrollX;
    const bottom = Math.max(...rects.map((r) => r.bottom)) + window.scrollY;
    return { x, y, width: right - x, height: bottom - y };
  }, id);
  await page.screenshot({ path: `/out/${name}.png`, clip });
}

// Each page to save, as PAGE_SHOTS has it: the covered file, the
// line whose button is pressed, and the PNG it is saved as.
const PAGE_SHOTS = [
  ['long.rb', 2, 'example-outcome'],
  ['remember.rb', 2, 'example-unreachable'],
  ['label.rb', 2, 'example-taken'],
  ['owner_of.rb', 2, 'example-nil'],
  ['any_odd.rb', 2, 'example-count'],
  ['odds.rb', 2, 'example-both'],
  ['notify.rb', 2, 'example-overview']
];

// Saves every popout in SHOTS, then every page in PAGE_SHOTS.
async function main() {
  const browser = await puppeteer.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1500, height: 900, deviceScaleFactor: 2 });
  for (const [file, line, name] of SHOTS) {
    await shot(page, file, line, name);
  }
  for (const [file, line, name] of PAGE_SHOTS) {
    await pageShot(page, file, line, name);
  }
  await browser.close();
}

main();
