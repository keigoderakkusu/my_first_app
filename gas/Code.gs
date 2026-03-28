// ============================================================
// 音声日報・議事録アプリ GASバックエンド (最新・完全版)
// ファイル名: Code.gs
// ============================================================

// ===== 設定 =====
function getConfig() {
  const props = PropertiesService.getScriptProperties();
  return {
    GEMINI_API_KEY:       props.getProperty('GEMINI_API_KEY'),
    NOTIFICATION_EMAIL:   'keigo828n@gmail.com',
    SEND_EMAIL:           false,
    SHEET_NAME:           '日報データ',
    KINDLE_SHEET_NAME:    'Kindleデータ',
    SPREADSHEET_ID:       props.getProperty('SPREADSHEET_ID') || null,
    GITHUB_CONFIG: {
      OWNER: 'keigoderakkusu',
      REPO:  'my_first_app',
      TOKEN: props.getProperty('GITHUB_TOKEN'),
    }
  };
}

// ===== ユーティリティ =====
function ensureArray(val) {
  return Array.isArray(val) ? val : (val ? [val] : []);
}

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// ===== スプレッドシート取得 =====
function getSpreadsheet() {
  const config = getConfig();
  if (config.SPREADSHEET_ID) {
    return SpreadsheetApp.openById(config.SPREADSHEET_ID);
  }
  return SpreadsheetApp.getActiveSpreadsheet();
}

// ===== CORS対応 =====
function doOptions(e) {
  return ContentService.createTextOutput('')
    .setMimeType(ContentService.MimeType.TEXT);
}

// ===== Webhook受信 (POST) =====
function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return jsonResponse({ success: false, error: 'リクエストデータが空です' });
    }

    const raw    = JSON.parse(e.postData.contents);
    const action = raw.action || 'report';

    if (action === 'report') {
      const voiceText = raw.text;
      const timestamp = raw.timestamp || new Date().toISOString();
      if (!voiceText) return jsonResponse({ success: false, error: 'テキストが空です' });

      const structured = structureWithGemini(voiceText);
      saveToSheet(structured, voiceText, timestamp);
      
      const config = getConfig();
      if (config.SEND_EMAIL) sendNotification(structured, timestamp);
      
      return jsonResponse({ success: true, data: structured });
    }

    if (action === 'trigger_kindle' || action === 'trigger_kindle_scraper') {
      const bookUrl   = raw.book_url || '';
      const githubRes = triggerGitHubAction('start-scraper', { book_url: bookUrl });
      if (githubRes.success) {
        return jsonResponse({ success: true, message: 'スクレイパーを起動しました' });
      } else {
        console.error('GitHub連携エラー: ' + githubRes.error);
        return jsonResponse({ success: false, error: githubRes.error });
      }
    }

    if (action === 'update_kindle_status') {
      return updateKindleStatus(raw.title, raw.status, raw.driveUrl, raw.timestamp);
    }

    return jsonResponse({ success: false, error: '不明なアクションです' });

  } catch (err) {
    console.error('doPost error:', err);
    return jsonResponse({ success: false, error: err.message });
  }
}

// ===== Webhook受信 (GET) =====
function doGet(e) {
  if (!e || !e.parameter) {
    return jsonResponse({ success: true, message: 'GAS Backend is active' });
  }

  const action = e.parameter.action;
  const setup  = e.parameter.setup;

  if (setup === '1') {
    setupProperties();
    return jsonResponse({ success: true, message: 'Properties have been set.' });
  }

  if (action === 'get_kindle_library') {
    return jsonResponse({ success: true, data: getKindleLibrary() });
  }

  if (action === 'trigger_kindle') {
    const bookUrl = e.parameter.book_url || '';
    const result  = triggerGitHubAction('start-scraper', { book_url: bookUrl });
    return jsonResponse({ success: true, message: 'スクレイパーを起動しました', github_response: result });
  }

  return jsonResponse({ success: true, message: 'GAS Backend is active' });
}

