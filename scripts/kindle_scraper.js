const { chromium } = require('playwright');
const { PDFDocument } = require('pdf-lib');
const fs = require('fs-extra');
const path = require('path');
const axios = require('axios'); // For GAS communication

// GAS Endpoint (from environment)
const GAS_URL = process.env.GAS_WEB_APP_URL;

async function run() {
    const email = process.env.AMAZON_EMAIL;
    const password = process.env.AMAZON_PASSWORD;
    let bookUrl = process.env.KINDLE_BOOK_URL;
    const maxPages = parseInt(process.env.MAX_PAGES || '500');

    if (!email || !password) {
        console.error('Error: AMAZON_EMAIL and AMAZON_PASSWORD are required.');
        process.exit(1);
    }

    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        viewport: { width: 1200, height: 1600 },
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    });
    const page = await context.newPage();

    console.log('Logging in to Amazon Kindle Cloud Reader...');
    await page.goto('https://read.amazon.co.jp/');

    if (await page.$('#ap_email')) {
        await page.fill('#ap_email', email);
        await page.click('#continue');
        await page.waitForTimeout(1000);
        await page.fill('#ap_password', password);
        await page.click('#signInSubmit');
    }

    await page.waitForTimeout(5000);
    if (page.url().includes('cvf/approval')) {
        console.error('Login Blocked: Amazon requires manual approval/OTP.');
        await page.screenshot({ path: 'login_blocked.png' });
        process.exit(1);
    }

    // Step 2: Determine target book
    if (!bookUrl) {
        console.log('No URL provided. Scanning library for unread books...');
        await page.goto('https://read.amazon.co.jp/kindle-library');
        await page.waitForTimeout(5000);

        // Find visible book items
        const bookItems = await page.$$('.library-item');
        if (bookItems.length === 0) {
            console.error('No books found in library.');
            await page.screenshot({ path: 'library_empty.png' });
            process.exit(1);
        }

        // Get processed status from GAS
        const processedBooks = await getProcessedBooks();
        console.log(`Found ${processedBooks.length} processed books in GAS.`);

        // Pick the first book that is NOT processed
        let targetBook = null;
        for (const item of bookItems) {
            const title = await item.getAttribute('aria-label') || await item.innerText();
            const cleanTitle = title.replace('の表紙', '').trim();

            if (!processedBooks.includes(cleanTitle)) {
                targetBook = { item, title: cleanTitle };
                console.log(`Targeting: ${cleanTitle}`);
                break;
            }
        }

        if (!targetBook) {
            console.log('All visible books are already processed. Finishing.');
            return;
        }

        await targetBook.item.click();
    } else {
        await page.goto(bookUrl);
    }

    console.log('Book opened. Loading...');
    await page.waitForTimeout(10000);

    // Get Title from Reader
    const bookTitle = await page.title() || 'Unknown Book';
    console.log(`Starting Scraper for: ${bookTitle}`);

    const screenshotsDir = path.join(__dirname, 'temp_screenshots');
    await fs.ensureDir(screenshotsDir);

    let pageCount = 0;
    const pdfDoc = await PDFDocument.create();

    // Capture Loop
    while (pageCount < maxPages) {
        pageCount++;
        const screenshotPath = path.join(screenshotsDir, `p${pageCount}.png`);

        await page.screenshot({ path: screenshotPath });
        console.log(`Captured page ${pageCount}`);

        const imgBytes = fs.readFileSync(screenshotPath);
        const img = await pdfDoc.embedPng(imgBytes);
        const pdfPage = pdfDoc.addPage([img.width, img.height]);
        pdfPage.drawImage(img, { x: 0, y: 0, width: img.width, height: img.height });

        // Turn Page
        await page.keyboard.press('ArrowRight');
        await page.waitForTimeout(2000);

        if (pageCount > 10 && await isEndOfBook(page)) {
            console.log('Reached end of book.');
            break;
        }
    }

    const pdfBytes = await pdfDoc.save();
    const pdfPath = path.join(__dirname, 'output_book.pdf');
    fs.writeFileSync(pdfPath, pdfBytes);

    // Step 4: Finalize
    console.log('Upload complete (Simulated in local script, GitHub Action handles Drive)');

    // Notify GAS
    await notifyGAS(bookTitle, 'Success');

    await browser.close();
    await fs.remove(screenshotsDir);
}

async function isEndOfBook(page) {
    const markers = ['本を評価', 'Rate this book', '次のおすすめ', 'Kindle Store', 'Review this'];
    const content = await page.content();
    return markers.some(m => content.includes(m));
}

async function getProcessedBooks() {
    if (!GAS_URL) return [];
    try {
        const res = await axios.get(`${GAS_URL}?action=get_kindle_library`);
        if (res.data.success) {
            return res.data.data.map(b => b['タイトル']);
        }
    } catch (e) {
        console.warn('Failed to fetch library status from GAS:', e.message);
    }
    return [];
}

async function notifyGAS(title, status) {
    if (!GAS_URL) return;
    try {
        await axios.post(GAS_URL, {
            action: 'update_kindle_status',
            title: title,
            status: status,
            timestamp: new Date().toISOString()
        });
        console.log('Status updated in GAS.');
    } catch (e) {
        console.warn('Failed to update status in GAS:', e.message);
    }
}

run().catch(err => {
    console.error('Fatal Error:', err);
    process.exit(1);
});
