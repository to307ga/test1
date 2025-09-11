# 本番環境（Production）パラメータ設定ガイド

## 概要

本ドキュメントは、AWS BYODMIM（Bring Your Own DKIM Migration and Management）プロジェクトの本番環境における各パラメータの設定値、意味、適用可能な値について説明します。

**重要**: 本システムは**BYODKIM（Bring Your Own DKIM）**を採用し、カスタムセレクターによるDKIM証明書管理を自動化します。EasyDKIMは使用せず、3つのカスタムセレクター（`gooid-21-pro-20250907-1/2/3`）を生成します。

## 環境基本設定

### config.yaml

| パラメータ | 現在の設定値 | 説明 | 適用可能な値 |
|-----------|-------------|------|-------------|
| `project_code` | `aws-byodmim-prod` | プロジェクト識別子（本番環境用） | 英数字とハイフンの組み合わせ |
| `region` | `ap-northeast-1` | AWSリージョン（東京） | 有効なAWSリージョンコード |
| `template_bucket_name` | `aws-byodmim-prod-templates` | CloudFormationテンプレート保存用S3バケット名 | グローバルにユニークなS3バケット名 |
| `environment` | `prod` | 環境識別子 | `prod`, `staging`, `dev` |

## フェーズ別パラメータ設定

### Phase 1: インフラ基盤構築フェーズ

**ファイル**: `phase-1-infrastructure-foundation.yaml`

| パラメータ | 現在の設定値 | 説明 | 適用可能な値 |
|-----------|-------------|------|-------------|
| `ProjectName` | `aws-byodmim` | プロジェクト名（全環境共通） | 英数字とハイフンの組み合わせ |
| `Environment` | `prod` | 環境識別子 | `prod`, `staging`, `dev` |
| `DomainName` | `goo.ne.jp` | DKIM設定対象ドメイン | 有効なドメイン名 |
| `DKIMSeparator` | `gooid-21-pro` | DKIMセレクター識別子 | 英数字とハイフンの組み合わせ（最大63文字） |
| `LogRetentionDays` | `90` | CloudWatchログ保持期間（日数） | 1-3650日 |
| `DNSTeamEmail` | `tomonaga@mx2.mesh.ne.jp` | DNS管理チームの通知先メールアドレス | 有効なメールアドレス |
| `LogsRetentionDays` | `90` | S3ログ保持期間（日数） | 1-3653日 |
| `LogsTransitionToIADays` | `30` | Infrequent Access移行までの日数 | 1-365日 |
| `LogsTransitionToGlacierDays` | `30` | Glacier移行までの日数 | 1-365日 |

**説明**:
- `DomainName`: DKIM署名を設定するメール送信ドメイン
- `DKIMSeparator`: DKIMレコードの識別子（例：`gooid-21-pro._domainkey.goo.ne.jp`）
- `LogRetentionDays`: コスト最適化のため、本番環境では90日間の保持期間を設定
- `LogsRetentionDays`: S3バケットのログ保持期間（本番環境では90日間）
- `LogsTransitionToIADays`: ログをInfrequent Accessに移行するまでの日数（30日後）
- `LogsTransitionToGlacierDays`: ログをGlacierに移行するまでの日数（30日後）

### Phase 2: DKIM管理システム構築フェーズ

**ファイル**: `phase-2-dkim-system.yaml`

| パラメータ | 現在の設定値 | 説明 | 適用可能な値 |
|-----------|-------------|------|-------------|
| `ProjectName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName` | プロジェクト名 | Phase 1からの出力値 |
| `Environment` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::Environment` | 環境識別子 | Phase 1からの出力値 |
| `DKIMManagerRoleArn` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DKIMManagerRoleArn` | DKIM管理Lambda実行ロールARN | Phase 1からの出力値 |
| `DKIMConfigSecretArn` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DKIMConfigSecretArn` | DKIM設定保存用Secrets Manager ARN | Phase 1からの出力値 |
| `DKIMCertificatesBucketName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DKIMCertificatesBucketName` | DKIM証明書保存用S3バケット名 | Phase 1からの出力値 |
| `DKIMEncryptionKeyArn` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DKIMEncryptionKeyArn` | DKIM暗号化用KMSキーARN | Phase 1からの出力値 |