// ===== GitHub Actions トリガー =====
function triggerGitHubAction(eventType, clientPayload) {
  const config = getConfig();
  const url = 'https://api.github.com/repos/' + config.GITHUB_CONFIG.OWNER + '/' + config.GITHUB_CONFIG.REPO + '/dispatches';

  const options = {
    method:      'POST',
    contentType: 'application/json',
    headers: {
      'Authorization': 'Bearer ' + config.GITHUB_CONFIG.TOKEN,
      'Accept':        'application/vnd.github.v3+json',
    },
    payload:          JSON.stringify({ event_type: eventType, client_payload: clientPayload }),
    muteHttpExceptions: true,
  };

  try {
    const response = UrlFetchApp.fetch(url, options);
    const code     = response.getResponseCode();
    if (code === 204) return { success: true };
    return { success: false, error: 'HTTP ' + code + ' - ' + response.getContentText() };
  } catch (err) {
    return { success: false, error: err.toString() };
  }
}

// ===== Kindle ライブラリ取得 =====
function getKindleLibrary() {
  const config = getConfig();
  const ss     = getSpreadsheet();
  let sheet    = ss.getSheetByName(config.KINDLE_SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(config.KINDLE_SHEET_NAME);
    sheet.appendRow(['タイトル', 'URL', 'ステータス', '最終更新', '保存先URL']);
    return [];
  }
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) return [];
  const headers = values[0];
  return values.slice(1).map(row => {
    const obj = {};
    headers.forEach((h, i) => obj[h] = row[i]);
    return obj;
  });
}

// ===== Kindle ステータス更新 =====
function updateKindleStatus(title, status, driveUrl, timestamp) {
  const config = getConfig();
  const ss     = getSpreadsheet();
  let sheet    = ss.getSheetByName(config.KINDLE_SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(config.KINDLE_SHEET_NAME);
    sheet.appendRow(['タイトル', 'URL', 'ステータス', '最終更新', '保存先URL']);
  }

  const values   = sheet.getDataRange().getValues();
  let foundRow   = -1;
  for (let i = 1; i < values.length; i++) {
    if (values[i][0] === title) { foundRow = i + 1; break; }
  }

  const now = timestamp || new Date().toISOString();
  if (foundRow > 0) {
    sheet.getRange(foundRow, 3).setValue(status);
    sheet.getRange(foundRow, 4).setValue(now);
    if (driveUrl) sheet.getRange(foundRow, 5).setValue(driveUrl);
  } else {
    sheet.appendRow([title, '', status, now, driveUrl || '']);
  }

  return jsonResponse({ success: true });
}

// ===== Gemini API で構造化 =====
function structureWithGemini(voiceText) {
  const config = getConfig();
  if (!config.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY が設定されていません');
  }

  // 確実に対応している無料軽量モデルを指定
  const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=' + config.GEMINI_API_KEY;
  
  const payload = {
    contents: [{ parts: [{ text: buildPrompt(voiceText) }] }],
    generationConfig: { temperature: 0.2, responseMimeType: 'application/json' },
  };

  const options = {
    method:      'POST',
    contentType: 'application/json',
    payload:     JSON.stringify(payload),
    muteHttpExceptions: true,
  };

  const response = UrlFetchApp.fetch(url, options);
  const result   = JSON.parse(response.getContentText());

  if (response.getResponseCode() !== 200) {
    // 文字列結合で安全にエラーメッセージを作成（構文エラー対策）
    const errMsg = (result.error && result.error.message) ? result.error.message : 'unknown';
    throw new Error('Gemini APIエラー: ' + errMsg);
  }

  let jsonText = result.candidates[0].content.parts[0].text;
  jsonText = jsonText.replace(/^```(json)?|```$/gm, '').trim();

  return JSON.parse(jsonText);
}

