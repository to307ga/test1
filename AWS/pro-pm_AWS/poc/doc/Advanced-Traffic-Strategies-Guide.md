# Advanced Blue-Green Deployment: トラフィック戦略詳細ガイド

## 🎯 トラフィック戦略の詳細解説

### **1. 段階的切り替え (Gradual Strategy)**

#### **トリガー条件**

**現在の実装:**
```python
# 時間ベーストリガー
time.sleep(validation_minutes * 60)

# ヘルスチェックベース
healthy_count, total_count = check_target_group_health(target_group_arn)

# メトリクスベーストリガー（新機能）
validate_metrics(load_balancer_name, error_threshold=5.0, response_time_threshold=2.0)
```

**改善されたトリガー条件:**

1. **時間ベース**: 設定可能な待機時間（1-30分）
2. **ヘルスチェックベース**: Target Groupの健全性確認
3. **メトリクスベース**: 
   - エラー率（5XX）が閾値以下
   - レスポンス時間が閾値以下
   - リクエスト数の安定性
4. **手動承認**: 本番環境での段階的承認
5. **自動進行**: `--auto-proceed`オプションでの完全自動化

#### **実行例**

```bash
# 手動確認付き段階的切り替え
python3 scripts/advanced_blue_green_traffic_manager.py \
    --environment poc \
    --application poc-web \
    --action shift \
    --target green \
    --percentage 10 \
    --validation-minutes 5 \
    --metric-validation

# 完全自動化
python3 scripts/advanced_blue_green_traffic_manager.py \
    --environment poc \
    --application poc-web \
    --action shift \
    --target green \
    --percentage 20 \
    --validation-minutes 3 \
    --auto-proceed \
    --metric-validation
```

---

### **2. IP基盤カナリア切り替え (IP-Based Canary)**

#### **特定IPアドレス指定機能**

**✅ 実装済み機能:**
- 事務所固定IPアドレス指定
- Jenkins/CI環境からのE2Eテスト
- 複数IP範囲の同時指定
- CIDR記法対応

#### **使用例**

```bash
# 事務所IPとJenkins IPでのカナリアテスト
python3 scripts/advanced_blue_green_traffic_manager.py \
    --environment poc \
    --application poc-web \
    --action canary-ip \
    --target green \
    --canary-ips 203.0.113.100/32 10.0.1.50/32 192.168.1.0/24

# カナリアルール削除
python3 scripts/advanced_blue_green_traffic_manager.py \
    --environment poc \
    --application poc-web \
    --action cleanup-rule \
    --rule-arn arn:aws:elasticloadbalancing:ap-northeast-1:123456789:listener-rule/app/poc-poc-web-alb/12345/abcdef
```

#### **Jenkins統合例**

```groovy
// Jenkinsfile内でのIP基盤カナリア
stage('IP-Based Canary Setup') {
    steps {
        script {
            // 事務所IP + Jenkins IP
            def canaryIPs = "203.0.113.100/32 ${env.JENKINS_IP}"
            
            sh """
                CANARY_RULE_ARN=\$(python3 scripts/advanced_blue_green_traffic_manager.py \\
                    --environment ${params.ENVIRONMENT} \\
                    --application ${env.APPLICATION_NAME} \\
                    --action canary-ip \\
                    --target ${env.TARGET_COLOR} \\
                    --canary-ips ${canaryIPs})
            """
        }
    }
}
```

---

## 🧪 E2Eテスト統合

### **Playwright自動テスト**

#### **IP基盤カナリア環境でのテスト**

```bash
# カナリア環境でのE2Eテスト実行
python3 tests/e2e/test_blue_green_deployment.py \
    --base-url http://alb-dns-name.elb.amazonaws.com \
    --environment poc \
    --target green \
    --headless

# Pytest経由での実行
pytest tests/e2e/ \
    --browser chromium \
    --environment poc \
    --target green \
    --base-url http://alb-dns-name.elb.amazonaws.com \
    --junit-xml=test-results.xml
```

#### **テストスイート内容**

1. **Health Check**: `/health.php`エンドポイント確認
2. **Main Page Load**: メインページ読み込み確認
3. **Application Functionality**: 主要機能のテスト
4. **API Endpoints**: APIエンドポイントの確認
5. **Performance Metrics**: レスポンス時間とページロード測定
6. **Responsive Design**: 異なる画面サイズでのテスト

### **事務所からの手動検証**

#### **アクセス方法**

```bash
# 1. IP基盤カナリアルール設定（Jenkins経由）
# 2. 事務所固定IPからALBアクセス
curl -H "Host: your-app.example.com" http://alb-dns-name.elb.amazonaws.com/

# 3. ブラウザでの手動確認
# - Green環境に自動的にルーティング
# - 通常ユーザーは引き続きBlue環境
```

---

## 🔧 実践的な運用シナリオ

### **シナリオ1: 本番環境でのOS脆弱性パッチ適用**

