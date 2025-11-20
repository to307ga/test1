# 要件定義書

## 目次

1. [プロジェクト概要](#1-プロジェクト概要)
   - 1.1 [idhub とは](#11-idhub-とは)
   - 1.2 [前提と背景](#12-前提と背景)
     - 1.2.1 [EC2の積極利用](#121-ec2の積極利用)
     - 1.2.2 [EC2採用の背景](#122-ec2採用の背景)
   - 1.3 [プロジェクト名](#13-プロジェクト名)
   - 1.4 [目的](#14-目的)
   - 1.5 [対象環境](#15-対象環境)
     - 1.5.1 [dev](#151-dev)
     - 1.5.2 [prod](#152-prod)
2. [システム構成要件](./02-system-components-requirements.md#2-システム構成要件)
   - 2.1 [AWSアカウント構成要件](./02-system-components-requirements.md#21-awsアカウント構成要件)
   - 2.2 [検証環境](./02-system-components-requirements.md#22-検証環境)
     - 2.2.1 [検証環境へのWEBアクセス制限](./02-system-components-requirements.md#221-検証環境へのwebアクセス制限)
   - 2.3 [管理ツール](./02-system-components-requirements.md#23-管理ツール)
     - 2.3.1 [ヘルプツールの要件](./02-system-components-requirements.md#231-ヘルプツールの要件)
   - 2.4 [ネットワーク構成要件](./02-system-components-requirements.md#24-ネットワーク構成要件)
     - 2.4.1 [外部からAWSへのネットワーク構成](./02-system-components-requirements.md#241-外部からawsへのネットワーク構成)
     - 2.4.2 [外部への通信（アウトバウンド）](./02-system-components-requirements.md#242-外部への通信アウトバウンド)
     - 2.4.3 [AWS内のネットワーク構成](./02-system-components-requirements.md#243-aws内のネットワーク構成)
   - 2.5 [サーバ構成要件（ECS/Fargate vs EC2）](./02-system-components-requirements.md#25-サーバ構成要件ecsfargate-vs-ec2)
     - 2.5.1 [EC2構成](./02-system-components-requirements.md#251-ec2構成)
   - 2.6 [CDN構成要件](./02-system-components-requirements.md#26-cdn構成要件)
   - 2.7 [データベース機能要件](./02-system-components-requirements.md#27-データベース機能要件)
     - 2.7.1 [基本構成](./02-system-components-requirements.md#271-基本構成)
     - 2.7.2 [今後、検討の余地がある項目](./02-system-components-requirements.md#272-今後検討の余地がある項目)
   - 2.8 [キャッシュ機能要件](./02-system-components-requirements.md#28-キャッシュ機能要件)
3. [セキュリティ要件](./03-security-requirements.md#3-セキュリティ要件)
   - 3.1 [AWSアカウントアクセス制御要件](./03-security-requirements.md#31-awsアカウントアクセス制御要件)
     - 3.1.1 [今後、検討の余地がある項目](./03-security-requirements.md#311-今後検討の余地がある項目)
   - 3.2 [ユーザー通信制御要件](./03-security-requirements.md#32-ユーザー通信制御要件)
     - 3.2.1 [今後、検討の余地がある項目](./03-security-requirements.md#321-今後検討の余地がある項目)
   - 3.3 [暗号化要件](./03-security-requirements.md#33-暗号化要件)
     - 3.3.1 [通信暗号化](./03-security-requirements.md#331-通信暗号化)
     - 3.3.2 [保存データの暗号化](./03-security-requirements.md#332-保存データの暗号化)
     - 3.3.3 [今後、検討の余地がある項目](./03-security-requirements.md#333-今後検討の余地がある項目)
   - 3.4 [セキュリティ監視要件](./03-security-requirements.md#34-セキュリティ監視要件)
     - 3.4.1 [監視ツール構成](./03-security-requirements.md#341-監視ツール構成)
     - 3.4.2 [今後、検討の余地がある項目](./03-security-requirements.md#342-今後検討の余地がある項目)
   - 3.5 [監査証跡要件](./03-security-requirements.md#35-監査証跡要件)
     - 3.5.1 [今後、検討の余地がある項目](./03-security-requirements.md#351-今後検討の余地がある項目)
   - 3.6 [個人情報保護要件](./03-security-requirements.md#36-個人情報保護要件)
     - 3.6.1 [個人情報を含むデータへのアクセス制御](./03-security-requirements.md#361-個人情報を含むデータへのアクセス制御)
   - 3.7 [EC2アクセス管理要件](./03-security-requirements.md#37-ec2アクセス管理要件)
     - 3.7.1 [基本アクセス方式](./03-security-requirements.md#371-基本アクセス方式)
     - 3.7.2 [OSユーザーアカウント管理](./03-security-requirements.md#372-osユーザーアカウント管理)
     - 3.7.3 [ec2-userセキュリティ対策](./03-security-requirements.md#373-ec2-userセキュリティ対策)
4. [非機能要件](./04-non-functional-requirements.md#4-非機能要件)
   - 4.1 [可用性要件](./04-non-functional-requirements.md#41-可用性要件)
     - 4.1.1 [目標値・構成](./04-non-functional-requirements.md#411-目標値構成)
     - 4.1.2 [本システムでの可用性設計](./04-non-functional-requirements.md#412-本システムでの可用性設計)
     - 4.1.3 [今後、検討の余地がある項目](./04-non-functional-requirements.md#413-今後検討の余地がある項目)
   - 4.2 [拡張性要件](./04-non-functional-requirements.md#42-拡張性要件)
     - 4.2.1 [インスタンス構成要件](./04-non-functional-requirements.md#421-インスタンス構成要件)
     - 4.2.2 [本システム固有の拡張性設定](./04-non-functional-requirements.md#422-本システム固有の拡張性設定)
     - 4.2.3 [今後、検討の余地がある項目](./04-non-functional-requirements.md#423-今後検討の余地がある項目)
   - 4.3 [パフォーマンス要件](./04-non-functional-requirements.md#43-パフォーマンス要件)
     - 4.3.1 [レスポンス要件](./04-non-functional-requirements.md#431-レスポンス要件)
     - 4.3.2 [スループット要件](./04-non-functional-requirements.md#432-スループット要件)
     - 4.3.3 [スケーラビリティ要件](./04-non-functional-requirements.md#433-スケーラビリティ要件)
     - 4.3.4 [CDN活用要件](./04-non-functional-requirements.md#434-cdn活用要件)
   - 4.4 [運用要件](./04-non-functional-requirements.md#44-運用要件)
     - 4.4.1 [監視設計](./04-non-functional-requirements.md#441-監視設計)
     - 4.4.2 [ログ設計](./04-non-functional-requirements.md#442-ログ設計)
     - 4.4.3 [今後、検討の余地がある項目](./04-non-functional-requirements.md#443-今後検討の余地がある項目)
     - 4.4.4 [Sorryページ、メンテナンスページ](./04-non-functional-requirements.md#444-sorryページメンテナンスページ)
     - 4.4.5 [パッチ管理要件](./04-non-functional-requirements.md#445-パッチ管理要件)
5. [追加機能要件](./05-additional-functional-requirements.md#5-追加機能要件)
   - 5.1 [メール送信要件](./05-additional-functional-requirements.md#51-メール送信要件)
     - 5.1.1 [基本方針](./05-additional-functional-requirements.md#511-基本方針)
     - 5.1.2 [SES利用時の留意事項](./05-additional-functional-requirements.md#512-ses利用時の留意事項)
     - 5.1.3 [ユーザー問合せ対応](./05-additional-functional-requirements.md#513-ユーザー問合せ対応)
   - 5.2 [バックアップ設計要件](./05-additional-functional-requirements.md#52-バックアップ設計要件)
     - 5.2.1 [基本方針](./05-additional-functional-requirements.md#521-基本方針)
     - 5.2.2 [本システム固有のバックアップ構成](./05-additional-functional-requirements.md#522-本システム固有のバックアップ構成)
     - 5.2.3 [バックアップ対象とその世代や格納先](./05-additional-functional-requirements.md#523-バックアップ対象とその世代や格納先)
   - 5.3 [ジョブ設計要件](./05-additional-functional-requirements.md#53-ジョブ設計要件)
     - 5.3.1 [基本方針](./05-additional-functional-requirements.md#531-基本方針)
     - 5.3.2 [AWS機能を使用したジョブ実装例](./05-additional-functional-requirements.md#532-aws機能を使用したジョブ実装例)
   - 5.4 [コンソールログイン要件](./05-additional-functional-requirements.md#54-コンソールログイン要件)
   - 5.5 [デプロイ要件](./05-additional-functional-requirements.md#55-デプロイ要件)
     - 5.5.1 [IaC（Infra as a Code）](./05-additional-functional-requirements.md#551-iacinfra-as-a-code)
   - 5.6 [マイグレーション要件](./05-additional-functional-requirements.md#56-マイグレーション要件)
6. [技術要件](#6-技術要件)
   - 6.1 [インフラストラクチャ](#61-インフラストラクチャ)
   - 6.2 [セキュリティ](#62-セキュリティ)
   - 6.3 [監視・ログ](#63-監視ログ)
7. [制約事項](#7-制約事項)
   - 7.1 [技術的制約](#71-技術的制約)
   - 7.2 [セキュリティ制約](#72-セキュリティ制約)
   - 7.3 [運用制約](#73-運用制約)
8. [成功基準](#8-成功基準)
   - 8.1 [機能面](#81-機能面)
   - 8.2 [非機能面](#82-非機能面)
   - 8.3 [移行面](#83-移行面)
9. [前提条件](#9-前提条件)
   - 9.1 [環境前提](#91-環境前提)
   - 9.2 [技術前提](#92-技術前提)
   - 9.3 [セキュリティ前提](#93-セキュリティ前提)
10. [除外事項](#10-除外事項)
    - 10.1 [機能除外](#101-機能除外)
    - 10.2 [非機能除外](#102-非機能除外)
11. [参考手順書](#11-参考手順書)

---

🔔 文中、 [MoSCoW法](https://en.wikipedia.org/wiki/MoSCoW_method) にやや準じる形で、以下のように優先度をレベル分けしている箇所が出現する。

- `MUST` （絶対必要） ＞ `SHOULD` （できれば欲しい） ＞ `OPTIONAL` （あれば嬉しい） ＞ `WON'T` （今回は含めない）

## 1. プロジェクト概要

### 1.1 idhub とは

- OCNのID（＝OCN ID）と DOCOMOのID（＝dアカウント）を連携するシステム。
- 連携することでOCNブランドの世界でdポイントの進呈・利用ができたり、煩雑なOCN IDのログインをdアカウントで容易に日常使いのログインを実現させるためのもの。
- 詳しくはこちら → [idhub-overview.md](../minutes/idhub-overview.md)

### 1.2 前提と背景

- オンプレミスで稼働している本システム。そのデータセンタ（以降「三鷹DC」）の閉鎖が2026年6月を予定している。
- それまで、もしくはそれ以前に他のIaaS基盤へのマイグレーションが必須。
- idhub自体と連携する利用サービスがいくつか現存しているが、数年後に大きなトラフィック・トランザクションを要求するサービス（OCNメール）の新規利用が計画されている。
  - 現在の小規模人数での体制での運用、冗長性・安定性への懸念（DRが実現してない、等）から、ドコモビジネス社（旧NTTコミュニケーションズ）への譲渡・マイグレーションが計画されている。
  - その実現よりも先に三鷹DCの閉鎖（2026年6月）を迎えるため、 `暫定的にAWSへ移転` するものである。

- [AWS標準構成テンプレート](/nttdocomo-com/aws-templates-bprtech) に準拠させる。
  - AWSへの基盤移転を取りまとめしている部隊、 `bprtech Working Group` （もしくは `AWS移転ワーキンググループ`, `bpr` ） が定めたもの。（これを略して、プロジェクト中に `WG` という言葉が頻出されます。）
  - ドコモ社のセキュリティ上のレギュレーションを網羅する形で作成されている。
  - 以下の思想。
        - **goo/OCNサービスでの標準的なシステム構成**: Webアプリケーションをコンテナ化した構成を自動構築
  - **セキュリティ**: WAF + Security Groupsによる多層防御
  - **コンテナ化**: ECS/Fargateによるサーバーレスコンテナ実行（EC2非推奨）
  - **Infrastructure as Code**: CloudFormation + Sceptreによる自動化

#### 1.2.1 EC2の積極利用

- だが当プロジェクトは `暫定的にAWSへ移転` するため、 **積極的にEC2を用いる。**
  - コンテナ化を目指すとリリースのフローが大きく変わり、CI/CDを大きく作り替えないとならない。
  - コンテナではなくコンピューティングインスタンス前提でのIaC（Ansible）が資産として大きい。これを再利用したいため。
  - ロケーションの変更・マイグレーション（三鷹DC → AWS）が最優先。クラウドネイティブな最適化などはそのマイグレーションの後に検討する。
- ただし、データベースなどはその限りではない。
  - 主にWEBアプリケーションサーバにてEC2を積極利用する。
  - データベースなどは、Aurora等のマネージドサービスを採用することで、その利便性（バックアップ、スケール、パッチなど）の恩恵を受けることを狙う。
  - バッチサーバ（時刻トリガのタスク起動）についてはEC2なのか、マネージドサービスなのか？は要検討。

#### 1.2.2 EC2採用の背景

本プロジェクトでEC2を採用する主な理由：

- **リフト&シフト移行**: オンプレミス環境からのスムーズな移行を最優先
  - 三鷹DC閉鎖（2026年6月）までの限られた時間での移行
  - コンテナ化による大規模なCI/CD再構築を回避
- **既存資産の活用**: 
  - Ansible Playbookによる構成管理の資産が大きい
  - 既存のサーバ運用体制・ノウハウの継続活用
- **段階的モダナイゼーション**: 
  - まずはロケーション移行を完了
  - バッチ処理のLambda化、DB基盤のAurora移行は並行実施
  - クラウドネイティブな最適化は移行完了後に検討
- **Immutableインフラ**: 
  - ゴールデンAMIによるImmutableインフラストラクチャの実現
  - Blue/Greenデプロイメントによる無停止更新

**注意事項**: ECS/Fargateと比較した運用負荷の増加（OSパッチ管理、ミドルウェア管理等）は承知の上での採用です。詳細は以下の各セクションを参照してください：
- [§ 2.5 サーバ構成要件](./02-system-components-requirements.md#25-サーバ構成要件ecsfargate-vs-ec2)
- [§ 3.7 EC2アクセス管理要件](./03-security-requirements.md#37-ec2アクセス管理要件)
- [§ 4.2 拡張性要件](./04-non-functional-requirements.md#42-拡張性要件)
- [§ 4.4.5 パッチ管理要件](./04-non-functional-requirements.md#445-パッチ管理要件)
- [§ 5.2 バックアップ設計要件](./05-additional-functional-requirements.md#52-バックアップ設計要件)

### 1.3 プロジェクト名

- idhub AWS標準構成テンプレート（prod環境とdev環境）

### 1.4 目的

- オンプレミス上の現システムを、当社セキュリティに準拠させパブリッククラウド AWS 向けに無事故で、かつ、その後の安定運用ができる形でマイグレーションすること。
- 期限は、2026年5月末。
- 目標は、年度内切り替え。

### 1.5 対象環境

- `dev` = 検証環境、 `prod` = 商用環境。
- ![warning](https://api.iconify.design/twemoji/warning.svg) `dev` と `prod` で、AWSアカウントを分けている点に注意が必要である。

#### 1.5.1 dev

- **Sign-in URL** : <https://gooid-idhub-aws-dev.signin.aws.amazon.com/console>
  - **Account ID** : `910230630316`
  - **Alias** : `gooid-idhub-aws-dev`
  - **リージョン**: ap-northeast-1（東京）

#### 1.5.2 prod

- **Sign-in URL** : <https://gooid-idhub-aws-prod.signin.aws.amazon.com/console>
  - **Account ID** : `007773581311`
  - **Alis** : `gooid-idhub-aws-prod`
  - **リージョン**: ap-northeast-1（東京）

## 2. システム構成要件

- [2. システム構成要件](./02-system-components-requirements.md)

## 3. セキュリティ要件

- [3. セキュリティ要件](./03-security-requirements.md)

## 4. 非機能要件

- [4. 非機能要件](./04-non-functional-requirements.md)

## 5. 追加機能要件

- [5. 追加機能要件](./05-additional-functional-requirements.md)

## 6. 技術要件

### 6.1 インフラストラクチャ

- **コンピューティング**: EC2 (ECSは管理用ツール等、内部で一部利用)
- **ネットワーク**: Amazon VPC
- **ロードバランサー**: Application Load Balancer
- **データベース**: Amazon Aurora MySQL
- **ストレージ**: Amazon S3
- **CDN**: Amazon CloudFront

詳細は [§ 2. システム構成要件](./02-system-components-requirements.md) を参照してください。

### 6.2 セキュリティ

- **WAF**: AWS WAF
- **ファイアウォール**: AWS Network Firewall
- **証明書**: AWS Certificate Manager
- **認証情報管理**: AWS Secrets Manager
- **EDR**: CrowdStrike
- **脆弱性検知**: Future Vuls

詳細は [§ 3. セキュリティ要件](./03-security-requirements.md) を参照してください。

### 6.3 監視・ログ

- **監視**: Datadog
- **ログ分析**: Amazon Athena
- **アラート**: Amazon SNS
- **API監査**: Amazon CloudTrail

詳細は [§ 4.4 運用要件](./04-non-functional-requirements.md#44-運用要件) を参照してください。

## 7. 制約事項

### 7.1 技術的制約

- **リージョン**: ap-northeast-1のみ
- **AZ**: 3つのAZ（1a, 1c, 1d）を使用
- **IPアドレス**: 10.60.0.0/22のCIDRブロック
- **EC2採用**: EC2によるWebアプリケーション実行（ECS/Fargate非推奨）
- **CDN**: CloudFrontを前提とする

### 7.2 セキュリティ制約

- **MFA必須**: 初回ログイン時のMFA設定必須
- **HTTPS通信**: 外部向けシステムとしてHTTPS通信必須
- **マルチAZ**: 高可用性のためマルチAZ構成必須
- **暗号化**: 通信時・保存時暗号化必須

### 7.3 運用制約

- **メンテナンス時間**
  - `土曜日の 19:00-19:30` といった具合の、特定のメンテナンス時間は、 **ない**。
  - 24/365で常時稼働することを想定している。
- **バックアップ時間**
  - 基本的に、深夜早朝を想定している。
  - バックアップ項目ごとに時間は異なる。 [5.2 バックアップ設計要件](./05-additional-functional-requirements.md#52-バックアップ設計要件) を参照。
- **証明書更新**: 自動更新（ACM）
- **ログ保管**: システムセキュリティ対策チェックリストに基づく期間

## 8. 成功基準

### 8.1 機能面

- Webアプリケーションが正常に動作すること
- データベースへの接続が確立されること
- 静的コンテンツが正常に配信されること
- 別途保持している、PlaywrightによるE2Eテストが全てパスすること。

### 8.2 非機能面

- 可用性99.9%以上を達成すること
- セキュリティ要件を満たすこと
- パフォーマンス要件を満たすこと
- 監視・アラートが正常に動作すること
- マルチAZ構成による冗長化が実現されること

### 8.3 移行面

- オンプレミスからAWSへ移行する際、
  - 事前に告知・取り決めした時間内に終わること。
  - 移行後、前述の機能・非機能面で問題がないこと。

## 9. 前提条件

### 9.1 環境前提

- AWSアカウントが利用可能であること
- 必要なIAM権限が付与されていること
- ドメイン名が取得済みであること
- CCoEによるアカウント払い出しが完了していること

### 9.2 技術前提

- アプリケーションがEC2環境で動作可能であること
- アプリケーションコードがGitリポジトリに格納されていること
- SSL証明書が取得済みであること（ACMまたは外部証明書）
- Datadogアカウントが利用可能であること

### 9.3 セキュリティ前提

- システムセキュリティ対策チェックリストに準拠していること
  - 📂 [情報セキュリティ部HP > 規程・マニュアル類 > システムセキュリティ対策マニュアル](https://nttdocomo.sharepoint.com/:f:/r/sites/822150000/tasoshiki/Shared%20Documents/00%20%E6%83%85%E5%A0%B1%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E9%83%A8HP/01%20%E8%A6%8F%E7%A8%8B%E3%83%BB%E3%83%9E%E3%83%8B%E3%83%A5%E3%82%A2%E3%83%AB%E9%A1%9E/02%20%E3%83%9E%E3%83%8B%E3%83%A5%E3%82%A2%E3%83
### 9.3 セキュリティ前提

- システムセキュリティ対策チェックリストに準拠していること
  - 📂 [情報セキュリティ部HP > 規程・マニュアル類 > システムセキュリティ対策マニュアル](https://nttdocomo.sharepoint.com/:f:/r/sites/822150000/tasoshiki/Shared%20Documents/00%20%E6%83%85%E5%A0%B1%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E9%83%A8HP/01%20%E8%A6%8F%E7%A8%8B%E3%83%BB%E3%83%9E%E3%83%8B%E3%83%A5%E3%82%A2%E3%83%AB%E9%A1%9E/02%20%E3%83%9E%E3%83%8B%E3%83%A5%E3%82%A2%E3%83%AB/11_%E3%82%B7%E3%82%B9%E3%83%86%E3%83%A0%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E5%AF%BE%E7%AD%96%E3%83%9E%E3%83%8B%E3%83%A5%E3%82%A2%E3%83%AB/20241001%E7%89%88?csf=1&web=1&e=KpT48U) 🔒
- MFA設定が可能な環境であること
- ログ保管期間が規定に準拠していること

## 10. 除外事項

### 10.1 機能除外

- 外部システムとの連携機能
- リアルタイム通信機能
- ファイルアップロード機能
- オンプレミス環境との連携機能
  - 三鷹データセンタ <-> AWS間でのVPCの必要性のナゾ → [5.6 マイグレーション要件](./05-additional-functional-requirements.md#56-マイグレーション要件)

### 10.2 非機能除外

- 99.99%以上の可用性
- グローバル展開（マルチリージョン）
- オンプレミス環境とのハイブリッド構成
- 99.99%以上のSLA保証

## 11. 参考手順書

- [システム設計ガイドライン](../../doc-bpr/guideline/system-design/1.system architecture/README.md)
- [システム設計ガイドライン](../../doc-bpr/guideline/system-design/1.system%20architecture/README.md)
- [セキュリティ設計ガイドライン](../../doc-bpr/guideline/system-design/12.security/README.md)
- [可用性設計ガイドライン](../../doc-bpr/guideline/system-design/5.availability/README.md)
- [拡張性設計ガイドライン](../../doc-bpr/guideline/system-design/6.scalability/README.md)
- [サーバ構成ガイドライン](../../doc-bpr/guideline/system-design/3.server%20architecture/README.md)
