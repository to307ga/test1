
# JCasC（Jenkins Configuration as Code）とは？

## 🤔 そもそもJCasCって何？

**JCasC**は「Jenkins Configuration as Code」の略称で、日本語に訳すと「設定をコードで管理するJenkins」という意味です。

普通のJenkinsは、ブラウザ上でポチポチとボタンを押して設定を変更しますが、JCasCはYAMLファイルという文字で書かれた設定ファイルを使って、Jenkinsの設定を管理します。

## 🏠 身近な例で考えてみよう

### 普通のJenkins（従来の方法）
レストランで例えると...
- お客さんが店員に口頭で「ハンバーガーセット、ポテトは塩多め、ドリンクはコーラで」と注文
- 店員がその場で覚えて作る
- でも、店員が変わったり、忙しくて忘れちゃうと、注文内容が分からなくなる

### JCasC（新しい方法）
レストランで例えると...
- お客さんが注文票に「ハンバーガーセット、ポテト塩多め、コーラ」と書く
- 誰でもその注文票を見れば、同じものが作れる
- 注文票をコピーすれば、他の店でも同じものが作れる

## 📝 JCasCの仕組み

### YAMLファイルとは？
```yaml
jenkins:
  systemMessage: "これは私のJenkinsサーバーです"
  numExecutors: 2
  
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: "github-token"
              username: "myusername"
              password: "mypassword"
```

上のような、インデント（字下げ）で階層を表現する設定ファイルです。まるで家系図のように、親子関係が分かりやすく書かれています。

## 🎯 JCasCの良いところ

### 1. **設定が見える化される**
- 設定内容が文字で書かれているので、何が設定されているか一目で分かる
- Gitなどでバージョン管理ができる（いつ、誰が、何を変更したかが分かる）

### 2. **同じ環境を簡単に作れる**
- テスト環境と本番環境で全く同じ設定にできる
- 新しいサーバーでも、同じYAMLファイルを使えばすぐに同じJenkinsが作れる

### 3. **設定ミスが減る**
- 手作業でポチポチ設定する必要がないので、クリックミスがない
- 設定内容をチームで確認しあえる

### 4. **バックアップが簡単**
- YAMLファイルをコピーするだけで設定のバックアップが完了
- 設定を間違えても、前のバージョンに簡単に戻せる

## 🛠️ 実際の使い方

### ステップ1: YAMLファイルを作る
`jenkins.yaml`というファイルを作って、設定を書きます。

### ステップ2: Jenkinsに読み込ませる
Jenkinsを起動するときに、そのYAMLファイルを指定します。

### ステップ3: 自動で設定される
Jenkinsが起動すると、YAMLファイルの内容に従って自動で設定されます。

## 📚 具体的な設定例

### 基本的なJenkins設定
```yaml
jenkins:
  systemMessage: "チーム開発用Jenkinsサーバー"
  numExecutors: 4  # 同時に実行できるジョブの数
  scmCheckoutRetryCount: 3  # ソースコード取得の再試行回数
  mode: NORMAL  # 通常モード
```

### ユーザー管理
```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false  # 新規ユーザー登録を禁止
      users:
        - id: "admin"
          password: "admin123"
          name: "管理者"
          description: "システム管理者"
```

### プラグイン設定
```yaml
jenkins:
  installState:
    installLevel: "NEW_INSTALL"
    
plugins:
  - "git:latest"
  - "workflow-aggregator:latest"
  - "blueocean:latest"
```

## 🔄 従来の方法との比較

| 項目 | 従来の方法 | JCasC |
|------|------------|-------|
| 設定方法 | ブラウザでクリック | YAMLファイルで記述 |
| 設定の確認 | 画面を開いて確認 | ファイルを見るだけ |
| 環境複製 | 手作業で再設定 | ファイルコピーで完了 |
| バージョン管理 | 困難 | Gitで簡単に管理 |
| チーム共有 | 口頭説明や手順書 | ファイル共有だけ |
| 設定ミス | 起こりやすい | 起こりにくい |

