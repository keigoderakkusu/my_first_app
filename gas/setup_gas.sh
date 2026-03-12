#!/bin/bash
# ===========================================================
# Life-Gravity 日報システム - GAS 自動デプロイスクリプト
# 実行方法: bash setup_gas.sh
# ===========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================="
echo "  Life-Gravity 日報システム GAS デプロイツール"
echo -e "=================================================${NC}"

# --- 依存チェック ---
echo -e "\n${YELLOW}[1/5] 依存関係を確認中...${NC}"
if ! command -v node &> /dev/null; then
  echo -e "${RED}✗ Node.js が見つかりません。https://nodejs.org からインストールしてください${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Node.js OK${NC}"

if ! command -v clasp &> /dev/null; then
  echo -e "${YELLOW}  clasp をインストール中...${NC}"
  npm install -g @google/clasp
fi
echo -e "${GREEN}✓ clasp OK${NC}"

# --- Google ログイン ---
echo -e "\n${YELLOW}[2/5] Google アカウントにログイン...${NC}"
if ! clasp login --status &> /dev/null 2>&1; then
  echo "ブラウザが開きます。Googleアカウントでログインしてください。"
  clasp login
else
  echo -e "${GREEN}✓ すでにログイン済み${NC}"
fi

# --- Gemini APIキー入力 ---
echo -e "\n${YELLOW}[3/5] Gemini API キーを入力してください${NC}"
echo "  (取得先: https://aistudio.google.com/apikey)"
read -p "  Gemini API Key: " GEMINI_KEY

echo -e "\n${YELLOW}  通知メールアドレスを入力してください${NC}"
read -p "  Email (Enterでスキップ): " EMAIL

# Code.gs に設定を注入
SEND_EMAIL="false"
if [ -n "$EMAIL" ]; then
  SEND_EMAIL="true"
fi

sed -i.bak \
  -e "s|YOUR_GEMINI_API_KEY|${GEMINI_KEY}|g" \
  -e "s|your@email.com|${EMAIL}|g" \
  -e "s|SEND_EMAIL: true|SEND_EMAIL: ${SEND_EMAIL}|g" \
  "$SCRIPT_DIR/Code.gs"
rm -f "$SCRIPT_DIR/Code.gs.bak"
echo -e "${GREEN}✓ 設定を反映しました${NC}"

# --- GASプロジェクト作成・プッシュ ---
echo -e "\n${YELLOW}[4/5] GASプロジェクトを作成・アップロード中...${NC}"
cd "$SCRIPT_DIR"

if [ ! -f ".clasp.json" ]; then
  # 新規スプレッドシートを作成してGASプロジェクトを紐付け
  clasp create --title "Life-Gravity 日報システム" --type sheets --rootDir .
  echo -e "${GREEN}✓ スプレッドシートとGASプロジェクトを作成しました${NC}"
else
  echo -e "${GREEN}✓ 既存プロジェクトを使用します${NC}"
fi

clasp push --force
echo -e "${GREEN}✓ コードをアップロードしました${NC}"

# --- デプロイ ---
echo -e "\n${YELLOW}[5/5] Webアプリとしてデプロイ中...${NC}"
DEPLOY_OUTPUT=$(clasp deploy --description "Life-Gravity 日報 v1.0" 2>&1)
echo "$DEPLOY_OUTPUT"

# デプロイIDを抽出
DEPLOYMENT_ID=$(echo "$DEPLOY_OUTPUT" | grep -oP '(?<=- )[A-Za-z0-9_-]+(?= @)' | tail -1)

if [ -z "$DEPLOYMENT_ID" ]; then
  # fallback: listから取得
  DEPLOYMENT_ID=$(clasp deployments 2>&1 | grep -oP '(?<=- )[A-Za-z0-9_-]+(?= @)' | tail -1)
fi

WEB_APP_URL="https://script.google.com/macros/s/${DEPLOYMENT_ID}/exec"

# gas_service.dart のURLを自動更新
DART_FILE="$SCRIPT_DIR/gas_service.dart"
if [ -f "$DART_FILE" ]; then
  sed -i.bak "s|https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec|${WEB_APP_URL}|g" "$DART_FILE"
  rm -f "$DART_FILE.bak"
  echo -e "${GREEN}✓ gas_service.dart のURLを自動更新しました${NC}"
fi

# .env ファイルに保存
cat > "$SCRIPT_DIR/.gas_env" << EOF
GAS_WEB_APP_URL=${WEB_APP_URL}
DEPLOYMENT_ID=${DEPLOYMENT_ID}
DEPLOYED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF

# --- 完了 ---
echo -e "\n${GREEN}================================================="
echo "  ✅ デプロイ完了！"
echo "================================================="
echo ""
echo "  🌐 WebアプリURL:"
echo "     ${WEB_APP_URL}"
echo ""
echo "  📊 スプレッドシートを開くには:"
clasp open --addon 2>/dev/null || echo "     clasp open を実行してください"
echo ""
echo "  📱 Flutter側の設定:"
echo "     gas/gas_service.dart の _gasUrl が自動更新されました"
echo -e "=================================================${NC}"
