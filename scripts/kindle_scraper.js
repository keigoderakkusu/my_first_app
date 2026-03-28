const { chromium } = require('playwright-extra');
const stealth = require('puppeteer-extra-plugin-stealth')();
const { PDFDocument } = require('pdf-lib');
const fs = require('fs-extra');
const path = require('path');
const axios = require('axios');
const { google } = require('googleapis');
const { GoogleAuth } = require('google-auth-library');

// Enable stealth
chromium.use(stealth);

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

    console.log('Starting stealth browser...');
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        viewport: { width: 1200, height: 1600 },
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        locale: 'ja-JP',
        timezoneId: 'Asia/Tokyo',
    });
    const page = await context.newPage();

    console.log('Logging in to Amazon Kindle Cloud Reader...');

    // Attempt to load cookies if provided
    const amazonCookies = process.env.AMAZON_COOKIES;
    if (amazonCookies) {
        try {
            const cookies = JSON.parse(amazonCookies);
            await context.addCookies(cookies);
            console.log('Loaded cookies from AMAZON_COOKIES secret.');
        } catch (e) {
            console.error('Failed to parse AMAZON_COOKIES JSON:', e.message);
        }
    }

    await page.goto('https://read.amazon.co.jp/');
    await page.waitForTimeout(3000);

    // If the login form is still present, cookies didn't work or weren't provided.
    if (await page.$('#ap_email')) {
        console.log('Cookies invalid or missing. Attempting email/password login...');
        if (!email || !password) {
            console.error('Error: AMAZON_EMAIL and AMAZON_PASSWORD are required if cookies are not used.');
            process.exit(1);
        }
        await page.fill('#ap_email', email);
        await page.click('#continue');
        await page.waitForTimeout(1000);
        await page.fill('#ap_password', password);
        await page.click('#signInSubmit');
    } else {
        console.log('Successfully bypassed login form (likely using cookies)!');
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

        // Find visible book items with timeout handling
        try {
            console.log('Waiting for library items to appear...');
            await page.waitForSelector('.library-item, #itemViewResponse', { state: 'attached', timeout: 30000 });
        } catch (e) {
            console.error('Timeout waiting for library items. Capturing debug evidence...');
            await page.screenshot({ path: 'error_screenshot.png', fullPage: true });
            const html = await page.content();
            fs.writeFileSync('error_page.html', html);
            console.error('Fatal Error: page.waitForSelector: Timeout 30000ms exceeded.');
            process.exit(1);
        }

        // Fetch book list from Amazon's injected JSON (Modern approach)
        const itemsListJson = await page.evaluate(() => {
            const el = document.getElementById('itemViewResponse');
            return el ? JSON.parse(el.textContent).itemsList : [];
        });

        const bookItemsDOM = await page.$$('.library-item'); // Fallback for older layouts
        
        if (itemsListJson.length === 0 && bookItemsDOM.length === 0) {
            console.error('No books found in library even after wait.');
            process.exit(1);
        }

        // Get processed status from GAS
        const processedBooks = await getProcessedBooks();
        console.log(`Found ${processedBooks.length} processed books in GAS.`);

        let targetBookUrl = null;
        let targetBookTitle = null;
        let targetBookDomElement = null;

        // Strategy A: JSON Extraction (Preferred)
        if (itemsListJson.length > 0) {
            for (const item of itemsListJson) {
                const cleanTitle = item.title.replace('の表紙', '').trim();
                if (!processedBooks.includes(cleanTitle)) {
                    targetBookUrl = item.webReaderUrl;
                    targetBookTitle = cleanTitle;
                    console.log(`Targeting (from JSON): ${cleanTitle}`);
                    break;
                }
            }
        }

        // Strategy B: DOM Extraction (Fallback)
        if (!targetBookUrl && bookItemsDOM.length > 0) {
            for (const item of bookItemsDOM) {
                const title = await item.getAttribute('aria-label') || await item.innerText();
                const cleanTitle = title.replace('の表紙', '').trim();
                if (!processedBooks.includes(cleanTitle)) {
                    targetBookDomElement = item;
                    targetBookTitle = cleanTitle;
                    console.log(`Targeting (from DOM): ${cleanTitle}`);
                    break;
                }
            }
        }

        if (targetBookUrl) {
            console.log(`Navigating directly to: ${targetBookUrl}`);
            await page.goto(targetBookUrl);
        } else if (targetBookDomElement) {
            console.log('Clicking DOM element to open book...');
            await targetBookDomElement.click();
        } else {
            console.log('All visible books are already processed. Finishing.');
            return;
        }
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
    
    let previousImgBytes = null;
    let stuckCount = 0;
    let forwardKey = 'ArrowLeft'; // Defaults to Japanese format (Left turn)
    const possibleKeys = ['ArrowLeft', 'ArrowRight', 'Space', 'PageDown'];
    let keyIndex = 0;

    // Capture Loop
    while (pageCount < maxPages) {
        pageCount++;
        const screenshotPath = path.join(screenshotsDir, `p${pageCount}.png`);

        await page.screenshot({ path: screenshotPath });
        const imgBytes = fs.readFileSync(screenshotPath);

        // Check if page actually turned (stuck detection)
        if (previousImgBytes && Buffer.compare(previousImgBytes, imgBytes) === 0) {
            stuckCount++;
            console.log(`Page unchanged. Stuck count: ${stuckCount}`);
            
            if (stuckCount >= 2) {
                // Try different interaction methods
                if (stuckCount === 2) {
                    console.log('Trying mouse click on right side...');
                    await page.mouse.click(1100, 800);
                } else if (stuckCount === 3) {
                    console.log('Trying mouse click on left side (for Japanese books)...');
                    await page.mouse.click(100, 800);
                } else if (stuckCount === 4) {
                    console.log('Trying Space key...');
                    await page.keyboard.press('Space');
                } else {
                    console.log('No movement after multiple attempts. Reached end of book.');
                    break;
                }
            }
        } else {
            // New page! Add to PDF
            console.log(`Captured unique page ${pageCount}.`);
            const img = await pdfDoc.embedPng(imgBytes);
            const pdfPage = pdfDoc.addPage([img.width, img.height]);
            pdfPage.drawImage(img, { x: 0, y: 0, width: img.width, height: img.height });
            
            previousImgBytes = imgBytes;
            stuckCount = 0;
        }

        // Standard turn attempt
        await page.keyboard.press(forwardKey);
        await page.waitForTimeout(3000); // Wait longer for render

        if (pageCount > 5 && await isEndOfBook(page)) {
            console.log('Reached end of book (marker detected).');
            break;
        }
    }

    const pdfBytes = await pdfDoc.save();
    const pdfPath = path.join(__dirname, 'output_book.pdf');
    fs.writeFileSync(pdfPath, pdfBytes);
    console.log(`PDF saved locally: ${pdfPath} (${(pdfBytes.length / 1024 / 1024).toFixed(1)} MB)`);

    // Step 4: Upload to Google Drive directly
    const driveUrl = await uploadToGoogleDrive(pdfPath, bookTitle);
    console.log(`Google Drive URL: ${driveUrl || 'N/A'}`);

    // Notify GAS
    await notifyGAS(bookTitle, 'Success', driveUrl);

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

async function uploadToGoogleDrive(filePath, bookTitle) {
    const credentialsJson = process.env.GOOGLE_DRIVE_CREDENTIALS_JSON;
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;
    if (!credentialsJson || !folderId) {
        console.warn('Google Drive credentials or folder ID not set. Skipping upload.');
        return null;
    }

    try {
        // Decode Base64 credentials
        const credentialsStr = Buffer.from(credentialsJson, 'base64').toString('utf-8');
        const credentials = JSON.parse(credentialsStr);

        const auth = new GoogleAuth({
            credentials: credentials,
            scopes: ['https://www.googleapis.com/auth/drive.file'],
        });

        const drive = google.drive({ version: 'v3', auth });

        const safeName = bookTitle.replace(/[^a-zA-Z0-9\u3000-\u9FFF\uFF00-\uFFEF_\-]/g, '_').substring(0, 100);
        const fileName = `${safeName}_${new Date().toISOString().slice(0,10)}.pdf`;

    let retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
        try {
            console.log(`Uploading to Google Drive as: ${fileName} (Attempt ${retryCount + 1})...`);
            const res = await drive.files.create({
                requestBody: { name: fileName, parents: [folderId] },
                media: { mimeType: 'application/pdf', body: fs.createReadStream(filePath) },
                fields: 'id, webViewLink',
            });
            console.log(`Upload successful! File ID: ${res.data.id}`);
            return res.data.webViewLink || `https://drive.google.com/file/d/${res.data.id}/view`;
        } catch (e) {
            console.error(`Upload attempt ${retryCount + 1} failed: ${e.message}`);
            if (e.message.includes('storage quota')) {
                console.error('CRITICAL: Service Account has NO storage quota. Please use Case A or Case C from the FIX PLAN.');
                break; // Quota error won't be fixed by retrying
            }
            retryCount++;
            if (retryCount <= maxRetries) await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }
        return null;
    } catch (e) {
        console.error('Fatal error during Google Drive upload:', e.message);
        return null;
    }
}

async function notifyGAS(title, status, driveUrl) {
    if (!GAS_URL) {
        console.warn('GAS_WEB_APP_URL is not set. Skipping GAS update.');
        return;
    }
    try {
        console.log(`Sending update to GAS for "${title}" with status "${status}"...`);
        const res = await axios.post(GAS_URL, {
            action: 'update_kindle_status',
            title: title,
            status: status,
            driveUrl: driveUrl || '',
            timestamp: new Date().toISOString()
        });
        if (res.data && res.data.success) {
            console.log('Successfully updated status in GAS.');
        } else {
            console.warn('GAS returned success: false or unexpected response:', res.data);
        }
    } catch (e) {
        console.error(`Failed to update status in GAS: ${e.message}`);
        if (e.response) {
            console.error(`Response data: ${JSON.stringify(e.response.data)}`);
            console.error(`Status code: ${e.response.status}`);
        }
    }
}

run().catch(err => {
    console.error('Fatal Error:', err);
    process.exit(1);
});