## 🚀 始め方

### 1. 必要なプラグインをインストール
- Configuration as Code Plugin

### 2. 環境変数を設定
```bash
export CASC_JENKINS_CONFIG=/path/to/jenkins.yaml
```

### 3. Jenkinsを起動
```bash
java -jar jenkins.war
```

## ⚠️ 注意点

### 1. **YAML文法に注意**
- インデント（字下げ）を間違えると動かない
- タブ文字は使わず、スペースを使う

### 2. **機密情報の取り扱い**
- パスワードなどは環境変数や暗号化して管理
- YAMLファイルに直接書かない

### 3. **段階的な導入**
- いきなり全設定をJCasCにしない
- 少しずつ移行していく

## 🎓 まとめ

JCasCは、Jenkinsの設定を**文字で書いて管理する仕組み**です。

**メリット：**
- 設定が見える化される
- 環境の複製が簡単
- チームでの管理がしやすい
- 設定ミスが減る

**デメリット：**
- 最初はYAMLの書き方を覚える必要がある
- 従来の画面操作に慣れている人には新しい学習が必要

でも、チームで開発するなら、JCasCを使った方が断然便利です！まるで、みんなで同じレシピ本を見ながら料理するような感じで、誰でも同じJenkins環境を作ることができるようになります。

## 📖 参考リンク

- [Jenkins Configuration as Code 公式ドキュメント](https://plugins.jenkins.io/configuration-as-code/)
- [YAML文法ガイド](https://yaml.org/)
- [Jenkins公式サイト](https://www.jenkins.io/)

---
*このドキュメントは初心者向けに作成されています。より詳細な技術情報については、公式ドキュメントを参照してください。*

JCasC（Jenkins Configuration as Code）設定ファイルは、Jenkins WebUIから作成・参照・管理することができます。

JCasC WebUIでの操作方法
1. Configuration as Code プラグインの確認
まず、Jenkins WebUIで以下を確認してください：

Manage Jenkins → Manage Plugins で「Configuration as Code」プラグインがインストールされているか確認
2. JCasC設定の管理
プラグインがインストールされていれば：

Manage Jenkins → Configuration as Code メニューが表示されます
3. 主な機能
現在の設定をエクスポート：

現在のJenkins設定をYAML形式でエクスポートできます
「View Configuration」ボタンで現在の設定を確認
「Download Configuration」でYAMLファイルとしてダウンロード可能
設定ファイルの適用：

YAMLファイルをアップロードして設定を適用
テキストエリアに直接YAML設定を貼り付けて適用
「Apply new configuration」ボタンで設定を反映
設定の検証：

設定を適用する前に構文チェックが可能
エラーがある場合は詳細なエラーメッセージを表示
4. 設定ファイルの場所
WebUIで設定したJCasCファイルは通常以下の場所に保存されます：

$JENKINS_HOME/jenkins.yaml
または環境変数 CASC_JENKINS_CONFIG で指定された場所
この方法で、バックアップファイルを展開しなくても、Jenkins WebUIから直接JCasC設定を確認・管理できます。


JCasC設定の優先順位について
CloudFormationテンプレート側でJCasCを無効化/有効化できます。

設定の優先順位
Dockerfileでの設定（ベースイメージ）:
```
COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs
```
CloudFormationテンプレートでの環境変数（実行時）:
```
Environment:
  # 現在はコメントアウト（無効化）
  # - Name: CASC_JENKINS_CONFIG
  #   Value: '/var/jenkins_home/casc_configs'
```
動作メカニズム
現在の状態（JCasC無効）:

Dockerfileで CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs を設定
しかし、CloudFormationで同じ環境変数をコメントアウト
結果: CloudFormationの環境変数設定が優先され、JCasCが無効化される
なぜ無効化されるのか:
# CloudFormationテンプレートで CASC_JENKINS_CONFIG を設定しない場合
# コンテナは Dockerfile の ENV を使用するが、
# ECS Fargateでは明示的に設定されていない環境変数は継承されない場合がある
















