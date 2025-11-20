# デスクトップ環境を整える

<!-- TOC -->
- [デスクトップ環境を整える](#デスクトップ環境を整える)
  - [1. 方針](#1-方針)
  - [2. 新規プロジェクト参加者が行うべきこと Quick Setup](#2-新規プロジェクト参加者が行うべきこと-quick-setup)
    - [2.1. 前提条件](#21-前提条件)
      - [2.1.1. uv Install](#211-uv-install)
      - [2.1.2. awscli 2.x Install](#212-awscli-2x-install)
        - [2.1.2.1. （方法1）portable awscli を使用する](#2121-方法1portable-awscli-を使用する)
        - [2.1.2.2. （方法2）Windowsパッケージマネージャ "Scoop" を利用してインストールする](#2122-方法2windowsパッケージマネージャ-scoop-を利用してインストールする)
    - [2.2. 手順](#22-手順)
      - [2.2.1. uv sync でエラーとなる場合](#221-uv-sync-でエラーとなる場合)
  - [3. VSCode設定・拡張機能](#3-vscode設定拡張機能)
    - [3.1. setting.json設定](#31-settingjson設定)
    - [3.2. 拡張機能](#32-拡張機能)
<!-- /TOC -->

## 1. 方針

* Cloud Shellからではなく、 **徹底的にデスクトップ上のVSCODEから操作する方針** でセットアップします。
* 理由は、デスクトップ上でCopilotを利用できるようにし、 **徹底的にその恩恵を受けるためです。**
* 一方で、Cloud Shellから実行するのも一つの方法です。アクセスキーの取得や、以降述べる煩わしいンストール作業も不要です。 **しかしそれよりもCopilotの恩恵のほうが大きい** 、と判断しました。

## 2. 新規プロジェクト参加者が行うべきこと　Quick Setup

- このプロジェクトはuvで管理されていますのでuv sync を行うことでこのプロジェクトに必要なツールは全て揃います。
- また、[AGENTS.md](../../AGENTS.md) にプロジェクトルールが記載されています。この記載内容はVSCode起動時に自動的に読み込まれAIエージェントは記載されたルールに従います。

### 2.1. 前提条件

- uv インストール済みであること
- AWS Cli インストール済みであること

![bulb](https://api.iconify.design/twemoji/light-bulb.svg)

<details>
<summary>Tips：その「前提条件」を整える方法</summary>

#### 2.1.1. uv Install

```powershell
PS C:\Users\7637416> powershell -ExecutionPolicy Bypass -c "irm https://github.com/astral-sh/uv/releases/download/0.8.17/uv-installer.ps1 | iex"

# PATHが効いているか？
PS C:\Users\7637416> Get-Command uv

CommandType     Name          Version    Source
-----------     ----          -------    ------
Application     uv.exe        0.0.0.0    C:\Users\7637416\.local\bin\uv.exe
```

#### 2.1.2. awscli 2.x Install

##### 2.1.2.1. （方法1）portable awscli を使用する

- ZeroSpace端末では管理者権限のないユーザなのでportable awscliを使用してください。
- このプロジェクトのルートフォルダにある [portable-awscli.zip](../../portable-awscli.zip) を適当な場所（各ユーザのホームディレクトリ推奨）に解凍し、Windowsのユーザ環境変数のPathに追加してください。
- インストール作業は以上となります。

##### 2.1.2.2. （方法2）Windowsパッケージマネージャ "Scoop" を利用してインストールする

- `.msi` （Windowsインストーラ）しかAWS公式から提供されておらず、それには管理者権限が必要。 → `Scoop` というWindowsパッケージマネージャを利用します。

###### Scoop Install

```powershell
# （ZeroSpace **以外の** 方）
# これが正常に実行できる場合は、これでOK
PS C:\Users\7637416> Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

# ZeroSpaceでは上記コマンドがエラーとなる。
# 「get.scoop.sh のリモートコンテンツを403エラーで取得できない。」という旨のエラー。

#
# 以降、ZeroSpace端末の方。
#

# 苦肉の策で、データセンタ上の任意のサーバからRemote Contentsを取得する。
[k5ito@xadmin-30-pro-ssh-001 <<R-Cloud-One>>~]$ curl -L https://get.scoop.sh > /var/tmp/a.txt

# ローカルへ持ってくる。
PS C:\Users\7637416> scp -p ssh.rc1.pf.goo.ne.jp:/var/tmp/a.txt C:\Temp\a.txt

# Install実行
PS C:\Users\7637416> Invoke-Expression (Get-Content 'C:\Temp\a.txt' -Raw)
Initializing...
(......)
Scoop was installed successfully!
Type 'scoop help' for instructions.
```

<!-- TOC --><a name="awscli-scoopinstall"></a>
###### awscli そのものをScoopにてInstall

```powershell
# インストール
PS C:\Users\7637416> scoop install aws
Installing 'aws' (2.30.0) [64bit] from 'main' bucket
Loading AWSCLIV2-2.30.0.msi from cache
(......)
'aws' (2.30.0) was installed successfully!

# version確認
PS C:\Users\7637416> aws --version
aws-cli/2.30.0 Python/3.13.7 Windows/11 exe/AMD64

# PATHが効いているか？
PS C:\Users\7637416> Get-Command aws

CommandType     Name     Version    Source
-----------     ----     -------    ------
Application     aws.exe  0.0.0.0    C:\Users\7637416\scoop\shims\aws.exe
```

</details>

### 2.2. 手順

```powershell
# 1. このプロジェクトをクローン
git clone <repository-url>
cd <リポジトリ名>

# 2. 依存関係をインストール
uv sync
# もしくは（上記でエラーの場合）
uv sync --native-tls
```

![bulb](https://api.iconify.design/twemoji/warning.svg)

<details>
<summary>uv sync でエラーとなる場合</summary>

#### 2.2.1. uv sync でエラーとなる場合

- （ZeroSpace端末の場合）`uv sync` 実行時に、GithubからPythonのDownloadを試みるも、 エラー `Caused by: client error (Connect)` が発生することがあります。
- その際は以下の方法にて手動でPythonをインストールしてください。

##### （方法1）環境変数を設定し 証明書検証をスキップさせる

```powershell
set CURL_CA_BUNDLE=
set REQUESTS_CA_BUNDLE=
uv sync
```

これでもエラーが出るようであれば次を実行してください。

##### （方法2）Python for Win をインストール

- [https://www.python.org/downloads/release/](https://www.python.org/downloads/release/)
  - [https://www.python.org/downloads/release/python-3137/](https://www.python.org/downloads/release/python-3137/)
  - 2025-09-16現在、最新Verは3.13.7
  - `Custom Install` で、インストール先には `C:\Users\XXXX\AppData/Local/Programs/Python/Python313` を指定すること。
- 環境変数 `PATH` において、 `%USERPROFILE%\AppData\Local\Programs\Python\Python313` を追加。それが上位になるよう設定する。
- PATHが効いているか、確認。

```powershell
PS C:\Users\7637416> Get-Command python

CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Application     python.exe                                         3.13.71... C:\Users\7637416\AppData\Local\Programs\Python\Python313\python.exe
```

- 前項 `uv sync` へ戻ってください。

</details>

```powershell
# 3. 企業環境SSL設定（zero space端末限定 Pythonインタープリター実行時に環境変数を読み込ませることでこのプロジェクトで使用するpythonツールでは証明書を無視するようになります）
uv run python scripts/setup_ssl.py

# 4. sceptreコマンドをテスト
cd sceptre
uv run sceptre --help
uv run sceptre status [prod dev]
```

## 3. VSCode設定・拡張機能

GitHub Copilot開発の上で、必要な設定と追加するVSCode拡張機能を記載する。

### 3.1. setting.json設定

`setting.json`に以下を追加

```jsonc
{
  // EditorConfig有効化
  "editorconfig.enable": true,
  // 保存時に自動整形
  "editor.formatOnSave": true,
  // 保存時にLint/修正を自動実行
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  },
  // Markdownlintルール
  "markdownlint.config": {
    "MD013": false
  }
}
```

### 3.2. 拡張機能

- EditorConfig for VS Code（editorconfig.editorconfig）
- Markdownlint（DavidAnson.vscode-markdownlint）
- JSONLint
- Flake8
- ShellCheck
- PowerShell（PSScriptAnalyzerが含まれている）
- YamlLint Fix