// ===== プロンプト生成 =====
function buildPrompt(voiceText) {
  return `
あなたはビジネス日報・議事録の整理を行う専門AIアシスタントです。
以下の「音声認識テキスト（生データ）」を読み取り、構造化されたJSON形式に変換してください。

## 音声認識テキスト（生データ）
---
${voiceText}
---

## 出力形式（JSON）
以下のJSONスキーマに従って出力してください。不明な項目は "" または [] にしてください。
{
  "title": "日報または議事録のタイトル（簡潔に）",
  "meeting_partner": "商談・会議の相手（会社名・人名）",
  "date": "日時（テキストから読み取り。不明なら本日の日付）",
  "location": "場所・手段（対面/オンライン/電話など）",
  "summary": "全体の要約（3〜5文）",
  "decisions": ["決定事項1", "決定事項2"],
  "concerns": ["懸念点1", "懸念点2"],
  "next_actions": [
    { "action": "アクション内容", "owner": "担当者", "deadline": "期限" }
  ],
  "memo": "その他の補足・メモ"
}
JSONのみを出力してください。説明文や前置きは不要です。
`;
}

// ===== スプレッドシートに保存 =====
function saveToSheet(data, rawText, timestamp) {
  const config = getConfig();
  const ss     = getSpreadsheet();
  let sheet    = ss.getSheetByName(config.SHEET_NAME);

  if (!sheet) {
    sheet = ss.insertSheet(config.SHEET_NAME);
    const headers = ['記録日時','タイトル','商談相手','日時','場所','要約','決定事項','懸念点','ネクストアクション','メモ','生テキスト'];
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
    sheet.setFrozenRows(1);
  }

  const row = [
    new Date(timestamp),
    data.title           || '',
    data.meeting_partner || '',
    data.date            || '',
    data.location        || '',
    data.summary         || '',
    ensureArray(data.decisions).join('\n'),
    ensureArray(data.concerns).join('\n'),
    ensureArray(data.next_actions).map(a => '・' + (a.action || '') + '（担当: ' + (a.owner || '') + '、期限: ' + (a.deadline || '') + '）').join('\n'),
    data.memo            || '',
    rawText,
  ];

  sheet.appendRow(row);
  const lastRow = sheet.getLastRow();
  sheet.getRange(lastRow, 1, 1, row.length).setWrap(true);
}

// ===== メール通知 =====
function sendNotification(data, timestamp) {
  const config  = getConfig();
  const date    = new Date(timestamp).toLocaleString('ja-JP');
  
  const actions = ensureArray(data.next_actions)
    .map((a, i) => '  ' + (i+1) + '. ' + (a.action || '') + '（担当: ' + (a.owner || '') + '、期限: ' + (a.deadline || '') + '）')
    .join('\n');

  const body = `
【日報・議事録】${data.title || '（タイトルなし）'}
記録日時: ${date}

▼ 商談相手
${data.meeting_partner || '不明'}

▼ 日時・場所
${data.date || '不明'} ／ ${data.location || '不明'}

▼ 要約
${data.summary || '（なし）'}

▼ 決定事項
${ensureArray(data.decisions).map((d, i) => '  ' + (i+1) + '. ' + d).join('\n') || '  （なし）'}

▼ 懸念点
${ensureArray(data.concerns).map((c, i) => '  ' + (i+1) + '. ' + c).join('\n') || '  （なし）'}

▼ ネクストアクション
${actions || '  （なし）'}

▼ メモ
${data.memo || '（なし）'}

---
Life-Gravity 日報システム から自動送信
`;

  GmailApp.sendEmail(
    config.NOTIFICATION_EMAIL,
    `【日報】${data.title || '新しい記録'} - ${date}`,
    body
  );
}

// ===== 手動テスト用 =====
function testDoPost() {
  const mockE = {
    postData: {
      contents: JSON.stringify({
        text: `
          本日15時、株式会社テスト商事の田中部長と商談を行いました。
          先方から新サービス導入について前向きな回答をいただきました。
          ただし、予算承認に社内決裁が必要とのことで、来週金曜日までに見積もりを送付する必要があります。
          懸念点としては、競合他社も同時に提案しているとのこと。
          ネクストアクションは、見積書の作成（担当：自分、期限：今週金曜）と
          サービス資料のアップデート（担当：マーケ、期限：木曜）です。
        `,
        timestamp: new Date().toISOString(),
      })
    }
  };
  const result = doPost(mockE);
  console.log(result.getContent());
}
