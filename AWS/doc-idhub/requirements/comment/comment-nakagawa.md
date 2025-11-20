# 要件定義書に対する中川コメント

## [README.md](../README.md)

| No |セクション | 指摘内容 | 回答 | 参考URL |
|----|-----------|---------|--------|----------|
| 1 | 1.5.1 dev (対象環境) | **Alias** : `gooid-idhub-aws-dev`が、そのままAWSリソースのプレフィックスに該当しますか？ | はい。「アカウントエイリアス」= `gooid-idhub-aws-dev` となります。<br/>IAMコンソールにも表示されてます。<br/>![alt text](account-alias.png)|  |
| 2 | 6.1 インフラストラクチャ | `Amazon ElastiCache Redis`の記載がありますが、[02-system-components-requirements.md](../02-system-components-requirements.md)の`## 2.8 キャッシュ機能要件`で利用しない記載があります。 | [6.1 インフラストラクチャ](../README.md#61-インフラストラクチャ) に「利用しない」旨、明記しました。| |
| 3 | 6.3 監視・ログ | Datadogから直接送る機能もあるようですが、SNS経由での送信でよろしいでしょうか？ |  `6.3 監視・ログ` は「設計じみた」「手段じみた」内容がAIによって書かれてしまいました。この章、いらないかも、ですね。トルことを検討します。<br/>[4.4.1 監視設計](../04-non-functional-requirements.md#441-監視設計) に「メールやChatで送信できること。」という要件が書かれています。あくまでこの段階では「要件」ですので、要件定義書内の「手段」については無視してください。とは言いつつ、いろんな解決策の「手段」はご提案ください。| <https://docs.datadoghq.com/ja/monitors/notify/> |
| 4 | 7.1 技術的制約 | `10.60.0.0/22`は本番環境でしょうか？検証、開発環境も確認させていただきたいです。 | [2.4 ネットワーク構成要件](../02-system-components-requirements.md#24-ネットワーク構成要件) のMermaid図にもAIが記載してます。私自身、 **IPレンジ（CIDR）をどのように決めにかかればよいか、よくわかってません。** 相談させてください。<br/><br/>……と思ったら、 [sceptre/templates/vpc.yaml](../../../sceptre/templates/vpc.yaml) に、デフォルトのIPレンジの値として定義されているようでした。 <br/>（CNS中川さん）`10.60.0.0/22`は本番環境でしょうか？検証、開発環境も確認させていただきたいです。また、[bprガイドラインのVPCテンプレート](../../../doc-bpr/guideline/template/vpc/README.md)に「Rクラウドと接続する場合は運用改革担当から払い出されたネットワークレンジを使用すること。そうしないとRクラウドのVPN接続ができない」の記載がございますが、Rクラウドと接続しない場合は自分でネットワークレンジを決めてよい記載にも読み取れました| |
| 5 | 11. 参考手順書 | [システム設計ガイドライン]、[サーバ構成ガイドライン]がパスに空白が含まれているため、リンクになっておりません。 | リンク先が、 `....../3.server architecture/README.md` これを `....../3.server %20architecture/README.md` にしました。（URL Encode）| |

## [02-system-components-requirements.md](../02-system-components-requirements.md)

| No |セクション | 指摘内容 | 回答 | 参考URL |
|----|-----------|---------|--------|----------|
| 1 | 2.6 CDN構成要件 | `静的コンテンツ`が取り消し線になっていますが、[04-non-functional-requirements.md](../04-non-functional-requirements.md)の`### 4.3.4 CDN活用要件`で使う記載がございました。 | bd92511c2249051c8c2df278df6420cfe2594921 のコミットで修正済みかもしれません。[4.4.4 Sorryページ、メンテナンスページ](../04-non-functional-requirements.md#434-cdn活用要件) に記載のとおり、Sorry/メンテページで必要となります。 | |
| 2 | 2.7.2 今後、検討の余地がある項目 | `保存世代数`が明記されているが、`2.7.1 基本構成`で7日間の記載があります。 | [5.2.3 バックアップ対象とその世代や格納先](../05-additional-functional-requirements.md#523-バックアップ対象とその世代や格納先) にも明記されてますね。← `こちらを参照` 的なテイストに変更しました。| |

## [03-security-requirements.md](../03-security-requirements.md)

| No |セクション | 指摘内容 | 回答 | 参考URL |
|----|-----------|---------|--------|----------|
| 1 | 3.3.2 保存データの暗号化 | `Secrets Manager`, `Parameter Store`にもデータ保管するかと思います。またECSを使う場合、EFSを使う可能性もあるかと思います。 | こちらも設計書フェーズで、いろいろとご提案ください。<br/>[AWSのParameter StoreとSecrets Manager、結局どちらを使えばいいのか？比較 #Security - Qiita](https://qiita.com/tomoya_oka/items/a3dd44879eea0d1e3ef5) ふむふむ。 | |

## [04-non-functional-requirements.md](../04-non-functional-requirements.md)

| No |セクション | 指摘内容 | 回答 | 参考URL |
|----|-----------|---------|--------|----------|
| 1 | 4.4.1 監視設計 | `アプリケーションログ監視`以外のログ監視は、監視対象にしないでよろしいでしょうか？OSログやAWSレイヤー（ALBアクセスログなど）もあるかと思います。 | なるほど。鋭い指摘。ログの「監視」まではしてませんが、現オンプレ環境では、S3への転送をしてました。対象となるファイルは、 `/var/log/{secure,message,falcon-sensor}` 。このファイルの監視は **[MUST]** 要件ではありません。んー、思い切って、「監視しない。」に倒してしまってよいかも。S3に転送されたファイルを見返した実績もないですし、これらログファイルを特定文字列で検知するニーズも思い浮かびません。<br/>See. [log-files-transfer-policy.xlsx](https://nttdocomoocx.sharepoint.com/:x:/r/sites/ID-Point/Shared%20Documents/%E4%B8%80%E8%88%AC/gooID%E8%AA%B2%E9%87%91HW%E6%9B%B4%E6%94%B9/General/01_%E6%8A%80%E8%A1%93%E6%A4%9C%E8%A8%8E%E8%B3%87%E6%96%99/2022-08-%E3%83%AD%E3%82%B0%E3%82%B9%E3%83%88%E3%83%AA%E3%83%BC%E3%83%9F%E3%83%B3%E3%82%B0%E5%8C%96%E6%A7%8B%E6%83%B3/log-files-transfer-policy.xlsx?d=wbb19e534e35b4fe39de290e18073da59&csf=1&web=1&e=n2ky5Q) 🔒（ドコモ限り） | |
| 2 | 4.4.1 監視設計 | AutoScalling失敗などの`イベント監視`も項目追加したほうがよいかと思いました。 | なるほど。ありがとうございます。 [4.4.1 監視設計](../04-non-functional-requirements.md#441-監視設計) に追記しました。 `その他、AWSの内部的な構成変更の成功、失敗の検知。` と含みを持たせた曖昧な記載にしてます。思いつくものありましたらご提案ください。 | |
