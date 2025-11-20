# IAM User 作成・管理方法

<!-- TOC -->
- [IAM User 作成・管理方法](#iam-user-作成管理方法)
  - [1. 概要](#1-概要)
  - [2. ユーザ、グループ設計思想](#2-ユーザグループ設計思想)
  - [3. ファイル構成](#3-ファイル構成)
    - [3.1. テンプレート](#31-テンプレート)
    - [3.2. 設定ファイル](#32-設定ファイル)
  - [4. デプロイ手順](#4-デプロイ手順)
    - [4.1. IAMグループとMFA Policyの作成（初回のみ実行）](#41-iamグループとmfa-policyの作成初回のみ実行)
    - [4.2. 個別ユーザーの作成](#42-個別ユーザーの作成)
    - [4.3. 新しいユーザーの追加](#43-新しいユーザーの追加)
    - [4.4. Tips](#44-tips)
      - [4.4.1. ユーザを削除していったんリセットする](#441-ユーザを削除していったんリセットする)
  - [5. 背景](#5-背景)
  - [6. パラメータ](#6-パラメータ)
    - [6.1. iam-single-user.yaml](#61-iam-single-useryaml)
    - [6.2. iam-groups.yaml](#62-iam-groupsyaml)
  - [7. ファイル命名規則](#7-ファイル命名規則)
  - [8. 注意事項](#8-注意事項)
  - [9. 初回ログイン手順](#9-初回ログイン手順)
    - [9.1. （前提情報）AWSアカウント](#91-前提情報awsアカウント)
      - [9.1.1. dev](#911-dev)
      - [9.1.2. prod](#912-prod)
    - [9.2. IAMユーザー作成後の初期設定](#92-iamユーザー作成後の初期設定)
      - [9.2.1. ステップ1: AWSコンソールへログイン](#921-ステップ1-awsコンソールへログイン)
      - [9.2.2. ステップ2: 初回パスワード変更](#922-ステップ2-初回パスワード変更)
      - [9.2.3. ステップ3: MFA（多要素認証）の設定](#923-ステップ3-mfa多要素認証の設定)
      - [9.2.4. ステップ4: MFA動作確認](#924-ステップ4-mfa動作確認)
    - [9.3. MFA設定完了後のアクセス権限](#93-mfa設定完了後のアクセス権限)
      - [9.3.1. AdminUserGroup メンバー](#931-adminusergroup-メンバー)
      - [9.3.2. PowerUserGroup メンバー](#932-powerusergroup-メンバー)
    - [9.4. 注意事項](#94-注意事項)
<!-- /TOC -->

## 1. 概要

- ユーザーごとに個別の設定ファイルを作成し、単一ユーザーテンプレートを使用してIAMユーザーを管理します。

## 2. ユーザ、グループ設計思想

![overview](./img/iam-user-overview.drawio.svg)

- シンプルに2つのグループから成る。（ `AdminUserGroup` と `PowerUserGroup` ）
- グループに対してIAMポリシー（権限）を付与。
  - `AdminUserGroup` が当社の社員 / その他、外部コラボレータを `PowerUserGroup` に所属させることを想定。

## 3. ファイル構成

### 3.1. テンプレート

- `iam-groups.yaml`: IAMグループ管理用（共通）
- `iam-mfa-policy.yaml`: MFA強制ポリシー（共通）
- `iam-single-user.yaml`: 単一ユーザー作成用

### 3.2. 設定ファイル

- `config/account-resource/iam-mfa-policy.yaml`: MFA強制ポリシー設定
- `config/account-resource/[dev|prod]/iam-groups.yaml`: IAMグループ設定
- `config/account-resource/[dev|prod]/iam-user-{username}.yaml`: 各ユーザー個別設定

## 4. デプロイ手順

### 4.1. IAMグループとMFA Policyの作成（初回のみ実行）

```bash
cd sceptre
# `prod` の部分は環境に応じて `dev` 等にしてください。
sceptre launch account-resource/iam-mfa-policy.yaml
sceptre launch account-resource/prod/iam-groups.yaml
```

### 4.2. 個別ユーザーの作成

```bash
# `prod` の部分は環境に応じて `dev` 等にしてください。

# Admin権限ユーザーの作成
sceptre launch account-resource/prod/iam-user-keigo-itou-sk.yaml

# PowerUser権限ユーザーの作成
sceptre launch account-resource/prod/iam-user-cns-ogishi.yaml
```

### 4.3. 新しいユーザーの追加

新しいユーザーを追加する場合：

- まずIAMユーザ名を決定します。
  - （当社社員、例）メールアドレスが `keigo.itou.sk@nttdocomo.com` ならば、 → `keigo.itou.sk` （ ＠より前の文字列）
  - （協力会社社員、例） メールアドレスが、 `michael@vendor.co.jp` ならば、 → `vendor-michael` （会社名のPrefixをつけ、そのあとは ＠以前の文字列）
    - 例： `cns-ogishi`

1. 既存の設定ファイルをコピー

```bash
# `prod` の部分は環境に応じて `dev` 等にしてください。

# AdminUserGroup所属のIAMユーザの場合
cp config/account-resource/prod/iam-user-keigo-itou-sk.yaml config/account-resource/prod/iam-user-<NEW USER NAME>.yaml

# PowerUserGroup所属のIAMユーザの場合
cp config/account-resource/prod/iam-user-sample-power-user.yaml config/account-resource/prod/iam-user-<NEW-USER-NAME>.yaml
```

2. 設定ファイルを編集

```yaml
parameters:
  IAMUserName: "cns-ogishi"    # ここにはIAMユーザ名を指定する。
  IAMGroupName: "PowerUserGroup"  # または "AdminUserGroup"
```

3. デプロイ

```bash
sceptre launch account-resource/iam-user-cns-ogishi".yaml
```

### 4.4. Tips

#### 4.4.1. ユーザを削除していったんリセットする

- IAMユーザーにアクティブなMFAデバイスやセッショントークンが関連付けられていると、CloudFormationでは削除できません。
- MFAデバイスやアクセスキーなどをいったん削除し、最後にユーザ削除します。

<details>
<summary>削除する例</summary>

```powershell
# MFAデバイスの確認:
aws iam list-mfa-devices --user-name "keigo.itou.sk"

# MFAデバイスの無効化:
aws iam deactivate-mfa-device --user-name "keigo.itou.sk" --serial-number "arn:aws:iam::007773581311:mfa/Browser-QR-extension-and-business-mobile-phone"

# 仮想MFAデバイスの削除: aws iam delete-virtual-mfa-device
aws iam delete-virtual-mfa-device --serial-number "arn:aws:iam::007773581311:mfa/Browser-QR-extension-and-business-mobile-phone"

# アクセスキーの確認・削除
aws iam list-access-keys --user-name "keigo.itou.sk"

# スタック削除の再試行: 
sceptre delete account-resource/prod/iam-user-keigo-itou-sk.yaml
```

</details>

## 5. 背景

- 1つのUser定義ファイルに複数ユーザを定義する形を目指したが依存関係が複雑、可読性も下がるため、1ユーザあたり1つの定義ファイルとした。

1. **明確な管理**: 1ユーザー = 1設定ファイル
2. **個別制御**: ユーザーごとに独立したスタック
3. **簡単な追加**: 設定ファイルをコピーして編集するだけ
4. **依存関係**: グループが先に作成されることを保証
5. **削除の安全性**: 個別ユーザーだけを削除可能

## 6. パラメータ

### 6.1. iam-single-user.yaml

- `IAMUserName`: ユーザー名（必須）
- `IAMGroupName`: 割り当てるグループ名（AdminUserGroup/PowerUserGroup）
- `InitialPassword`: 初回ログイン用パスワード（必須、初回変更要求有効）
- `AdminUserGroupName`: Admin群名（デフォルト: "AdminUserGroup"）
- `PowerUserGroupName`: PowerUser群名（デフォルト: "PowerUserGroup"）

### 6.2. iam-groups.yaml

- `AdminUserGroupName`: Admin群名（デフォルト: "AdminUserGroup"）
- `PowerUserGroupName`: PowerUser群名（デフォルト: "PowerUserGroup"）

## 7. ファイル命名規則

設定ファイル: `iam-user-{username}.yaml`

例：

- `iam-user-keigo-itou-sk.yaml`
- `iam-user-cns-ogishi.yaml`

## 8. 注意事項

![warning](https://api.iconify.design/twemoji/warning.svg)

1. IAMグループとMFA Policyは最初に作成する必要があります
2. 各ユーザースタックはグループスタックに依存しています
3. MFAポリシーは各ユーザーごとに個別作成されます
4. ユーザー削除時は対応するスタックを削除してください
5. ファイル名にはユーザー名を含めて管理しやすくしてください

## 9. 初回ログイン手順

### 9.1. （前提情報）AWSアカウント

- 検証環境 (dev), 商用環境 (prod) 間で、AWSアカウントのレベルで分けています。
（つまり、1つのAWSアカウント内で検証や商用環境を構築するわけではありません。）

#### 9.1.1. dev

- Sign-in URL : <https://gooid-idhub-aws-dev.signin.aws.amazon.com/console>
  - Account ID : `910230630316`
  - Alias : `gooid-idhub-aws-dev`

#### 9.1.2. prod

- Sign-in URL : <https://gooid-idhub-aws-prod.signin.aws.amazon.com/console>
  - Account ID : `007773581311`
  - Alias : `gooid-idhub-aws-prod`

### 9.2. IAMユーザー作成後の初期設定

IAMユーザーが作成されたら、以下の手順で初回ログインとMFA設定を行います：

#### 9.2.1. ステップ1: AWSコンソールへログイン

1. **ログインURL**: 前項 `9.1. （前提情報）AWSアカウント` 参照
2. **ユーザー名**: （当社社員）メールアドレスの＠より前 例．`keigo.itou.sk` 、（協力会社） 例． `cns-xogishi`
3. **初期パスワード**: `TempPassword123!`

#### 9.2.2. ステップ2: 初回パスワード変更

- 初回ログイン時に新しいパスワードの設定が要求されます
- 8文字以上の強固なパスワードを設定してください

#### 9.2.3. ステップ3: MFA（多要素認証）の設定

**重要**: MFAを設定するまで、ほとんどのAWSサービスにアクセスできません。

1. **IAMコンソールに移動**:
   - サービス検索で「IAM」を検索してクリック

2. **MFAデバイスの追加**:

   ```text
   IAM → Users → [あなたのユーザー名] → Security credentials → Multi-factor authentication (MFA)
   ```

3. **MFAデバイスの選択**:

   - **Virtual MFA device** (推奨): スマートフォンアプリ使用
     - （Tips） おすすめEdgeプラグイン [Authenticator: 2FA Client](https://microsoftedge.microsoft.com/addons/detail/authenticator-2fa-client/ocglkepbibnalbgmbachknglpdipeoio?refid=bingshortanswersdownload) で、スマホとこのプラグインに同じQRを読み込ませると、MFA設定数を節約できる。スマホとブラウザで同じPINコードを得られる。
   - **Hardware TOTP token**: 物理デバイス使用
   - **Hardware FIDO security key**: FIDO対応キー使用

4. **Virtual MFA設定手順**:

   ```text
   1. [Assign MFA device] をクリック
   2. "Virtual MFA device" を選択
   3. QRコードをスマートフォンアプリでスキャン
      推奨アプリ: Google Authenticator, Microsoft Authenticator
   4. 連続する2つのMFAコードを入力
   5. [Assign MFA] をクリック
   ```

#### 9.2.4. ステップ4: MFA動作確認

1. 一度ログアウト
2. 再度ログイン（ユーザー名、パスワード + MFAコード）
3. 各種AWSサービスにアクセス可能か確認

### 9.3. MFA設定完了後のアクセス権限

#### 9.3.1. AdminUserGroup メンバー

- AWS管理者権限（AdministratorAccess）
- MFA認証後は全てのAWSサービスにアクセス可能

#### 9.3.2. PowerUserGroup メンバー

- AWS PowerUser権限（PowerUserAccess）
- IAM関連操作は制限あり
- MFA認証後は対象サービスにアクセス可能

### 9.4. 注意事項

![warning](https://api.iconify.design/twemoji/warning.svg)

- **MFA未設定時**: 自分のパスワード変更とMFA設定以外の操作は拒否されます
- **MFAデバイス紛失時**: 管理者に連絡して新しいMFAデバイスの設定を依頼してください
- **パスワード忘れ**: 管理者がAWSコンソールから新しい一時パスワードを設定できます
