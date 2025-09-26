
## 失われた機能の確認

バックアップとして保管されていたテンプレートses.yaml と現行のテンプレートses-configuration.yamlで機能比較を行ったところ以下の指摘を受けた。

ses-configuration.yamlでは以下の機能が失われている

- CloudWatch監視・アラーム機能が不足
- 高度な設定パラメータが不足
- 機能フラグシステムが不足
- 日本向け特殊機能が不足
- 通知システムが不足

他のテンプレートに機能を分散した可能性もあるので現行のテンプレート全体を確認し、本当に機能が失われているのであれば再実装する必要がある


### CloudWatch監視・アラーム機能が不足

BounceRateAlarm:        # バウンス率監視
ComplaintRateAlarm:     # 苦情率監視
SESIAMRole:            # SES用IAMロール
とあるがphase-8で行っている筈なので確認phase-8では足りなくてここでやっておく必要があるか？
例えばCloudWatchの監視はphase-8で設定されているが、SES側の設定が無いので実際は監視できていないとかあったら困ります
phase-8以外でもやっている可能性があるのでテンプレートディレクトリを確認し本当に機能として足りていないか確認してほしい

### 高度な設定パラメータが不足

CloudWatchLogRetentionDays: # ログ保持期間設定
BounceRateThreshold:        # アラート閾値設定
ComplaintRateThreshold:     # 苦情率閾値
とあるがphase-8で行っている筈なので確認phase-8では足りなくてここでやっておく必要があるか？
例えばCloudWatchの監視はphase-8で設定されているが、SES側の設定が無いので実際は監視できていないとかあったら困ります
phase-8以外でもやっている可能性があるのでテンプレートディレクトリを確認し本当に機能として足りていないか確認してほしい

### 機能フラグシステムが不足

EnableBounceComplaintHandling: "true"
EnableDKIM: "true"  
EnableDomainVerification: "true"
EnableTokyoRegionFeatures: "true"
EnableJapaneseCompliance: "true"
EnableBYODKIMAutomation: "true"
それぞれの機能についてを詳しく説明してほしい
大阪リージョンを使用する場合はどこか変更があるか

### 日本向け特殊機能が不足

EnableTokyoSES: "false"
EnableJapaneseEmailTemplates: "true"  
CloudWatchMetricNamespace: "ses-migration/production/SES"
それぞれの機能についてを詳しく説明してほしい
大阪リージョンを使用する場合はどこか変更があるか

### 通知システムが不足

NotificationEmail: # 通知用メールアドレス
NotificationPhone: # 通知用電話番号
SNSTopicArn:      # SNS統合
それぞれの機能についてを詳しく説明してほしい
phase-8以外でもやっている可能性があるのでテンプレートディレクトリを確認し本当に機能として足りていないか確認してほしい
