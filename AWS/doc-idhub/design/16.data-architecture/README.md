# データアーキテクチャ設計書

## 目次

- [概要](#概要)
- [データベース設計](#データベース設計)
- [ストレージ設計](#ストレージ設計)
- [データ暗号化設計](#データ暗号化設計)

---

## 概要

本設計書では、idhubシステムのデータ層のアーキテクチャを定義します。Aurora MySQL、S3ストレージ、データ暗号化の構成を記載します。

---

## データベース設計

```mermaid
graph TB
    subgraph "Aurora MySQL Cluster - Multi-AZ Architecture"
        CLUSTER[Aurora Cluster<br/>MySQL 8.0]
        
        subgraph "AZ-1a (Primary)"
            WRITER_1a[Writer Instance<br/>r5.large<br/>Read/Write Operations]
            STORAGE_1a[Storage Node 1<br/>SSD Storage]
        end
        
        subgraph "AZ-1c (Replica)"
            READER_1c[Reader Instance<br/>r5.large<br/>Read-Only Operations]
            STORAGE_1c[Storage Node 2<br/>SSD Storage]
        end
        
        subgraph "AZ-1d (Replica)"
            READER_1d[Reader Instance<br/>r5.large<br/>Read-Only Operations]  
            STORAGE_1d[Storage Node 3<br/>SSD Storage]
        end
        
        subgraph "Shared Cluster Storage (Cross-AZ)"
            SHARED_STORAGE[Aurora Shared Storage<br/>6 copies across 3 AZs<br/>Auto-scaling 10GB-128TB]
            BACKUP[Automated Backup<br/>14 days retention<br/>Cross-AZ Snapshots]
            BINLOG[Binary Log Replication<br/>Real-time Sync]
        end
        
        subgraph "Failover & Recovery"
            FAILOVER[Automatic Failover<br/>Writer: 30-120秒<br/>Reader: 即座]
            MONITORING[Aurora Monitoring<br/>Health Check & Metrics]
        end
        
        subgraph "Security & Access"
            ENCRYPTION[Encryption at Rest<br/>AWS KMS Customer Key]
            SECRETS_MGR[Secrets Manager<br/>30日自動ローテーション]
            VPC_SECURITY[VPC Security Groups<br/>Private Subnet Group]
        end
    end
    
    CLUSTER --> WRITER_1a
    CLUSTER --> READER_1c
    CLUSTER --> READER_1d
    
    WRITER_1a -.-> SHARED_STORAGE
    READER_1c -.-> SHARED_STORAGE
    READER_1d -.-> SHARED_STORAGE
    
    SHARED_STORAGE --> STORAGE_1a
    SHARED_STORAGE --> STORAGE_1c
    SHARED_STORAGE --> STORAGE_1d
    
    SHARED_STORAGE --> BACKUP
    WRITER_1a --> BINLOG
    BINLOG --> READER_1c
    BINLOG --> READER_1d
    
    subgraph "Application Connection Patterns"
        subgraph "商用環境 - 負荷分散"
            APP_WRITE[Write Operations<br/>EC2 from all AZs] --> WRITER_1a
            APP_READ_1[Read Operations<br/>EC2 from AZ-1a] --> READER_1c
            APP_READ_2[Read Operations<br/>EC2 from AZ-1c] --> READER_1d  
            APP_READ_3[Read Operations<br/>EC2 from AZ-1d] --> WRITER_1a
        end
        
        subgraph "検証環境 - 簡易構成"
            DEV_WRITE[Write Operations] --> WRITER_1a
            DEV_READ[Read Operations] --> READER_1c
        end
    end
```

**Aurora Multi-AZ分散の技術詳細:**

| 項目 | AZ-1a | AZ-1c | AZ-1d | 特徴 |
|------|-------|-------|-------|------|
| **Writer Instance** | ✅ Primary | ❌ | ❌ | 全ての書き込み処理（Private Subnet） |
| **Reader Instance** | ❌ | ✅ Replica | ✅ Replica | 読み取り負荷分散（Private Subnet） |
| **Storage Copy** | ✅ 2 copies | ✅ 2 copies | ✅ 2 copies | 自動6重化 |
| **Failover Target** | ✅ Primary | ✅ 候補1 | ✅ 候補2 | 30-120秒で自動切替 |
| **Backup Source** | ✅ Primary | ✅ Replica | ✅ Replica | Cross-AZバックアップ |

**商用環境のEC2-Aurora接続パターン:**

- **各AZのEC2** → 最も近いAuroraインスタンス優先
- **書き込み処理** → 必ずWriter Instance (AZ-1a)
- **読み取り処理** → Reader Instance優先、Writer Instanceはフォールバック
- **接続プール** → アプリケーションレベルで負荷分散

**データベース設計詳細:**

| 項目 | 設定値 | 備考 |
|------|-------|------|
| エンジン | Aurora MySQL 8.0 | 最新LTS版 |
| インスタンスクラス | r5.large | 2vCPU, 16GB RAM |
| **インスタンス構成** | **Writer 1台 + Reader 2台（固定）** | **Writer: AZ-1a、Reader: AZ-1c/1d**<br/>※自動復旧・動的スケーリングは将来検討 |
| ストレージ | 自動スケーリング | 10GB〜128TB |
| バックアップ保持期間 | 14日間 | 自動バックアップ（要件準拠） |
| 暗号化 | AWS KMS | 保存時暗号化 |
| マルチAZ | 3AZ配置 | 高可用性確保 |

---

## ストレージ設計

```mermaid
graph TB
    subgraph "S3 Buckets"
        S3_LOGS[Log Bucket<br/>ALB/VPC/WAF Logs]
        S3_BACKUP[Backup Bucket<br/>DB Snapshots]
        S3_STATIC[Static Assets Bucket<br/>Images/CSS/JS]
        S3_ARTIFACTS[Deployment Artifacts<br/>Application Code]
    end
    
    subgraph "Lifecycle Management"
        LC_LOGS[Log Lifecycle<br/>30d→IA→90d→Glacier→365d→Delete]
        LC_BACKUP[Backup Lifecycle<br/>30d→IA→1y→Glacier→7y→Delete]
        LC_STATIC[Static Lifecycle<br/>Standard Storage]
    end
    
    subgraph "Security"
        S3_ENCRYPT[Server-Side Encryption<br/>AES-256/KMS]
        S3_VERSIONING[Versioning Enabled]
        S3_ACCESS[Bucket Policies<br/>Least Privilege]
    end
    
    S3_LOGS --> LC_LOGS
    S3_BACKUP --> LC_BACKUP
    S3_STATIC --> LC_STATIC
    S3_LOGS --> S3_ENCRYPT
    S3_BACKUP --> S3_VERSIONING
    S3_STATIC --> S3_ACCESS
```

---

## データ暗号化設計

```mermaid
graph TB
    subgraph "暗号化レイヤー"
        subgraph "Transit Encryption"
            TLS[TLS 1.2+<br/>User ↔ CloudFront]
            HTTPS[HTTPS<br/>CloudFront ↔ ALB]
            SSL[SSL/TLS<br/>App ↔ Aurora]
        end
        
        subgraph "At-Rest Encryption"
            EBS_ENC[EBS Encryption<br/>AWS KMS]
            AURORA_ENC[Aurora Encryption<br/>AWS KMS]
            S3_ENC[S3 Encryption<br/>AES-256]
        end
        
        subgraph "Key Management"
            KMS[AWS KMS<br/>Customer Managed Keys]
            SECRETS[Secrets Manager<br/>DB Credentials]
            ROTATION[Automatic Rotation<br/>30 days]
        end
    end
    
    TLS --> HTTPS
    HTTPS --> SSL
    EBS_ENC --> KMS
    AURORA_ENC --> KMS
    S3_ENC --> KMS
    SECRETS --> ROTATION
```
