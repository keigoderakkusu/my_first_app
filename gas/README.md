# 音声日報・議事録アプリ GASバックエンド

## ファイル構成

| ファイル | 内容 |
|---------|------|
| `Code.gs` | GASメインコード（コピペしてGASに貼り付ける） |
| `gas_service.dart` | Flutter/DartからGASを呼び出すサービスクラス |

---

## GASセットアップ手順

### 1. スプレッドシートを作成
1. [Google スプレッドシート](https://sheets.google.com) で新規シートを作成
2. シート名はなんでもOK（後でGASから「日報データ」シートが自動作成される）

### 2. GASエディタを開く
1. スプレッドシートで **拡張機能 > Apps Script** をクリック
2. `コード.gs` の中身を **`Code.gs` の内容で全部上書き**

### 3. 設定を変更
`Code.gs` の一番上の `CONFIG` を編集：
```js
const CONFIG = {
  GEMINI_API_KEY: 'ここにGeminiのAPIキーを入れる',
  NOTIFICATION_EMAIL: 'ここに受け取りメールアドレス',
  SEND_EMAIL: true,   // メール不要なら false
  SHEET_NAME: '日報データ',
};
```

### 4. Gemini APIキーの取得
1. [Google AI Studio](https://aistudio.google.com/apikey) にアクセス
2. 「APIキーを作成」をクリック → コピーしてCONFIGに貼り付け

### 5. デプロイ（Webアプリとして公開）
1. GASエディタ右上の **「デプロイ」>「新しいデプロイ」**
2. 種類：**「ウェブアプリ」**
3. 次のユーザーとして実行：**「自分」**
4. アクセスできるユーザー：**「全員」**
5. デプロイ → 表示されたURLをコピー

### 6. Flutter側にURLを設定
`gas_service.dart` の `_gasUrl` を書き換え：
```dart
static const String _gasUrl =
    'https://script.google.com/macros/s/【コピーしたID】/exec';
```

### 7. 動作テスト（GASエディタ内）
GASエディタで `testDoPost` 関数を選択して実行 → スプレッドシートに1行追加されればOK。

---

## データフロー

```
Flutter（音声認識テキスト）
    ↓ POST /exec
GAS doPost()
    ↓ Gemini API
構造化JSON（タイトル・決定事項・懸念点・ネクストアクション）
    ↓
Googleスプレッドシートに自動追記
    ↓
メール通知（オプション）
```

---

## Gemini に渡すプロンプト（要点）

GASの `buildPrompt()` 関数内のプロンプトが核心部分です。
以下の項目に構造化されます：

| フィールド | 内容 |
|-----------|------|
| `title` | 日報タイトル |
| `meeting_partner` | 商談相手（会社・人名） |
| `date` | 日時 |
| `location` | 場所・手段（対面/オンライン） |
| `summary` | 全体要約（3〜5文） |
| `decisions` | 決定事項リスト |
| `concerns` | 懸念点リスト |
| `next_actions` | ネクストアクション（担当・期限付き） |
| `memo` | その他メモ |