**説明**:
- すべてのパラメータがPhase 1のスタック出力を参照するため、Phase 1のデプロイ完了後に設定される
- 共通パラメータ（`ProjectName`, `Environment`）もPhase 1から参照することで一貫性を保つ

### Phase 3: SES設定・BYODKIM初期化フェーズ

**ファイル**: `phase-3-ses-byodkim.yaml`

| パラメータ | 現在の設定値 | 説明 | 適用可能な値 |
|-----------|-------------|------|-------------|
| `ProjectName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName` | プロジェクト名 | Phase 1からの出力値 |
| `Environment` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::Environment` | 環境識別子 | Phase 1からの出力値 |
| `DomainName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DomainName` | SES設定対象ドメイン | Phase 1からの出力値 |
| `DKIMManagerFunctionArn` | `!stack_output prod/phase-2-dkim-system.yaml::DKIMManagerFunctionArn` | DKIM管理Lambda関数ARN | Phase 2からの出力値 |

**説明**:
- このフェーズでSESのEmail Identityが作成され、BYODKIM機能が初期化される
- 共通パラメータ（`ProjectName`, `Environment`, `DomainName`）はPhase 1から参照

### Phase 4: DKIM証明書生成・DNS準備フェーズ

**ファイル**: `phase-4-dns-preparation.yaml`

| パラメータ | 現在の設定値 | 説明 | 適用可能な値 |
|-----------|-------------|------|-------------|
| `ProjectName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName` | プロジェクト名 | Phase 1からの出力値 |
| `Environment` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::Environment` | 環境識別子 | Phase 1からの出力値 |
| `DKIMManagerFunctionArn` | `!stack_output prod/phase-2-dkim-system.yaml::DKIMManagerFunctionArn` | DKIM管理Lambda関数ARN | Phase 2からの出力値 |
| `DomainName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DomainName` | DNS設定対象ドメイン | Phase 1からの出力値 |

**説明**:
- **BYODKIM証明書生成**: 3つのカスタムセレクター（`gooid-21-pro-20250907-1/2/3`）を生成
- **TXTレコード作成**: DNS TXTレコード（`k=rsa; p=...`）を生成（CNAMEレコードではない）
- **Python標準ライブラリ**: `secrets`と`base64`を使用してRSAキーペアを生成
- **S3保存**: 生成されたTXTレコードをS3に保存し、Phase 5で通知に使用

### Phase 5: DNS管理チーム連携フェーズ

**ファイル**: `phase-5-dns-team-collaboration.yaml`

| パラメータ | 現在の設定値 | 説明 | 適用可能な値 |
|-----------|-------------|------|-------------|
| `ProjectName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName` | プロジェクト名 | Phase 1からの出力値 |
| `Environment` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::Environment` | 環境識別子 | Phase 1からの出力値 |
| `DKIMManagerFunctionArn` | `!stack_output prod/phase-2-dkim-system.yaml::DKIMManagerFunctionArn` | DKIM管理Lambda関数ARN | Phase 2からの出力値 |
| `DNSTeamEmail` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DNSTeamEmail` | DNS管理チームの通知先メールアドレス | Phase 1からの出力値 |
| `SlackWebhookURL` | `""` | Slack通知用Webhook URL（空文字） | 有効なSlack Webhook URL または空文字 |

**説明**:
- **BYODKIM TXTレコード通知**: Phase 4で生成された3つのTXTレコードをDNS管理チームに通知
- **自動連携**: Phase 5完了後にPhase 7の自動実行をトリガー
- **EventBridge連携**: Custom ResourceではなくEventBridgeを使用した安定した自動化
- **メール・Slack通知**: `SlackWebhookURL`が空文字のため、メール通知のみが有効

### Phase 6: DNS設定完了待機フェーズ

**ファイル**: `phase-6-dns-wait.yaml` （**削除済み**）

**説明**:
- **削除理由**: 外部DNS管理チームの作業待ちのため、CloudFormationリソースは不要
- **待機期間**: 約2週間（DNS管理チームがTXTレコードを登録する期間）
- **自動化**: Phase 5→7の自動連携により、手動でのPhase 6実行は不要

### Phase 7: DNS設定検証・BYODKIM有効化フェーズ

