// ============================================================
// 音声日報・議事録アプリ GASバックエンド
// ファイル名: Code.gs
// ============================================================

// ===== 設定 =====
const CONFIG = {
  GEMINI_API_KEY: 'AIzaSyCmEd3SGm3LqrlblJJQX9agDL0pOy9Nq6w',
  NOTIFICATION_EMAIL: 'keigo828n@gmail.com',         // ← 通知先メールアドレス
  SEND_EMAIL: false,                              // false にするとメール通知OFF
  SHEET_NAME: '日報データ',                      // スプレッドシートのシート名
  KINDLE_SHEET_NAME: 'Kindleデータ',            // Kindle用シート名
  GITHUB_CONFIG: {
    OWNER: 'keigoderakkusu',
    REPO: 'my_first_app',
    TOKEN: PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN') // GASのスクリプトプロパティから取得するように変更
  }
};

function doOptions(e) {
  return ContentService.createTextOutput("")
    .setMimeType(ContentService.MimeType.TEXT);
}

// ===== Webhook受信エントリーポイント (POST) =====
function doPost(e) {
  try {
    const raw = JSON.parse(e.postData.contents);
    const action = raw.action || 'report'; // デフォルトは日報

    // 1. 日報処理
    if (action === 'report') {
      const voiceText = raw.text;
      const timestamp  = raw.timestamp || new Date().toISOString();
      if (!voiceText) return jsonResponse({ success: false, error: 'テキストが空です' }, 400);
      const structured = structureWithGemini(voiceText);
      saveToSheet(structured, voiceText, timestamp);
      if (CONFIG.SEND_EMAIL) sendNotification(structured, timestamp);
      return jsonResponse({ success: true, data: structured });
    }

    // 2. Kindle スクレイパー開始
    if (action === 'trigger_kindle') {
      const bookUrl = raw.book_url || '';
      const result = triggerGitHubAction('start-scraper', { book_url: bookUrl });
      return jsonResponse({ success: true, message: 'スクレイパーを起動しました', github_response: result });
    }

    // 3. Kindle ステータス更新 (スクレイパーからの通知)
    if (action === 'update_kindle_status') {
      return updateKindleStatus(raw.title, raw.status, raw.timestamp);
    }

    return jsonResponse({ success: false, error: '不明なアクションです' }, 400);

  } catch (err) {
    console.error('doPost error:', err);
    return jsonResponse({ success: false, error: err.message }, 500);
  }
}

// ===== Webhook受信エントリーポイント (GET) =====
function doGet(e) {
  const action = e.parameter.action;

  if (action === 'get_kindle_library') {
    const data = getKindleLibrary();
    return jsonResponse({ success: true, data: data });
  }

  // 追加: GET リクエストによるスクレイパー起動 (CORS 回避用)
  if (action === 'trigger_kindle') {
    const bookUrl = e.parameter.book_url || '';
    const result = triggerGitHubAction('start-scraper', { book_url: bookUrl });
    return jsonResponse({ success: true, message: 'スクレイパーを起動しました（GET）', github_response: result });
  }

  return jsonResponse({ success: true, message: 'GAS Backend is active' });
}

// ===== GitHub Actions をトリガーする =====
function triggerGitHubAction(eventType, clientPayload) {
  const url = `https://api.github.com/repos/${CONFIG.GITHUB_CONFIG.OWNER}/${CONFIG.GITHUB_CONFIG.REPO}/dispatches`;
  
  const payload = {
    event_type: eventType,
    client_payload: clientPayload
  };

  const options = {
    method: 'POST',
    contentType: 'application/json',
    headers: {
      'Authorization': `token ${CONFIG.GITHUB_CONFIG.TOKEN}`,
      'Accept': 'application/vnd.github.v3+json'
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  const response = UrlFetchApp.fetch(url, options);
  return response.getContentText();
}

// ===== Kindle ライブラリ情報の取得 =====
function getKindleLibrary() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(CONFIG.KINDLE_SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(CONFIG.KINDLE_SHEET_NAME);
    sheet.appendRow(['タイトル', 'URL', 'ステータス', '最終更新', '保存先URL']);
    return [];
  }

  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) return [];

  const headers = values[0];
  const rows = values.slice(1);

  return rows.map(row => {
    let obj = {};
    headers.forEach((h, i) => obj[h] = row[i]);
    return obj;
  });
}

