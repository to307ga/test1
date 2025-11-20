# ログstdout化の実装方式比較・検討ドキュメント

## 目次

- [ログstdout化の実装方式比較・検討ドキュメント](#ログstdout化の実装方式比較検討ドキュメント)
  - [目次](#目次)
  - [1. 背景と目的](#1-背景と目的)
    - [1.1 現状の課題](#11-現状の課題)
    - [1.2 stdout化の目的](#12-stdout化の目的)
    - [1.3 作成済みファイル](#13-作成済みファイル)
  - [2. 実装方式の選択肢](#2-実装方式の選択肢)
    - [2.1 方式A: 全ログ集約 + CloudWatch Logs Insights分析](#21-方式a-全ログ集約--cloudwatch-logs-insights分析)
      - [2.1.1 方式A-1: メタデータなし（基本版）](#211-方式a-1-メタデータなし基本版)
      - [2.1.2 方式A-2: CloudWatch Agent メタデータ付与（パターンマッチ）](#212-方式a-2-cloudwatch-agent-メタデータ付与パターンマッチ)
      - [2.1.3 方式A-3: ログフォーマット識別子 + CloudWatch Agent メタデータ【最推奨】](#213-方式a-3-ログフォーマット識別子--cloudwatch-agent-メタデータ最推奨)
    - [方式A-3: ログフォーマット識別子付与の実装詳細](#方式a-3-ログフォーマット識別子付与の実装詳細)
      - [Apache実装例](#apache実装例)
      - [Tomcat実装例](#tomcat実装例)
      - [Node.js (Express) 実装例](#nodejs-express-実装例)
    - [方式A-2 vs 方式A-3 の比較](#方式a-2-vs-方式a-3-の比較)
    - [2.2 方式B: Subscription Filter + Lambda振り分け【ロググループ分離】](#22-方式b-subscription-filter--lambda振り分けロググループ分離)
    - [2.3 方式C: rsyslog経由ファイル化 + CloudWatch Agent【非推奨】](#23-方式c-rsyslog経由ファイル化--cloudwatch-agent非推奨)
    - [2.4 方式D: 複数CloudWatch Agent設定 + journaldフィルタ【限定的】](#24-方式d-複数cloudwatch-agent設定--journaldフィルタ限定的)
  - [3. 詳細比較](#3-詳細比較)
    - [3.1 比較表](#31-比較表)
    - [3.2 コスト比較](#32-コスト比較)
    - [3.3 運用負荷比較](#33-運用負荷比較)
  - [4. 各方式の実装詳細](#4-各方式の実装詳細)
    - [4.1 方式A: 全ログ集約実装](#41-方式a-全ログ集約実装)
      - [4.1.1 必要なファイル](#411-必要なファイル)
      - [4.1.2 CloudWatch Agent設定](#412-cloudwatch-agent設定)
      - [4.1.3 CloudWatch Logs Insightsクエリ集](#413-cloudwatch-logs-insightsクエリ集)
      - [4.1.4 メトリクスフィルタ設定](#414-メトリクスフィルタ設定)
      - [4.1.5 CloudWatch Alarmsアラート設定](#415-cloudwatch-alarmsアラート設定)
    - [4.2 方式B: Subscription Filter + Lambda実装](#42-方式b-subscription-filter--lambda実装)
      - [4.2.1 Lambda関数（Python）](#421-lambda関数python)
      - [4.2.2 Subscription Filter設定](#422-subscription-filter設定)
      - [4.2.3 Lambda IAMロール](#423-lambda-iamロール)
    - [4.3 方式C: rsyslog経由実装](#43-方式c-rsyslog経由実装)
      - [4.3.1 rsyslog設定ファイル](#431-rsyslog設定ファイル)
      - [4.3.2 logrotate設定](#432-logrotate設定)
      - [4.3.3 CloudWatch Agent設定](#433-cloudwatch-agent設定)
    - [4.4 方式D: 複数CloudWatch Agent設定実装](#44-方式d-複数cloudwatch-agent設定実装)
      - [4.4.1 CloudWatch Agent設定](#441-cloudwatch-agent設定)
  - [5. 既存運用への影響](#5-既存運用への影響)
    - [5.1 監視・アラート設定の移行](#51-監視アラート設定の移行)
      - [5.1.1 従来のファイルベース監視](#511-従来のファイルベース監視)
      - [5.1.2 方式A（全ログ集約）への移行](#512-方式a全ログ集約への移行)
      - [5.1.3 方式B（Lambda振り分け）への移行](#513-方式blambda振り分けへの移行)
    - [5.2 ログ分析手順の変更](#52-ログ分析手順の変更)
      - [5.2.1 従来の分析手順](#521-従来の分析手順)
      - [5.2.2 方式A（全ログ集約）での分析手順](#522-方式a全ログ集約での分析手順)
  - [6. 推奨事項と判断基準](#6-推奨事項と判断基準)
    - [6.1 最推奨: 方式A-3（ログフォーマット識別子付与）](#61-最推奨-方式a-3ログフォーマット識別子付与)
    - [6.2 シンプルさ最優先: 方式A-1/A-2（LogFormat変更不可の場合）](#62-シンプルさ最優先-方式a-1a-2logformat変更不可の場合)
    - [6.2 既存運用継続重視](#62-既存運用継続重視)
    - [6.3 バランス重視](#63-バランス重視)
  - [7. 決定事項（明日記入）](#7-決定事項明日記入)
  - [8. 次のステップ（明日のタスク）](#8-次のステップ明日のタスク)
    - [Phase 1: 方式決定（所要時間: 2-3時間）](#phase-1-方式決定所要時間-2-3時間)
    - [Phase 2: 詳細設計（所要時間: 1日）](#phase-2-詳細設計所要時間-1日)
    - [Phase 3: 検証環境での実装（所要時間: 2-3日）](#phase-3-検証環境での実装所要時間-2-3日)
    - [Phase 4: 本番展開計画（所要時間: 1日）](#phase-4-本番展開計画所要時間-1日)
  - [9. ログへの人間可読な識別子付与【追加タスク】](#9-ログへの人間可読な識別子付与追加タスク)
    - [9.1 背景と要件](#91-背景と要件)
    - [9.2 識別子の選択肢](#92-識別子の選択肢)
    - [9.3 実装方式](#93-実装方式)
      - [9.3.1 方式1: Nameタグから取得【推奨】](#931-方式1-nameタグから取得推奨)
      - [9.3.2 方式2: CloudWatch Agentのlog\_stream\_nameでカスタマイズ](#932-方式2-cloudwatch-agentのlog_stream_nameでカスタマイズ)
      - [9.3.3 方式3: journald識別子に追加](#933-方式3-journald識別子に追加)
      - [9.3.4 方式4: Apacheのログフォーマットに直接埋め込み](#934-方式4-apacheのログフォーマットに直接埋め込み)
    - [9.4 CloudWatch Logs表示例](#94-cloudwatch-logs表示例)
      - [9.4.1 方式1（LogFormatに追加）を採用した場合](#941-方式1logformatに追加を採用した場合)
      - [9.4.2 方式2（log\_stream\_name）を採用した場合](#942-方式2log_stream_nameを採用した場合)
    - [9.5 Auto Scaling Groupでの運用](#95-auto-scaling-groupでの運用)
      - [9.5.1 Launch Templateでの設定](#951-launch-templateでの設定)
      - [9.5.2 連番管理の自動化](#952-連番管理の自動化)
    - [9.6 実装チェックリスト](#96-実装チェックリスト)
    - [9.7 推奨実装（まとめ）](#97-推奨実装まとめ)
  - [10. 参考資料](#10-参考資料)
    - [10.1 作成済みファイルの場所](#101-作成済みファイルの場所)
    - [10.2 関連ドキュメント](#102-関連ドキュメント)
    - [10.3 AWS公式ドキュメント](#103-aws公式ドキュメント)
    - [10.4 Apacheドキュメント](#104-apacheドキュメント)

---

## 1. 背景と目的

### 1.1 現状の課題

**現在のログ管理方式（ファイルベース）:**
```
Apache → rotatelogs → ファイル出力
  - /var/log/httpd/access_log.20251119
  - /var/log/httpd/error_log.20251119
  - /var/log/httpd/healthcheck_access_log.20251119

課題:
  ✗ ログローテーション管理が必要
  ✗ ディスク容量管理が必要
  ✗ ファイルパーミッション管理が必要
  ✗ 古いログファイル削除の自動化が必要
```

### 1.2 stdout化の目的

```
目標:
  ✓ ログファイル管理の撤廃
  ✓ ログローテーション不要
  ✓ ディスク容量管理不要
  ✓ journald + CloudWatch Logsでの一元管理
  ✓ コンテナ化への将来対応
```

### 1.3 作成済みファイル

```
1. gooid-21-dev-web-101
   - 元のApache設定（rotatelogs使用）

2. gooid-21-dev-web-101_stdout
   - stdout/stderr化したApache設定
   - ErrorLog → stderr ("|/bin/cat 1>&2")
   - CustomLog → stdout ("|/bin/cat")

3. etc/systemd/system/httpd.service.d/override.conf
   - StandardOutput=journal
   - StandardError=journal
   - SyslogIdentifier=httpd
```

---

## 2. 実装方式の選択肢

### 2.1 方式A: 全ログ集約 + CloudWatch Logs Insights分析

#### 2.1.1 方式A-1: メタデータなし（基本版）

**フロー:**
```
Apache → stdout/stderr 
  → journald 
  → CloudWatch Agent 
  → CloudWatch Logs (/aws/ec2/httpd/all)
  → CloudWatch Logs Insightsで分析時にフィルタリング
```

**特徴:**
- ✅ **最もシンプル**: 設定ファイルが最小限
- ✅ **ファイル管理不要**: 完全にstdout化の目的を達成
- ✅ **運用負荷最小**: ログローテーション等の管理不要
- ⚠️ **分析時にフィルタリング**: CloudWatch Logs Insightsでクエリ実行が必要
- ⚠️ **既存監視設定の変更大**: メトリクスフィルタでパターンマッチが複雑
- ⚠️ **ログ種別の識別が曖昧**: メッセージ内容から判定するため誤判定の可能性

**推奨度:** ⭐⭐⭐⭐（新規構築・将来性重視の場合）

---

#### 2.1.2 方式A-2: CloudWatch Agent メタデータ付与（パターンマッチ）

**フロー:**
```
Apache → stdout/stderr 
  → journald 
  → CloudWatch Agent（メタデータ付与）
  → CloudWatch Logs (/aws/ec2/httpd/all)
      ├── log_type: access （メタデータ）
      ├── log_type: error  （メタデータ）
      └── log_type: healthcheck （メタデータ）
```

**特徴:**
- ✅ **全ログ1つのロググループに集約**: 最もシンプル
- ✅ **メタデータで種別分離**: CloudWatch Logs Insightsで簡単フィルタリング
- ✅ **ファイル管理不要**: stdout化の目的完全達成
- ✅ **Lambda不要**: 追加コンポーネントなし
- ✅ **既存監視設定の移行が容易**: メトリクスフィルタでメタデータ活用
- ✅ **ログ種別の識別が明確**: 正規表現パターンマッチで自動判定
- ⚠️ **パターン設計が重要**: HTTPメソッド + パスで厳密にマッチさせ誤判定を防止
- ⚠️ **誤判定の可能性**: 複雑なURLやログ内容で誤判定リスクあり
- ✅ **コスト最小**: 追加コストなし
- ✅ **リアルタイム性が高い**: Lambda経由の遅延なし
- ✅ **将来のコンテナ化に最適**: 標準的なログ管理手法

**推奨度:** ⭐⭐⭐⭐（パターンマッチの複雑さあり）

---

#### 2.1.3 方式A-3: ログフォーマット識別子 + CloudWatch Agent メタデータ【最推奨】

**フロー:**
```
Apache（LogFormatで識別子付与）
  → stdout/stderr: "[LOG_TYPE:access] ..." または "[LOG_TYPE:healthcheck] ..."
  → journald 
  → CloudWatch Agent（メタデータ付与）
  → CloudWatch Logs (/aws/ec2/httpd/all)
      ├── log_type: access （メタデータ）
      ├── log_type: error  （メタデータ）
      └── log_type: healthcheck （メタデータ）
```

**特徴:**
- ✅ **誤判定ゼロ**: Apache/Tomcatのログフォーマットで明示的に識別子付与
- ✅ **パターンマッチが簡単**: `\[LOG_TYPE:(access|error|healthcheck)\]` で確実にマッチ
- ✅ **アプリケーション側で制御**: ログの種別をアプリケーション層で明示
- ✅ **デバッグが容易**: ログに識別子が含まれるため、トラブルシューティングが簡単
- ✅ **既存LogFormatの拡張**: 既存のログフォーマットに識別子を追加するだけ
- ✅ **Tomcat/他のアプリにも適用可能**: 同じ手法でTomcat, Node.js等にも対応
- ✅ **全ての方式A-2のメリットを継承**: ファイル管理不要、Lambda不要、コスト最小

**推奨度:** ⭐⭐⭐⭐⭐【最推奨・誤判定ゼロ】

**CloudWatch Agent設定例（メタデータ付与）:**

> **⚠️ 重要: パターンマッチの注意点**
> 
> パターンは**上から順に評価**され、**最初にマッチしたパターン**が適用されます。
> より厳密なパターンを先に配置することで誤判定を防ぎます。

```json
{
  "logs": {
    "logs_collected": {
      "journals": {
        "collect_list": [
          {
            "journal_path": "/var/log/journal",
            "unit": "httpd.service",
            "log_group_name": "/aws/ec2/httpd/all",
            "log_stream_name": "{instance_id}",
            "log_metadata": {
              "log_type": {
                "value_from_message": {
                  "patterns": [
                    {
                      "pattern": "\"(GET|POST|HEAD) /heartbeat ",
                      "value": "healthcheck",
                      "comment": "ヘルスチェック: /heartbeat へのHTTPリクエスト"
                    },
                    {
                      "pattern": "\"(GET|POST|HEAD) /status\\.jsp ",
                      "value": "healthcheck",
                      "comment": "ヘルスチェック: /status.jsp へのHTTPリクエスト"
                    },
                    {
                      "pattern": "\\[error\\]",
                      "value": "error",
                      "comment": "Apacheエラーログ: [error]"
                    },
                    {
                      "pattern": "\\[warn\\]",
                      "value": "error",
                      "comment": "Apacheエラーログ: [warn]"
                    }
                  ],
                  "default_value": "access"
                }
              },
              "hostname": {
                "value_from_tag": "Name"
              }
            }
          }
        ]
      }
    }
  }
}
```

**パターンマッチの動作例:**

```yaml
# ケース1: ヘルスチェックリクエスト
ログ: '10.0.1.100 - - [20/Nov/2025:10:30:45 +0900] "GET /heartbeat HTTP/1.1" 200 2'
判定: healthcheck ✓ (パターン1にマッチ)

# ケース2: 通常アクセスログ（"status"という単語を含む）
ログ: '10.0.1.5 - - [20/Nov/2025:10:30:45 +0900] "GET /api/user/status HTTP/1.1" 200 1234'
判定: access ✓ (どのパターンにもマッチせず、default_value)

# ケース3: エラーログ
ログ: '[error] [client 10.0.1.5] File does not exist: /var/www/html/missing.html'
判定: error ✓ (パターン3にマッチ)

# ケース4: 通常アクセスログ
ログ: '10.0.1.5 - - [20/Nov/2025:10:30:45 +0900] "GET /index.html HTTP/1.1" 200 1234'
判定: access ✓ (どのパターンにもマッチせず、default_value)
```

**誤判定を防ぐパターン設計のポイント:**

1. **HTTPメソッドを含める**: `"GET /heartbeat ` (前後にスペースやダブルクォート)
2. **正確なパス指定**: `/heartbeat` と `/api/user/status` を区別
3. **順序を意識**: より厳密なパターンを先に配置
4. **正規表現の境界**: 部分一致を避ける

**改善前の問題例:**

```json
// ❌ 危険なパターン（部分一致）
{
  "pattern": "status",
  "value": "healthcheck"
}

// 誤判定の例:
// "GET /api/user/status HTTP/1.1" → healthcheck と判定されてしまう
// "Database connection status: OK" → healthcheck と判定されてしまう
```

**改善後の安全なパターン:**

```json
// ✅ 安全なパターン（厳密なマッチ）
{
  "pattern": "\"(GET|POST|HEAD) /status\\.jsp ",
  "value": "healthcheck"
}

// 正しく判定:
// "GET /status.jsp HTTP/1.1" → healthcheck ✓
// "GET /api/user/status HTTP/1.1" → access ✓
```

**メタデータ活用例:**
```sql
-- エラーログのみ抽出（メタデータで簡単フィルタ）
fields @timestamp, @message, hostname
| filter log_type = "error"
| sort @timestamp desc

-- ホスト名ごとのエラーカウント
fields @timestamp
| filter log_type = "error"
| stats count() as error_count by hostname
| sort error_count desc
```

**メトリクスフィルタ設定例:**
```yaml
# エラーログカウント（メタデータで正確に抽出）
FilterPattern: '{ $.log_type = "error" }'
MetricName: ErrorCount

# 5xxエラーカウント（アクセスログのみ対象）
FilterPattern: '{ $.log_type = "access" && $.message = "* 5?? *" }'
MetricName: 5xxCount
```

**パターンマッチのテスト方法:**

1. **開発環境でログ出力テスト**
```bash
# さまざまなパターンのログを出力
curl http://localhost/heartbeat
curl http://localhost/status.jsp
curl http://localhost/api/user/status
curl http://localhost/index.html
curl http://localhost/nonexistent  # 404エラー
```

2. **CloudWatch Logsでメタデータ確認**
```sql
fields @timestamp, @message, log_type
| sort @timestamp desc
| limit 100
```

3. **誤判定がないか確認**
```sql
-- /api/user/status が access になっているか確認
fields @timestamp, @message, log_type
| filter @message like "/api/user/status"
| display @message, log_type
```

---

### 方式A-3: ログフォーマット識別子付与の実装詳細

#### Apache実装例

**1. Apache LogFormat設定（識別子付与）**

```apache
# /etc/httpd/conf/httpd.conf または /etc/httpd/conf.d/logging.conf

# 通常アクセスログ用フォーマット（識別子付き）
LogFormat "[LOG_TYPE:access] %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" \"%{GOO_ID}e\"" combined_gooid_access

# ヘルスチェックログ用フォーマット（識別子付き）
LogFormat "[LOG_TYPE:healthcheck] %h %l %u %t \"%r\" %>s %b" healthcheck_format

# エラーログ設定（stderr経由）
ErrorLog "|/bin/cat 1>&2"
# エラーログには自動的に [error] や [warn] が付くため識別子不要

# 通常アクセスログ（ヘルスチェック以外）
SetEnvIf Request_URI "^/heartbeat$" healthcheck_request
SetEnvIf Request_URI "^/status\.jsp$" healthcheck_request
SetEnvIf Request_URI "\.(gif|jpg|jpeg|png|css|js|ico)$" no_record_object

# ヘルスチェックログ出力（識別子: healthcheck）
CustomLog "|/bin/cat" healthcheck_format env=healthcheck_request

# 通常アクセスログ出力（識別子: access）
CustomLog "|/bin/cat" combined_gooid_access env=!healthcheck_request env=!no_record_object
```

**ログ出力例:**
```
# 通常アクセスログ
[LOG_TYPE:access] 10.0.1.5 - - [20/Nov/2025:10:30:45 +0900] "GET /index.html HTTP/1.1" 200 1234 "-" "Mozilla/5.0" "goo123456"

# ヘルスチェックログ
[LOG_TYPE:healthcheck] 10.0.1.100 - - [20/Nov/2025:10:30:46 +0900] "GET /heartbeat HTTP/1.1" 200 2

# エラーログ（自動的に [error] 付与）
[error] [client 10.0.1.5] File does not exist: /var/www/html/missing.html

# /api/user/status へのアクセス（正しく access と判定）
[LOG_TYPE:access] 10.0.1.5 - - [20/Nov/2025:10:30:47 +0900] "GET /api/user/status HTTP/1.1" 200 456 "-" "Mozilla/5.0" "goo123456"
```

**2. CloudWatch Agent設定（識別子ベースのメタデータ）**

```json
{
  "logs": {
    "logs_collected": {
      "journals": {
        "collect_list": [
          {
            "journal_path": "/var/log/journal",
            "unit": "httpd.service",
            "log_group_name": "/aws/ec2/httpd/all",
            "log_stream_name": "{instance_id}",
            "log_metadata": {
              "log_type": {
                "value_from_message": {
                  "patterns": [
                    {
                      "pattern": "\\[LOG_TYPE:healthcheck\\]",
                      "value": "healthcheck"
                    },
                    {
                      "pattern": "\\[LOG_TYPE:access\\]",
                      "value": "access"
                    },
                    {
                      "pattern": "\\[error\\]",
                      "value": "error"
                    },
                    {
                      "pattern": "\\[warn\\]",
                      "value": "error"
                    }
                  ],
                  "default_value": "unknown"
                }
              },
              "hostname": {
                "value_from_tag": "Name"
              }
            }
          }
        ]
      }
    }
  }
}
```

**メリット:**
- ✅ パターンマッチが単純: `\[LOG_TYPE:access\]` で確実
- ✅ 誤判定ゼロ: `/api/user/status` も正しく `access` と判定
- ✅ デバッグが容易: ログファイル見るだけで識別子が分かる

---

#### Tomcat実装例

**1. server.xml設定（AccessLogValve）**

```xml
<!-- /opt/tomcat/conf/server.xml -->

<Host name="localhost" appBase="webapps"
      unpackWARs="true" autoDeploy="true">

  <!-- 通常アクセスログ（ヘルスチェック以外） -->
  <Valve className="org.apache.catalina.valves.AccessLogValve"
         directory="logs"
         prefix="localhost_access_log"
         suffix=".txt"
         pattern="[LOG_TYPE:access] %h %l %u %t &quot;%r&quot; %s %b %{User-Agent}i"
         conditionUnless="healthcheck"
         rotatable="false" />

  <!-- ヘルスチェックログ -->
  <Valve className="org.apache.catalina.valves.AccessLogValve"
         directory="logs"
         prefix="localhost_access_log"
         suffix=".txt"
         pattern="[LOG_TYPE:healthcheck] %h %l %u %t &quot;%r&quot; %s %b"
         conditionIf="healthcheck"
         rotatable="false" />

</Host>
```

**2. アプリケーション側でヘルスチェック判定**

```java
// ヘルスチェックエンドポイント
@GetMapping("/heartbeat")
public ResponseEntity<String> heartbeat(HttpServletRequest request) {
    // リクエスト属性にマークを付ける
    request.setAttribute("org.apache.catalina.AccessLog.RemoteAddr", 
                         request.getRemoteAddr());
    request.setAttribute("healthcheck", "true");
    return ResponseEntity.ok("OK");
}

@GetMapping("/status.jsp")
public ResponseEntity<String> status(HttpServletRequest request) {
    request.setAttribute("healthcheck", "true");
    return ResponseEntity.ok("Status: OK");
}
```

**3. Filter方式（より汎用的）**

```java
@WebFilter(urlPatterns = {"/heartbeat", "/status.jsp"})
public class HealthCheckFilter implements Filter {
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, 
                        FilterChain chain) throws IOException, ServletException {
        request.setAttribute("healthcheck", "true");
        chain.doFilter(request, response);
    }
}
```

**Tomcatログ出力例:**
```
# 通常アクセスログ
[LOG_TYPE:access] 10.0.1.5 - - [20/Nov/2025:10:30:45 +0900] "GET /api/users HTTP/1.1" 200 1234 Mozilla/5.0

# ヘルスチェックログ
[LOG_TYPE:healthcheck] 10.0.1.100 - - [20/Nov/2025:10:30:46 +0900] "GET /heartbeat HTTP/1.1" 200 2

# /api/user/status へのアクセス（正しく access と判定）
[LOG_TYPE:access] 10.0.1.5 - - [20/Nov/2025:10:30:47 +0900] "GET /api/user/status HTTP/1.1" 200 456 Mozilla/5.0
```

---

#### Node.js (Express) 実装例

```javascript
const express = require('express');
const morgan = require('morgan');

const app = express();

// カスタムトークン定義
morgan.token('log-type', (req, res) => {
  if (req.path === '/heartbeat' || req.path === '/status.jsp') {
    return 'healthcheck';
  }
  return 'access';
});

// ログフォーマット（識別子付き）
const logFormat = '[LOG_TYPE::log-type] :remote-addr - :remote-user [:date[clf]] ":method :url HTTP/:http-version" :status :res[content-length]';

app.use(morgan(logFormat));

app.get('/heartbeat', (req, res) => res.send('OK'));
app.get('/api/user/status', (req, res) => res.json({ status: 'active' }));

app.listen(3000);
```

**Node.jsログ出力例:**
```
[LOG_TYPE:access] 10.0.1.5 - - [20/Nov/2025:10:30:45 +0900] "GET /api/user/status HTTP/1.1" 200 456
[LOG_TYPE:healthcheck] 10.0.1.100 - - [20/Nov/2025:10:30:46 +0900] "GET /heartbeat HTTP/1.1" 200 2
```

---

### 方式A-2 vs 方式A-3 の比較

| 項目 | 方式A-2<br/>（パターンマッチ） | 方式A-3<br/>（識別子付与） |
|------|---------------------------|------------------------|
| **誤判定リスク** | あり ⚠️<br/>`/api/user/status` を誤判定の可能性 | なし ✅<br/>識別子で明示的に判定 |
| **パターン複雑度** | 高 ⚠️<br/>正規表現で複雑なマッチング | 低 ✅<br/>単純な文字列マッチ |
| **Apache設定** | 不要 ✅ | LogFormat変更 ⚠️ |
| **デバッグ容易性** | 中 ⚠️<br/>ログからは判別しにくい | 高 ✅<br/>ログに識別子が表示 |
| **メンテナンス性** | 低 ⚠️<br/>新しいURLパターン追加時に再設定 | 高 ✅<br/>LogFormatで一元管理 |
| **Tomcat対応** | 困難 ⚠️<br/>Tomcatログフォーマットが異なる | 容易 ✅<br/>同じ手法で実装可能 |
| **推奨度** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐【最推奨】 |

**結論:** ログフォーマットで識別子を付与する**方式A-3が最も確実で保守性が高い**

---

### 2.2 方式B: Subscription Filter + Lambda振り分け【ロググループ分離】

**フロー:**
```
Apache → stdout/stderr 
  → journald 
  → CloudWatch Agent 
  → CloudWatch Logs (/aws/ec2/httpd/combined)
  → Subscription Filter + Lambda
  → 振り分け先
      - /aws/ec2/httpd/access
      - /aws/ec2/httpd/error
      - /aws/ec2/httpd/healthcheck
```

**特徴:**
- ✅ **ファイル管理不要**: stdout化の目的達成
- ✅ **ロググループが物理的に分離**: 3つの独立したロググループ
- ✅ **既存ロググループ構造を完全維持**: 従来と同じロググループ名
- ✅ **ロググループ単位での権限分離が可能**: チーム別アクセス制御
- ⚠️ **Lambda管理必要**: 追加コンポーネント（運用負荷増）
- ⚠️ **コスト増**: Lambda実行コスト、ログ重複書き込み（約2倍）
- ⚠️ **遅延**: リアルタイム性が若干低下（数秒～数十秒）
- ⚠️ **複雑性増**: CloudWatch Agent + Lambda の2段階構成

**推奨度:** ⭐⭐⭐⭐（ロググループ物理分離が必須の場合）

**方式A-2との比較:**
```yaml
方式A-2の優位点:
  ✓ Lambda不要（シンプル）
  ✓ コスト半額
  ✓ リアルタイム性が高い
  ✓ メタデータで柔軟なフィルタリング可能

方式Bの優位点:
  ✓ ロググループが物理的に分離
  ✓ ロググループ単位での権限制御
  ✓ 既存の3つのロググループ構造を完全維持
```

**採用すべきケース:**
- ロググループ単位での厳密な権限分離が必要
- 複数チームが個別にロググループを管理
- 既存のロググループ構造を1ミリも変更できない制約

---

### 2.3 方式C: rsyslog経由ファイル化 + CloudWatch Agent【非推奨】

**フロー:**
```
Apache → stdout/stderr 
  → journald 
  → rsyslog（振り分け）
  → ファイル出力
      - /var/log/httpd/access.log
      - /var/log/httpd/error.log
      - /var/log/httpd/healthcheck_access.log
  → CloudWatch Agent（ファイル収集）
  → CloudWatch Logs
```

**特徴:**
- ✅ **既存運用完全維持**: ファイル名ベースの監視そのまま
- ✅ **ログ種別明確**: ファイルで分離
- ✅ **運用チーム習熟**: 従来と同じ運用フロー
- ✗ **ファイル管理必要**: ログローテーション等が復活
- ✗ **stdout化の目的未達成**: ファイル管理が残る
- ✗ **ディスク容量管理必要**: 元の課題が解決されない
- ✗ **方式A-2で同等の結果が得られる**: ファイル化する理由がない

**推奨度:** ⭐⭐（stdout化の目的と矛盾、方式A-2で代替可能）

**非推奨の理由:**
```
方式A-2（メタデータ付与）で以下が全て実現可能:
  ✓ ログ種別の明確な識別（メタデータ）
  ✓ メトリクスフィルタで種別ごとに監視
  ✓ CloudWatch Logs Insightsで種別ごとに分析
  ✓ ファイル管理不要
  ✓ ログローテーション不要
  ✓ ディスク容量管理不要

rsyslog経由でファイル化する必要性がない
```

---

### 2.4 方式D: 複数CloudWatch Agent設定 + journaldフィルタ【限定的】

**フロー:**
```
Apache → stdout/stderr 
  → journald 
  → CloudWatch Agent（複数設定）
      設定1: PRIORITY=6 → /aws/ec2/httpd/access
      設定2: PRIORITY=3,4 → /aws/ec2/httpd/error
```

**特徴:**
- ✅ **ファイル管理不要**: stdout化の目的達成
- ⚠️ **部分的なログ分離**: PRIORITYベースのみ（限定的）
- ⚠️ **ヘルスチェック分離困難**: メッセージ内容でのフィルタは不可
- ⚠️ **CloudWatch Agentの機能制約**: journal_fieldsのフィルタリングが限定的
- ⚠️ **方式A-2で完全に代替可能**: メタデータ機能の方が柔軟

**推奨度:** ⭐⭐（方式A-2で完全に代替可能）

**方式A-2との比較:**
```yaml
方式D（journaldフィルタ）:
  - PRIORITY（stderr/stdout）でのみ分離可能
  - ヘルスチェックログの分離: 不可 ✗
  - メッセージ内容での判定: 不可 ✗
  - ロググループ: 2つ（access, error）

方式A-2（メタデータ付与）:
  - メッセージ内容で柔軟に判定可能
  - ヘルスチェックログの分離: 可能 ✓
  - パターンマッチで自動判定: 可能 ✓
  - ロググループ: 1つ（all）でメタデータで分離
  - より柔軟で強力
```

**結論:** 方式A-2のメタデータ機能の方が優れているため、方式Dを選択する理由はない

---

## 3. 詳細比較

### 3.1 比較表

| 項目 | 方式A-1<br/>基本版 | 方式A-2<br/>パターンマッチ | 方式A-3<br/>識別子付与 | 方式B<br/>Lambda | 方式C<br/>rsyslog | 方式D<br/>journald |
|------|---------------|---------------------|------------------|---------------|---------------|----------------|
| **ファイル管理** | 不要 ✅ | 不要 ✅ | 不要 ✅ | 不要 ✅ | 必要 ✗ | 不要 ✅ |
| **ログ種別分離** | 分析時のみ ⚠️ | メタデータ ✅ | メタデータ ✅ | ロググループ ✅ | ファイル ✅ | 部分的 ⚠️ |
| **誤判定リスク** | - | あり ⚠️ | なし ✅ | なし ✅ | なし ✅ | - |
| **設定の複雑さ** | 最小 ✅ | 中 ⚠️ | 低 ✅ | 高 ⚠️ | 高 ✗ | 中 ⚠️ |
| **Apache設定変更** | 不要 ✅ | 不要 ✅ | LogFormat ⚠️ | 不要 ✅ | 不要 ✅ | 不要 ✅ |
| **Tomcat対応** | 容易 ✅ | 困難 ⚠️ | 容易 ✅ | 困難 ⚠️ | 容易 ✅ | 困難 ⚠️ |
| **デバッグ容易性** | 低 ⚠️ | 中 ⚠️ | 高 ✅ | 高 ✅ | 高 ✅ | 中 ⚠️ |
| **運用負荷** | 低 ✅ | 低 ✅ | 低 ✅ | 中 ⚠️ | 高 ✗ | 低 ✅ |
| **コスト** | 低 ✅ | 低 ✅ | 低 ✅ | 高 ⚠️ | 中 ⚠️ | 低 ✅ |
| **既存監視継続性** | 変更大 ⚠️ | 変更中 ⚠️ | 変更中 ⚠️ | 維持 ✅ | 完全維持 ✅ | 変更大 ⚠️ |
| **将来性** | 高 ✅ | 高 ✅ | 高 ✅ | 高 ✅ | 低 ✗ | 高 ✅ |
| **推奨度** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ |

### 3.2 コスト比較

**前提: 3台のEC2インスタンス、400MB/日のログ量**

| 方式 | CloudWatch Logs<br/>取り込み | Lambda実行 | ストレージ | 合計/月 |
|------|---------------------------|-----------|----------|---------|
| **方式A** | $1.80 | $0 | $0.36 | **$2.16** |
| **方式B** | $3.60（重複書き込み） | $0.50 | $0.72 | **$4.82** |
| **方式C** | $1.80 | $0 | $0.36 | **$2.16** |
| **方式D** | $1.80 | $0 | $0.36 | **$2.16** |

**コスト詳細:**
```
CloudWatch Logs取り込み: $0.50/GB
  - 400MB/日 × 30日 = 12GB/月
  - 3台 = 36GB/月
  - $0.50 × 36 = $18.00/月 → 修正: 0.4GB × 30 × 3 = 36GB → $0.50 × 0.4 × 30 × 3 = $18

正しい計算:
  - 1台: 400MB/日 = 0.4GB/日 × 30日 = 12GB/月
  - 3台: 12GB × 3 = 36GB/月
  - コスト: $0.05/GB（最初の10TB） × 36GB = $1.80/月

Lambda（方式B）:
  - リクエスト数: 36GB × 1000行/MB × 1024MB/GB = 約3,686万リクエスト/月
  - $0.20/100万リクエスト × 37 = $7.40/月
  - 実行時間: 128MB、10ms × 3,686万 = $0.50/月（概算）

ストレージ:
  - $0.03/GB/月 × 12GB = $0.36/月（1台、1ヶ月保持）
```

### 3.3 運用負荷比較

| タスク | 方式A | 方式B | 方式C | 方式D |
|--------|------|------|------|------|
| **初期設定工数** | 1日 | 3日 | 2日 | 2日 |
| **日次運用** | なし | なし | ログ容量確認 | なし |
| **月次運用** | なし | Lambda監視 | ローテーション確認 | なし |
| **トラブルシューティング** | 容易 | 中（Lambda含む） | 容易 | 中 |
| **新規メンバー習熟** | 1週間 | 2週間 | 即座 | 1週間 |

---

## 4. 各方式の実装詳細

### 4.1 方式A: 全ログ集約実装

#### 4.1.1 必要なファイル

```
✅ 作成済み:
  - gooid-21-dev-web-101_stdout
  - etc/systemd/system/httpd.service.d/override.conf

🆕 作成必要:
  - CloudWatch Agent設定ファイル
  - CloudWatch Logs Insightsクエリ集
  - メトリクスフィルタ設定
```

#### 4.1.2 CloudWatch Agent設定

```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "journals": {
        "collect_list": [
          {
            "journal_path": "/var/log/journal",
            "unit": "httpd.service",
            "log_group_name": "/aws/ec2/httpd/all",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

**配置パス:** `/opt/aws/amazon-cloudwatch-agent/etc/config.json`

#### 4.1.3 CloudWatch Logs Insightsクエリ集

```sql
-- 1. エラーログのみ抽出
fields @timestamp, @message
| filter @message like /\[error\]/ or @message like /\[warn\]/
| sort @timestamp desc
| limit 100

-- 2. 通常アクセスログ（ヘルスチェック除外）
fields @timestamp, @message
| filter @message not like /\/heartbeat/ 
    and @message not like /\/status\.jsp/
    and @message not like /\[error\]/
    and @message not like /\[warn\]/
| sort @timestamp desc
| limit 100

-- 3. ヘルスチェックログのみ
fields @timestamp, @message
| filter @message like /\/heartbeat/ or @message like /\/status\.jsp/
| sort @timestamp desc
| limit 100

-- 4. 5xxエラーの集計
fields @timestamp, @message
| filter @message like / 5\d\d /
| stats count() as error_count by bin(5m)
| sort @timestamp desc

-- 5. 4xxエラーの集計
fields @timestamp, @message
| filter @message like / 4\d\d /
| stats count() as error_count by bin(5m)
| sort @timestamp desc

-- 6. レスポンスタイム分析（combined_gooidフォーマット）
fields @timestamp, @message
| parse @message /(?<response_time>\d+) "(?<method>\w+) (?<path>\S+)/
| filter response_time > 1000
| stats avg(response_time) as avg_ms, max(response_time) as max_ms by path
| sort avg_ms desc
```

#### 4.1.4 メトリクスフィルタ設定

```yaml
# メトリクスフィルタ1: エラーログカウント
LogGroup: /aws/ec2/httpd/all
FilterName: HttpdErrorCount
FilterPattern: "[error]"
MetricNamespace: CustomMetrics/Httpd
MetricName: ErrorCount
MetricValue: 1
DefaultValue: 0

# メトリクスフィルタ2: 5xxエラーカウント
LogGroup: /aws/ec2/httpd/all
FilterName: Httpd5xxErrorCount
FilterPattern: "\" 5?? \""
MetricNamespace: CustomMetrics/Httpd
MetricName: 5xxCount
MetricValue: 1
DefaultValue: 0

# メトリクスフィルタ3: 4xxエラーカウント
LogGroup: /aws/ec2/httpd/all
FilterName: Httpd4xxErrorCount
FilterPattern: "\" 4?? \""
MetricNamespace: CustomMetrics/Httpd
MetricName: 4xxCount
MetricValue: 1
DefaultValue: 0

# メトリクスフィルタ4: レスポンスタイム遅延
LogGroup: /aws/ec2/httpd/all
FilterName: HttpdSlowResponse
FilterPattern: "[..., response_time > 2000, ...]"
MetricNamespace: CustomMetrics/Httpd
MetricName: SlowResponseCount
MetricValue: 1
DefaultValue: 0
```

#### 4.1.5 CloudWatch Alarmsアラート設定

```yaml
# アラーム1: エラーログ急増
AlarmName: Httpd-ErrorLog-High
MetricName: ErrorCount
Namespace: CustomMetrics/Httpd
Statistic: Sum
Period: 300  # 5分
EvaluationPeriods: 2
Threshold: 10
ComparisonOperator: GreaterThanThreshold
AlarmActions:
  - arn:aws:sns:ap-northeast-1:123456789012:ops-alerts

# アラーム2: 5xxエラー発生
AlarmName: Httpd-5xxError
MetricName: 5xxCount
Namespace: CustomMetrics/Httpd
Statistic: Sum
Period: 60  # 1分
EvaluationPeriods: 1
Threshold: 1
ComparisonOperator: GreaterThanThreshold
AlarmActions:
  - arn:aws:sns:ap-northeast-1:123456789012:critical-alerts
```

---

### 4.2 方式B: Subscription Filter + Lambda実装

#### 4.2.1 Lambda関数（Python）

```python
import json
import boto3
import base64
import gzip
from datetime import datetime

logs_client = boto3.client('logs')

# ログ振り分け先の定義
LOG_GROUPS = {
    'access': '/aws/ec2/httpd/access',
    'error': '/aws/ec2/httpd/error',
    'healthcheck': '/aws/ec2/httpd/healthcheck'
}

def lambda_handler(event, context):
    # CloudWatch Logsからのデータをデコード
    compressed_data = base64.b64decode(event['awslogs']['data'])
    log_data = json.loads(gzip.decompress(compressed_data))
    
    log_events = log_data['logEvents']
    log_stream = log_data['logStream']
    
    # ログを種別ごとに振り分け
    access_logs = []
    error_logs = []
    healthcheck_logs = []
    
    for log_event in log_events:
        message = log_event['message']
        timestamp = log_event['timestamp']
        
        # ヘルスチェックログ判定
        if '/heartbeat' in message or '/status.jsp' in message:
            healthcheck_logs.append({
                'timestamp': timestamp,
                'message': message
            })
        # エラーログ判定
        elif '[error]' in message or '[warn]' in message:
            error_logs.append({
                'timestamp': timestamp,
                'message': message
            })
        # 通常アクセスログ
        else:
            access_logs.append({
                'timestamp': timestamp,
                'message': message
            })
    
    # 各ロググループに書き込み
    if access_logs:
        put_log_events(LOG_GROUPS['access'], log_stream, access_logs)
    
    if error_logs:
        put_log_events(LOG_GROUPS['error'], log_stream, error_logs)
    
    if healthcheck_logs:
        put_log_events(LOG_GROUPS['healthcheck'], log_stream, healthcheck_logs)
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'access': len(access_logs),
            'error': len(error_logs),
            'healthcheck': len(healthcheck_logs)
        })
    }

def put_log_events(log_group_name, log_stream_name, log_events):
    try:
        # ログストリームの存在確認・作成
        try:
            logs_client.create_log_stream(
                logGroupName=log_group_name,
                logStreamName=log_stream_name
            )
        except logs_client.exceptions.ResourceAlreadyExistsException:
            pass
        
        # ログイベント書き込み
        logs_client.put_log_events(
            logGroupName=log_group_name,
            logStreamName=log_stream_name,
            logEvents=log_events
        )
    except Exception as e:
        print(f"Error writing to {log_group_name}: {str(e)}")
```

#### 4.2.2 Subscription Filter設定

```bash
# Subscription Filter作成
aws logs put-subscription-filter \
    --log-group-name /aws/ec2/httpd/combined \
    --filter-name httpd-log-distributor \
    --filter-pattern "" \
    --destination-arn arn:aws:lambda:ap-northeast-1:123456789012:function:httpd-log-distributor
```

#### 4.2.3 Lambda IAMロール

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:ap-northeast-1:123456789012:log-group:/aws/ec2/httpd/*"
      ]
    }
  ]
}
```

---

### 4.3 方式C: rsyslog経由実装

#### 4.3.1 rsyslog設定ファイル

```bash
# /etc/rsyslog.d/httpd-journal.conf

# journaldモジュールの読み込み
module(load="imjournal" StateFile="imjournal-httpd.state")

# httpdのログのみ処理
if $programname == 'httpd' then {
    
    # エラーログの振り分け（Priority 3=err, 4=warn）
    if $syslogseverity <= 4 then {
        action(type="omfile" file="/var/log/httpd/error.log")
        stop
    }
    
    # ヘルスチェックログの振り分け（メッセージ内容で判定）
    if $msg contains '/heartbeat' or $msg contains '/status.jsp' then {
        action(type="omfile" file="/var/log/httpd/healthcheck_access.log")
        stop
    }
    
    # 通常アクセスログ
    action(type="omfile" file="/var/log/httpd/access.log")
    stop
}
```

#### 4.3.2 logrotate設定

```bash
# /etc/logrotate.d/httpd
/var/log/httpd/*.log {
    daily
    rotate 14
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /bin/systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
```

#### 4.3.3 CloudWatch Agent設定

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access.log",
            "log_group_name": "/aws/ec2/httpd/access",
            "log_stream_name": "{instance_id}",
            "timezone": "Local"
          },
          {
            "file_path": "/var/log/httpd/error.log",
            "log_group_name": "/aws/ec2/httpd/error",
            "log_stream_name": "{instance_id}",
            "timezone": "Local"
          },
          {
            "file_path": "/var/log/httpd/healthcheck_access.log",
            "log_group_name": "/aws/ec2/httpd/healthcheck",
            "log_stream_name": "{instance_id}",
            "timezone": "Local"
          }
        ]
      }
    }
  }
}
```

---

### 4.4 方式D: 複数CloudWatch Agent設定実装

#### 4.4.1 CloudWatch Agent設定

```json
{
  "logs": {
    "logs_collected": {
      "journals": {
        "collect_list": [
          {
            "journal_path": "/var/log/journal",
            "unit": "httpd.service",
            "log_group_name": "/aws/ec2/httpd/access",
            "log_stream_name": "{instance_id}",
            "journal_fields": {
              "PRIORITY": "6"  // info level (stdout)
            }
          },
          {
            "journal_path": "/var/log/journal",
            "unit": "httpd.service",
            "log_group_name": "/aws/ec2/httpd/error",
            "log_stream_name": "{instance_id}",
            "journal_fields": {
              "PRIORITY": "3,4"  // err, warning (stderr)
            }
          }
        ]
      }
    }
  }
}
```

**注意**: この方式では、ヘルスチェックログの分離が困難。メッセージ内容でのフィルタリングはCloudWatch Agentの`journal_fields`では不可能。

---

## 5. 既存運用への影響

### 5.1 監視・アラート設定の移行

#### 5.1.1 従来のファイルベース監視

```bash
# 従来の監視スクリプト例
tail -f /var/log/httpd/error_log | grep "error"
grep "500" /var/log/httpd/access_log.20251119 | wc -l
```

#### 5.1.2 方式A（全ログ集約）への移行

```bash
# CloudWatch Logs Insightsクエリに移行
aws logs start-query \
    --log-group-name /aws/ec2/httpd/all \
    --start-time $(date -d '1 hour ago' +%s) \
    --end-time $(date +%s) \
    --query-string 'fields @timestamp, @message | filter @message like /error/ | sort @timestamp desc'
```

**メトリクスフィルタでアラート:**
```yaml
# 5xxエラー監視
FilterPattern: "\" 5?? \""
MetricName: 5xxCount
Alarm: 5xxCount > 10 in 5 minutes
```

#### 5.1.3 方式B（Lambda振り分け）への移行

既存のロググループ構造が維持されるため、**監視スクリプトの変更最小限**:

```bash
# CloudWatch Logs APIで検索
aws logs filter-log-events \
    --log-group-name /aws/ec2/httpd/error \
    --filter-pattern "500" \
    --start-time $(date -d '1 hour ago' +%s)
```

### 5.2 ログ分析手順の変更

#### 5.2.1 従来の分析手順

```bash
# 1. サーバにSSHログイン
ssh user@web-server

# 2. ログファイルを直接参照
tail -f /var/log/httpd/access_log
grep "192.168.1.1" /var/log/httpd/access_log.20251119
awk '{print $9}' /var/log/httpd/access_log.20251119 | sort | uniq -c
```

#### 5.2.2 方式A（全ログ集約）での分析手順

```bash
# CloudWatch Logs Insightsで分析（SSHログイン不要）
aws logs start-query \
    --log-group-name /aws/ec2/httpd/all \
    --start-time $(date -d '1 day ago' +%s) \
    --end-time $(date +%s) \
    --query-string '
        fields @timestamp, @message
        | filter @message like /192.168.1.1/
        | sort @timestamp desc
    '
```

**GUIでの分析:**
1. AWSコンソール → CloudWatch → Logs Insights
2. ロググループ選択: `/aws/ec2/httpd/all`
3. クエリ実行
4. 結果をCSVエクスポート

---

## 6. 推奨事項と判断基準

### 6.1 最推奨: 方式A-3（ログフォーマット識別子付与）

**推奨: 方式A-3（識別子付与 + メタデータ）**

```
採用条件:
  ✓ 全てのプロジェクトで推奨（新規・既存問わず）
  ✓ Apache, Tomcat, Node.js等のログフォーマットが変更可能
  ✓ 誤判定ゼロの確実なログ分離が必要
  ✓ 複数のアプリケーションサーバで統一的な運用
  ✓ デバッグ・トラブルシューティングの容易性重視

メリット:
  - 誤判定リスクゼロ（識別子で明示的に判定）
  - パターンマッチが単純（`[LOG_TYPE:access]` で確実）
  - Apache, Tomcat, Node.js等で同じ手法適用可能
  - ログ見るだけで種別が分かる（デバッグ容易）
  - 新しいエンドポイント追加時もLogFormatで一元管理
  - stdout化の目的を完全達成
  - コスト最小、運用負荷最小

デメリット:
  - Apache LogFormat変更が必要（1回のみ）
  - 既存ログフォーマットとの互換性（移行期間必要）

実装工数: 0.5日（LogFormat変更 + CloudWatch Agent設定）
```

### 6.2 シンプルさ最優先: 方式A-1/A-2（LogFormat変更不可の場合）

**推奨: 方式A-2（パターンマッチ）または A-1（基本版）**

```
採用条件:
  ✓ Apache LogFormatを変更できない制約がある
  ✓ 最小限の設定変更で実装したい
  ✓ 若干の誤判定リスクを許容できる

メリット:
  - Apache設定変更不要
  - 最もシンプルな設定
  - 運用負荷最小

デメリット:
  - パターンマッチの複雑さ（方式A-2）
  - 誤判定の可能性（方式A-2）
  - ログ種別がログから判別しにくい

実装工数: 0.25日（CloudWatch Agent設定のみ）
```

### 6.2 既存運用継続重視

**推奨: 方式B（Subscription Filter + Lambda）**

```
採用条件:
  ✓ 既存の監視・アラート設定を維持したい
  ✓ ログ種別を明確に分離したい
  ✓ Lambdaの運用経験がある
  ✓ 若干のコスト増は許容できる

メリット:
  - ロググループ構造が従来と同じ
  - 既存監視設定の移行が容易
  - ファイル管理不要（stdout化達成）

デメリット:
  - Lambda管理が必要
  - コストが約2倍
  - 若干の遅延発生
```

### 6.3 バランス重視

**推奨: 方式D（複数CloudWatch Agent設定）**

```
採用条件:
  ✓ シンプルさと分離のバランスを取りたい
  ✓ ヘルスチェックログの分離は妥協できる
  ✓ エラーログとアクセスログの分離は必須

メリット:
  - ファイル管理不要
  - Lambda不要
  - エラー/アクセスログの分離は可能

デメリット:
  - ヘルスチェックログの分離が困難
  - CloudWatch Agentのjournal_fields機能に制約
```

---

## 7. 決定事項（明日記入）

```
決定した方式: 【未決定】

選定理由:
  - 
  - 
  - 

懸念事項:
  - 
  - 

対応策:
  - 
  - 

決定者: 
決定日: 2025-11-__
```

---

## 8. 次のステップ（明日のタスク）

### Phase 1: 方式決定（所要時間: 2-3時間）

```
□ 1. このドキュメントを全員でレビュー
□ 2. 各方式のメリット・デメリットを議論
□ 3. プロジェクト要件との整合性確認
     - 運用チームのスキルセット
     - 既存監視設定の重要度
     - 将来のコンテナ化計画
     - 予算制約
□ 4. 方式を決定し、このドキュメントに記入
```

### Phase 2: 詳細設計（所要時間: 1日）

```
□ 1. 選定した方式の設定ファイル一式を作成
□ 2. CloudWatch Agent設定ファイル作成
□ 3. メトリクスフィルタ設定設計
□ 4. CloudWatch Alarms設定設計
□ 5. 運用手順書作成
□ 6. トラブルシューティングガイド作成
```

### Phase 3: 検証環境での実装（所要時間: 2-3日）

```
□ 1. 開発環境でApache設定変更
     - gooid-21-dev-web-101_stdout を適用
     - systemd override.conf を適用
□ 2. CloudWatch Agent設定適用
□ 3. ログ出力確認
     - journalctl -u httpd -f でログ確認
     - CloudWatch Logsへの送信確認
□ 4. メトリクスフィルタ動作確認
□ 5. CloudWatch Alarms動作確認
□ 6. パフォーマンステスト
     - ログ出力遅延測定
     - CPU/メモリ使用率確認
□ 7. 問題点の洗い出しと対策
```

### Phase 4: 本番展開計画（所要時間: 1日）

```
□ 1. ロールバック手順の作成
□ 2. 段階的展開計画
     - 1台目: パイロット展開（1週間監視）
     - 2台目以降: 問題なければ順次展開
□ 3. 運用チームへのトレーニング
     - CloudWatch Logs Insightsの使い方
     - 新しい監視手順
□ 4. ドキュメント整備
     - 運用手順書
     - トラブルシューティングガイド
     - FAQ作成
```

---

## 9. ログへの人間可読な識別子付与【追加タスク】

### 9.1 背景と要件

**課題:**
```
現状: CloudWatch Logsのログストリーム名がインスタンスIDベース
  例: i-0a1b2c3d4e5f6g7h8

問題点:
  ✗ インスタンスIDは人間が覚えにくい
  ✗ Auto Scaling Groupでインスタンスが再作成されると新しいIDになる
  ✗ どのサーバのログか判別しづらい

要件:
  ✓ 人間が理解しやすい名前
  ✓ Auto Scaling Groupでの再作成後も不変
  ✓ ログ上で明確に識別可能
```

### 9.2 識別子の選択肢

| 候補 | 例 | 再作成時の不変性 | 人間可読性 | 推奨度 |
|------|-----|---------------|----------|--------|
| **Nameタグ + AZ + 連番** | `poc-web-1a-001` | ✅（タグ引き継ぎ） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐【最推奨】 |
| **環境 + ロール + 連番** | `poc-web-001` | ✅（命名規則） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐【最推奨】 |
| **カスタムタグ（Host-ID）** | `host-web-001` | ✅（タグ引き継ぎ） | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **プライベートIP** | `10.0.1.10` | ✅（固定IP割当） | ⭐⭐⭐ | ⭐⭐⭐ |
| **プライベートDNS** | `ip-10-0-1-10` | ✅（固定IP割当） | ⭐⭐ | ⭐⭐ |
| **インスタンスID** | `i-0a1b2c3d4e5f6g7h8` | ✗（再作成で変わる） | ⭐ | ⭐ |

**推奨: Nameタグベース（`poc-web-1a-001`形式）**

理由:
- ✅ 環境（poc/stg/prd）が明確
- ✅ ロール（web/hlp）が明確
- ✅ AZ（1a/1c）が明確
- ✅ 連番で個体識別可能
- ✅ Auto Scaling Groupでも命名規則で再作成可能

### 9.3 実装方式

#### 9.3.1 方式1: Nameタグから取得【推奨】

**UserDataスクリプトでNameタグを取得し、環境変数に設定:**

```bash
#!/bin/bash
# /etc/profile.d/instance-name.sh

# EC2メタデータからインスタンスIDを取得
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)

# Nameタグを取得
INSTANCE_NAME=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" \
    --query 'Tags[0].Value' \
    --output text \
    --region ap-northeast-1)

# 環境変数として設定
export INSTANCE_NAME="${INSTANCE_NAME:-$INSTANCE_ID}"
echo "INSTANCE_NAME=$INSTANCE_NAME" >> /etc/environment
```

**Apache LogFormatに追加:**

```apache
# /etc/httpd/conf/httpd.conf

# 環境変数INSTANCE_NAMEをApacheに渡す
SetEnv INSTANCE_NAME ${INSTANCE_NAME}

# LogFormatにINSTANCE_NAMEを追加
LogFormat "%a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" \"%{GOO_ID}e\" [%{INSTANCE_NAME}e]" combined_gooid_with_hostname

# CustomLogで使用
CustomLog "|/bin/cat" combined_gooid_with_hostname env=!no_record_object
```

**ログ出力例:**
```
10.0.1.5 - - [19/Nov/2025:10:30:45 +0900] "GET /index.html HTTP/1.1" 200 1234 "-" "Mozilla/5.0" "goo123456" [poc-web-1a-001]
```

#### 9.3.2 方式2: CloudWatch Agentのlog_stream_nameでカスタマイズ

**CloudWatch Agent設定:**

```json
{
  "logs": {
    "logs_collected": {
      "journals": {
        "collect_list": [
          {
            "journal_path": "/var/log/journal",
            "unit": "httpd.service",
            "log_group_name": "/aws/ec2/httpd/all",
            "log_stream_name": "{instance_name}/{instance_id}"
          }
        ]
      }
    }
  }
}
```

**{instance_name}の設定方法:**

```bash
# /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml

[instance_name]
  # Nameタグから取得
  source = "ec2_tag"
  tag_key = "Name"
  
  # または環境変数から取得
  # source = "env"
  # env_var = "INSTANCE_NAME"
```

**結果:**
```
ロググループ: /aws/ec2/httpd/all
ログストリーム名: poc-web-1a-001/i-0a1b2c3d4e5f6g7h8
```

#### 9.3.3 方式3: journald識別子に追加

**systemd override設定でホスト名を明示:**

```ini
# /etc/systemd/system/httpd.service.d/override.conf

[Service]
StandardOutput=journal
StandardError=journal
SyslogIdentifier=httpd-%H  # %H: ホスト名プレースホルダー
SyslogLevel=info
SyslogFacility=daemon

# 環境変数からNameタグを読み込み
EnvironmentFile=/etc/environment
```

**結果:**
```
journalctl出力例:
Nov 19 10:30:45 poc-web-1a-001 httpd-poc-web-1a-001[12345]: GET /index.html HTTP/1.1 200 1234
```

#### 9.3.4 方式4: Apacheのログフォーマットに直接埋め込み

**mod_macro使用（最もシンプル）:**

```apache
# /etc/httpd/conf/httpd.conf

# ホスト名を取得
Define HOSTNAME poc-web-1a-001

# LogFormatにホスト名を埋め込み
LogFormat "[${HOSTNAME}] %a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" \"%{GOO_ID}e\"" combined_gooid_hostname

CustomLog "|/bin/cat" combined_gooid_hostname env=!no_record_object
```

**ログ出力例:**
```
[poc-web-1a-001] 10.0.1.5 - - [19/Nov/2025:10:30:45 +0900] "GET /index.html HTTP/1.1" 200 1234 "-" "Mozilla/5.0" "goo123456"
```

### 9.4 CloudWatch Logs表示例

#### 9.4.1 方式1（LogFormatに追加）を採用した場合

**CloudWatch Logs Insights クエリ:**

```sql
-- ホスト名でフィルタリング
fields @timestamp, @message
| parse @message /\[(?<hostname>[^\]]+)\]/
| filter hostname = "poc-web-1a-001"
| sort @timestamp desc

-- ホスト名ごとのエラーカウント
fields @timestamp, @message
| parse @message /\[(?<hostname>[^\]]+)\]/
| filter @message like /error/
| stats count() as error_count by hostname
| sort error_count desc

-- ホスト名ごとのレスポンスタイム集計
fields @timestamp, @message
| parse @message /(?<response_time>\d+) "(?<method>\w+) (?<path>\S+).*\[(?<hostname>[^\]]+)\]/
| stats avg(response_time) as avg_ms, max(response_time) as max_ms by hostname, path
| sort avg_ms desc
```

#### 9.4.2 方式2（log_stream_name）を採用した場合

**ログストリーム一覧:**
```
/aws/ec2/httpd/all
  ├── poc-web-1a-001/i-0a1b2c3d4e5f6g7h8
  ├── poc-web-1a-002/i-0b2c3d4e5f6g7h9i
  ├── poc-web-1c-001/i-0c3d4e5f6g7h9i0j
  └── poc-web-1c-002/i-0d4e5f6g7h9i0j1k
```

**CloudWatch Logs Insights クエリ:**

```sql
-- 特定ホストのログのみ
fields @timestamp, @message, @logStream
| filter @logStream like /poc-web-1a-001/
| sort @timestamp desc

-- ホストごとのエラー集計（ログストリーム名から抽出）
fields @timestamp, @message, @logStream
| parse @logStream /(?<hostname>[^\/]+)\/i-/
| filter @message like /error/
| stats count() as error_count by hostname
| sort error_count desc
```

### 9.5 Auto Scaling Groupでの運用

#### 9.5.1 Launch Templateでの設定

```yaml
# Launch Template UserData

#!/bin/bash
set -e

# 1. Nameタグを設定（Auto Scaling Groupのタグから継承）
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'AutoScalingInstances[0].AutoScalingGroupName' \
    --output text \
    --region ap-northeast-1)

# 2. インスタンス番号を決定（ASG内で一意な連番）
INSTANCE_INDEX=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].Instances[?InstanceId=='$INSTANCE_ID'].AvailabilityZone" \
    --output text \
    --region ap-northeast-1 | sed 's/.*-//')

AZ_SHORT=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/.*-//')
INSTANCE_NAME="${ASG_NAME}-${AZ_SHORT}-$(printf "%03d" $INSTANCE_INDEX)"

# 3. Nameタグを付与
aws ec2 create-tags \
    --resources "$INSTANCE_ID" \
    --tags "Key=Name,Value=$INSTANCE_NAME" \
    --region ap-northeast-1

# 4. 環境変数に設定
echo "INSTANCE_NAME=$INSTANCE_NAME" >> /etc/environment
export INSTANCE_NAME="$INSTANCE_NAME"

# 5. Apache設定に反映
sed -i "s/Define HOSTNAME .*/Define HOSTNAME $INSTANCE_NAME/" /etc/httpd/conf/httpd.conf

# 6. Apache再起動
systemctl restart httpd
```

#### 9.5.2 連番管理の自動化

**DynamoDBテーブルで連番管理:**

```python
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('instance-counter')

def get_next_instance_number(asg_name, az):
    response = table.update_item(
        Key={'asg_name': asg_name, 'az': az},
        UpdateExpression='ADD counter :inc',
        ExpressionAttributeValues={':inc': 1},
        ReturnValues='UPDATED_NEW'
    )
    return response['Attributes']['counter']

# 使用例
asg_name = "poc-web-asg"
az = "1a"
instance_number = get_next_instance_number(asg_name, az)
instance_name = f"{asg_name.replace('-asg', '')}-{az}-{instance_number:03d}"
# 結果: poc-web-1a-001
```

### 9.6 実装チェックリスト

```
Phase 1: 設計（明日実施）
□ 1. 識別子の命名規則を決定
     候補: poc-web-1a-001 または poc-web-001
□ 2. 実装方式を選択
     方式1: LogFormat追加【推奨】
     方式2: log_stream_name
     方式3: journald識別子
     方式4: Apache Define
□ 3. Auto Scaling Groupでの連番管理方法を決定

Phase 2: 実装（明日～明後日）
□ 1. UserDataスクリプト作成
□ 2. Apache設定ファイル更新
     - LogFormat修正
     - 環境変数読み込み
□ 3. systemd override.conf更新（必要に応じて）
□ 4. CloudWatch Agent設定更新（必要に応じて）
□ 5. Launch Template更新

Phase 3: 検証（明後日）
□ 1. 開発環境でテスト
     - ログにホスト名が表示されることを確認
     - CloudWatch Logsで確認
□ 2. Auto Scaling動作確認
     - インスタンス削除→再作成で連番が正しく付与されることを確認
□ 3. CloudWatch Logs Insightsクエリ動作確認
     - ホスト名でのフィルタリング
     - ホスト名ごとの集計
```

### 9.7 推奨実装（まとめ）

**最もシンプルで確実な方法:**

1. **Launch TemplateのUserDataでNameタグを設定**
   ```bash
   INSTANCE_NAME="poc-web-1a-001"
   aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=$INSTANCE_NAME
   echo "INSTANCE_NAME=$INSTANCE_NAME" >> /etc/environment
   ```

2. **ApacheのLogFormatに追加**
   ```apache
   SetEnv INSTANCE_NAME ${INSTANCE_NAME}
   LogFormat "... [%{INSTANCE_NAME}e]" combined_gooid_hostname
   ```

3. **CloudWatch Logs Insightsでパース**
   ```sql
   parse @message /\[(?<hostname>[^\]]+)\]/
   ```

**メリット:**
- ✅ 設定が最もシンプル
- ✅ Auto Scaling Groupでも対応可能
- ✅ 既存ログフォーマットを大きく変更しない
- ✅ CloudWatch Agentの設定変更不要

---

## 10. 参考資料

### 10.1 作成済みファイルの場所

```
doc-idhub/design/03.server-architecture/LogCollectionMethod/gather/
├── gooid-21-dev-web-101                         # 元のApache設定
├── gooid-21-dev-web-101_stdout                  # stdout化Apache設定
└── etc/systemd/system/httpd.service.d/
    └── override.conf                            # systemd設定
```

### 10.2 関連ドキュメント

```
- LogCollectionMethodCloudWatch.md
  → セクション4.2.2: 標準出力ログ収集（journald経由）
  → セクション6.1: 標準出力ログ収集詳細

- 03.server-architecture.md
  → ログ収集方式の概要

- app/supervisord/README.md
  → Supervisordでのstdout/stderr設定例
```

### 10.3 AWS公式ドキュメント

```
- CloudWatch Agent Configuration Reference
  https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html

- CloudWatch Logs Insights Query Syntax
  https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html

- Using Metric Filters to Extract Values from JSON Log Events
  https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html

- journald Integration
  https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-collect-systemd-journal.html
```

### 10.4 Apacheドキュメント

```
- Apache Log Files
  https://httpd.apache.org/docs/2.4/logs.html

- ErrorLog Directive
  https://httpd.apache.org/docs/2.4/mod/core.html#errorlog

- CustomLog Directive
  https://httpd.apache.org/docs/2.4/mod/mod_log_config.html#customlog
```

---

**作成日:** 2025-11-19  
**最終更新:** 2025-11-19  
**作成者:** システムアーキテクト  
**ステータス:** 方式選定待ち  
**次回レビュー:** 2025-11-20（明日）
