
<!-- TOC --><a name="idhub-2025-10-17"></a>
# idhub イントロダクション - 2025-10-17

* 「idhubとは」を俯瞰できるような説明をしていきます。
* 主にお客様視点の外部機能。（内部的な構成についても触れていきます。）
* 伊藤、朝長、宮内、（CNS）斎藤、尾岸、藤本、中川
* （![restricted](https://api.iconify.design/flat-color-icons:key.svg) 印はドコモ社のみに限定アクセス。）

## 0. Table of contents

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [1. お客様視点（外部機能）](#1-)
   * [1.1. お客様の操作、動画](#11-)
- [2. システム構成](#2-)
   * [2.1. 管理ツール「認ポ ヘルプツール」](#21-)
   * [2.2. オンプレミス世界でのインスタンス命名規約](#22-)
- [3. 外部対向先と、idhubを利用しているサービス](#3-idhub)
- [4. （ヘンな） 運用面での機能](#4-)
   * [4.1. 影武者](#41-)
   * [4.2. rbash](#42-rbash)

<!-- TOC end -->


<!-- TOC --><a name="1-"></a>
## 1. お客様視点（外部機能）

* [「OCNでたまる・つかう」全容.drawio.svg](https://nttdocomo-my.sharepoint.com/:u:/r/personal/keigo_itou_sk_nttdocomo_com/Documents/%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88/2025-03/%E3%80%8COCN%E3%81%A7%E3%81%9F%E3%81%BE%E3%82%8B%E3%83%BB%E3%81%A4%E3%81%8B%E3%81%86%E3%80%8D%E5%85%A8%E5%AE%B9.drawio.svg?csf=1&web=1&e=kh3aVy)![restricted](https://api.iconify.design/flat-color-icons:key.svg) より

![idhub-overview](./images/idhub-overview.drawio.png)

* 図中の `[3]` に記載の部分が、「大義」、目的。

<!-- TOC --><a name="11-"></a>
### 1.1. お客様の操作、動画

* ![video](https://api.iconify.design/streamline-color:live-video-flat.svg)（動画）[（お客様視点）dアカウント連携から充当まで.mp4](https://nttdocomo-my.sharepoint.com/:v:/p/keigo_itou_sk/EVbhiaGWBdtKkmuenbOx5DUB0-MKoBTs6L_04esPpMesOg?e=BHe2Up) ![restricted](https://api.iconify.design/flat-color-icons:key.svg)


<!-- TOC --><a name="2-"></a>
## 2. システム構成

* （再掲）![オンプレミス現在のシステム構成](../kickoff/images/system.drawio.svg) 
  * それぞれの `コンポーネント` `ロール` を構成しているサーバの一覧は？（＝サーバ名は？）（＝インスタンスは？）
    * → Ansible Playbookの `インベントリ` に答えがある。
    * <https://container.wbo110.goo.ne.jp/repo/nttr/playbook/src/branch/master/inventories/production/inventory.ini> より抜粋

```ini
[idhub_web]
idhub-21-pro-web-001
idhub-21-pro-web-002
idhub-21-pro-web-003
idhub-21-pro-web-004

[idhub_mdb]
idhub-21-pro-mdb-001
idhub-21-pro-mdb-002
idhub-21-pro-mdb-003
idhub-21-pro-mdb-004

(......)
```

<!-- TOC --><a name="21-"></a>
### 2.1. 管理ツール「認ポ ヘルプツール」

* 上図、図中、 `(13) idhub-hlp`
* DEMO <https://idhub.wbo110.goo.ne.jp/d_help/apl/visitor/login> (商用)

<!-- TOC --><a name="22-"></a>
### 2.2. オンプレミス世界でのインスタンス命名規約

* `SERVICE_TYPE`-`GENERATION`-`ENV`-`ROLE`-`SEQ_NUMBER`
  * 例： `idhub-21-pro-web-002`
    * `idhub` というサービスの、
    * 世代 `21` の、
    * `pro` ＝ 商用環境の、
    * `002` ＝ 2つ目のインスタンス。
  * Ansible Playbook の [all.yml](https://container.wbo110.goo.ne.jp/repo/nttr/playbook/src/branch/master/inventories/production/group_vars/all.yml) のあたりに、それをパースしている箇所が。
    * この命名規約を前提としパースロジックに依存する形でIaCが組まれている。 ![warning](https://api.iconify.design/twemoji/warning.svg) **AWSへ移転した際も、これは崩さないほうがいい。** （＝逆に崩す理由もない。）

```yml
# service_type: gooid, idhub
service_type: "{{ inventory_hostname_short.split('-')[0] }}"

# service_code: gooid-21, idhub-21
service_code: "{{ inventory_hostname_short.split('-')[0] ~ '-' ~ inventory_hostname_short.split('-')[1] }}"

# release_env: pro
release_env: "{{ inventory_hostname_short.split('-')[2] }}"
```


<!-- TOC --><a name="3-idhub"></a>
## 3. 外部対向先と、idhubを利用しているサービス

* [対向先俯瞰図 (idhub_system_relationship.drawio.svg)](https://nttdocomoocx.sharepoint.com/:u:/r/sites/ID-Point/Shared%20Documents/%E4%B8%80%E8%88%AC/ID%E8%AA%B2%E9%87%91/idhub/%E8%A8%AD%E8%A8%88%E9%96%A2%E9%80%A3/idhub_system_relationship.drawio.svg?csf=1&web=1&e=3DVmpq) ![restricted](https://api.iconify.design/flat-color-icons:key.svg) より抜粋。

![対向先](./images/idhub_system_relationship.drawio.png)



<!-- TOC --><a name="4-"></a>
## 4. （ヘンな） 運用面での機能

<!-- TOC --><a name="41-"></a>
### 4.1. 影武者

* <https://container.wbo110.goo.ne.jp/repo/nttr/playbook/src/branch/master/roles/kagemusha/README.md> を参照。
* そのサムネ、抜粋

![kagemusha](./images/kagemusha.png)

<!-- TOC --><a name="42-rbash"></a>
### 4.2. rbash

* `Restricted bash` （制限された bash）← 予想。
* 在宅からのSSHだと、
  * （個人情報閲覧を制限するため）実行できるコマンドが限定される。
  * MySQLのカラム単位で、機微な個人情報であるカラムはマスキング表示（ `******` ）されるように設定されている。
* [商用環境へssh.drawio.svg](https://nttdocomo.sharepoint.com/:u:/r/sites/OCNID-ID2/Shared%20Documents/%E5%85%B1%E9%80%9A/ID/%E5%96%B6%E3%81%BF/2025-4-%E5%95%86%E7%94%A8%E7%92%B0%E5%A2%83%E3%81%B8%E8%87%AA%E5%AE%85%E3%81%8B%E3%82%89ssh/%E5%95%86%E7%94%A8%E7%92%B0%E5%A2%83%E3%81%B8ssh.drawio.svg?csf=1&web=1&e=zzapVi) より。

![rbash](./images/rbash.png)

