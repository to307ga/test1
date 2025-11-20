# KickOff - 2025-10-03(金)

## 1. プロジェクト概要

* idhub とは。
  * OCNのID（＝OCN ID）と DOCOMOのID（＝dアカウント）を連携するシステム。
  * 連携することでOCNブランドの世界でdポイントの進呈・利用ができたり、煩雑なOCN IDのログインをdアカウントで容易に日常使いのログインを実現させるためのもの。
* 目標は、年度内切り替え。

### 1.1. 背景

* オンプレミスで稼働している本システム。そのデータセンタ（以降「三鷹DC」）の閉鎖が2026年6月を予定している。
* それまで、もしくはそれ以前に他のIaaS基盤へのマイグレーションが必須。
* idhub自体と連携する利用サービスがいくつか現存しているが、数年後に大きなトラフィック・トランザクションを要求するサービス（OCNメール）の新規利用が計画されている。
  * 現在の小規模人数での体制での運用、冗長性・安定性への懸念（DRが実現してない、等）から、ドコモビジネス社（旧NTTコミュニケーションズ）への譲渡・マイグレーションが計画されている。
  * その実現よりも先に三鷹DCの閉鎖が予定されているため、 `暫定的にAWSへ移転` するものである。

## 2. 要件、概要

* サーバレスは追及しない。
  * 「クラウドネイティブデザイン」を不必要に求めない。
  * EC2 を利用する。逆に利用してはいけない、ということはない。
  * 現存する IAS 「Ansible Playbook」の資産が大きい。（＝スクラッチからCloudFormation（以下、Cfn）に書き換えはコストがかかる。）
* 専門部隊が用意したCfn Templateに従う。
  * https://github.com/nttdocomo-com/aws-templates-bprtech/
    * ベストプラクティスに沿ってかつドコモのセキュリティルールに則った構成をより簡単に構築するためのテンプレート
  * 専門部隊＝運用改革チーム＝Business Process Reenginerring＝BPR TECH（この部署名は既に存在しない）

### 2.1. 現在のシステム構成（三鷹DC）

