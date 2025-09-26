# RenewalAlertDays参照統一修正レポート

## 修正内容

### 問題
Phase-8でRenewalAlertDaysがハードコード（16日）されており、Phase-2の実際の設定値（2日、テスト用）と不整合が発生していました。

### 修正前
```yaml
# phase-8-monitoring.yaml (修正前)
RenewalAlertDays: 16  # Phase 2と同じ値：DNS調整期間考慮（2週間+余裕）

# phase-2-dkim-system.yaml (実際の値)  
RenewalAlertDays: 2   # Test mode: Alert 2 days before expiration
```

## 実行した修正

### ✅ **1. Phase-2テンプレート修正**
**ファイル**: `sceptre/templates/dkim-manager-lambda.yaml`

#### RenewalAlertDays Outputの追加
```yaml
# 追加されたOutput
RenewalAlertDays:
  Description: Alert threshold in days before certificate expiration
  Value: !Ref RenewalAlertDays
  Export:
    Name: !Sub "${ProjectName}-${Environment}-renewal-alert-days"
```

#### Outputs名の統一
```yaml
# 修正前: V2サフィックス付き
DKIMManagerFunctionArnV2: ...
DKIMManagerFunctionNameV2: ...

# 修正後: 統一された名前
DKIMManagerFunctionArn: ...
DKIMManagerFunctionName: ...
```

### ✅ **2. Phase-8設定修正**
**ファイル**: `sceptre/config/prod/phase-8-monitoring.yaml`

#### 参照方式に変更
```yaml
# 修正前: ハードコード
RenewalAlertDays: 16  # Phase 2と同じ値：DNS調整期間考慮（2週間+余裕）

# 修正後: Phase-2から参照
RenewalAlertDays: !stack_output prod/phase-2-dkim-system.yaml::RenewalAlertDays  # Inherit from Phase 2 DKIM system
```

## 統一効果

### ✅ **パラメータ一貫性確保**
```yaml
# 現在の統一値（テスト環境）
Phase-2: RenewalAlertDays: 2  # テスト用設定
Phase-8: RenewalAlertDays: 2  # Phase-2から自動継承

# 本番環境時の変更例
Phase-2: RenewalAlertDays: 16  # 本番用（DNS調整期間2週間+余裕）
Phase-8: RenewalAlertDays: 16  # 自動で同期
```

### ✅ **設定変更の影響範囲明確化**
- **Phase-2で変更** → Phase-8も自動で同期
- **単一ソース**: RenewalAlertDaysの設定元が明確
- **運用効率**: パラメータ変更時の確認箇所が1か所

### ✅ **テスト環境対応**
```yaml
# テスト時の設定（現在）
証明書有効期間: 2日 (CertificateValidityDays: 2)
アラート閾値: 2日前 (RenewalAlertDays: 2)

# 本番時の設定（移行後）
証明書有効期間: 456日 (CertificateValidityDays: 456)  
アラート閾値: 16日前 (RenewalAlertDays: 16、DNS調整期間考慮)
```

## システム連携の整合性

### Phase-2 → Phase-8 連携
```yaml
Phase-2 DKIM Manager:
  - 証明書期限監視ロジック
  - RenewalAlertDays: 2 (テスト用)
    ↓ (stack_output参照)
Phase-8 Monitoring:
  - 統合監視システム  
  - RenewalAlertDays: 2 (Phase-2から自動継承)
```

### Lambda環境変数の統一
```python
# Phase-8 Lambda関数内
renewal_alert_days = int(os.environ.get('RENEWAL_ALERT_DAYS', 16))
# ↑ Phase-2の実際の値（2日）がPhase-8に正しく伝搬
```

## 運用上のメリット

### 1. **設定統一**
- Phase-2とPhase-8でRenewalAlertDaysが確実に一致
- テスト時（2日）と本番時（16日）の切り替えが Phase-2 のみの変更で完結

### 2. **メンテナンス効率**
- パラメータ変更時の影響範囲が明確（Phase-2のみ）
- 設定不整合によるバグを防止
- DNS調整期間の変更が全システムに自動反映

### 3. **環境間移行**
- テスト → 本番移行時のパラメータ設定ミスを防止
- 環境別の設定値が確実に統一される

## 結論

✅ **RenewalAlertDaysの参照統一が完了しました**

- **Phase-8**: Phase-2からstack_output参照でRenewalAlertDaysを取得
- **Phase-2**: RenewalAlertDaysをOutputとして出力追加
- **統一効果**: テスト時（2日）、本番時（16日）の設定が自動同期

これにより、証明書期限アラートの閾値がPhase-2とPhase-8で確実に一致し、DNS調整期間を考慮した統一運用が可能になりました。
