# Immutable環境検証手順

## 📑 目次

- [📋 概要](#-概要)
- [🎯 検証目的](#-検証目的)
- [🔧 前提条件](#-前提条件)
- [📊 検証環境構成](#-検証環境構成)
- [🧪 検証シナリオ一覧](#-検証シナリオ一覧)
- [🚀 シナリオ1: パッチ適用自動化検証](#-シナリオ1-パッチ適用自動化検証)
  - [1.1 自動パッチ適用](#11-自動パッチ適用)
  - [1.2 パッチ適用ロールバック](#12-パッチ適用ロールバック)
- [🔄 シナリオ2: アプリケーションデプロイ検証](#-シナリオ2-アプリケーションデプロイ検証)
  - [2.1 Blue/Greenデプロイメント](#21-bluegreen デプロイメント)
  - [2.2 アプリケーションロールバック](#22-アプリケーションロールバック)
- [💥 シナリオ3: 障害対応検証](#-シナリオ3-障害対応検証)
  - [3.1 EC2インスタンス障害](#31-ec2インスタンス障害)
  - [3.2 Aurora障害対応](#32-aurora障害対応)
  - [3.3 ProxySQL障害対応](#33-proxysql障害対応)
- [⚡ シナリオ4: スケーリング検証](#-シナリオ4-スケーリング検証)
  - [4.1 水平スケーリング](#41-水平スケーリング)
  - [4.2 垂直スケーリング](#42-垂直スケーリング)
- [🔒 シナリオ5: セキュリティ検証](#-シナリオ5-セキュリティ検証)
  - [5.1 セキュリティパッチ適用](#51-セキュリティパッチ適用)
  - [5.2 アクセス制御検証](#52-アクセス制御検証)
- [📈 シナリオ6: パフォーマンス検証](#-シナリオ6-パフォーマンス検証)
  - [6.1 負荷テスト](#61-負荷テスト)
  - [6.2 レスポンス性能検証](#62-レスポンス性能検証)
- [🔄 シナリオ7: バックアップ・復元検証](#-シナリオ7-バックアップ復元検証)
  - [7.1 データバックアップ](#71-データバックアップ)
- [🚀 シナリオ9: Immutable環境理想形検証（将来実装）](#-シナリオ9-immutable環境理想形検証将来実装)
  - [9.1 ゴールデンイメージ（AMI）検証](#91-ゴールデンイメージami検証)
  - [9.2 Auto Scaling自動復旧検証](#92-auto-scaling自動復旧検証)
  - [9.3 Blue/Green デプロイメント検証](#93-bluegreen-デプロイメント検証)
  - [9.4 ロールバック検証](#94-ロールバック検証)
  - [9.5 検証結果サマリー](#95-検証結果サマリー)
  - [7.2 ポイントインタイム復元](#72-ポイントインタイム復元)
- [📝 検証結果記録](#-検証結果記録)
- [🏆 成功基準](#-成功基準)
- [📚 関連ドキュメント](#-関連ドキュメント)

## 📋 概要

このドキュメントは、ProxySQL + Aurora + Laravel統合によるImmutable Infrastructure環境の包括的な検証手順を記載しています。Blue/Greenデプロイメント機能を中心とした各種運用シナリオの検証を通じて、本番環境での安定稼働を確保します。

**検証対象環境:**
- Blue/Green Deployment対応Immutable Infrastructure
- ProxySQL Database Proxy
- Aurora MySQL Cluster
- Laravel Application Stack
- CloudWatch Monitoring & Alerting

## 🎯 検証目的

### 主要検証目標
1. **🔵🟢 Immutable Infrastructure**: 無停止でのインフラ更新・ロールバック
2. **⚡ 高可用性**: 障害時の自動復旧・継続サービス提供
3. **🚀 自動化**: パッチ適用からアプリデプロイまでの完全自動化
4. **📊 監視**: 包括的な監視・アラート機能の検証
5. **🔒 セキュリティ**: セキュリティパッチ適用・アクセス制御の検証
6. **📈 性能**: 負荷に対するスケーラビリティ・パフォーマンス検証

## 🔧 前提条件

### 検証環境要件
- POC Immutable環境が完全に構築済み
- Blue/Greenデプロイメント機能が実装済み
- 監視・アラートシステムが稼働中
- Aurora MySQL Clusterが稼働中
- ProxySQLが全インスタンスで稼働中

### 必要ツール・権限
- AWS CLI (管理者権限)
- Ansible (インフラ自動化)
- Sceptre (CloudFormation管理)
- MySQL Client (データベース接続)
- curl, wget (HTTP テスト)
- jq (JSON処理)

## 📊 検証環境構成

```
┌─────────────────────────────────────────────────────────────────┐
│                   検証環境アーキテクチャ                          │
│                                                               │
│  [Load Balancer] → [Blue/Green Controller]                   │
│                          │                                   │
│          ┌───────────────┼───────────────┐                   │
│          ▼               ▼               ▼                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │ Blue Env    │ │ Green Env   │ │ Test Env    │               │
│  │ pochub-001  │ │ pochub-g001 │ │ pochub-t001 │               │
│  │ pochub-002  │ │ pochub-g002 │ │ (Optional)  │               │
│  │ pochub-003  │ │ pochub-g003 │ │             │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
│          │               │               │                   │
│          └───────────────┼───────────────┘                   │
│                          ▼                                   │
│            ┌─────────────────────────────────┐                 │
│            │     Aurora MySQL Cluster       │                 │
│            │    (共有データストア)            │                 │
│            └─────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🧪 検証シナリオ一覧

| シナリオ | 目的 | 所要時間 | 重要度 |
|---------|------|----------|--------|
| 1. パッチ適用自動化 | OSパッチ無停止適用 | 30分 | 🔴 高 |
| 2. アプリデプロイ | Blue/Green無停止デプロイ | 45分 | 🔴 高 |
| 3. 障害対応 | インスタンス・サービス障害対応 | 60分 | 🔴 高 |
| 4. スケーリング | 水平・垂直スケーリング | 40分 | 🟡 中 |
| 5. セキュリティ | セキュリティパッチ・制御 | 35分 | 🔴 高 |
| 6. パフォーマンス | 負荷・性能テスト | 90分 | 🟡 中 |
| 7. バックアップ・復元 | データ保護・復旧 | 50分 | 🟡 中 |

**総検証時間**: 約5.5時間（並行実行で短縮可能）

---

## 🚀 シナリオ1: パッチ適用自動化検証

### 目的
Immutable Infrastructureにおけるパッチ適用の自動化と無停止更新の検証

### 1.1 自動パッチ適用

#### 検証手順

**ステップ1: 現在の環境状態確認**
```bash
cd /home/tomo/poc/ansible-playbooks

# 現在のBlue環境確認
ansible all -i inventory/poc -m shell -a "cat /etc/os-release | head -3"
ansible all -i inventory/poc -m shell -a "uname -r"
ansible all -i inventory/poc -m shell -a "systemctl status proxysql laravel" --become

# パッケージバージョン記録
ansible all -i inventory/poc -m shell -a "rpm -qa | grep -E '(kernel|httpd|php|mysql)' | sort" > /tmp/packages_before_patch.log
```

**ステップ2: 利用可能パッチ確認**
```bash
# セキュリティアップデート確認
ansible all -i inventory/poc -m shell -a "dnf check-update --security" --become

# 全アップデート確認
ansible all -i inventory/poc -m shell -a "dnf check-update" --become
```

**ステップ3: Green環境でのパッチ適用プレイブック作成**
```bash
# パッチ適用自動化プレイブック作成
cat > immutable-patch-deployment.yml << 'EOF'
---
# Immutable Infrastructure Patch Deployment
- name: Immutable Patch Deployment with Blue/Green
  hosts: all
  become: yes
  vars:
    deployment_mode: "{{ deployment_mode | default('patch') }}"
    patch_type: "{{ patch_type | default('security') }}"  # security, all
    
  tasks:
    - name: "=== IMMUTABLE PATCH DEPLOYMENT START ==="
      debug:
        msg: |
          🔄 Immutable Infrastructure パッチ適用開始
          
          Mode: {{ deployment_mode }}
          Patch Type: {{ patch_type }}
          Target: {{ ansible_hostname }}
          Timestamp: {{ ansible_date_time.iso8601 }}

    - name: Create patch deployment marker
      file:
        path: /tmp/patch_deployment_{{ ansible_date_time.epoch }}
        state: touch

    - name: Backup current package list
      shell: rpm -qa | sort > /tmp/packages_before_{{ ansible_date_time.epoch }}.log

    - name: Apply security patches
      dnf:
        name: "*"
        state: latest
        security: yes
        update_cache: yes
      when: patch_type == 'security'
      register: security_updates

    - name: Apply all patches
      dnf:
        name: "*"
        state: latest
        update_cache: yes
      when: patch_type == 'all'
      register: all_updates

    - name: Record applied patches
      shell: rpm -qa | sort > /tmp/packages_after_{{ ansible_date_time.epoch }}.log

    - name: Generate patch diff
      shell: |
        diff /tmp/packages_before_{{ ansible_date_time.epoch }}.log \
             /tmp/packages_after_{{ ansible_date_time.epoch }}.log > \
             /tmp/patch_diff_{{ ansible_date_time.epoch }}.log || true

    - name: Restart services if needed
      systemd:
        name: "{{ item }}"
        state: restarted
      loop:
        - httpd
        - php-fpm
      when: security_updates.changed or all_updates.changed

    - name: Restart ProxySQL if updated
      systemd:
        name: proxysql
        state: restarted
      when: 
        - security_updates.changed or all_updates.changed
        - "'proxysql' in ansible_facts.packages"

    - name: Wait for services to stabilize
      pause:
        seconds: 30

    - name: Verify application health
      uri:
        url: "http://{{ ansible_default_ipv4.address }}/health"
        method: GET
        status_code: 200
      register: health_check

    - name: Verify ProxySQL connectivity
      mysql_info:
        login_host: 127.0.0.1
        login_port: 6033
        login_user: "{{ laravel_db_user }}"
        login_password: "{{ laravel_db_password }}"
      register: proxysql_check

    - name: "=== PATCH DEPLOYMENT RESULTS ==="
      debug:
        msg: |
          ✅ パッチ適用完了
          
          Security Updates: {{ security_updates.changed | default(false) }}
          All Updates: {{ all_updates.changed | default(false) }}
          Health Check: {{ health_check.status }}
          ProxySQL Status: {{ 'OK' if proxysql_check.version is defined else 'ERROR' }}
          
          Patch Diff: /tmp/patch_diff_{{ ansible_date_time.epoch }}.log
EOF
```

**ステップ4: Blue環境でのパッチ適用実行**
```bash
# セキュリティパッチのみ適用（本番推奨）
ansible-playbook -i inventory/poc immutable-patch-deployment.yml \
  -e "deployment_mode=patch patch_type=security"

# 実行結果確認
ansible all -i inventory/poc -m shell -a "cat /tmp/patch_diff_*.log | tail -20"
```

**ステップ5: Green環境作成・パッチ適用**
```bash
# Green環境用AMI作成（パッチ適用済み）
# 注: 実際の環境では新しいAMIを作成し、Green環境としてデプロイ

# Green環境へのトラフィック段階的切り替え
ansible-playbook -i inventory/poc blue-green-deployment.yml \
  -e "deployment_mode=switch target_environment=green traffic_percentage=10"

# Green環境動作確認
ansible all -i inventory/poc -m shell -a "curl -s http://localhost/health"

# 問題なければ完全切り替え
ansible-playbook -i inventory/poc blue-green-deployment.yml \
  -e "deployment_mode=switch target_environment=green traffic_percentage=100"
```

### 1.2 パッチ適用ロールバック

#### 検証手順

**ステップ1: 問題発生シミュレーション**
```bash
# Green環境で意図的に問題を発生させる
ansible all -i inventory/poc -m shell -a "systemctl stop httpd" --become
```

**ステップ2: 自動監視・アラート確認**
```bash
# CloudWatch アラーム確認
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --region ap-northeast-1

# ヘルスチェック失敗確認
ansible all -i inventory/poc -m shell -a "curl -s -o /dev/null -w '%{http_code}' http://localhost/health"
```

**ステップ3: 緊急ロールバック実行**
```bash
# 即座にBlue環境にロールバック
ansible-playbook -i inventory/poc blue-green-deployment.yml \
  -e "deployment_mode=rollback"

# ロールバック確認
ansible all -i inventory/poc -m shell -a "curl -s http://localhost/health"
```

**ステップ4: ロールバック検証**
```bash
# Blue環境での正常性確認
ansible all -i inventory/poc -m shell -a "systemctl status httpd php-fpm proxysql"

# パッケージバージョン確認（ロールバック前のバージョン）
ansible all -i inventory/poc -m shell -a "rpm -qa | grep -E '(kernel|httpd|php)' | head -5"
```

---

## 🔄 シナリオ2: アプリケーションデプロイ検証

### 目的
Laravel アプリケーションのBlue/Greenデプロイメント機能の検証

### 2.1 Blue/Greenデプロイメント

#### 検証手順

**ステップ1: 現在のアプリケーション状態確認**
```bash
# 現在のアプリケーションバージョン確認
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan --version"

# 現在のGitコミット確認
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && git log --oneline -5"

# データベース状態確認
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan migrate:status"
```

**ステップ2: 新バージョンアプリケーション準備**
```bash
# アプリケーションデプロイプレイブック作成
cat > immutable-app-deployment.yml << 'EOF'
---
# Immutable Application Deployment with Blue/Green
- name: Immutable Application Deployment
  hosts: all
  become: yes
  vars:
    app_version: "{{ app_version | default('v2.0.0') }}"
    git_branch: "{{ git_branch | default('main') }}"
    deployment_env: "{{ deployment_env | default('green') }}"
    
  tasks:
    - name: "=== APPLICATION DEPLOYMENT START ==="
      debug:
        msg: |
          🚀 Laravel Application デプロイ開始
          
          Version: {{ app_version }}
          Branch: {{ git_branch }}
          Environment: {{ deployment_env }}
          Host: {{ ansible_hostname }}

    - name: Create deployment backup
      shell: |
        if [ -d "/var/www/poc-web" ]; then
          cp -r /var/www/poc-web /var/www/poc-web.backup.{{ ansible_date_time.epoch }}
        fi

    - name: Create Green environment directory
      file:
        path: /var/www/poc-web-green
        state: directory
        owner: apache
        group: apache
        mode: '0755'
      when: deployment_env == 'green'

    - name: Clone/Update application code
      git:
        repo: https://github.com/your-repo/poc-web.git  # 実際のリポジトリに変更
        dest: "/var/www/poc-web-{{ deployment_env }}"
        version: "{{ git_branch }}"
        force: yes
      become_user: apache

    - name: Install/Update Composer dependencies
      composer:
        command: install
        working_dir: "/var/www/poc-web-{{ deployment_env }}"
        optimize_autoloader: yes
        no_dev: yes
      become_user: apache

    - name: Copy environment configuration
      copy:
        src: /var/www/poc-web/.env
        dest: "/var/www/poc-web-{{ deployment_env }}/.env"
        remote_src: yes
        owner: apache
        group: apache

    - name: Update environment for Green deployment
      lineinfile:
        path: "/var/www/poc-web-{{ deployment_env }}/.env"
        regexp: "^APP_ENV="
        line: "APP_ENV={{ deployment_env }}"
      when: deployment_env == 'green'

    - name: Clear Laravel caches
      shell: |
        cd "/var/www/poc-web-{{ deployment_env }}"
        php artisan config:clear
        php artisan cache:clear
        php artisan view:clear
        php artisan route:clear
      become_user: apache

    - name: Run database migrations
      shell: |
        cd "/var/www/poc-web-{{ deployment_env }}"
        php artisan migrate --force
      become_user: apache
      when: deployment_env == 'green'

    - name: Optimize Laravel
      shell: |
        cd "/var/www/poc-web-{{ deployment_env }}"
        php artisan config:cache
        php artisan route:cache
        php artisan view:cache
      become_user: apache

    - name: Update Apache DocumentRoot for Green
      lineinfile:
        path: /etc/httpd/conf/httpd.conf
        regexp: '^DocumentRoot'
        line: 'DocumentRoot "/var/www/poc-web-{{ deployment_env }}/public"'
      when: deployment_env == 'green'
      notify: restart httpd

    - name: Test application connectivity
      uri:
        url: "http://{{ ansible_default_ipv4.address }}/health"
        method: GET
        status_code: 200
      register: app_health

    - name: "=== DEPLOYMENT VERIFICATION ==="
      debug:
        msg: |
          ✅ アプリケーションデプロイ完了
          
          Version: {{ app_version }}
          Environment: {{ deployment_env }}
          Health Status: {{ app_health.status }}
          Response Time: {{ app_health.elapsed }}秒

  handlers:
    - name: restart httpd
      systemd:
        name: httpd
        state: restarted
EOF
```

**ステップ3: Green環境へのアプリデプロイ**
```bash
# Green環境に新バージョンデプロイ
ansible-playbook -i inventory/poc immutable-app-deployment.yml \
  -e "app_version=v2.1.0 deployment_env=green git_branch=release/v2.1.0"

# Green環境動作確認
ansible all -i inventory/poc -m shell -a "curl -s http://localhost/health | jq ."
```

**ステップ4: 段階的トラフィック切り替え**
```bash
# 5%のトラフィックをGreen環境に
ansible-playbook -i inventory/poc blue-green-deployment.yml \
  -e "deployment_mode=switch target_environment=green traffic_percentage=5"

# 5分間監視
echo "5分間の監視開始..."
for i in {1..30}; do
    curl -s http://pochub-001/health | jq -r '.status // "ERROR"'
    sleep 10
done

# 25%に増加
ansible-playbook -i inventory/poc blue-green-deployment.yml \
  -e "deployment_mode=switch target_environment=green traffic_percentage=25"

# 50%に増加
ansible-playbook -i inventory/poc blue-green-deployment.yml \
  -e "deployment_mode=switch target_environment=green traffic_percentage=50"

# 100%完全切り替え
ansible-playbook -i inventory/poc blue-green-deployment.yml \
  -e "deployment_mode=switch target_environment=green traffic_percentage=100"
```

### 2.2 アプリケーションロールバック

#### 検証手順

**ステップ1: 問題発生シミュレーション**
```bash
# Green環境で意図的にアプリケーションエラーを発生
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web-green && chmod 000 storage/logs/laravel.log" --become
```

**ステップ2: エラー監視確認**
```bash
# CloudWatch Laravel エラーメトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace "Laravel/poc" \
  --metric-name "ErrorCount" \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum

# アプリケーションエラー確認
ansible all -i inventory/poc -m shell -a "curl -s -o /dev/null -w '%{http_code}' http://localhost/health"
```

**ステップ3: 自動ロールバック実行**
```bash
# Blue環境への緊急ロールバック
ansible-playbook -i inventory/poc blue-green-deployment.yml \
  -e "deployment_mode=rollback"

# ロールバック確認
ansible all -i inventory/poc -m shell -a "curl -s http://localhost/health"
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan --version"
```

---

## 💥 シナリオ3: 障害対応検証

### 目的
各種障害シナリオでの自動復旧・継続サービス提供の検証

### 3.1 EC2インスタンス障害

#### 検証手順

**ステップ1: インスタンス障害シミュレーション**
```bash
# pochub-002 インスタンスを意図的に停止
aws ec2 stop-instances \
  --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-002" --query 'Reservations[0].Instances[0].InstanceId' --output text) \
  --region ap-northeast-1

# 停止確認
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=pochub-002" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output table
```

**ステップ2: 自動検出・アラート確認**
```bash
# CloudWatch アラーム確認
aws cloudwatch describe-alarms \
  --alarm-names "poc-EC2-pochub-002-StatusCheck" \
  --region ap-northeast-1

# ProxySQL自動除外確認
ansible pochub-001:pochub-003 -i inventory/poc -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e 'SELECT hostgroup_id,hostname,port,status FROM mysql_servers;'"
```

**ステップ3: サービス継続性確認**
```bash
# 残りインスタンスでのサービス継続確認
for i in {1..10}; do
    curl -s http://pochub-001/health | jq -r '.status // "ERROR"'
    curl -s http://pochub-003/health | jq -r '.status // "ERROR"'
    sleep 5
done
```

**ステップ4: インスタンス自動復旧**
```bash
# Auto Scaling Group による自動復旧確認（設定済みの場合）
# または手動でインスタンス再起動
aws ec2 start-instances \
  --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-002" --query 'Reservations[0].Instances[0].InstanceId' --output text) \
  --region ap-northeast-1

# 復旧確認
sleep 120  # 起動待機
ansible pochub-002 -i inventory/poc -m shell -a "systemctl status httpd php-fpm proxysql"
```

### 3.2 Aurora障害対応

#### 検証手順

**ステップ1: Aurora Writer障害シミュレーション**
```bash
# Aurora Writer インスタンスの強制フェイルオーバー
aws rds failover-db-cluster \
  --db-cluster-identifier poc-aurora-mysql \
  --region ap-northeast-1

# フェイルオーバー状況監視
watch "aws rds describe-db-clusters --db-cluster-identifier poc-aurora-mysql --query 'DBClusters[0].{Status:Status,Writer:Endpoint}' --output table"
```

**ステップ2: ProxySQL自動対応確認**
```bash
# ProxySQL接続プール状況確認
ansible all -i inventory/poc -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e 'SELECT hostgroup,srv_host,srv_port,status,ConnUsed,ConnFree,ConnERR FROM stats_mysql_connection_pool;'"

# アプリケーション継続性確認
for i in {1..20}; do
    echo "$(date): $(curl -s http://pochub-001/health | jq -r '.database.status // "ERROR"')"
    sleep 5
done
```

### 3.3 ProxySQL障害対応

#### 検証手順

**ステップ1: ProxySQL障害シミュレーション**
```bash
# pochub-001のProxySQLサービス停止
ansible pochub-001 -i inventory/poc -m shell -a "systemctl stop proxysql" --become

# 障害検出確認
ansible pochub-001 -i inventory/poc -m shell -a "curl -s -o /dev/null -w '%{http_code}' http://localhost/health"
```

**ステップ2: アプリケーション自動復旧確認**
```bash
# Laravel の自動接続復旧確認
ansible pochub-001 -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan tinker --execute='DB::connection()->getPdo(); echo \"DB Connected\";'"

# 他インスタンスでの正常動作確認
ansible pochub-002:pochub-003 -i inventory/poc -m shell -a "curl -s http://localhost/health | jq -r '.status'"
```

**ステップ3: ProxySQL自動復旧**
```bash
# ProxySQL サービス自動復旧
ansible pochub-001 -i inventory/poc -m shell -a "systemctl start proxysql" --become

# 復旧確認
sleep 30
ansible pochub-001 -i inventory/poc -m shell -a "mysql -h127.0.0.1 -P6033 -upoc_user -p'password' -e 'SELECT @@hostname;'"
```

---

## ⚡ シナリオ4: スケーリング検証

### 目的
水平・垂直スケーリング機能の検証

### 4.1 水平スケーリング

#### 検証手順

**ステップ1: 現在のリソース状況確認**
```bash
# 現在のインスタンス数確認
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=pochub-*" "Name=instance-state-name,Values=running" \
  --query 'length(Reservations[].Instances[])'

# CPU・メモリ使用率確認
ansible all -i inventory/poc -m shell -a "top -bn1 | grep 'Cpu(s)'"
ansible all -i inventory/poc -m shell -a "free -m"
```

**ステップ2: 負荷生成でスケーリング需要作成**
```bash
# 負荷生成スクリプト作成
cat > /tmp/load-generator.sh << 'EOF'
#!/bin/bash
# 水平スケーリング検証用負荷生成

for i in {1..1000}; do
    curl -s http://pochub-001/health >/dev/null &
    curl -s http://pochub-002/health >/dev/null &
    curl -s http://pochub-003/health >/dev/null &
    sleep 0.1
done
wait
EOF

chmod +x /tmp/load-generator.sh

# 負荷生成実行
/tmp/load-generator.sh &
LOAD_PID=$!
```

**ステップ3: 新インスタンス追加**
```bash
# スケールアウト用新インスタンス作成（CloudFormation）
cd /home/tomo/poc/sceptre

# スケールアウト設定テンプレート作成（必要に応じて）
# 新インスタンス起動後、ProxySQL設定追加
```

### 4.2 垂直スケーリング

#### 検証手順

**ステップ1: 現在のインスタンスタイプ確認**
```bash
# インスタンスタイプ確認
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=pochub-*" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceType]' \
  --output table
```

**ステップ2: Green環境での垂直スケーリング**
```bash
# より大きなインスタンスタイプでGreen環境作成
# t3.medium → t3.large への変更例

# Blue/Green切り替えでインスタンスタイプ変更
# （実際の環境では新しいAMIで新インスタンス作成）
```

---

## 🔒 シナリオ5: セキュリティ検証

### 目的
セキュリティパッチ適用・アクセス制御の検証

### 5.1 セキュリティパッチ適用

#### 検証手順

**ステップ1: 脆弱性スキャン**
```bash
# セキュリティスキャンプレイブック作成
cat > security-scan.yml << 'EOF'
---
- name: Security Vulnerability Scan
  hosts: all
  become: yes
  tasks:
    - name: Check for security updates
      dnf:
        list: updates
        security: yes
      register: security_updates

    - name: Scan for known vulnerabilities
      shell: |
        dnf updateinfo list security
        rpm -qa | xargs -I {} rpm -q --changelog {} | grep -i security | head -10
      register: vuln_scan

    - name: Display security findings
      debug:
        msg: |
          Security Updates Available: {{ security_updates.results | length }}
          Vulnerabilities Found: {{ vuln_scan.stdout_lines | length }}
EOF

ansible-playbook -i inventory/poc security-scan.yml
```

**ステップ2: セキュリティパッチ適用**
```bash
# セキュリティパッチのみ適用
ansible-playbook -i inventory/poc immutable-patch-deployment.yml \
  -e "deployment_mode=security_patch patch_type=security"
```

### 5.2 アクセス制御検証

#### 検証手順

**ステップ1: ネットワークアクセス制御確認**
```bash
# セキュリティグループ確認
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*poc*" \
  --query 'SecurityGroups[].[GroupName,IpPermissions[]]'

# ProxySQL管理ポートのアクセス制限確認
ansible all -i inventory/poc -m shell -a "netstat -tulpn | grep :6032"
```

**ステップ2: データベースアクセス制御確認**
```bash
# Aurora接続セキュリティ確認
ansible all -i inventory/poc -m shell -a "mysql -h127.0.0.1 -P6033 -upoc_user -p'password' -e 'SHOW GRANTS FOR CURRENT_USER();'"
```

---

## 📈 シナリオ6: パフォーマンス検証

### 目的
負荷に対するスケーラビリティ・パフォーマンスの検証

### 6.1 負荷テスト

#### 検証手順

**ステップ1: ベースライン性能測定**
```bash
# パフォーマンステストツール設定
dnf install -y wrk

# ベースライン測定
wrk -t12 -c400 -d30s http://pochub-001/health
```

**ステップ2: ProxySQL負荷分散確認**
```bash
# 負荷テスト中のProxySQL統計確認
while true; do
    ansible all -i inventory/poc -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e 'SELECT hostgroup,srv_host,Queries,Bytes_data_sent FROM stats_mysql_connection_pool;'"
    sleep 10
done
```

### 6.2 レスポンス性能検証

#### 検証手順

**ステップ1: レスポンス時間測定**
```bash
# レスポンス時間継続監視
cat > /tmp/response-time-monitor.sh << 'EOF'
#!/bin/bash
echo "=== Response Time Monitoring ==="
echo "Timestamp,Endpoint,ResponseTime(ms),StatusCode"

for i in {1..100}; do
    for endpoint in pochub-001 pochub-002 pochub-003; do
        RESPONSE=$(curl -s -w "%{time_total},%{http_code}" -o /dev/null http://$endpoint/health)
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        echo "$TIMESTAMP,$endpoint,$RESPONSE"
    done
    sleep 5
done
EOF

chmod +x /tmp/response-time-monitor.sh
/tmp/response-time-monitor.sh > /tmp/response-times.csv
```

---

## 🔄 シナリオ7: バックアップ・復元検証

### 目的
データ保護・復旧機能の検証

### 7.1 データバックアップ

#### 検証手順

**ステップ1: Aurora自動バックアップ確認**
```bash
# Aurora バックアップ設定確認
aws rds describe-db-clusters \
  --db-cluster-identifier poc-aurora-mysql \
  --query 'DBClusters[0].{BackupRetentionPeriod:BackupRetentionPeriod,PreferredBackupWindow:PreferredBackupWindow}' \
  --region ap-northeast-1
```

**ステップ2: アプリケーションデータバックアップ**
```bash
# アプリケーション設定バックアップ
ansible all -i inventory/poc -m shell -a "tar -czf /tmp/app-backup-$(date +%Y%m%d-%H%M%S).tar.gz /var/www/poc-web/.env /etc/httpd/conf/ /etc/proxysql.cnf" --become
```

### 7.2 ポイントインタイム復元

#### 検証手順

**ステップ1: 復元ポイント作成**
```bash
# テストデータ挿入
ansible pochub-001 -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan tinker --execute='DB::table(\"test_backup\")->insert([\"data\" => \"backup_test_\" . now(), \"created_at\" => now()]);'"

# 復元ポイント記録
RESTORE_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
echo "Restore Point: $RESTORE_TIME"
```

**ステップ2: ポイントインタイム復元実行**
```bash
# Aurora Point-in-Time復元（テスト環境で実行）
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier poc-aurora-mysql \
  --db-cluster-identifier poc-aurora-mysql-restored \
  --restore-to-time "$RESTORE_TIME" \
  --region ap-northeast-1

# 復元確認
aws rds describe-db-clusters \
  --db-cluster-identifier poc-aurora-mysql-restored \
  --query 'DBClusters[0].Status' \
  --region ap-northeast-1
```

---

## 📝 検証結果記録

### 検証結果記録テンプレート

```bash
# 包括的検証結果記録スクリプト作成
cat > /tmp/verification-report.sh << 'EOF'
#!/bin/bash
# Immutable Infrastructure 検証結果レポート生成

REPORT_FILE="/tmp/immutable-verification-report-$(date +%Y%m%d-%H%M%S).md"

cat > $REPORT_FILE << 'REPORT_EOF'
# Immutable Infrastructure 検証結果レポート

## 実行概要
- 検証日時: $(date)
- 検証担当者: [担当者名]
- 環境: POC Immutable Infrastructure

## 検証結果サマリー

| シナリオ | 結果 | 所要時間 | 備考 |
|---------|------|----------|------|
| 1. パッチ適用自動化 | ✅ PASS | XX分 | 無停止でパッチ適用完了 |
| 2. アプリデプロイ | ✅ PASS | XX分 | Blue/Green切り替え成功 |
| 3. 障害対応 | ✅ PASS | XX分 | 自動復旧動作確認 |
| 4. スケーリング | ✅ PASS | XX分 | 水平・垂直スケーリング OK |
| 5. セキュリティ | ✅ PASS | XX分 | セキュリティパッチ適用 OK |
| 6. パフォーマンス | ✅ PASS | XX分 | 負荷テスト基準クリア |
| 7. バックアップ・復元 | ✅ PASS | XX分 | データ保護・復旧 OK |

## 詳細結果

### 1. パッチ適用自動化
- セキュリティパッチ適用: ✅ 成功
- サービス継続性: ✅ 無停止
- ロールバック機能: ✅ 1秒以内復旧

### 2. Blue/Greenデプロイメント
- 段階的切り替え: ✅ 5% → 25% → 50% → 100%
- アプリケーション無停止: ✅ ダウンタイム0秒
- ロールバック: ✅ 即座復旧

### 3. 障害対応
- EC2障害: ✅ 自動検出・除外
- Aurora障害: ✅ 自動フェイルオーバー
- ProxySQL障害: ✅ 自動復旧

## 推奨事項
1. [推奨事項1]
2. [推奨事項2]
3. [推奨事項3]

## 次回検証事項
1. [次回検証1]
2. [次回検証2]

REPORT_EOF

echo "検証結果レポート生成: $REPORT_FILE"
EOF

chmod +x /tmp/verification-report.sh
```

---

## 🏆 成功基準

### 各シナリオの成功基準

| シナリオ | 成功基準 |
|---------|---------|
| **パッチ適用** | ダウンタイム < 5秒、ロールバック < 1秒 |
| **アプリデプロイ** | ダウンタイム = 0秒、段階的切り替え成功 |
| **障害対応** | RTO < 5分、RPO < 1分 |
| **スケーリング** | 水平: 10分以内、垂直: Blue/Green切り替え |
| **セキュリティ** | 全セキュリティパッチ適用、アクセス制御正常 |
| **パフォーマンス** | レスポンス時間 < 200ms、エラー率 < 0.1% |
| **バックアップ・復元** | PITR成功、データ損失なし |

### 全体成功基準
- **可用性**: 99.9%以上
- **パフォーマンス**: レスポンス時間平均 < 200ms
- **自動化率**: 95%以上の操作が自動化
- **セキュリティ**: 脆弱性0件
- **運用性**: 管理作業時間50%削減

---

## 📚 関連ドキュメント

### 内部ドキュメント
- [POCImmutable環境構築手順.md](./POCImmutable環境構築手順.md) - 環境構築手順
- [POC環境構築手順.md](./POC環境構築手順.md) - 基盤環境構築
- [テンプレート構成.md](./テンプレート構成.md) - CloudFormation構成
- [ベストプラクティス.md](./ベストプラクティス.md) - 運用ベストプラクティス

### 外部リファレンス
- [AWS Blue/Green Deployments](https://docs.aws.amazon.com/whitepapers/latest/blue-green-deployments/welcome.html)
- [ProxySQL Documentation](https://proxysql.com/documentation/)
- [Aurora MySQL User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [CloudWatch Monitoring](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/)
- [Immutable環境改善ガイド](./Immutable環境改善ガイド.md) - 真のImmutable環境構築ガイド

### 検証ツール・スクリプト場所
- **Ansible Playbooks**: `/home/tomo/ansible-playbooks/`
- **検証スクリプト**: `/tmp/`
- **結果ログ**: `/tmp/verification-*`
- **設定バックアップ**: `/tmp/backup-*`

---

## 🚀 シナリオ9: Immutable環境理想形検証（将来実装）

**⚠️ 注意: このシナリオは現在のPOC環境では未実装です。将来の改善時に実施してください。**

### 概要

現在のPOC環境は、EC2起動後にAnsibleで設定を追加する「Mutable」な構成になっています。
このセクションでは、真のImmutable Infrastructure（ゴールデンイメージ + Blue/Green）を実現するための検証項目を定義します。

詳細は **[Immutable環境改善ガイド](./Immutable環境改善ガイド.md)** を参照してください。

---

### 9.1 ゴールデンイメージ（AMI）検証

**目的**: AMIから起動したインスタンスが追加設定なしで稼働するか検証

#### 前提条件
- ゴールデンイメージ（AMI）が作成済み
- AMIには以下がすべて含まれている：
  - Laravel アプリケーション
  - Apache, PHP, ProxySQL
  - CloudWatch Agent
  - すべての設定ファイル

#### 検証手順

```bash
# 1. AMIから新規インスタンス起動
GOLDEN_AMI_ID="ami-xxxxx"  # ゴールデンイメージのAMI ID
SUBNET_ID="subnet-xxxxx"   # プライベートサブネット
SG_ID="sg-xxxxx"           # セキュリティグループ

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $GOLDEN_AMI_ID \
  --instance-type t3.medium \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --iam-instance-profile Name=poc-ec2-instance-profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=poc-ami-test},{Key=Environment,Value=poc-test}]' \
  --region ap-northeast-1 \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched instance: $INSTANCE_ID"

# 2. インスタンス起動完了待機
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region ap-northeast-1

# 3. Status Check完了待機（5分程度）
echo "Waiting for status checks..."
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID --region ap-northeast-1

# 4. SSM接続確認
echo "Testing SSM connectivity..."
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["echo SSM connection successful"]' \
  --region ap-northeast-1

# 5. サービス起動確認
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl status apache","systemctl status proxysql","systemctl status amazon-cloudwatch-agent"]' \
  --region ap-northeast-1 \
  --output text

# 6. Webアプリケーション動作確認
PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text \
  --region ap-northeast-1)

echo "Testing web application at $PRIVATE_IP..."
# 踏み台経由またはVPN経由でアクセス
curl -s http://$PRIVATE_IP/health

# 7. 起動時間計測
LAUNCH_TIME=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].LaunchTime' \
  --output text \
  --region ap-northeast-1)

echo "Instance launched at: $LAUNCH_TIME"
echo "Time to operational: measure from launch to first successful health check"
```

#### 期待結果

| 項目 | 期待値 |
|------|--------|
| 起動時間 | 5分以内 |
| Ansible実行 | **不要** |
| Apache起動 | 自動起動（enabled） |
| ProxySQL起動 | 自動起動（enabled） |
| CloudWatch Agent起動 | 自動起動（enabled） |
| /health エンドポイント | HTTP 200 |
| アプリケーションログ | エラーなし |

#### クリーンアップ

```bash
# テスト用インスタンス削除
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region ap-northeast-1
echo "Test instance terminated: $INSTANCE_ID"
```

---

### 9.2 Auto Scaling自動復旧検証

**目的**: インスタンス障害時にASGが自動で復旧するか検証

#### 前提条件
- Auto Scaling Group設定済み
- Desired Capacity = 3
- Launch TemplateにゴールデンイメージAMI設定済み

#### 検証手順

```bash
# 1. 現在のASG状態確認
ASG_NAME="poc-web-asg"

aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region ap-northeast-1 \
  --query 'AutoScalingGroups[0].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Current:Instances[].InstanceId}' \
  --output table

# 2. 監視開始（別ターミナルで実行）
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names poc-web-asg \
  --region ap-northeast-1 \
  --query "AutoScalingGroups[0].{Desired:DesiredCapacity,InService:Instances[?LifecycleState==\`InService\`]|length(@)}"'

# 3. 1台を強制終了
TARGET_INSTANCE=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region ap-northeast-1 \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

echo "Terminating instance: $TARGET_INSTANCE"
TERMINATION_TIME=$(date +%s)

aws ec2 terminate-instances \
  --instance-ids $TARGET_INSTANCE \
  --region ap-northeast-1

# 4. 新インスタンス起動監視
echo "Waiting for new instance to launch..."
sleep 60

NEW_INSTANCE=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region ap-northeast-1 \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`Pending` || LifecycleState==`InService`] | [?InstanceId!=`'$TARGET_INSTANCE'`].InstanceId' \
  --output text | head -n 1)

echo "New instance: $NEW_INSTANCE"

# 5. 新インスタンスの起動完了待機
aws ec2 wait instance-status-ok --instance-ids $NEW_INSTANCE --region ap-northeast-1
RECOVERY_TIME=$(date +%s)

RECOVERY_DURATION=$((RECOVERY_TIME - TERMINATION_TIME))
echo "Recovery completed in $RECOVERY_DURATION seconds"

# 6. ALBヘルスチェック確認
TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:ap-northeast-1:xxx:targetgroup/poc-web/xxx"

aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN \
  --region ap-northeast-1 \
  --query "TargetHealthDescriptions[?Target.Id=='$NEW_INSTANCE'].{Instance:Target.Id,State:TargetHealth.State}" \
  --output table
```

#### 期待結果

| 項目 | 期待値 |
|------|--------|
| 検知時間 | 1分以内 |
| 新インスタンス起動 | 2分以内 |
| 起動完了（Status OK） | 5分以内 |
| ALB Healthy | 7分以内 |
| **合計復旧時間** | **10分以内** |
| 最終インスタンス数 | 3台（元通り） |
| サービス停止 | なし（残り2台で継続） |

---

### 9.3 Blue/Green デプロイメント検証

**目的**: ダウンタイムゼロで新バージョンをデプロイできるか検証

#### 前提条件
- Blue/Green用の2つのASG設定済み（Blue: 運用中、Green: 停止）
- 2つのターゲットグループ設定済み
- ALBリスナーはBlueを参照
- 新バージョンのゴールデンイメージAMI作成済み

#### 検証手順

```bash
# 環境変数設定
BLUE_ASG="poc-web-blue-asg"
GREEN_ASG="poc-web-green-asg"
BLUE_TG="arn:aws:elasticloadbalancing:ap-northeast-1:xxx:targetgroup/poc-blue/xxx"
GREEN_TG="arn:aws:elasticloadbalancing:ap-northeast-1:xxx:targetgroup/poc-green/xxx"
LISTENER_ARN="arn:aws:elasticloadbalancing:ap-northeast-1:xxx:listener/app/poc-alb/xxx"
NEW_AMI="ami-new-version"

# 1. 継続的アクセステスト開始（別ターミナル）
ALB_DNS="poc-alb-xxxxx.ap-northeast-1.elb.amazonaws.com"

# アクセスログ記録
while true; do
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" http://$ALB_DNS/health)
  echo "$(date +%Y-%m-%d\ %H:%M:%S),$RESPONSE" >> /tmp/blue-green-access.log
  sleep 1
done

# 2. Green環境起動
echo "Step 1: Launching Green environment..."
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name $GREEN_ASG \
  --desired-capacity 3 \
  --region ap-northeast-1

# 3. Green環境起動完了待機（15分程度）
echo "Step 2: Waiting for Green instances to be healthy..."
for i in {1..30}; do
  HEALTHY_COUNT=$(aws elbv2 describe-target-health \
    --target-group-arn $GREEN_TG \
    --region ap-northeast-1 \
    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
    --output text)
  
  echo "Healthy instances in Green: $HEALTHY_COUNT / 3"
  
  if [ "$HEALTHY_COUNT" -eq 3 ]; then
    echo "✅ All Green instances are healthy"
    break
  fi
  
  sleep 30
done

# 4. Green環境で動作確認
echo "Step 3: Verifying Green environment..."
GREEN_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $GREEN_ASG \
  --region ap-northeast-1 \
  --query 'AutoScalingGroups[0].Instances[].InstanceId' \
  --output text)

for INSTANCE in $GREEN_INSTANCES; do
  echo "Testing instance: $INSTANCE"
  
  PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text \
    --region ap-northeast-1)
  
  # ProxySQL接続確認
  aws ssm send-command \
    --instance-ids $INSTANCE \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["mysql -h127.0.0.1 -P6033 -ularavel_user -pLaravel123! -e \"SELECT 1\""]' \
    --region ap-northeast-1
done

# 5. トラフィック切替（段階的）
echo "Step 4: Switching traffic to Green..."

# 10% → Green
echo "Switching 10% traffic to Green..."
aws elbv2 modify-rule \
  --rule-arn $LISTENER_ARN \
  --actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$BLUE_TG'","Weight":90},
      {"TargetGroupArn":"'$GREEN_TG'","Weight":10}
    ]
  }' \
  --region ap-northeast-1

sleep 300  # 5分監視

# 50% → Green
echo "Switching 50% traffic to Green..."
aws elbv2 modify-rule \
  --rule-arn $LISTENER_ARN \
  --actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$BLUE_TG'","Weight":50},
      {"TargetGroupArn":"'$GREEN_TG'","Weight":50}
    ]
  }' \
  --region ap-northeast-1

sleep 300

# 100% → Green
echo "Switching 100% traffic to Green..."
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,TargetGroupArn=$GREEN_TG \
  --region ap-northeast-1

echo "✅ Traffic switched to Green"

# 6. アクセスログ分析
echo "Step 5: Analyzing access logs..."
cat /tmp/blue-green-access.log | awk -F',' '{
  if ($2 != 200) errors++;
  total++;
  sum_time += $3;
} END {
  print "Total requests:", total;
  print "Errors:", errors;
  print "Success rate:", (total-errors)/total*100 "%";
  print "Avg response time:", sum_time/total "s";
}'

# 7. Blue環境削除（問題なければ）
echo "Step 6: Terminating Blue environment..."
read -p "Remove Blue environment? (yes/no): " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name $BLUE_ASG \
    --desired-capacity 0 \
    --region ap-northeast-1
  echo "✅ Blue environment terminated"
fi
```

#### 期待結果

| 項目 | 期待値 |
|------|--------|
| Green環境起動時間 | 15分以内 |
| トラフィック切替時間 | 15分（段階的） |
| **合計デプロイ時間** | **30分** |
| HTTPエラー | **0件** |
| リクエスト失敗率 | **0%** |
| レスポンスタイム変動 | ±10%以内 |
| ダウンタイム | **ゼロ** |

---

### 9.4 ロールバック検証

**目的**: 問題発生時に即座に旧バージョンに戻せるか検証

#### 検証手順

```bash
# Green環境で問題発見（想定）
echo "Problem detected in Green environment!"
echo "Initiating rollback to Blue..."

START_TIME=$(date +%s)

# トラフィックをBlueに戻す
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,TargetGroupArn=$BLUE_TG \
  --region ap-northeast-1

END_TIME=$(date +%s)
ROLLBACK_TIME=$((END_TIME - START_TIME))

echo "✅ Rollback completed in $ROLLBACK_TIME seconds"

# Green環境削除
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name $GREEN_ASG \
  --desired-capacity 0 \
  --region ap-northeast-1

echo "Green environment terminated"
```

#### 期待結果

| 項目 | 期待値 |
|------|--------|
| ロールバック時間 | **60秒以内** |
| データ損失 | なし |
| サービス停止 | なし |

---

### 9.5 検証結果サマリー

#### 現在のPOC環境（Mutable）

| 項目 | 現状値 |
|------|--------|
| 新インスタンスデプロイ | 30-35分（Ansible実行含む） |
| スケールアウト | 35分/台 |
| 障害復旧 | 30-40分 |
| ロールバック | 30-35分 |
| 構成の一貫性 | 低（ドリフト発生） |

#### 理想形（Immutable）

| 項目 | 目標値 |
|------|--------|
| 新インスタンスデプロイ | **5分** |
| スケールアウト | **5分/台** |
| 障害復旧 | **10分** |
| ロールバック | **60秒** |
| 構成の一貫性 | **100%（ドリフトなし）** |

---

### 改善実装時のチェックリスト

実際にImmutable環境を構築する際は、以下の順序で進めてください：

- [ ] **Phase 1: ゴールデンイメージ作成**
  - [ ] 現在のEC2インスタンスからAMI作成
  - [ ] AMI検証（9.1実施）
  - [ ] AMIタグ付け・バージョニング

- [ ] **Phase 2: Launch Template更新**
  - [ ] 新AMIでLaunch Template作成
  - [ ] UserDataを最小化（動的設定のみ）
  - [ ] Instance Profile設定確認

- [ ] **Phase 3: Auto Scaling動作確認**
  - [ ] ASGで新Launch Template使用
  - [ ] インスタンスリフレッシュ実行
  - [ ] 自動復旧検証（9.2実施）

- [ ] **Phase 4: Blue/Green環境構築**
  - [ ] Blue/Green用CloudFormationテンプレート作成
  - [ ] 2つのASG + 2つのTarget Group作成
  - [ ] Blue/Green切替検証（9.3実施）
  - [ ] ロールバック検証（9.4実施）

- [ ] **Phase 5: CI/CDパイプライン**
  - [ ] Packer / EC2 Image Builderでのビルド自動化
  - [ ] デプロイパイプライン構築
  - [ ] 自動テスト統合

詳細な実装手順は **[Immutable環境改善ガイド](./Immutable環境改善ガイド.md)** を参照してください。

---

**Document Version**: v2.0  
**Last Updated**: 2025年10月18日  
**Environment**: POC Immutable Infrastructure Verification  
**Total Verification Time**: ~5.5時間（並行実行で短縮可能） + Immutable環境検証（将来実装時: +3時間）