```bash
# 1. 新しいGolden AMI作成（OSパッチ適用済み）
cd /home/tomo/poc/packer
packer build \
    -var 'environment=prod' \
    -var 'ami_version=20241015-security-patch' \
    golden-ami.pkr.hcl

# 2. Green環境構築
cd /home/tomo/poc/sceptre
uv run sceptre update prod/ec2-green --yes

# 3. IP基盤カナリアテスト
python3 scripts/advanced_blue_green_traffic_manager.py \
    --environment prod \
    --application poc-web \
    --action canary-ip \
    --target green \
    --canary-ips 203.0.113.100/32

# 4. E2Eテスト実行
pytest tests/e2e/ --environment prod --target green

# 5. 段階的トラフィック移行
python3 scripts/advanced_blue_green_traffic_manager.py \
    --environment prod \
    --application poc-web \
    --action shift \
    --target green \
    --percentage 5 \
    --validation-minutes 10 \
    --metric-validation

# 6. 本番環境でのクリーンアップ
# （手動承認後）
```

### **シナリオ2: アプリケーション新機能リリース**

```bash
# Jenkinsパイプライン実行
# パラメータ設定:
# - ENVIRONMENT: prod
# - DEPLOYMENT_TYPE: application
# - TRAFFIC_STRATEGY: ip-canary
# - CANARY_IPS: 203.0.113.100/32,10.0.1.50/32
# - AUTO_PROCEED: false
# - METRIC_VALIDATION: true

# 手動検証ステップ:
# 1. IP基盤カナリア環境での機能確認
# 2. E2Eテスト結果確認
# 3. 段階的トラフィック移行承認
# 4. 最終環境クリーンアップ承認
```

### **シナリオ3: 緊急時ロールバック**

```bash
# 即座のロールバック
python3 scripts/advanced_blue_green_traffic_manager.py \
    --environment prod \
    --application poc-web \
    --action rollback

# または Jenkins UI から "Emergency Rollback" ジョブ実行
```

---

## 📊 トラフィック戦略比較表

| 戦略 | 用途 | 切り替え時間 | リスク | 検証レベル |
|------|------|--------------|---------|------------|
| **Immediate** | 緊急パッチ | 1分 | 高 | 基本 |
| **Gradual** | 通常リリース | 15-30分 | 低 | 段階的 |
| **Canary** | 重要リリース | 5-10分 | 中 | 小規模先行 |
| **IP-Canary** | 本番前検証 | 設定次第 | 最低 | 完全制御 |

---

## ⚙️ 設定可能パラメータ

### **Jenkinsパイプラインパラメータ**

```groovy
parameters {
    // 基本設定
    choice(name: 'ENVIRONMENT', choices: ['poc', 'dev', 'staging', 'prod'])
    choice(name: 'TRAFFIC_STRATEGY', choices: ['gradual', 'immediate', 'canary', 'ip-canary'])
    
    // 詳細制御
    booleanParam(name: 'AUTO_PROCEED', defaultValue: false)
    booleanParam(name: 'METRIC_VALIDATION', defaultValue: true)
    string(name: 'SHIFT_PERCENTAGE', defaultValue: '10')      // 5-50
    string(name: 'VALIDATION_MINUTES', defaultValue: '5')     // 1-30
    string(name: 'CANARY_IPS', defaultValue: '')             // IP範囲指定
}
```

### **スクリプト直接実行パラメータ**

```bash
python3 scripts/advanced_blue_green_traffic_manager.py \
    --environment poc \                    # 環境名
    --application poc-web \                # アプリケーション名
    --action shift \                       # アクション
    --target green \                       # ターゲット色
    --percentage 10 \                      # ステップ割合
    --validation-minutes 5 \               # 検証時間
    --auto-proceed \                       # 自動進行
    --metric-validation \                  # メトリクス検証
    --canary-ips 203.0.113.100/32 \      # カナリアIP
    --region ap-northeast-1                # AWSリージョン
```

---

## 🛡️ セキュリティとベストプラクティス

### **IP基盤カナリアのセキュリティ**

1. **IP許可リスト管理**: 事前定義されたIP範囲のみ
2. **一時的ルール**: テスト完了後の自動クリーンアップ
3. **監査ログ**: 全アクセスのCloudTrail記録
4. **権限制御**: カナリア設定権限の制限

### **本番環境での注意事項**

1. **段階的承認**: 重要な本番変更での手動確認
2. **ロールバック準備**: 常に即座のロールバック可能性
3. **監視強化**: CloudWatchアラームとSlack通知
4. **変更記録**: 全デプロイメントの詳細ログ

---

## 📋 チェックリスト

### **IP基盤カナリア実行前**
- [ ] 事務所固定IPアドレス確認
- [ ] Jenkins環境IPアドレス確認
- [ ] E2Eテストスクリプト更新
- [ ] Green環境の健全性確認

### **段階的切り替え実行前**
- [ ] CloudWatchアラーム設定確認
- [ ] ロールバック手順確認
- [ ] 監視体制準備
- [ ] 緊急連絡先確認

### **本番環境クリーンアップ前**
- [ ] 新環境24時間安定稼働確認
- [ ] 全機能動作確認完了
- [ ] ユーザーフィードバック確認
- [ ] 次回デプロイメント準備

この実装により、**完全に制御された段階的デプロイメント**と**特定IP向けカナリアテスト**が可能になります！
