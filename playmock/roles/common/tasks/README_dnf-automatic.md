# Vulnerability_Response
===================================


## 脆弱性対応の自働化に関するチケット

[GOOID-822 脆弱性対応の自働化](https://bklg.docomo-common.com/backlog/view/GOOID-822)


## 背景と目的


MAMOL-ISMPによる脆弱性検知やAWSのセキュリティーアラート、が定期的に来る  
マニュアルで対応するにはコスパが悪い為ルールを決めてある程度自働化したい  

MAMOL-ISMP  
脆弱性対応のルールを決めて対応を半自働化する  
パッチ適用や緊急時のワークアラウンドな対処など検証や判断が必要なものもあるので完全な自働化は目指さず対応方法をルール化する  

AWSセキュリティ設定リスク  
AWSの設定するセキュリティベストプラクティスに対してルールを設定し、ルールの自働復旧を定義することでアラート検出をトリガーとしたルール適用の自働化を行う  

## 自働化ツールについて

OSや各種パッケージの更新の自働化には[dnf-automatic](https://dnf.readthedocs.io/en/latest/automatic.html) を導入する  
dnf-automaticでは  
アップデート対象として  
全て or セキュリティ（バグ修正や機能拡張は含まない）のみ  
のいずれかを選択可能、  
タスクとして  
リポジトリデータのダウンロードのみ or パッケージのダウンロードのみ or パッケージをダウンロードしてインストール  
のいずれかを選択可能、
適用後の再起動はサービス・OS共に設定可能、  
実行日時がSystemd.time形式で設定可能なツール   

AWSセキュリティ設定リスクに対してはAWS Config にAWSセキュリティベストプラクティスに則ったルールを定義することで  
ベストプラクティスに反する設定を行っても自動的に修正されるようにする  



## パッチ適用ルールの叩き台

1. 月に一度適用する
2. 開発環境は商用環境より1週間程度先行して適用する
3. 適用方法は開発環境はバージョンアップ～OS再起動まで自動的に行う（サービスの再起動のみ必要な場合もこのツールは対応できないためOS再起動）
4. 商用環境はバージョンアップは行わずダウンロードのみとする（アップデート作業は後日リリース作業の一環として行う）
5. ProxySQL Tomcat awscli等現在Ansibleでインストールバージョンを指定しているものやyumを使用しないでインストールしているものに関してはprivate リポジトリの扱いもあるので、一旦このツールを使ったアップデートの対象外とする

開発環境  
・全てを対象にアップデート  
・パッケージのダウンロードからインストール・OS再起動まで行う  
・毎月第1火曜日 10:00に適用  
・実施後メールによる通知を行う
商用環境  
・開発環境に適用したもののみ適用する(ツールの実施日を開発環境と合わせることで担保する)　  
・ツール実施スケジュールを開発と合わせる、ダウンロードのみ行いインストールは行わない
・ダウンロードが完了した時点でメールによる通知を行う  
・月に一度手動で適用（リリース作業）  
・ダウンロードしたパッケージは移動してまとめておいた方が良い（要検討）
ホスト  
・パッチ適用まではこちらで行いOS再起動が必要な場合はインフラチームと連動する  

## 後日検討
1. private リポジトリに関して  
・rpmファイルをRocky Linux のリポジトリから持って来ているのであまり意味が無い（古いバージョンのものが消えてしまったことがあったためprivateリポジトリに持ってきておくようにした -> 現在もRocky Linux のリポジトリでは古いバージョンは削除されて無くなっているが最新のものを適用しなければならないのであればそれは大した問題ではない）  
・Rocky Linux からローカルリポジトリの管理スクリプトが[提供されている](https://github.com/rocky-linux/rocky-tools/tree/main/mirror)ようなのでそちらを使用して運用し維持する方法もある  
・上記スクリプトのオプションから--delete-delay を取り除けば古いバージョンも消えることはない筈  
・private リポジトリを残せばPlaybookの修正や、各サーバでのキャッシュ削除等が不要となるので安全且つ効率が良さそう  
・スキームが確立するまでは/etc/dnf/dnf.conf に除外設定を行い更新を行えないようにする  


[既存の対応方法](https://ticket.id001.goo.ne.jp/projects/idsvc/wiki/Vuls)では指摘されたものをすべて適用しているようなので1.で良いように思われる
但し外部アクセスの影響や依存関係などのリスクが存在するので  
適用されるパッチの事前通知(適用前と適用後のrpm名のdiffのようなイメージ)と  
開発環境で（E2Eテストを使いたい）動作確認済みのもののみ商用環境でも適用するようにする  


MAMOL-ISMPの通知内容とdnf-automaticからのメールとの突合は手作業    
実施タイミングによってはMAMOL-ISMPの通知にしか記載されていないものがある場合もあるが開発環境への適用もあるので基本は翌月対応  

## 課題

### 1. dnf.conf でのアップデート除外パッケージ設定

dnf.conf はpuppet で管理配布している
開発環境は mediainfra-01のひな形を使用している為SO申請が必要
商用環境は mediainfra-01のひな形を使用していない為こちらで自由にコントロールできる

mediainfra-01/dist/mediainfra-01-common/etc/dnf/dnf.conf でひな形を定義
例）gooid-30
~~~
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
~~~

mediainfra-01/manifests/mediainfra-01-common/rc/mediainfra-01-common_rc_yumrepos_centos.pp で配布するファイルとして定義
~~~
	case $operatingsystemmajrelease {
	/7/:{
		file { '/etc/yum.conf':
			owner  => 'root', group => 'root', mode => 0644,
			source => "$mediainfra_01_mi_files/etc/yum.conf.centos7";
		}
	}
	/(8|9)/:{
		file { '/etc/dnf/dnf.conf':
			owner  => 'root', group => 'root', mode => 0644,
			source => "$mediainfra_01_mi_files/etc/dnf/dnf.conf";
		}
	}
~~~


それをmanifestsのrgc/各サーバ_rgc.pp で継承して配布しているだけ 開発環境は特にオーバーライドしてはいない
include 'mediainfra-01-common_rc_yumrepos_centos'
商用環境は mediainfra-01のひな形を使用せず、gooid-21/dist/gooid-21-common/etc/dnf.conf.tpl で
~~~
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=False

# 基盤部門指定の Proxy を経由させます。
proxy=<%= mediainfra_01_webproxy %>
~~~

とproxy設定等を追記して
gooid-21/manifests/gooid-21-common/rc/gooid-21-common_rc_baserepo.pp で配布している
~~~
class gooid-21-common_rc_baserepo {
    #リポジトリファイルの配布
    case $operatingsystemmajrelease {
        /7/:{
                # 基盤部門指定の Proxy を経由させるため配布します。
                file { '/etc/yum.conf':
                    content  => template("${mediainfra_01_sc_template}/etc/yum.conf.tpl"),
                    owner => 'root', group => 'root', mode => 644;
                }

                file { '/etc/yum.repos.d/CentOS-base-mirror.repo':
                    source => "${mediainfra_01_sc_files}/etc/yum.repos.d/CentOS-base-mirror.repo",
                    owner => 'root', group => 'root', mode => 644;
                }
        }
        /(8|9)/:{
                # 基盤部門指定の Proxy を経由させるため配布します。
                file { '/etc/dnf/dnf.conf':
                    content  => template("${mediainfra_01_sc_template}/etc/dnf.conf.tpl"),
                    owner => 'root', group => 'root', mode => 644;
                }

                file { '/etc/yum.repos.d/rockylinux_mirror.repo':
                    source => "${mediainfra_01_sc_files}/etc/yum.repos.d/rockylinux_mirror.repo",
                    owner => 'root', group => 'root', mode => 644;
                }
        }
        default:{
                # 基盤部門指定の Proxy を経由させるため配布します。
                file { '/etc/yum.conf':
                    content  => template("${mediainfra_01_sc_template}/etc/yum.conf.tpl"),
                    owner => 'root', group => 'root', mode => 644;
                }

                file { '/etc/yum.repos.d/CentOS-base-mirror.repo':
                    source => "${mediainfra_01_sc_files}/etc/yum.repos.d/CentOS-base-mirror.repo",
                    owner => 'root', group => 'root', mode => 644;
                }
    }}

    # EPEL Repositoryは基盤部門提供の一元化された定義を参照するようにします。
    include 'mediainfra-01-common_rc_yumrepos_epel'
    if $operatingsystem == 'Rocky' and $operatingsystemmajrelease =='8' {
        include 'gooid-21-common_rc_powertoolsrepo'
    }
}
~~~

### 2. tomcat アップデート

パッケージ自体のアップデートはダウンロードして、/opt 下に解凍して/opt/tomcat へのシンボリックリンクを既存のものから解凍したディレクトリに書き換えれば良さそう  
デプロイしたアプリは/usr/local/tomcat/bin/(一部は idc/bin) に配置されているので影響なし再デプロイは不要  

Ansible のfiles 下にあるjar ファイルなんかはバージョンアップの影響を受けない？それともバージョンを上げるタイミングでこのディレクトリ下のファイルも置き換えている？  




## Rocky Linux の　Errata/Update Sites

https://errata.rockylinux.org/

例えばopenssl や CVE-2022-0778 を検索して、このセキュリティ問題が対処されているかどうかを調べることができます。  
適切なアップデートのエラッタを見つけるためのフィルタ機能もあります。  

## 指摘事項保管フォルダ

MAMOL-ISMP  
SharePoint OCN部IDポイント-IDポイント全員＋技術開発  
ドキュメント > 共通 > ID > 運用 > MAMOL-ISMP対応  

[AWSセキュリティ設定リスクの検出結果](https://nttdocomo.sharepoint.com/sites/822150000/tasoshiki/Shared%20Documents/Forms/AllItems.aspx?FolderCTID=0x0120000EACA6D5B697674A901E2CDB2604995Did=%2Fsites%2F822150000%2Ftasoshiki%2FShared%20Documents%2F38%5F%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E6%A5%AD%E5%8B%99%EF%BC%88%E6%9A%97%E5%8F%B7%E5%8D%B1%E6%AE%86%E5%8C%96%E3%80%81%E3%81%B5%E3%82%8B%E3%81%BE%E3%81%84%E6%A4%9C%E7%9F%A5%E3%80%81%E3%82%AF%E3%83%A9%E3%82%A6%E3%83%89%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%EF%BC%89%2F01%2E%E3%82%AF%E3%83%A9%E3%82%A6%E3%83%89%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%2F%E3%80%90%E6%83%85%E5%A0%B1%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E9%83%A8%5FAWS%E5%88%A9%E7%94%A8%E3%82%B7%E3%82%B9%E3%83%86%E3%83%A0%E3%81%AE%E3%83%A2%E3%83%8B%E3%82%BF%E3%83%AA%E3%83%B3%E3%82%B0%E6%96%BD%E7%AD%96%E3%80%91%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E8%A8%AD%E5%AE%9A%E3%83%AA%E3%82%B9%E3%82%AF%E3%81%AE%E6%A4%9C%E5%87%BA%E7%B5%90%E6%9E%9C&viewid=e101b702%2D0f83%2D466f%2Dbc24%2D049edf681cc3)


### 3. 起動順番

| role         | 1番目                                                  | ２番目                                                                    | ３番目       | ４番目      | ５番目      |
|--------------|------------------------------------------------------|------------------------------------------------------------------------|-----------|----------|----------|
| gooid_web    | proxysql<br/>Playbookではenabled化されていないが実際にはされているものがある | tomcat_idc                                                             | httpd_idc |          |          |
|^             |^                                                     | gbs_spring-green<br/>若しくは<br/>gbs_spring-blue<br/>switchファイルに書いてある方を起動 | httpd_gbs |          |          |
| gooid_mdb    | mariadb<br/>ローリングアップデートなので考慮不要                       |                                                                        |           |          |          |
| gooid_sdb    | mariadb<br/>ローリングアップデートなので考慮不要                       |                                                                        |           |          |          |
| gooid_hlp    | proxysql                                             | tomcat                                                                 | httpd     | gbs_mule |          |
| gooid_batch  | pcsd<br/>pacemaker等の中身は見ていないので適切かどうかは不明              | proxysql                                                               |           |          |          |
| gooid_msg    | pcsd<br/>pacemaker等の中身は見ていないので適切かどうかは不明              | proxysql                                                               | tomcat    | httpd    |          |
| gooid_fgw    | pcsd<br/>pacemaker等の中身は見ていないので適切かどうかは不明              | httpd                                                                  | squid     |          |          |
| gooid_oidc   | proxysql                                             | httpd                                                                  |           |          |          |
| gooid_edb    | mariadb                                              | proxysql                                                               | tomcat    | httpd    | gbs_mule |
| gooid_log    | td-agent                                             |                                                                        |           |          |          |
| gooid_rproxy | httpd                                                |                                                                        |           |          |          |
| idhub_web    | proxysql                                             | tomcat_idc                                                             | httpd_idc |          |          |
| idhub_mdb    | mariadb<br/>ローリングアップデートなので考慮不要                       |                                                                        |           |          |          |
| idhub_sdb    | mariadb<br/>ローリングアップデートなので考慮不要                       |                                                                        |           |          |          |
| idhub_hlp    | proxysql                                             | tomcat                                                                 | httpd     |          |          |
| idhub_batch  | pcsd<br/>pacemaker等の中身は見ていないので適切かどうかは不明              | proxysql                                                               |           |          |          |
| idhub_rproxy | httpd                                                |        |           |          |          |


### 4. 各サービスのユニットファイルについて

サービスの起動順を制御するには各ユニットファイルのAfter若しくはRequiresで行うことができる。挙動の差異については以下を参照

| # | シナリオ                                                                                                                               | OS再起動                                                  | tomcat_idcの再起動                                                   | httpd_idcの再起動                                  | proxysqlを停止した状態でtomcat_idcの再起動                                                                                                                         | proxysqlとtomcat_idcを停止した状態でhttpd_idcの再起動                                                                                     |
|---|------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------|------------------------------------------------------------------|------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| 1 | tomcat_idcのユニットファイルでAfter=proxysql を<br/>httpd_idcのユニットファイルでAfter=proxysql tomcat_idc を記載した場合                                      | proxysql:起動OK<br/>tomcat_idc:起動OK<br/>httpd_idc:起動OK   | proxysql:OK<br/>tomcat_idc:OK<br/>httpd_idc:OK                   | proxysql:OK<br/>tomcat_idc:OK<br/>httpd_idc:OK | proxysql:停止したまま<br/>tomcat_idc:OK<br/>httpd_idc:OK                                                                                                     | proxysql:停止したまま<br/>tomcat_idc:停止したまま<br/>httpd_idc:OK                                                                       |
| 2 | tomcat_idcのユニットファイルでRequires=proxysql を<br/>httpd_idcのユニットファイルでRequires=proxysql tomcat_idc を記載した場合                                | proxysql:起動OK<br/>tomcat_idc:起動OK<br/>httpd_idc:起動OK   | proxysql:OK<br/>tomcat_idc:OK<br/>httpd_idc:tomcat停止時に停止して停止したまま | proxysql:OK<br/>tomcat_idc:OK<br/>httpd_idc:OK | proxysqlを停止した時点で依存するtomcat_idcとそれに依存するhttpd_idcが停止した。<br/>tomcat_idcを起動すると起動の前提条件であるproxysqlが起動<br/>proxysql:OK<br/>tomcat_idc:OK<br/>httpd_idc:停止したまま | httpd_idcを起動すると起動の前提条件であるtomcat_idcと、tomcat_idcの起動条件であるproxysqlが一気通貫で起動する<br/>proxysql:OK<br/>tomcat_idc:OK<br/>httpd_idc:OK |
| 3 | proxysqlをdisable化してOS再起動する<br/>tomcat_idcのユニットファイルでAfter=proxysql を<br/>httpd_idcのユニットファイルでAfter=proxysql tomcat_idc を記載した場合       | proxysql:停止したまま<br/>tomcat_idc:起動OK<br/>httpd_idc:起動OK | ー | ー | ー | ー |
| 4 | proxysqlをdisable化してOS再起動する<br/>tomcat_idcのユニットファイルでRequires=proxysql を<br/>httpd_idcのユニットファイルでRequires=proxysql tomcat_idc を記載した場合 | proxysql:起動OK<br/>tomcat_idc:起動OK<br/>httpd_idc:起動OK   | ー | ー | ー | ー |