* 俯瞰図 ー [01-リリースの影響範囲.drawio.svg](./images/01-リリースの影響範囲.drawio.svg)（ [Sharepoint](https://nttdocomo.sharepoint.com/:u:/r/sites/OCNID-ID2/Shared%20Documents/%E5%85%B1%E9%80%9A/ID/%E9%81%8B%E7%94%A8/%E3%83%AA%E3%83%AA%E3%83%BC%E3%82%B9%E3%83%95%E3%83%AD%E3%83%BC/01-%E3%83%AA%E3%83%AA%E3%83%BC%E3%82%B9%E3%81%AE%E5%BD%B1%E9%9F%BF%E7%AF%84%E5%9B%B2.drawio.svg?csf=1&web=1&e=zU7PCG) のレプリカ）
* さらに深部を説明した挿絵 ー [system.drawio.svg](./images/system.drawio.svg)（ [Sharepoint](https://nttdocomo.sharepoint.com/:u:/r/sites/cx-dccshare/Shared%20Documents/%E3%83%A1%E3%83%BC%E3%83%ABd%E3%82%A2%E3%82%AB%E3%82%B7%E3%83%95%E3%83%88%E6%A4%9C%E8%A8%8E/%E5%8F%82%E8%80%83%E8%B3%87%E6%96%99/%E7%8F%BE%E7%8A%B6%E3%81%AEidhub/system.drawio.svg?csf=1&web=1&e=xnZa1v) のレプリカ）

### 2.2. AWS移転後の構成（未来予想図）

* [構成図2025.drawio.svg](./images/構成図2025.drawio.svg) (推奨：draw.ioで開く `(*1)`)
* EC2インスタンスの見積り（予想。確定でない）

（ [AWS費用見積り.xlsx](https://nttdocomo.sharepoint.com/:x:/r/sites/OCNID-ID2/Shared%20Documents/%E5%85%B1%E9%80%9A/ID/%E5%96%B6%E3%81%BF/2024-09-AWS%EF%BC%88R%E3%82%AF%E3%83%A9%E3%82%A6%E3%83%89%E7%A7%BB%E8%BB%A2%EF%BC%89/idhub_AWS%E7%A7%BB%E8%BB%A2/AWS%E8%B2%BB%E7%94%A8%E8%A6%8B%E7%A9%8D%E3%82%8A/AWS%E8%B2%BB%E7%94%A8%E8%A6%8B%E7%A9%8D%E3%82%8A.xlsx?d=w64fee9622d1d46339b6213e59691fd8d&csf=1&web=1&e=VVRR0P&nav=MTVfezAwMDAwMDAwLTAwMDEtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMH0)  (DOCOMO限り `(*2)` ) より ）

|サービス名|用途概要|リージョン|インスタンスタイプ/スペック|利用数量|
|:----|:----|:----|:----|:----|
|EC2|商用WEB - idhub-22-pro-web|ap-northeast-1|t3.2xlarge|3|
|EC2|商用Help - idhub-22-pro-hlp|ap-northeast-1|t3.medium|3|
|EC2|商用Batch - idhub-22-pro-batch|ap-northeast-1|t3.xlarge|3|
|EC2|検証WEB - idhub-22-dev-web|ap-northeast-1|t3.medium|3|
|EC2|検証Help - idhub-22-dev-hlp|ap-northeast-1|t3.medium|3|
|EC2|検証Batch - idhub-22-dev-batch|ap-northeast-1|t3.medium|3|
|ECS|Jenkins|ap-northeast-1|t3.medium|1|
|ECS|Gitea|ap-northeast-1|t3.medium|1|
|ECS|Redmine|ap-northeast-1|t3.medium|1|

## 3. 体制・メンバ

```plaintext
伊藤 恵吾（マネジャー、雑用）
  宮内 賢（PMO）
    今井 聡史（PL）
      馬場 順司（インフラ、アプリケーション）
      朝長 俊光（インフラ）
  
      CNS 斎藤（インフラ、アプリケーション）
      CNS 尾岸（インフラ、アプリケーション）
      CNS 藤本 秋彦（インフラ） - 0.3稼働
      CNS 中川 聖也（インフラ） - 1.0稼働
```

## 4. コミュニケーション手段

* Chat
  * Slackを公式のチャットツールとしよう。
    * `#x_pjct_goosubsc_cns` チャネル
* Ticket
  * 今のところ出番がないが、
  * 必要が出てきたら [Backlog](https://bklg.docomo-common.com/backlog/projects/GOOID)
* 文書
  * 今のところ、GithubへMarkdownや挿絵をCommitすることを考えている。
  * PowerPoint, Excel も共有したいところ。
* 定例
  * 毎週水曜 14:30～16:00

## 5. 武器・必要なモノ・アカウント

* Githubアカウント
* Github Copilot有償アカウント（有償だとベター）
* 三鷹DCアカウント（SSH）
* Gitea（Playbook）
* Slackへ招待（藤本さん、中川さん）

## 6. いまいま

* AWSを使い倒したことが無い人が多い。 → タスクにまでは分解できてない状態。
  * タスクを具体化したい。
  * せっかちな自分だけ？
  * でも慌ててもしょうがない。
* 「最強のデスクトップ」を作っている。
  * Copilotの恩恵を受けたいため。
  * なので、CloudShellは利用したくない。
  * [トップのREADME.md](../../README.md) に詳細なセットアップ手順が。
* `feature/docs` ブランチの [docs/設計書/要件定義書.md] を鍛えていってる。
  * Copilotへ依存し設計書を作ってもらう構想。
  * 「Cfnテンプレート作成に必要なドキュメントを作ってください。」と、Copilotへお願いする。

## 9. 原図へのリソース

* Sharepoint ![folder](https://api.iconify.design/fluent-emoji-flat:file-folder.svg) [2024-09-AWS（Rクラウド移転）](https://nttdocomo.sharepoint.com/:f:/r/sites/OCNID-ID2/Shared%20Documents/%E5%85%B1%E9%80%9A/ID/%E5%96%B6%E3%81%BF/2024-09-AWS%EF%BC%88R%E3%82%AF%E3%83%A9%E3%82%A6%E3%83%89%E7%A7%BB%E8%BB%A2%EF%BC%89?csf=1&web=1&e=uxs4bS)
* Sharepoint ![folder](https://api.iconify.design/fluent-emoji-flat:file-folder.svg) [メールdアカシフト検討 > 現状のidhub](https://nttdocomo.sharepoint.com/:f:/r/sites/cx-dccshare/Shared%20Documents/%E3%83%A1%E3%83%BC%E3%83%ABd%E3%82%A2%E3%82%AB%E3%82%B7%E3%83%95%E3%83%88%E6%A4%9C%E8%A8%8E/%E5%8F%82%E8%80%83%E8%B3%87%E6%96%99/%E7%8F%BE%E7%8A%B6%E3%81%AEidhub?csf=1&web=1&e=nJNzAH)

## 10. メモ

