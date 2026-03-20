const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('http://localhost:4321');

  const footerText = await page.innerText('footer');
  console.log('Footer Text:', footerText);
  if (footerText.includes('Theme: Cactus')) {
    console.log('Footer credits found.');
  } else {
    console.log('Footer credits NOT found.');
    process.exit(1);
  }

  await browser.close();
})();
