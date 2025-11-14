#!/bin/bash

echo "🚀 Gitea と Jenkins への接続を開始します"
echo ""
echo "新しいターミナルウィンドウが2つ開きます:"
echo "  - Gitea: http://localhost:8080"
echo "  - Jenkins: http://localhost:8081"
echo ""

# macOS/Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  osascript -e 'tell app "Terminal" to do script "cd \"'$(pwd)'\" && ./scripts/connect-gitea.sh"'
  sleep 2
  osascript -e 'tell app "Terminal" to do script "cd \"'$(pwd)'\" && ./scripts/connect-jenkins.sh"'
elif command -v gnome-terminal &> /dev/null; then
  # Linux with GNOME
  gnome-terminal -- bash -c "cd $(pwd) && ./scripts/connect-gitea.sh; exec bash"
  sleep 2
  gnome-terminal -- bash -c "cd $(pwd) && ./scripts/connect-jenkins.sh; exec bash"
else
  echo "⚠️  自動的にターミナルを開けませんでした"
  echo "   手動で以下を別々のターミナルで実行してください:"
  echo ""
  echo "   ターミナル1: ./scripts/connect-gitea.sh"
  echo "   ターミナル2: ./scripts/connect-jenkins.sh"
fi

echo ""
echo "✅ 接続スクリプトを起動しました"