**ファイル**: `phase-7-dns-validation-dkim-activation.yaml`

| パラメータ | 現在の設定値 | 説明 | 適用可能な値 |
|-----------|-------------|------|-------------|
| `ProjectName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName` | プロジェクト名 | Phase 1からの出力値 |
| `Environment` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::Environment` | 環境識別子 | Phase 1からの出力値 |
| `DKIMManagerFunctionArn` | `!stack_output prod/phase-2-dkim-system.yaml::DKIMManagerFunctionArn` | DKIM管理Lambda関数ARN | Phase 2からの出力値 |
| `DomainName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DomainName` | 検証対象ドメイン | Phase 1からの出力値 |

**説明**:
- **DNS伝播確認**: TXTレコードの伝播状況を確認（`dig`コマンド使用）
- **BYODKIM有効化**: `put_email_identity_dkim_signing_attributes`でSigningEnabled: trueに設定
- **自動実行**: Phase 5完了後にEventBridgeで自動トリガー
- **Custom Resource不使用**: EventBridgeによる安定した自動化アーキテクチャ

### Phase 8: 監視システム開始フェーズ

**ファイル**: `phase-8-monitoring-system.yaml`

| パラメータ | 現在の設定値 | 説明 | 適用可能な値 |
|-----------|-------------|------|-------------|
| `ProjectName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName` | プロジェクト名 | Phase 1からの出力値 |
| `Environment` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::Environment` | 環境識別子 | Phase 1からの出力値 |
| `DKIMManagerFunctionArn` | `!stack_output prod/phase-2-dkim-system.yaml::DKIMManagerFunctionArn` | DKIM管理Lambda関数ARN | Phase 2からの出力値 |
| `DomainName` | `!stack_output prod/phase-1-infrastructure-foundation.yaml::DomainName` | 監視対象ドメイン | Phase 1からの出力値 |
| `MonitoringSchedule` | `"cron(0 0 1 * ? *)"` | 監視スケジュール（毎月1日 0:00 UTC = 9:00 JST） | 有効なCloudWatch Events cron式 |

**説明**:
- **定期監視**: 毎月1日 9:00 JSTにBYODKIM証明書の期限チェック
- **期限切れアラート**: 1ヶ月前の期限切れアラート送信
- **自動更新**: 期限切れ時の自動証明書更新プロセス開始

## BYODKIM自動化システムの特徴

### 1. カスタムセレクター生成
- **3つのセレクター**: `gooid-21-pro-20250907-1`, `gooid-21-pro-20250907-2`, `gooid-21-pro-20250907-3`
- **TXTレコード**: `k=rsa; p=...`形式のDNS TXTレコードを生成
- **Python標準ライブラリ**: `cryptography`ライブラリではなく`secrets`+`base64`を使用

### 2. EventBridge自動連携
- **Phase 5→7自動実行**: DNS通知完了後に自動的にPhase 7を実行
- **Custom Resource不使用**: より安定した自動化アーキテクチャ
- **手動実行不要**: Phase 6の手動実行は不要（外部作業待ちのため）

### 3. 設定値の変更が必要な項目

#### 3.1. パラメータ参照パスの統一
Phase 2とPhase 3では`prod/`プレフィックス付きの参照を使用し、Phase 4以降では`prod/`プレフィックスなしの参照を使用しています。これは実際のパラメータファイルの設定に基づいています。

#### 3.2. Slack通知の設定（オプション）
```yaml
# 現在（無効）
SlackWebhookURL: ""

# 修正後（有効にする場合）
SlackWebhookURL: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
```

## 修正済み項目

### 1. 依存関係の統合
Phase 1でインフラ基盤が統合されたため、以下の古い個別スタック参照を修正しました：

**修正前（古い個別スタック参照）**:
```yaml
dependencies:
  - phase-1-infrastructure.yaml
  - phase-1-kms.yaml
  - phase-1-secrets.yaml
  - phase-1-s3.yaml
  - phase-1-cloudwatch.yaml
```

**修正後（統合されたスタック参照）**:
```yaml
dependencies:
  - phase-1-infrastructure-foundation.yaml
```

### 2. パラメータ参照の統一
Phase 2以降のすべてのフェーズで、共通パラメータをPhase 1から参照するように修正：

