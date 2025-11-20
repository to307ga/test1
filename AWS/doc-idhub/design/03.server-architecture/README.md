# サーバーアーキテクチャ設計書

## 目次

1. [概要](#1-概要)
2. [サーバー構成設計](#2-サーバー構成設計)
3. [インスタンス設計](#3-インスタンス設計)
4. [OS設計](#4-os設計)

---

## 1. 概要

本設計書は、idhubシステムのAWS移行におけるEC2サーバーアーキテクチャを定義する。

### 1.1 設計方針

- **Immutableインフラストラクチャ**: ゴールデンAMIによる不変インフラの実現
- **セキュリティファースト**: 多層防御、最小権限の原則、暗号化の徹底
- **運用自動化**: Systems Managerによる運用タスクの自動化
- **コスト最適化**: Savings Plans活用、適切なインスタンスタイプ選定
- **可用性重視**: マルチAZ構成、手動スケーリング対応

### 1.2 参照ドキュメント

- EC2要件定義書
- マイグレーション検証プロセス
- システムセキュリティ対策チェックリスト
- [詳細設計書](./03.server-architecture.md)

---

## 2. サーバー構成設計

### 2.1 構成概要

> 詳細: [03.server-architecture.md - 1. 設計概要](./03.server-architecture.md#1-設計概要)

#### 環境別構成

| 環境 | インスタンス数 | 配置 | 用途 |
|------|--------------|------|------|
| 本番環境 | 6台（常時稼働） | 各AZ 2台 × 3AZ | Blue/Green運用 |
| ステージング環境 | 3台 | 各AZ 1台 × 3AZ | 本番同等の負荷テスト |
| 開発環境 | 2台 | AZ分散 | 開発・テスト |

#### Blue/Greenデプロイメント構成

```
本番環境の構成:
- 2組のAuto Scalingグループ（Blue/Green）インスタンス自動復旧時も動作確認完了まではインターネット公開はしない？（内部ルールの問題：検証済みのフルベイクドなEC2であればしても良い）
- 常時稼働: 1組のみ（3台: 各AZ 1台）
- パッチ適用時: 新AMIでGreen起動 → 検証 → 切り替え → Blue削除
- 切り替え頻度: 月1-3回（パッチ適用、アプリデプロイ）
```

### 2.2 ネットワーク設計

> 詳細: [03.server-architecture.md - 8. セキュリティ強化設計](./03.server-architecture.md#8-セキュリティ強化設計)

#### ロードバランサー構成

```yaml
Application Load Balancer:
  配置: パブリックサブネット
  リスナー:
    - Port 80 (HTTP) → 443へリダイレクト
    - Port 443 (HTTPS) → ターゲットグループ
  ヘルスチェック:
    パス: /health
    間隔: 30秒
    タイムアウト: 5秒
    正常閾値: 2回
    異常閾値: 2回

ターゲットグループ:
  プロトコル: HTTP
  ポート: 80
  スティッキーセッション: 有効
  Connection Draining: 300秒
```

#### セキュリティグループ

```yaml
ALB用セキュリティグループ:
  インバウンド:
    - Port 80: 0.0.0.0/0 (HTTPリダイレクト用)
    - Port 443: 0.0.0.0/0 (HTTPS)
  アウトバウンド:
    - Port 80: EC2セキュリティグループへ

EC2用セキュリティグループ:
  インバウンド:
    - Port 80: ALBセキュリティグループから
  アウトバウンド:
    - Port 443: VPCエンドポイント（Systems Manager等）
    - Port 3306: Auroraセキュリティグループへ
    - Port 443: S3へ（Gateway Endpoint経由）
```

### 2.3 スケーリング戦略

> 詳細: [03.server-architecture.md - 6. スケーリング運用設計](./03.server-architecture.md#6-スケーリング運用設計)

#### 手動スケーリング方針

本システムでは、予測可能な負荷変動と運用ノウハウの活用を前提に、**手動スケーリング**を採用。

```yaml
スケールアウト判断基準:
  レベル1（注意）:
    - CPU使用率: 60%以上が1時間継続
    - メモリ使用率: 70%以上が1時間継続
  
  レベル2（警告）:
    - CPU使用率: 70%以上が30分継続
    - メモリ使用率: 80%以上が30分継続
    → 対応: スケールアウト実施判断
  
  レベル3（緊急）:
    - CPU使用率: 85%以上
    - メモリ使用率: 90%以上
    → 対応: 即座にスケールアウト実施

スケールイン判断基準:
  条件:
    - CPU使用率: 30%未満が24時間継続
    - メモリ使用率: 40%未満が24時間継続
    - 最小台数を上回っている（3台以上稼働中）
```

### 2.4 AMI管理戦略

> 詳細: [03.server-architecture.md - 4. AMI管理戦略設計](./03.server-architecture.md#4-ami管理戦略設計)

#### ゴールデンAMI構成

```
レイヤー構成:
┌─────────────────────────────────────┐
│ Layer 3: Application AMI            │
│ - アプリケーションコード配置         │
│ - 環境別設定ファイル                │
└─────────────────────────────────────┘
         ↑ ビルド時に作成
┌─────────────────────────────────────┐
│ Layer 2: Middleware AMI             │
│ - Apache, Java, その他ミドルウェア  │
│ - 共通設定、監視エージェント        │
│ - CrowdStrike Falcon                │
└─────────────────────────────────────┘
         ↑ 月次パッチ適用時に更新
┌─────────────────────────────────────┐
│ Layer 1: Base AMI                   │
│ - Amazon Linux 2023                 │
│ - OSレベルセキュリティ設定          │
│ - Systems Manager Agent             │
└─────────────────────────────────────┘
```

#### AMI命名規則

```
{プロジェクトコード}-{ロール}{レイヤー}-{バージョン}-{作成日時}

例:
- idhub-40-web-base-v1.0-20251115
- idhub-40-web-middleware-v2.3-20251115
- idhub-40-web-app-v1.5-20251115
```

#### AMI更新サイクル

```
月次更新（第2水曜日）:
- Week 2 火曜: 新AMI作成・開発環境検証
- Week 2 以降: ステージング環境検証
- Week 3 月火: 本番環境へBlue/Greenデプロイ

緊急更新（Critical脆弱性）:
- Day 1: 脆弱性評価
- Day 2: 緊急AMI作成、ステージング検証
- Day 3: 本番環境へ適用
```

### 2.5 パッチ管理

> 詳細: [03.server-architecture.md - 5. パッチ管理自動化設計](./03.server-architecture.md#5-パッチ管理自動化設計)

#### Immutable方式のパッチ適用

**基本原則**: 稼働中インスタンスへのパッチ適用は行わず、新AMI作成 + インスタンス置換

```yaml
パッチ適用フロー:
  1. 新AMI作成:
     - EC2 Image BuilderでOS・ミドルウェアパッチ適用
     - 開発環境で検証
  
  2. Blue/Greenデプロイ:
     - 新AMIからGreen環境起動
     - 動作確認後、トラフィック切替
     - Blue環境削除
  
  3. ロールバック対応:
     - 即時: Greenを切り離し、Blueに戻す（30分以内）
     - 完全: 1世代前AMIから再起動（1日以内）
```

### 2.6 監視・ロギング

> 詳細: [03.server-architecture.md - 9. 監視・ロギング設計](./03.server-architecture.md#9-監視ロギング設計)

#### CloudWatch監視

```yaml
基本メトリクス（5分間隔）:
  - CPUUtilization
  - NetworkIn/Out
  - StatusCheckFailed

カスタムメトリクス（1分間隔）:
  - CPU使用率詳細
  - メモリ使用率
  - ディスク使用率
  - プロセス数

アラート閾値:
  Critical:
    - CPU使用率: 85%以上、5分継続
    - メモリ使用率: 90%以上、5分継続
    - ディスク使用率: 90%以上
  
  Warning:
    - CPU使用率: 70%以上、15分継続
    - メモリ使用率: 80%以上、15分継続
```

#### ログ収集

```yaml
ログ収集方式（検討中）:
  推奨: journald → CloudWatch Logs Agent（方式C）
  - システムログとアプリログを統合
  - 12-factor app準拠
  - ディスクI/O最小化

ログ保持期間:
  CloudWatch Logs: 90日
  S3アーカイブ:
    - アプリケーションログ: 3年
    - 監査ログ: 7年
```

### 2.7 コスト最適化

> 詳細: [03.server-architecture.md - 10. コスト最適化設計](./03.server-architecture.md#10-コスト最適化設計)

#### Savings Plans採用

```yaml
購入プラン:
  タイプ: EC2 Instance Savings Plans
  期間: 1年間（No Upfront）
  対象: t3ファミリー全体
  割引率: 約30%

月額コスト（Savings Plans適用後）:
  本番環境: 約$4,258/月（6台常時稼働）
  ステージング環境: 約$503/月
  開発環境: 約$42/月
  総計: 約$4,803/月

年間削減額: 約$36,000（オンデマンド比）
```

---

## 3. インスタンス設計

### 3.1 インスタンスタイプ選定

> 詳細: [03.server-architecture.md - 3. インスタンスタイプ最適化設計](./03.server-architecture.md#3-インスタンスタイプ最適化設計)

#### 環境別インスタンスタイプ

| 環境 | インスタンスタイプ | vCPU | メモリ | 選定理由 |
|------|-------------------|------|--------|---------|
| 開発環境 | t3.medium | 2 | 4GB | 開発・テスト用途、低負荷想定 |
| ステージング環境 | t3.2xlarge | 8 | 32GB | 本番同等の負荷テスト実施 |
| 本番環境 | t3.2xlarge | 8 | 32GB | 本番ワークロード対応 |

#### t3.2xlarge選定根拠

**現行環境からの移行判断**:
```yaml
現行サーバー（オンプレミス）:
  CPU: 8コア（実使用率10%以下）
  メモリ: 23GB搭載（最大22.06GB使用、使用率96%）
  
課題:
  - CPU: 大幅にオーバースペック
  - メモリ: ほぼ上限まで使用、不足リスク

t3.2xlarge選定理由:
  1. メモリ: 32GB搭載
     - 現行最大使用22.06GBに対し約45%の余裕
  
  2. CPU: 8vCPU、ベースライン1.6vCPU
     - 実使用0.8コアに対し2倍の余裕
     - バースト時最大8vCPUで突発負荷対応
  
  3. コスト: T3ファミリーの効率性
     - 低CPU使用率でクレジット蓄積
     - Savings Plans適用で大幅割引
```

#### T3インスタンスの特性

```yaml
バースト性能:
  ベースライン: 20%（t3.2xlargeの場合）
  - 継続利用可能: 1.6vCPU相当
  - バースト時: 最大8vCPU
  
クレジットシステム:
  蓄積: CPU使用率がベースライン以下の場合
  消費: ベースライン超過時
  監視: CPUCreditBalance, CPUCreditUsage
  
Unlimitedモード（オプション）:
  - クレジット不足時も追加料金でバースト継続
  - 設定: CreditSpecification.CpuCredits = "unlimited"
```

#### 代替インスタンスタイプ

安定したベースライン性能を求める場合:

| タイプ | vCPU | メモリ | ベースライン | 月額（本番6台）* |
|--------|------|--------|-------------|-----------------|
| t3.2xlarge | 8 | 32GB | 1.6 (バースト) | $4,258 |
| m5.2xlarge | 8 | 32GB | 8 (固定) | $5,184 |
| t3.2xlarge (Unlimited) | 8 | 32GB | 1.6+ | $4,258+バースト料金 |

*Savings Plans適用後

### 3.2 ストレージ設計

> 詳細: [03.server-architecture.md - 2. ディレクトリ構成設計](./03.server-architecture.md#2-ディレクトリ構成設計)

#### EBSボリューム構成

```yaml
ルートボリューム:
  タイプ: gp3
  サイズ: 50GB
  IOPS: 3000（ベースライン）
  スループット: 125 MB/s
  暗号化: 有効（AWS managed key）
  削除保護: インスタンス削除時に削除

サイジング根拠:
  OS + システムファイル: 5GB
  ミドルウェア: 5GB
  アプリケーション: 5GB
  ログバッファ: 5GB
  成長余地: 30GB
  合計: 50GB

gp3選定理由:
  - gp2比で同価格、性能向上
  - ベースライン3000 IOPS（gp2は150 IOPS/GB）
  - バースト不要の安定性能
  
月額コスト:
  50GB × $0.096/GB = 約$4.80/月
```

#### EBS追加アタッチを行わない理由

```yaml
Immutable構成のメリット:
  1. AMIから完全再現可能
  2. 運用負荷削減（ボリューム管理不要）
  3. スケーリング高速化
  4. コスト最適化

データ永続化の代替手段:
  - データベース: RDS Aurora
  - 共有ファイル: EFS（必要時）
  - オブジェクトストレージ: S3
  - セッション: ElastiCache Redis（検討中）
```

### 3.3 Launch Template設計

> 詳細: [03.server-architecture.md - 6.4 Launch Template設計](./03.server-architecture.md#64-launch-template設計)

#### Launch Template構成

```yaml
基本設定:
  AMI: 最新のゴールデンAMI（動的参照）
  インスタンスタイプ: t3.2xlarge
  キーペア: 設定なし（Session Manager利用）

ネットワーク:
  サブネット: 起動時に指定（マルチAZ対応）
  セキュリティグループ: sg-web-app-prod
  パブリックIP: 無効

IAMインスタンスプロファイル:
  本番: poc-poc-ec2-ec2-instance-profile（既存）
  開発/検証: poc-ec2-cloudwatch-agent-profile（新規）

メタデータオプション:
  IMDSv2: 必須（required）
  ホップ制限: 1
  インスタンスメタデータタグ: 有効

タグ:
  Name: web-prod-${INSTANCE_NUM}
  Environment: prod
  ManagedBy: launch-template
  Application: web-app
```

#### IAMロール・ポリシー設計

```yaml
必要なポリシー:
  AWS管理ポリシー:
    - CloudWatchAgentServerPolicy
    - AmazonSSMManagedInstanceCore
    - AmazonSSMPatchAssociation
  
  カスタムポリシー:
    - poc-cloudwatch-agent-policy（作成済み）
      目的: CloudWatch Logs拡張機能
      権限: logs:*, ssm:GetParameter, ec2:Describe*
    
    - S3アクセスポリシー（将来）
      目的: アプリログ・バックアップ保存
    
    - RDS接続ポリシー（将来）
      目的: RDS Proxy経由DB接続
```

### 3.4 起動最適化

> 詳細: [03.server-architecture.md - 7. 起動最適化設計](./03.server-architecture.md#7-起動最適化設計)

#### 起動時間目標

```
目標: 5分以内（インスタンスRunning → サービスReady）

実測内訳:
- インスタンス起動: 1分40秒
- OS起動: 35秒
- アプリケーション初期化: 3分11秒
- ヘルスチェック: 30秒
- 総計: 5分56秒

最適化施策:
- AMI事前設定でアプリ初期化を1分短縮
- 目標5分以内を達成
```

#### ゴールデンAMIの活用

```yaml
事前設定内容:
  - OSパッケージ事前インストール
  - ミドルウェア（Apache, Java）事前設定
  - 監視エージェント事前インストール
  - セキュリティ設定適用済み
  - ログ設定完了

起動時の実施内容（最小化）:
  - ホスト名設定
  - 環境別パラメータ取得
  - アプリケーションコード最新化（必要時）
```

### 3.5 セキュリティ設定

> 詳細: [03.server-architecture.md - 8. セキュリティ強化設計](./03.server-architecture.md#8-セキュリティ強化設計)

#### IMDSv2強制設定

```yaml
メタデータオプション:
  HttpTokens: required（IMDSv2必須）
  HttpPutResponseHopLimit: 1（SSRF対策）
  HttpEndpoint: enabled
  InstanceMetadataTags: enabled

セキュリティ向上点:
  - セッショントークンベースの認証
  - SSRF攻撃の防止
  - メタデータへの不正アクセス防止
```

#### VPCエンドポイント

```yaml
Interface型エンドポイント:
  - com.amazonaws.ap-northeast-1.ec2
  - com.amazonaws.ap-northeast-1.ssm
  - com.amazonaws.ap-northeast-1.ssmmessages
  - com.amazonaws.ap-northeast-1.ec2messages
  - com.amazonaws.ap-northeast-1.logs
  - com.amazonaws.ap-northeast-1.secretsmanager

Gateway型エンドポイント:
  - com.amazonaws.ap-northeast-1.s3

メリット:
  - インターネット経由不要
  - セキュリティ向上
  - データ転送料金削減
  - レイテンシ削減
```

#### CrowdStrike Falcon

```yaml
導入方法: AMIビルド時に事前インストール

設定:
  監視対象: 全ファイルシステム、プロセス、ネットワーク
  除外設定: /tmp, /var/tmp, /var/log
  リアルタイム監視: 有効
  検知感度: 中レベル

ライセンス管理:
  ライセンスキー: Parameter Store管理
  更新: 自動更新（CrowdStrikeコンソール）
```

---

## 4. OS設計

### 4.1 OS選定

> 詳細: [03.server-architecture.md - 1. 設計概要](./03.server-architecture.md#1-設計概要)

#### Amazon Linux 2023採用

```yaml
選定理由:
  - AWS最適化: EC2専用最適化
  - 長期サポート: 5年間のセキュリティ更新
  - パッケージ管理: dnf（yum後継）
  - セキュリティ: SELinux標準装備
  - パフォーマンス: Nitro System対応
  - コスト: ライセンス料金不要

バージョンポリシー:
  - メジャーバージョン: 2年ごとにリリース
  - セキュリティパッチ: 毎月リリース
  - サポート期間: リリースから5年間
```

### 4.2 ディレクトリ構成

> 詳細: [03.server-architecture.md - 2. ディレクトリ構成設計](./03.server-architecture.md#2-ディレクトリ構成設計)

#### 標準ディレクトリマップ

```
/ (root volume: 50GB gp3)
├── /etc/                   # 設定ファイル
│   ├── /httpd/            # Apache設定
│   ├── /systemd/          # systemd設定
│   └── /opt/aws/          # AWS設定
├── /opt/                   # オプションソフトウェア
│   ├── /aws/              # AWS CLIなど
│   └── /crowdstrike/      # CrowdStrike Falcon
├── /srv/                   # サービスデータ
│   └── /www/              # Webアプリケーション
│       ├── html/          # ドキュメントルート
│       └── app/           # アプリケーションコード
├── /var/                   # 可変データ
│   ├── /log/              # ログファイル（最小利用）
│   │   ├── messages       # システムログ（rsyslog有効時）
│   │   ├── secure         # 認証ログ
│   │   └── journal/       # systemd journal（プライマリ）
│   └── /cache/            # キャッシュ
└── /tmp/                   # 一時ファイル
```

#### ディレクトリ構成の基本方針

```yaml
方針1: Amazon Linux 2023標準構成を踏襲
  - AWS推奨のディレクトリ構成
  - カスタムマウントポイント不要
  - FHS準拠

方針2: EBS追加アタッチなし
  - ルートボリューム（/）のみ使用
  - Immutable構成を維持
  - スケーリング時の管理簡素化

方針3: ログは標準出力/journald
  - アプリログ: stdout/stderr → journald
  - システムログ: journald → CloudWatch Logs
  - ディスクI/O削減
  - 12-factor app準拠

方針4: ルートボリューム50GB
  - OS + ミドルウェア + アプリ + ログバッファ
  - 成長余地を考慮
```

### 4.3 パッケージ管理

> 詳細: [03.server-architecture.md - 5. パッチ管理自動化設計](./03.server-architecture.md#5-パッチ管理自動化設計)

#### dnfパッケージマネージャ

```bash
# パッケージ検索
dnf search <package-name>

# パッケージインストール
dnf install -y <package-name>

# パッケージ更新
dnf update -y

# セキュリティパッチのみ適用
dnf update-minimal --security -y

# インストール済みパッケージ一覧
dnf list installed

# パッケージ情報確認
dnf info <package-name>
```

#### パッケージ管理方針

```yaml
基本方針:
  - AMIビルド時に必要パッケージを事前インストール
  - 稼働中インスタンスでのパッケージ変更は原則禁止
  - 緊急時のみ手動パッケージ更新を許可

除外パッケージ（自動更新対象外）:
  - kernel*: カーネルは計画的に更新
  - httpd*: Apache は検証後に更新
  - java*: Java は検証後に更新
  - tomcat*: 緊急度に応じてAnsibleで適用

自動更新対象:
  - セキュリティパッチ（Critical/Important）
  - Bugfixパッチ
  - 上記除外パッケージ以外の全パッケージ
```

### 4.4 ログ管理

> 詳細: [03.server-architecture.md - 9.3 ログ設計](./03.server-architecture.md#93-ログ設計)

#### ログ収集方式（検討中）

**推奨: 方式C（アプリログstdout化 + journald単体）**

```yaml
システムログ:
  方法: journald → CloudWatch Logs Agent（journaldプラグイン）
  対象: systemd-journald全体

アプリケーションログ:
  方法: Apache/Tomcat → stdout/stderr → journald → CloudWatch
  設定例:
    Apache: ErrorLog "|/bin/cat"
    Tomcat: StandardOutput=journal

メリット:
  - ディスクI/O最小化
  - ログローテーション不要
  - 12-factor app準拠
  - コンテナ化への移行容易

コスト:
  CloudWatch Logs: 約$9/月（15GB/月）
  ディスク使用量: 約15GB/月
```

#### ログ保持ポリシー

```yaml
journaldローカル保持:
  最大サイズ: 2GB
  保持期間: 7日間
  設定: /etc/systemd/journald.conf

CloudWatch Logs保持:
  アプリケーションログ: 90日
  システムログ: 90日
  監査ログ: 1年
  セキュリティログ: 1年

S3アーカイブ:
  アプリケーションログ: 3年
  監査ログ: 7年
  ライフサイクル: 90日後にS3移行
```

### 4.5 systemd設定

> 詳細: [03.server-architecture.md - 2. ディレクトリ構成設計](./03.server-architecture.md#2-ディレクトリ構成設計)

#### サービス管理

```bash
# サービス起動
systemctl start <service-name>

# サービス停止
systemctl stop <service-name>

# サービス再起動
systemctl restart <service-name>

# サービス自動起動設定
systemctl enable <service-name>

# サービス状態確認
systemctl status <service-name>

# 全サービス一覧
systemctl list-units --type=service
```

#### 主要サービス

```yaml
必須サービス:
  - amazon-ssm-agent: Systems Manager Agent
  - amazon-cloudwatch-agent: CloudWatch Agent
  - httpd: Apache Webサーバー
  - tomcat: Tomcat アプリケーションサーバー
  - falcon-sensor: CrowdStrike Falcon（セキュリティ）

自動起動設定:
  - 全て有効（systemctl enable）
  - AMIビルド時に設定済み
```

### 4.6 セキュリティ設定

> 詳細: [03.server-architecture.md - 8. セキュリティ強化設計](./03.server-architecture.md#8-セキュリティ強化設計)

#### SELinux設定

```yaml
状態: Enforcing（強制モード）
ポリシー: targeted

確認コマンド:
  - sestatus: SELinux状態確認
  - getenforce: 現在のモード確認
  - setenforce [0|1]: モード変更（一時的）

注意事項:
  - アプリケーション動作確認時はPermissiveモード推奨
  - 本番環境では必ずEnforcingモード
  - カスタムポリシーが必要な場合はドキュメント化
```

#### ファイアウォール設定

```bash
# firewalld（デフォルトで有効）
systemctl status firewalld

# ポート開放（本番では不要、SGで制御）
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

# 設定確認
firewall-cmd --list-all
```

**注意**: EC2ではセキュリティグループで制御するため、firewalldは無効化を推奨。

#### ユーザー管理

```yaml
デフォルトユーザー: ec2-user
  - sudoアクセス: 有効
  - SSHアクセス: 無効（Session Manager使用）
  - パスワード: 未設定

アプリケーションユーザー:
  - tomcat: Tomcat実行用
  - apache: Apache実行用
  - 権限: 最小限

ルートアクセス:
  - 直接ログイン: 禁止
  - sudo経由のみ許可
  - 監査ログ: CloudTrail記録
```

### 4.7 監視エージェント

> 詳細: [03.server-architecture.md - 9. 監視・ロギング設計](./03.server-architecture.md#9-監視ロギング設計)

#### CloudWatch Agent

```yaml
設定ファイル: /opt/aws/amazon-cloudwatch-agent/etc/config.json
設定方法: Parameter Store経由

収集メトリクス:
  - CPU使用率（詳細）
  - メモリ使用率
  - ディスク使用率
  - プロセス数
  - ネットワークI/O

ログ収集:
  - journald → CloudWatch Logs
  - アプリケーションログ
  - システムログ

起動コマンド:
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c ssm:AmazonCloudWatch-linux
```

#### Datadog Agent（オプション）

```yaml
設定ファイル: /etc/datadog-agent/datadog.yaml
APIキー: Parameter Store管理

収集内容:
  - システムメトリクス
  - APMトレース（Tomcat）
  - ログ収集
  - プロセス監視

統合:
  - Apache統合
  - Tomcat統合
  - AWS統合（CloudWatch連携）
```

---

## 参考資料

- [03.server-architecture.md](./03.server-architecture.md) - EC2システム設計書完全版（全12セクション）
- [CI/CDパイプライン設計](./03.server-architecture.md#11-cicdパイプライン設計)
- [次のステップ（検討課題）](./03.server-architecture.md#12-次のステップ)
