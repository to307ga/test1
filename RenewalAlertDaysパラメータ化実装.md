# RenewalAlertDaysパラメータ化実装完了

## 実装内容

### 問題
Phase 8監視システムで、証明書期限アラートの閾値がハードコードされていました：
```python
# 修正前（ハードコード）
if days_until_expiry <= 16:
```

### 解決策
`RenewalAlertDays`パラメータを使用してパラメータファイルで制御可能にしました。

## 修正されたファイル

### 1. Phase 2 DKIM Manager V2設定
**ファイル**: `sceptre/config/prod/phase-2-dkim-system-v2.yaml`
```yaml
# 修正後
RenewalAlertDays: 16         # Alert 16 days before expiration for DNS coordination (2 weeks + buffer)
```

**変更点**:
- ✅ `1` → `16` に変更（DNS調整期間2週間+余裕を考慮）
- ✅ コメント追加でDNS調整期間の説明明確化

### 2. Phase 8監視システム設定
**ファイル**: `sceptre/config/prod/phase-8-monitoring.yaml`
```yaml
# 追加
RenewalAlertDays: 16  # Phase 2と同じ値：DNS調整期間考慮（2週間+余裕）
```

**変更点**:
- ✅ `RenewalAlertDays`パラメータを新規追加
- ✅ Phase 2と同じ値で統一

### 3. Phase 8テンプレート
**ファイル**: `sceptre/templates/phase-8-monitoring.yaml`

#### パラメータ定義追加
```yaml
RenewalAlertDays:
  Type: Number
  Description: Alert threshold in days before certificate expiration
  Default: 16
  MinValue: 1
  MaxValue: 365
```

#### 環境変数追加
```yaml
Environment:
  Variables:
    MONITORING_TOPIC_ARN: !Ref MonitoringNotificationTopic
    RENEWAL_ALERT_DAYS: !Ref RenewalAlertDays  # 新規追加
```

#### Lambda関数ロジック修正
```python
# 修正前（ハードコード）
if days_until_expiry <= 16:

# 修正後（パラメータ化）
renewal_alert_days = int(os.environ.get('RENEWAL_ALERT_DAYS', 16))
if days_until_expiry <= renewal_alert_days:
```

## パラメータ統一の効果

### ✅ **運用面のメリット**
1. **一元管理**: Phase 2とPhase 8の両方で同じパラメータ値を使用
2. **柔軟性**: 環境やDNS調整プロセスに応じて閾値を調整可能
3. **一貫性**: 全システムで統一されたアラートタイミング

### ✅ **現在の設定（DNS調整最適化）**
- **本番環境**: `RenewalAlertDays: 16`
  - DNS申請・登録期間: 2週間
  - 余裕期間: 2日
  - 合計: 16日前アラート

### ✅ **テスト環境での活用**
```yaml
# テスト時の設定例
RenewalAlertDays: 1   # テスト用（即座アラート）
RenewalAlertDays: 7   # 検証用（1週間前）
RenewalAlertDays: 30  # 余裕をもった運用
```

## 統合フロー確認

### Phase 2 → Phase 8連携
1. **Phase 2**: `RenewalAlertDays: 16`でDKIM Manager設定
2. **Phase 8**: 同じ`16日`で証明書監視実行
3. **連携**: 統一された閾値でシステム全体が動作

### パラメータ変更時の影響
```bash
# パラメータ変更手順（例: 30日前アラートに変更）
# 1. Phase 2設定変更
sed -i 's/RenewalAlertDays: 16/RenewalAlertDays: 30/' phase-2-dkim-system-v2.yaml

# 2. Phase 8設定変更  
sed -i 's/RenewalAlertDays: 16/RenewalAlertDays: 30/' phase-8-monitoring.yaml

# 3. デプロイ実行
sceptre update prod/phase-2-dkim-system-v2.yaml --yes
sceptre update prod/phase-8-monitoring.yaml --yes
```

## 結論

✅ **ハードコードされた閾値**を**パラメータ化**により解決  
✅ **Phase 2とPhase 8**で**統一されたRenewalAlertDays**使用  
✅ **DNS調整期間**を考慮した**16日前アラート**設定  
✅ **運用時の柔軟性**と**システム一貫性**を両立

これにより、証明書期限アラートのタイミングを環境やプロセスに応じて柔軟に調整できるようになりました。
