# アプリケーションアーキテクチャ設計書

## 目次

- [概要](#概要)
- [コンピューティングアーキテクチャ](#コンピューティングアーキテクチャ)
- [ロードバランサー設計](#ロードバランサー設計)
- [CDN設計](#cdn設計)
- [WAF設計（商用環境）](#waf設計商用環境)

---

## 概要

本設計書では、idhubシステムのアプリケーション層のアーキテクチャを定義します。EC2インスタンス、ロードバランサー、CDN、WAFの構成を記載します。

---

## コンピューティングアーキテクチャ

```mermaid
graph TB
    subgraph "EC2 Auto Scaling Group"
        subgraph "AZ-1a"
            EC2_1a[EC2 Instance<br/>t3.medium<br/>Java/Apache Tomcat]
        end
        
        subgraph "AZ-1c"  
            EC2_1c[EC2 Instance<br/>t3.medium<br/>Java/Apache Tomcat]
        end
        
        subgraph "AZ-1d"
            EC2_1d[EC2 Instance<br/>t3.medium<br/>Java/Apache Tomcat]
        end
    end
    
    subgraph "管理・運用"
        ASG[Auto Scaling Group]
        LC[Launch Configuration]
        USERDATA[User Data Script]
        
        ASG --> EC2_1a
        ASG --> EC2_1c
        ASG --> EC2_1d
        LC --> ASG
        USERDATA --> LC
    end
    
    subgraph "監視・セキュリティ"
        CW_AGENT[CloudWatch Agent]
        DD_AGENT[Datadog Agent]
        CS_AGENT[CrowdStrike Agent]
        FV_AGENT[Future Vuls Agent]
        
        CW_AGENT --> EC2_1a
        DD_AGENT --> EC2_1a
        CS_AGENT --> EC2_1a
        FV_AGENT --> EC2_1a
    end
```

**EC2設計詳細:**

| 項目 | 設定値 | 備考 |
|------|-------|------|
| インスタンスタイプ | t3.medium | 2vCPU, 4GB RAM |
| OS | Amazon Linux 2023 | 最新セキュリティパッチ |
| ストレージ | 20GB gp3 | 暗号化有効 |
| **起動台数** | **3台固定** | **各AZに1台ずつ（現時点）** |
| 自動復旧 | 未実装（将来検討） | 障害時の自動起動は今後検討 |
| 手動スケーリング | 対応可能 | 将来の負荷増加に備えた設計 |
| ヘルスチェック | ELB + EC2 | 多重ヘルスチェック |

---

## ロードバランサー設計

```mermaid
graph LR
    USER[End Users<br/>エンドユーザー]
    
    subgraph "Application Load Balancer"
        subgraph "Listeners"
            LISTENER_80[HTTP:80<br/>Listener]
            LISTENER_443[HTTPS:443<br/>Listener<br/>SSL Certificate]
        end
        
        subgraph "Routing Rules"
            RULE_ADMIN[Path: /admin/*<br/>→ Admin Target Group]
            RULE_DEFAULT[Default<br/>→ Web Target Group]
        end
        
        subgraph "Target Groups"
            TG_WEB[Web Target Group<br/>Port 80<br/>Health Check: /health]
            TG_ADMIN[Admin Target Group<br/>Port 80<br/>Health Check: /admin/health]
        end
        
        subgraph "EC2 Instances"
            EC2_1a[EC2<br/>AZ-1a]
            EC2_1c[EC2<br/>AZ-1c]
            EC2_1d[EC2<br/>AZ-1d]
        end
    end
    
    USER -->|HTTP Request| LISTENER_80
    USER -->|HTTPS Request| LISTENER_443
    LISTENER_80 -.->|Redirect to HTTPS| LISTENER_443
    
    LISTENER_443 --> RULE_ADMIN
    LISTENER_443 --> RULE_DEFAULT
    RULE_ADMIN --> TG_ADMIN
    RULE_DEFAULT --> TG_WEB
    TG_WEB --> EC2_1a
    TG_WEB --> EC2_1c
    TG_WEB --> EC2_1d
    TG_ADMIN --> EC2_1a
    TG_ADMIN --> EC2_1c
    TG_ADMIN --> EC2_1d
```

---

## CDN設計

```mermaid
graph TB
    subgraph "CloudFront Distribution"
        
        subgraph "Origins"
            ORIGIN_ALB[ALB Origin<br/>Custom Origin]
            ORIGIN_S3[S3 Origin<br/>Static Assets]
        end

        subgraph "Behaviors"
            BEHAVIOR_DEFAULT["Default (*)<br/>ALB Origin<br/>TTL: 0<br/>Cache無効"]
            BEHAVIOR_STATIC["<strike>Path: /*</strike><br/>S3 Origin<br/>TTL: 86400<br/>（Pathによるルーティングではなく、サイト全体をメンテナンス状態にする際に利用。）"]
        end

        subgraph "Security"
            OAC[Origin Access Control]
            CUSTOM_HEADERS[Custom Headers<br/>X-Forwarded-For-CloudFront]
        end
    end

    BEHAVIOR_DEFAULT --> ORIGIN_ALB
    BEHAVIOR_STATIC --> ORIGIN_S3
    OAC --> ORIGIN_S3
    CUSTOM_HEADERS --> ORIGIN_ALB
```

**CDN設計の特徴:**

- CDNは、高速コンテンツデリバリーのためにキャッシュさせる、という意味合いは薄く、どちらかといえばIPを分散させてDDoS攻撃を防ぐため、という目的が強い。（参考： [要件定義書 ＞ 2.6 CDN構成要件](../../requirements/02-system-components-requirements.md#26-cdn構成要件)）
  - よって、Cacheを無効にする。（つまり、TTL=0である。）
- S3 による静的コンテンツデリバリーはメンテナンスページの用途だけである。（2025年11月現在）メンテナンスや大規模障害の有事の際、トラフィック全体をそのページに流すように切り替える。（参考： [要件定義書 ＞ 4.4.4 Sorryページ、メンテナンスページ](../../requirements/04-non-functional-requirements.md#444-sorryページメンテナンスページ)）

---

## WAF設計（商用環境）

```mermaid
graph TB
    subgraph "商用環境 - CloudFront Distribution"
        SPACER[" "]
        CF_DIST[CloudFront Distribution<br/>Production Environment]
        
        subgraph "Attached Web ACL"
            WAF[AWS WAF v2 Web ACL<br/>商用環境セキュリティルール]
            
            subgraph "Rule Groups"
                RG_CORE[Core Rule Set<br/>OWASP Top 10]
                RG_IP[IP Reputation<br/>Known Bad IPs]
                RG_RATE[Rate Limiting<br/>商用トラフィック対応<br/>per IP/URI]
                RG_GEO[Geographic Blocking<br/>Country Restrictions]
                RG_CUSTOM[Custom Rules<br/>Application Specific]
            end
            
            subgraph "IP Sets"
                IP_ALLOW[Allowed IP Set<br/>社内/VDI/ベンダ]
                IP_BLOCK[Blocked IP Set<br/>攻撃元IP]
            end
            
            subgraph "Actions"
                ACTION_ALLOW[Allow]
                ACTION_BLOCK[Block]
                ACTION_COUNT[Count Only]
                ACTION_CAPTCHA[CAPTCHA Challenge]
            end
        end
        
        subgraph "商用環境 Processing Flow"
            USERS[一般ユーザー<br/>外部システム] --> WAF_PROCESSING[WAF Processing<br/>within CloudFront<br/>商用セキュリティチェック]
            WAF_PROCESSING --> ORIGIN[Origin ALB<br/>商用環境]
        end
    end
    
    WAF --> RG_CORE
    WAF --> RG_IP
    WAF --> RG_RATE
    WAF --> RG_GEO
    WAF --> RG_CUSTOM
    RG_CUSTOM --> IP_ALLOW
    RG_CUSTOM --> IP_BLOCK
    RG_CORE --> ACTION_BLOCK
    RG_RATE --> ACTION_CAPTCHA
    IP_ALLOW --> ACTION_ALLOW
    IP_BLOCK --> ACTION_BLOCK
    
    style SPACER fill:none,stroke:none
```

**商用環境WAF設計の特徴:**

- **高トラフィック対応**: 商用環境の本格的なアクセス負荷に対応したレート制限
- **包括的セキュリティ**: OWASP Top 10対策、地理的制限、IP評価ルール
- **運用考慮**: アクション種別による段階的対応（Block/CAPTCHA/Count）

**検証環境との差異:**

- 検証環境では簡素化されたWAFルール（基本的なOWSP対策のみ）
- 商用環境ではより厳格なレート制限とセキュリティルール
- IP許可リストの範囲が異なる（検証環境は開発者IP含む）

**WAF統合の技術的詳細:**

- WAF Web ACLはCloudFrontディストリビューションにアタッチされる
- リクエストはCloudFront内でWAF処理が実行された後、Originに転送される
- WAFルールによってブロックされた場合、Originには到達しない
