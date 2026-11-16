const { chromium } = require('playwright');
const assert = require('node:assert/strict');

const url = process.env.TEST_URL;
const password = 'Testing-Only-Password-123!';

(async () => {
    const browser = await chromium.launch({
        headless: true,
        ...(process.env.PLAYWRIGHT_EXECUTABLE_PATH && { executablePath: process.env.PLAYWRIGHT_EXECUTABLE_PATH }),
    });
    const page = await browser.newPage({ locale: 'es-ES' });
    page.setDefaultTimeout(180000);
    page.setDefaultNavigationTimeout(180000);

    try {
        if (process.argv[2] === 'install') {
            await page.goto(`${url}/main/install/index.php`);
            await page.locator('button[name=step1]').click();
            await page.locator('button[name=step2_install]').click();
            // The test uses a disposable database and accepts Chamilo's GPLv3 license.
            await page.locator('input[name=accept]').check();
            await page.locator('button[name=step3]').click();
            await page.locator('input[name=dbHostForm]:visible').fill('db');
            await page.locator('input[name=dbUsernameForm]:visible').fill('chamilo');
            await page.locator('input[name=dbPassForm]:visible').fill(process.env.DB_PASSWORD);
            await page.locator('button[name=step3]').click();
            await page.locator('button[name=step4]:enabled').click();
            await page.locator('input[name=passForm]:visible').fill(password);
            await page.locator('input[name=emailForm]:visible').fill('admin@example.test');
            await page.locator('button[name=step5]').click();
            await page.locator('button[name=button_step6]').click();
            await page.getByText('Ir a la plataforma que acaba de crear.').waitFor();
            console.log('Web installation completed');
        }

        const home = await page.goto(url, { waitUntil: 'networkidle' });
        assert.equal(home.status(), 200);
        await page.locator('input[type=text]').first().fill('admin');
        await page.locator('input[type=password]').first().fill(password);
        const response = page.waitForResponse(r => r.url().includes('/login_json'));
        await page.locator('button[type=submit]').first().click();
        assert.equal((await response).status(), 200);
        await page.waitForURL('**/admin');
        await page.getByText('Cerrar sesión').first().waitFor();
        console.log('Administrator login succeeded');
    } finally {
        await browser.close();
    }
})().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
