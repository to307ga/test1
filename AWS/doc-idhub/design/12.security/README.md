# セキュリティアーキテクチャ設計書

## 目次

- [概要](#概要)
- [アクセス制御設計](#アクセス制御設計)
- [通信暗号化設計](#通信暗号化設計)
- [アウトバウンド通信制御設計](#アウトバウンド通信制御設計)
- [監視・監査設計](#監視監査設計)
- [個人情報保護設計](#個人情報保護設計)

---

## 概要

本設計書では、idhubシステムのセキュリティアーキテクチャを定義します。多層防御、アクセス制御、暗号化、監視・監査の構成を記載します。

---

## アクセス制御設計

```mermaid
graph TB
    subgraph "IAM アクセス制御"
        subgraph "Users"
            ADMIN_USER[管理者ユーザー<br/>MFA必須]
            DEV_USER[開発者ユーザー<br/>MFA必須]
            READONLY_USER[参照ユーザー<br/>MFA必須]
        end
        
        subgraph "Roles"
            ADMIN_ROLE[Administrator Role<br/>Full Access]
            DEV_ROLE[Developer Role<br/>Limited Access]
            READONLY_ROLE[ReadOnly Role<br/>View Only]
            EC2_ROLE[EC2 Instance Role<br/>Service Access]
        end
        
        subgraph "Policies"
            ADMIN_POLICY[Admin Policy<br/>*:*]
            DEV_POLICY[Developer Policy<br/>Specific Services]
            READONLY_POLICY[ReadOnly Policy<br/>Describe/List Only]
            SERVICE_POLICY[Service Policy<br/>Aurora/S3/CloudWatch]
        end
    end
    
    ADMIN_USER --> ADMIN_ROLE
    DEV_USER --> DEV_ROLE
    READONLY_USER --> READONLY_ROLE
    ADMIN_ROLE --> ADMIN_POLICY
    DEV_ROLE --> DEV_POLICY
    READONLY_ROLE --> READONLY_POLICY
    EC2_ROLE --> SERVICE_POLICY
```

---

## 通信暗号化設計

```mermaid
graph LR
    subgraph "通信経路暗号化"
        A[User Browser] -->|TLS 1.3| B[CloudFront]
        B -->|TLS 1.2| C[ALB]
        C -->|HTTP*| D[EC2]
        D -->|TLS 1.2| E[Aurora]
        
        subgraph "証明書管理"
            ACM[AWS Certificate Manager]
            AUTO_RENEWAL[自動更新<br/>90日前]
            WILDCARD[ワイルドカード証明書]
        end
        
        ACM --> B
        ACM --> C
        AUTO_RENEWAL --> ACM
        WILDCARD --> ACM
    end
    
    style A fill:#e1f5fe
    style E fill:#e8f5e8
```

---

## アウトバウンド通信制御設計

```mermaid
graph TB
    subgraph Layer1["レイヤー1: Network Firewall"]
        NF[Network Firewall<br/>ドメインベースホワイトリスト]
        NF_ALLOW[許可ドメインリスト<br/>明示的許可]
        NF_DENY[Default Deny<br/>デフォルト拒否]
        NF_THREAT[脅威インテリジェンス<br/>既知の悪意あるドメインブロック]
    end
    
    subgraph Layer2["レイヤー2: Security Group"]
        SG_EGRESS[Security Group<br/>Egress Rules]
        SG_HTTPS[HTTPS 443 許可]
        SG_DNS[DNS 53 許可]
    end
    
    subgraph Layer3["レイヤー3: DNS Resolution"]
        DNS[Route 53 Resolver<br/>DNS解決]
        DNS_VALIDATE[健全な対向先確認<br/>IPアドレス解決]
    end
    
    subgraph Layer4["レイヤー4: Application Level"]
        APP_PROXY[アプリケーションレベル制御<br/>HTTP Clientライブラリ設定]
        APP_TIMEOUT[タイムアウト設定<br/>異常検知]
    end
    
    EC2[EC2 Instance<br/>Private Subnet] --> SG_EGRESS
    SG_EGRESS --> DNS
    DNS --> NF
    NF --> NAT[NAT Gateway<br/>固定EIP]
    NAT --> INTERNET[Internet<br/>許可ドメインのみ]
    
    NF --> NF_ALLOW
    NF --> NF_DENY
    NF --> NF_THREAT
    SG_EGRESS --> SG_HTTPS
    SG_EGRESS --> SG_DNS
    DNS --> DNS_VALIDATE
    APP_PROXY --> APP_TIMEOUT
```

**アウトバウンド通信制御の設計概要:**

| 制御レイヤー | 制御方式 | 対象 | 効果 |
|------------|---------|------|------|
| Network Firewall | ドメインホワイトリスト | 全外部通信 | 明示的許可のみ通信可能 |
| Security Group | ポート・プロトコル制御 | EC2 Egress | HTTPS/DNS以外のプロトコルブロック |
| DNS Resolution | 健全性確認 | ドメイン→IP | 正規のIPアドレスへの接続確認 |
| VPC Flow Logs | 通信記録 | 全ネットワーク通信 | 監査証跡・異常検知 |

**セキュリティ効果:**

- **マルウェア対策**: C&Cサーバへの通信を遮断
- **データ流出防止**: 未許可の外部サービスへのデータ送信をブロック
- **コンプライアンス**: システムセキュリティ対策マニュアル準拠
- **監査対応**: 全通信の記録と分析

---

## 監視・監査設計

```mermaid
graph TB
    subgraph "セキュリティ監視"
        subgraph "EDR"
            CS[CrowdStrike Falcon<br/>リアルタイム脅威検知]
            CS_AGENT[各EC2にAgent導入]
            CS_CONSOLE[CrowdStrike Console<br/>アラート管理]
        end
        
        subgraph "脆弱性管理"
            FV[Future Vuls<br/>脆弱性スキャン]
            FV_SCHEDULE[定期スキャン<br/>週次実行]
            FV_REPORT[脆弱性レポート<br/>自動生成]
        end
        
        subgraph "ログ監査"
            CT[CloudTrail<br/>API呼び出しログ]
            VPC_FLOW[VPC Flow Logs<br/>ネットワーク監視]
            WAF_LOG[WAF Logs<br/>攻撃パターン分析]
        end
        
        subgraph "監視ダッシュボード"
            DD[Datadog<br/>統合監視]
            ALERTS[アラート通知<br/>Slack/Email]
        end
    end
    
    CS --> CS_AGENT
    CS_AGENT --> CS_CONSOLE
    FV --> FV_SCHEDULE
    FV_SCHEDULE --> FV_REPORT
    CT --> DD
    VPC_FLOW --> DD
    WAF_LOG --> DD
    DD --> ALERTS
```

---

## 個人情報保護設計

```mermaid
graph TB
    subgraph "個人情報アクセス制御"
        subgraph "平常時アクセス"
            GOLD_ZONE[Gold Zone<br/>生体認証エリア]
            OFFICE_IP[事務局固定IP<br/>金沢/名古屋/仙台センタ]
            VPN_ACCESS[VPN経由アクセス<br/>MFA必須]
        end
        
        subgraph "緊急時アクセス"
            EMERGENCY[緊急時対応<br/>リモートアクセス]
            MFA_AUTH[多要素認証<br/>ID+Pass+TOTP]
            APPROVAL[承認プロセス<br/>管理者許可]
        end
        
        subgraph "監査ログ"
            ACCESS_LOG[アクセスログ記録<br/>全ての個人情報アクセス]
            AUDIT_TRAIL[監査証跡<br/>誰がいつ何にアクセス]
        end
        
        subgraph "データマスキング"
            PROD_DATA[本番データ<br/>個人情報あり]
            MASKED_DATA[マスク済データ<br/>開発/検証用]
            ANONYMIZE[匿名化処理<br/>統計分析用]
        end
    end
    
    GOLD_ZONE --> ACCESS_LOG
    OFFICE_IP --> ACCESS_LOG
    VPN_ACCESS --> MFA_AUTH
    MFA_AUTH --> ACCESS_LOG
    EMERGENCY --> APPROVAL
    APPROVAL --> ACCESS_LOG
    ACCESS_LOG --> AUDIT_TRAIL
    PROD_DATA --> MASKED_DATA
    PROD_DATA --> ANONYMIZE
```
