const { chromium } = require('playwright');
const { PDFDocument } = require('pdf-lib');
const fs = require('fs-extra');
const path = require('path');
const { google } = require('googleapis');

async function run() {
    const email = process.env.AMAZON_EMAIL;
    const password = process.env.AMAZON_PASSWORD;
    const bookUrl = process.env.KINDLE_BOOK_URL; // Specific book URL support
    const maxPages = parseInt(process.env.MAX_PAGES || '500');
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;
    const credentialsJson = process.env.GOOGLE_DRIVE_CREDENTIALS_JSON;

    if (!email || !password) {
        console.error('Error: AMAZON_EMAIL and AMAZON_PASSWORD environment variables are required.');
        process.exit(1);
    }

    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        viewport: { width: 1200, height: 1600 },
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    });
    const page = await context.newPage();

    console.log('Logging in to Amazon Kindle Cloud Reader...');
    await page.goto('https://read.amazon.co.jp/');

    // Check if login is needed
    if (await page.$('#ap_email')) {
        await page.fill('#ap_email', email);
        await page.click('#continue');
        await page.fill('#ap_password', password);
        await page.click('#signInSubmit');
    }

    // Check for OTP or Verification
    await page.waitForTimeout(5000);
    if (page.url().includes('cvf/approval')) {
        console.error('Login Error: Amazon requires manual approval/OTP. Please login manually in a browser first or handle OTP.');
        // In a real scenario, we might wait for manual input or use a service to solve this.
        // For this POC, we assume session or simple login works.
        await page.screenshot({ path: 'login_error.png' });
        process.exit(1);
    }

    console.log('Successfully logged in (hopefully). Navigating to library...');
    await page.goto('https://read.amazon.co.jp/kindle-library');
    await page.waitForTimeout(5000);

    // If bookUrl is provided, go there. Otherwise, find the first book.
    if (bookUrl && bookUrl.includes('read.amazon')) {
        console.log(`Navigating to specific book: ${bookUrl}`);
        await page.goto(bookUrl);
    } else {
        console.log('No URL provided or invalid URL. Scanning library for the most recent book...');
        // The library page might take time to render items
        await page.waitForSelector('.library-item, #library-container', { timeout: 30000 });

        // Attempt to find the first book cover/link
        // Kindle Cloud Reader structure often uses data-asin or specific ARIA labels
        const books = await page.$$('.library-item');
        if (books.length > 0) {
            console.log(`Found ${books.length} books. Opening the first one...`);
            await books[0].click();
        } else {
            console.error('Library Error: No books found in the library. Please make sure you have books in your Kindle account.');
            await page.screenshot({ path: 'library_empty.png' });
            process.exit(1);
        }
    }

    console.log('Book opened. Starting screenshot loop...');
    await page.waitForTimeout(10000); // Wait for reader to load

    const screenshotsDir = path.join(__dirname, 'temp_screenshots');
    await fs.ensureDir(screenshotsDir);

    let pageCount = 0;
    const pdfDoc = await PDFDocument.create();

    while (pageCount < maxPages) {
        pageCount++;
        const screenshotPath = path.join(screenshotsDir, `p${pageCount}.png`);

        // Capture the reader content
        // Note: Kindle Cloud Reader often uses a canvas or multiple divs. 
        // We might need to target a specific wrapper.
        await page.screenshot({ path: screenshotPath });
        console.log(`Captured page ${pageCount}`);

        // Embed in PDF
        const imgBytes = fs.readFileSync(screenshotPath);
        const img = await pdfDoc.embedPng(imgBytes);
        const pageObj = pdfDoc.addPage([img.width, img.height]);
        pageObj.drawImage(img, { x: 0, y: 0, width: img.width, height: img.height });

        // Click Next Page
        // Kindle usually has a specific button or allows arrow keys
        const nextButton = await page.$('.next-button'); // Placeholder selector
        if (nextButton) {
            await nextButton.click();
        } else {
            await page.keyboard.press('ArrowRight');
        }

        await page.waitForTimeout(2000); // Wait for page turn animation

        // Detect end of book
        // (Logic to detect if the page content didn't change or if a "End of Book" dialog appeared)
        if (pageCount > 10 && await isEndOfBook(page)) {
            console.log('Reached end of book.');
            break;
        }
    }

    const pdfBytes = await pdfDoc.save();
    const pdfPath = path.join(__dirname, 'output_book.pdf');
    fs.writeFileSync(pdfPath, pdfBytes);
    console.log(`Successfully generated PDF: ${pdfPath}`);

    // Upload to Google Drive
    const fileName = `KindleBook_${new Date().toISOString().split('T')[0]}.pdf`;
    await uploadToGoogleDrive(pdfPath, fileName, folderId, credentialsJson);

    await browser.close();
    await fs.remove(screenshotsDir);
}

async function isEndOfBook(page) {
    // Common markers for end of book in Kindle Cloud Reader
    const markers = ['本を評価', 'Rate this book', '次のおすすめ'];
    const content = await page.content();
    return markers.some(m => content.includes(m));
}

async function uploadToGoogleDrive(filePath, fileName, folderId, credentialsJson) {
    if (!credentialsJson || !folderId) {
        console.log('Skipping Google Drive upload: Credentials or Folder ID not provided.');
        return;
    }

    try {
        console.log('Uploading PDF to Google Drive...');
        const credentials = JSON.parse(credentialsJson);
        const auth = new google.auth.GoogleAuth({
            credentials,
            scopes: ['https://www.googleapis.com/auth/drive.file'],
        });

        const drive = google.drive({ version: 'v3', auth });
        const fileMetadata = {
            name: fileName,
            parents: [folderId],
        };
        const media = {
            mimeType: 'application/pdf',
            body: fs.createReadStream(filePath),
        };

        const response = await drive.files.create({
            resource: fileMetadata,
            media: media,
            fields: 'id, webViewLink',
        });

        console.log('Successfully uploaded to Google Drive:', response.data.id);
        console.log('View Link:', response.data.webViewLink);
        return response.data.webViewLink;
    } catch (error) {
        console.error('Error uploading to Google Drive:', error);
    }
}

run().catch(err => {
    console.error('Fatal Error:', err);
    process.exit(1);
});