**修正前（ハードコードされた値）**:
```yaml
ProjectName: aws-byodmim
Environment: prod
DomainName: goo.ne.jp
DNSTeamEmail: dns-team@goo.ne.jp
```

**修正後（Phase 1からの参照）**:
```yaml
ProjectName: !stack_output phase-1-infrastructure-foundation.yaml::ProjectName
Environment: !stack_output phase-1-infrastructure-foundation.yaml::Environment
DomainName: !stack_output phase-1-infrastructure-foundation.yaml::DomainName
DNSTeamEmail: !stack_output phase-1-infrastructure-foundation.yaml::DNSTeamEmail
```

**注意**: Phase 2とPhase 3では`prod/`プレフィックス付きの参照を使用し、Phase 4以降では`prod/`プレフィックスなしの参照を使用しています。これは実際のパラメータファイルの設定に基づいています。

### 3. テンプレートのパラメータ化
S3ライフサイクル設定をパラメータ化し、環境別に設定可能に：

**追加されたパラメータ**:
- `LogsRetentionDays`: S3ログ保持期間
- `LogsTransitionToIADays`: IA移行までの日数（30日）
- `LogsTransitionToGlacierDays`: Glacier移行までの日数

**影響を受けたフェーズ**:
- Phase 2: DKIM管理システム構築
- Phase 3: SES設定・BYODKIM初期化
- Phase 4: DNS設定準備
- Phase 5: DNS管理チーム連携
- Phase 6: DNS設定完了待機
- Phase 7: DNS設定検証・DKIM有効化
- Phase 8: 監視システム開始

## デプロイメント順序

1. **Phase 1**: インフラ基盤構築
2. **Phase 2**: DKIM管理システム構築
3. **Phase 3**: SES設定・BYODKIM初期化
4. **Phase 4**: BYODKIM証明書生成・DNS準備（自動）
5. **Phase 5**: DNS管理チーム連携（自動）
6. **Phase 6**: DNS設定完了待機（外部作業・約2週間）
7. **Phase 7**: DNS設定検証・BYODKIM有効化（自動）
8. **Phase 8**: 監視システム開始（自動）

**自動化フロー**: Phase 4→5→7は自動実行され、手動での実行は不要です。

## 注意事項

1. **依存関係**: 各フェーズは前のフェーズの完了を待つ必要があります
2. **外部依存**: Phase 6は外部DNS管理チームの作業待ちのため、約2週間の待機が必要
3. **パラメータ参照**: Phase 2とPhase 3では`prod/`プレフィックス付きの参照を使用
4. **通知設定**: DNS管理チームのメールアドレスが正しく設定されていることを確認してください
5. **BYODKIM設定**: EasyDKIMは無効化され、カスタムセレクターによるBYODKIMが使用されます
6. **TXTレコード**: DNSレコードはCNAMEではなくTXTレコード（`k=rsa; p=...`）です

## トラブルシューティング

### よくある問題
1. **パラメータ参照エラー**: Phase 2とPhase 3では`prod/`プレフィックス付きの参照を使用
2. **DNS通知失敗**: `DNSTeamEmail`が正しく設定されていない
3. **監視スケジュールエラー**: `MonitoringSchedule`のcron式が正しくない
4. **S3ライフサイクル設定**: `LogsTransitionToIADays`が30日に設定されている
5. **BYODKIM設定エラー**: EasyDKIMが無効化されていない場合の競合
6. **TXTレコード形式エラー**: DNSレコードがCNAMEではなくTXTレコードであることを確認
7. **Lambda Layerエラー**: `cryptography`ライブラリの代わりにPython標準ライブラリを使用

### 確認コマンド
```bash
# スタック一覧確認
uv run sceptre list stacks --config-dir sceptre/config/prod

# 特定スタックの状態確認
uv run sceptre describe phase-1-infrastructure-foundation --config-dir sceptre/config/prod

# スタックの出力値確認
uv run sceptre get outputs phase-1-infrastructure-foundation --config-dir sceptre/config/prod
```

---

**最終更新日**: 2024年12月19日  
**更新者**: AI Assistant  
**バージョン**: 2.0  
**更新内容**: BYODKIM自動化システム対応、Phase 6削除、EventBridge自動連携追加
