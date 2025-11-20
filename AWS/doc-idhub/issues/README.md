# 課題一覧

* 初期フェーズ時点で徒然なるままに、思いついた課題を挙げていってみる。

## 1. CI/CD 機能が冗長

* Fargate上に、（CI/CD機能を担う）Jenkinsコンテナインスタンスを起動しようとしている。
* そもそもFargate上に `Code Pipeline` といったCI/CD機能を有したマネージドサービスが存在している。
* 後者に寄せてもよいのではないか？
* `Jenkins JOBを Code Piplineに再定義・書き換えるコスト` / `今後の拡張性` / `本件、「暫定移設」なのでコストかけない？` ・・・・・・等を鑑みて、総合的に判断していく。 ![pin](https://api.iconify.design/fxemoji:roundpushpin.svg) `(1)`


## 2. Batchは、EC2インスタンスで稼働？それともEventBridge等マネージドサービス化？

* オンプレのHA構成（Active/Standby）は運用に苦労した。それをまたわざわざAWSに持って行くの？
* マネージドサービス向けにBatch Scriptを書き換えるコストが気になるところ。
  * でもそもそもそんなにBatch本数ないよね？
* Batch処理の所要時間も、決断を左右させる。
* こちらも、前述の ![pin](https://api.iconify.design/fxemoji:roundpushpin.svg) `(1)` と同様。

## 3. FutureVulsに、後工程になって丸裸にされる可能性

* ミドルウェア、Framework のEOL。
* FutureVuls（エージェント型 脆弱性検知ソフト。DOCOMO社で導入必須。）に丸裸にされる可能性。
* 例えば、SpringBoot。
  * 現状は [2.5.0 を利用している](https://container.wbo110.goo.ne.jp/repo/nttr/idhub-oidc/src/branch/master/pom.xml#L8) っぽい。
  * とっくにEOL。
  * 2系の最新バージョン: 2.7.18 (2023年11月23日リリース)
    * 最新かつ最終パッチバージョン
  * 2.5.15 - 2022年8月にEOL。
* 例えば Tomcat 9.0.102
  * Tomcat 9系全体: まだサポート継続中
  * 最新バージョン: 9.0.95 (2024年10月現在の最新)
  * EOL予定: 正式なEOL日程は未発表
  * 9.0.102 には以下の脆弱性があるようだ。
    * CVE-2024-38286 (DoS攻撃)
    * CVE-2024-34750 (情報漏洩)
* **早い段階で、オンプレミス環境にでもいいからFutureVulsをインストールさせておいて、「ウミ」を出しておくか？**
