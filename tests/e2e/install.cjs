const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const url = process.env.TEST_URL;
const password = 'Testing-Only-Password-123!';
const mode = process.argv[2];
const courseCode = 'CONTAINERTEST';
const documentName = 'container-upload.txt';
const documentBody = 'Uploaded through the container integration test\n';

async function login(page) {
    const home = await page.goto(url, { waitUntil: 'networkidle' });
    assert.equal(home.status(), 200);
    await page.locator('input[type=text]').first().fill('admin');
    await page.locator('input[type=password]').first().fill(password);
    const response = page.waitForResponse(r => r.url().includes('/login_json'));
    await page.locator('button[type=submit]').first().click();
    assert.equal((await response).status(), 200);
    await page.waitForURL('**/admin');
    await page.locator('a[href="/logout"]').first().waitFor({ state: 'attached' });
}

async function api(page, resource) {
    const response = await page.request.get(`${url}${resource}`, { headers: { Accept: 'application/json' } });
    assert.equal(response.status(), 200, resource);
    return response.json();
}

async function findCourse(page) {
    const [course] = await api(page, `/api/courses?code=${courseCode}`);
    assert.ok(course, `Course ${courseCode} not found`);
    return { id: course.id, node: course.resourceNode.id };
}

async function checkDocument(page, course) {
    const documents = await api(page, `/api/documents?cid=${course.id}&sid=0&gid=0&resourceNode.parent=${course.node}`);
    const document = documents.find(item => item.title === documentName);
    assert.ok(document, 'Uploaded document is missing');
    const file = await page.request.get(`${url}${document.contentUrl}`);
    assert.equal(file.status(), 200);
    assert.equal(await file.text(), documentBody);
}

async function playScorm(page, course) {
    await page.goto(`${url}/resources/lp/${course.node}?cid=${course.id}`, { waitUntil: 'networkidle' });
    const runtime = page.locator('a[href*="/runtime"]').filter({ hasText: 'Container SCORM test' }).first();
    await page.goto(`${url}${await runtime.getAttribute('href')}`, { waitUntil: 'networkidle' });
    const sco = page.frames().find(frame => frame.url().includes('/learning-path/scorm/'));
    assert.ok(sco, 'SCORM content frame is missing');
    await sco.locator('#s', { hasText: 'scorm-api-found' }).waitFor();
}

async function createCourseContent(page) {
    await page.goto(`${url}/main/admin/course_add.php`, { waitUntil: 'networkidle' });
    await page.locator('input[name=title]').fill('Container integration test');
    await page.locator('input[name=visual_code]').fill(courseCode);
    await Promise.all([page.waitForNavigation(), page.locator('button[name=submit]').click()]);
    const course = await findCourse(page);

    const file = path.join(process.env.TEST_TMPDIR, documentName);
    fs.writeFileSync(file, documentBody);
    await page.goto(`${url}/resources/document/${course.node}/upload?cid=${course.id}&gid=0`, { waitUntil: 'networkidle' });
    await page.locator('input[type=file]').first().setInputFiles(file);
    const uploaded = page.waitForResponse(r => r.url().includes('/api/documents') && r.request().method() === 'POST');
    await page.locator('button.uppy-StatusBar-actionBtn--upload').click();
    assert.equal((await uploaded).status(), 201);
    await checkDocument(page, course);

    await page.goto(`${url}/resources/lp/${course.node}/import?cid=${course.id}`, { waitUntil: 'networkidle' });
    await page.locator('form input[type=file]').setInputFiles(process.env.TEST_SCORM_ZIP);
    const imported = page.waitForResponse(r => r.url().includes('/api/learning_paths/scorm/import'));
    await page.locator('form button[type=submit]').click();
    assert.equal((await imported).status(), 201);
    await playScorm(page, course);
    console.log('Course document upload, download, SCORM import and playback succeeded');
}

(async () => {
    const browser = await chromium.launch({
        headless: true,
        ...(process.env.PLAYWRIGHT_EXECUTABLE_PATH && { executablePath: process.env.PLAYWRIGHT_EXECUTABLE_PATH }),
    });
    const isProxy = mode === 'proxy';
    const page = await browser.newPage({
        locale: 'es-ES',
        ...(isProxy && { extraHTTPHeaders: {
            'X-Forwarded-For': '203.0.113.7',
            'X-Forwarded-Host': new URL(url).host,
            'X-Forwarded-Port': '443',
            'X-Forwarded-Proto': 'https',
        } }),
    });
    page.setDefaultTimeout(180000);
    page.setDefaultNavigationTimeout(180000);

    try {
        if (mode === 'install') {
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

        await login(page);
        if (isProxy) {
            const cookies = await page.context().cookies();
            assert.ok(cookies.some(cookie => cookie.name === 'chamilo2' && cookie.secure), 'Expected a secure Chamilo session cookie behind HTTPS');
        }
        console.log('Administrator login succeeded');
        if (mode === 'course') {
            await createCourseContent(page);
        } else if (mode === 'course-check') {
            const course = await findCourse(page);
            await checkDocument(page, course);
            await playScorm(page, course);
            console.log('Course content survived container recreation');
        }
    } finally {
        await browser.close();
    }
})().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
