# Bitcoin Tracker - 資産管理アプリ

Bitcoinの現在価格をリアルタイムで取得・表示するシンプルな資産管理アプリのプロトタイプです。

## 機能

- ✅ Bitcoin (BTC) の現在価格をUSD・JPYで表示
- ✅ 「更新」ボタンでリアルタイム価格取得
- ✅ CoinGecko API使用（APIキー不要）
- ✅ ダークテーマUI

## 使用技術

- **Flutter** 3.x
- **http** パッケージ（API通信）
- **intl** パッケージ（数値フォーマット）
- **API**: [CoinGecko](https://www.coingecko.com/en/api) (無料、認証不要)

## Project IDX へのインポート手順

1. Project IDX (https://idx.google.com) を開く
2. 「Import a repo」を選択
3. このリポジトリのURLを入力:  
   `https://github.com/keigoderakki/my-first-app`
4. Flutter テンプレートとして自動認識される
5. `flutter pub get` を実行（自動で実行される場合もあり）
6. アプリを実行

## ローカル実行

```bash
# 依存関係のインストール
flutter pub get

# アプリ実行
flutter run
```

## フォルダ構成

```
bitcoin_app/
├── lib/
│   └── main.dart        # メインアプリケーション
├── android/             # Android設定
├── ios/                 # iOS設定
├── pubspec.yaml         # Flutter依存関係定義
└── README.md
```

## スクリーンショット

ダークテーマ・Bitcoinオレンジカラーの洗練されたUI。  
起動時に自動で価格取得、「更新」ボタンで再取得可能。