/**
 * スクレイパーからの完了通知を受け取り、ステータスを更新する
 */
function updateKindleStatus(title, status, timestamp) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(CONFIG.KINDLE_SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(CONFIG.KINDLE_SHEET_NAME);
    sheet.appendRow(['タイトル', 'URL', 'ステータス', '最終更新', '保存先URL']);
  }
  
  const values = sheet.getDataRange().getValues();
  let foundRow = -1;
  
  for (let i = 1; i < values.length; i++) {
    if (values[i][0] === title) {
      foundRow = i + 1;
      break;
    }
  }
  
  const now = timestamp || new Date().toISOString();
  
  if (foundRow > 0) {
    // 既存の行を更新 (ステータス=3列目, 最終更新=4列目)
    sheet.getRange(foundRow, 3).setValue(status);
    sheet.getRange(foundRow, 4).setValue(now);
  } else {
    // 新規追加: タイトル, URL(空), ステータス, 最終更新, 保存先URL(空)
    sheet.appendRow([title, '', status, now, '']);
  }
  
  return jsonResponse({ success: true });
}

// ===== Gemini API で構造化 =====
function structureWithGemini(voiceText) {
  const prompt = buildPrompt(voiceText);

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${CONFIG.GEMINI_API_KEY}`;

  const payload = {
    contents: [{
      parts: [{ text: prompt }]
    }],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: 'application/json',
    }
  };

  const options = {
    method: 'POST',
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  };

  const response = UrlFetchApp.fetch(url, options);
  const result   = JSON.parse(response.getContentText());

  if (response.getResponseCode() !== 200) {
    throw new Error(`Gemini APIエラー: ${result.error?.message || 'unknown'}`);
  }

  const jsonText = result.candidates[0].content.parts[0].text;
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
以下のJSONスキーマに従って出力してください。不明な項目は "" (空文字) または [] (空配列) にしてください。

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
  const ss    = SpreadsheetApp.getActiveSpreadsheet();
  let sheet   = ss.getSheetByName(CONFIG.SHEET_NAME);

  // シートがなければ作成
  if (!sheet) {
    sheet = ss.insertSheet(CONFIG.SHEET_NAME);
    const headers = [
      '記録日時', 'タイトル', '商談相手', '日時', '場所',
      '要約', '決定事項', '懸念点', 'ネクストアクション', 'メモ', '生テキスト'
    ];
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
    sheet.setFrozenRows(1);
  }

  const row = [
    new Date(timestamp),
    data.title        || '',
    data.meeting_partner || '',
    data.date         || '',
    data.location     || '',
    data.summary      || '',
    (data.decisions   || []).join('\n'),
    (data.concerns    || []).join('\n'),
    (data.next_actions || []).map(a =>
      `・${a.action}（担当: ${a.owner}、期限: ${a.deadline}）`
    ).join('\n'),
    data.memo         || '',
    rawText,
  ];

  sheet.appendRow(row);
  // 最終行を自動折り返し
  const lastRow = sheet.getLastRow();
  sheet.getRange(lastRow, 1, 1, row.length).setWrap(true);
}

// ===== メール通知 =====
function sendNotification(data, timestamp) {
  const date    = new Date(timestamp).toLocaleString('ja-JP');
  const actions = (data.next_actions || []).map((a, i) =>
    `  ${i+1}. ${a.action}（担当: ${a.owner}、期限: ${a.deadline}）`
  ).join('\n');

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
${(data.decisions || []).map((d, i) => `  ${i+1}. ${d}`).join('\n') || '  （なし）'}

▼ 懸念点
${(data.concerns || []).map((c, i) => `  ${i+1}. ${c}`).join('\n') || '  （なし）'}

▼ ネクストアクション
${actions || '  （なし）'}

▼ メモ
${data.memo || '（なし）'}

---
Life-Gravity 日報システム から自動送信
`;

  GmailApp.sendEmail(
    CONFIG.NOTIFICATION_EMAIL,
    `【日報】${data.title || '新しい記録'} - ${date}`,
    body
  );
}

// ===== ユーティリティ: JSONレスポンス =====
function jsonResponse(obj, statusCode = 200) {
  // text/plain にすることで、ブラウザが CORS プリフライト（OPTIONS）を要求しにくくなる
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.TEXT);
}

// ===== (GASエディタから手動テスト用) =====
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
