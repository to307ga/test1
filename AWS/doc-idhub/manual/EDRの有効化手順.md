# edr適用手順

## 目次
- [edr適用手順](#edr適用手順)
  - [目次](#目次)
  - [1.SecretsManagerにEDR認証情報を登録](#sec1)
    - [1-1.falcon-sensorライセンス情報の取得](#sec1-1)
    - [1-2.ライセンス情報の設定用シークレット作成](#sec1-2)
    - [1-3.ライセンス情報をシークレットへ登録](#sec1-3)
  - [2.EDRイメージ登録テンプレートの実行](#sec2)
    - [2-1.falcon-sensorイメージ登録用のCodeBuild環境構築](#sec2-1)
    - [2-2.falcon-sensorイメージの登録](#sec2-2)
  - [3.ECSタスク定義テンプレートを編集＆ECSへ反映](#sec3)
    - [3-1.コンテナ定義を変更](#sec3-1)
    - [3-2.タスクを再起動させてfalcon-sensorを起動](#sec3-2)
    - [3-3.falcon-sensorの起動確認用の情報取得](#sec3-3)
    - [3-4.falcon-sensorの起動確認](#sec3-4)
  - [4.EDRイメージ登録テンプレートの定期実行](#sec4)
    - [4-1.falcon-sensorイメージ更新のスケジュール有効化](#sec4-1)
    - [4-2.スケジュールの確認](#sec4-2)

ECS Fargateにてfalcon-sensorを適用するまでの手順を説明する
手順は大きく分けて
1. SecretsManagerにEDR認証情報を登録  
SecretsManagerにfalcon-sensorイメージを取得する為のアカウント情報とfalcon-sensorを起動させるためのアカウント情報を登録する
2. EDRイメージ登録テンプレートの実行  
EDRイメージ登録用のCodebuileの構築＆実行と実行後にECRへイメージが正しく登録されたことを確認する
3. ECSタスク定義テンプレートを編集＆ECSへ反映  
タスク定義をAppコンテナにてfalcon-sensorを起動するように変更とECS再構築による反映を実施  
実施後にfalcon-sensorが正しく起動していることの確認も行う
4. EDRイメージ登録テンプレートの定期実行  
EDRイメージを定期的に更新する為に、EventBridgeのスケジューラを有効にする  
※デフォルト無効としている

<a id="sec1"></a>
## 1.SecretsManagerにEDR認証情報を登録
falcon-sensorイメージの取得、起動に必要なライセンス情報をSecretsManagerにて管理する  
管理するシークレットについては、キー名のみ用意したテンプレートを作成し、値については手動で登録する  
※ライセンス情報を直接テンプレートに記載するのはセキュリティ違反となる(githubにて外部に公開される恐れがある）

<a id="sec1-1"></a>
### 1-1.falcon-sensorライセンス情報の取得
情報セキュリティに問い合わせを行い、ECS Fargate用のfalcon-sensorの以下４つの情報を頂く  
この情報は [1-3.ライセンス情報をシークレットへ登録](#sec1-3) にてSecretsManagerへ登録する
- falcon-sensorイメージ取得用クライアントID
- falcon-sensorイメージ取得用シークレット
- falcon-sensor起動に指定するクライアントID
- falcon-sensor起動に指定するタグ  

<a id="sec1-2"></a>
### 1-2.ライセンス情報の設定用のシークレット作成
ライセンス情報を管理する為のキー名だけを用意したシークレットを作成する  
階層の移動
```
$ cd sceptre
```
構築
```
$ sceptre launch tst/app/edr/secrets.yaml
Do you want to launch 'tst/app/edr/secrets.yaml' [y/N]: y
[2025-05-08 10:27:19] - tst/app/edr/secrets - Launching Stack
[2025-05-08 10:27:20] - tst/app/edr/secrets - Stack is in the PENDING state
[2025-05-08 10:27:20] - tst/app/edr/secrets - Creating Stack
：
：中略
[2025-05-08 10:27:29] - tst/app/edr/secrets ocx-standard-template-tst-app-edr-secrets AWS::CloudFormation::Stack CREATE_COMPLETE
```

<a id="sec1-3"></a>
### 1-3.ライセンス情報をシークレットへ登録
secrets.yamlにて作成されたシークレットのシークレット名を取得  
SecretsManagerのコンソールにて取得したシークレットにアクセスし、シークレットの値を編集する
```
$ aws secretsmanager list-secrets |jq -r .SecretList[].Name|grep falcon-sensor
twg-falcon-sensor


■複数出力された場合
「EnvShort / SystemName」にて判断する
例：
EnvShort: t
SystemName: wg
接頭辞に「twg」が付与されたシークレットが今回作成されたシークレットとなる
```
作成されたシークレットにfalcon-sensorのライセンス情報を設定する  
構築直後は、キーのみで値は空の状態である  
※「dummy_key」はCloudFormationの仕様上、作成したキーであり無視してよい
![](./img/falcon-sensorシークレット情報.png)

```
シークレットキー
   client_id:          <falcon-sensorイメージ取得用クライアントID>
   secret:             <falcon-sensorイメージ取得用シークレット>
   cid:                <falcon-sensor起動に指定するクライアントID>
   falcon-sensor_tags: <falcon-sensor起動に指定するタグ>
```
【注意事項】  
templatesの「app/edr/secrets.yaml」を故意に修正して、シークレットを更新した場合、シークレットに設定したfalcon-sensorのライセンス情報が削除(値が空に戻る)されます  

<a id="sec2"></a>
## 2.falcon-sensorイメージ登録
ECRへのfalcon-sensorイメージ登録の手順は  
[ECS with Fargateへのインストール手順](http://hdsrv015.hdsrv.gvm-jp.groupis-gn.ntt/confluence/pages/viewpage.action?pageId=280364063)の■デプロイ手順内リンクの「ESC with FargateへのコンテナEDRエージェントデプロイメントガイド」(以下EDRエージェントデプロイメントガイドと記載)の「センサーイメージを取得し、ECRにプッシュする」に手順が記載されている  
この手順をCodeBuildにて実装することで、CodeBuildを実行するだけでECRへfalcon-sensorイメージの登録を実現した  
但し以下の差分あり
- latestタグ(最新版)のイメージがECRへPushされるが、最新版での不具合にてサービス影響が出たことがある為、過去バージョンのイメージを使用（Defaultは2つ前のバージョンを使用)
- 指定したタグの他にバージョンもタグとするとこで、ECRに登録されたイメージのバージョンを確認できるようにした  
  
その他にCodeBuildを定期的に実行するEventBridgeスケジュールも用意（Defaultでは無効としている)
![](../guideline/template/app/edr/img/edr-build-related.drawio.png)

<a id="sec2-1"></a>
### 2-1.falcon-sensorイメージ登録用のCodeBuild環境構築
階層の移動
```
$ cd sceptre
```
構築
```
$ sceptre launch tst/app/edr/build.yaml
Do you want to launch 'tst/app/edr/build.yaml' [y/N]: y
[2025-04-15 14:33:36] - tst/app/ecr - Launching Stack
[2025-04-15 14:33:37] - tst/app/ecr - Stack is in the UPDATE_COMPLETE state
[2025-04-15 14:33:37] - tst/app/ecr - Updating Stack
：
：中略
[2025-04-15 14:34:23] - tst/app/edr/build ocx-standard-template-tst-app-edr-build AWS::CloudFormation::Stack CREATE_COMPLETE
```

<a id="sec2-2"></a>
### 2-2.falcon-sensorイメージの登録
CodeBuild実行によるイメージ登録＆登録確認までの概要
- CodeBuildを実行する為に必要なプロジェクト名の取得
- CodeBuildの実行
- CodeBuildの実行した際のビルドIDを取得
- ビルドIDからビルド結果を確認
- イメージ登録用のECR名を取得
- イメージ登録用のECRにイメージが登録されたことを確認

ビルドプロジェクトのプロジェクト名確認  
```
$ aws codebuild list-projects |jq -r .projects[]|grep push_falcon-sensor-image_to_ecr
twg-push_falcon-sensor-image_to_ecr  ★プロジェクト名が出力


■複数出力された場合
「EnvShort / SystemName」にて判断する
例：
EnvShort: t
SystemName: wg
接頭辞に「twg」が付与されたプロジェクトが今回作成されたプロジェクトである
```
ビルドプロジェクトのビルド実行  
「--project-name」に指定するプロジェクト名は上記で確認したプロジェクト名を指定
```
$ aws codebuild start-build --project-name twg-push_falcon-sensor-image_to_ecr
{
    "build": {
：
：中略
:[Space]押下することで(END)まで出力させる
 ※[q]押下で出力を途中キャンセルすることも可能
：
：中略
(END)  [q]押下でコマンドから抜ける
```
ビルド結果確認のためにビルドIDを取得する  
※「--max-items 1」の指定にて最新のビルド情報のみ取得となる
```
$ aws codebuild list-builds --max-items 1
{
    "ids": [
        "push_falcon-sensor-image_to_ecr:348ec744-ef21-4bcc-8771-1228648aaaef"  ★このビルドIDを確認に使用
    ],
    "NextToken": "eyJuZXh0VG9rZW4iOiBudWxsLCAiYm90b190cnVuY2F0ZV9hbW91bnQiOiAxfQ=="
}
```
ビルド結果を確認
```
$ aws codebuild batch-get-builds --ids push_falcon-sensor-image_to_ecr:348ec744-ef21-4bcc-8771-1228648aaaef |jq -r .builds[].buildStatus 
IN_PROGRESS ★ビルド中の為、しばらく待ってからコマンドを再実行
SUCCEEDED   ★正常終了ならECRにイメージが登録されたことを確認
FAILED      ★異常終了の場合、どのフェーズで異常終了したかを確認
```
ビルド異常終了時の確認
```
aws codebuild batch-get-builds --ids push_falcon-sensor-image_to_ecr:348ec744-ef21-4bcc-8771-1228648aaaef |jq .builds[].phases

phaseStatusが「FAILED」となっているフェーズのmessage内容を確認
```
ECR名の確認  
※falcon-sensorイメージ登録用のECRは、「app/deploy.yaml」にて作成済である
```
$ aws ecr describe-repositories |jq -r .repositories[].repositoryName |grep falcon-sensor/falcon-container
twg-falcon-sensor/falcon-container  ★ECR名が出力


■複数出力された場合
「EnvShort / SystemName」にて判断する
例：
EnvShort: t
SystemName: wg
接頭辞に「twg」が付与された物が必要なECRである
```
ECRにイメージが登録されたことを確認  
「--repository-name」に指定するECR名は 上記で確認したECR名である
```
$ aws ecr list-images --repository-name twg-falcon-sensor/falcon-container
{
    "imageIds": [
        {
            "imageDigest": "sha256:9b735e1acfa40c312e69c3fdfd7106013232e432497580da178735245d81e4d6", ★
            "imageTag": "N-2_version"
        },
        {
            "imageDigest": "sha256:9b735e1acfa40c312e69c3fdfd7106013232e432497580da178735245d81e4d6", ★
            "imageTag": "7.22.0-6104.container.x86_64.Release.US-1"
        },
        {
            "imageDigest": "sha256:225852255852c3532798602edb9166bef7abbdb4906448c2fb804c9fd794264a",
            "imageTag": "7.21.0-6003.container.x86_64.Release.US-1"
        },
        {
            "imageDigest": "sha256:299f0af6575f793049ce1226b0b86cbc60efde3d91f36b0ccd91c38827dd7457",
            "imageTag": "7.20.0-5908.container.x86_64.Release.US-1"
        }
    ]
}

指定したタグとバージョンのタグが登録されていることを確認
上記例では
指定タグ「N-2_version」とバージョンタグ「7.22.0-6104.container.x86_64.Release.US-1」のsha256ハッシュが同一なので
「N-2_version」のバージョンは「7.22.0-6104」である事がわかる
```

<a id="sec3"></a>
## 3.コンテナにfalcon-sensorを適用
EDRエージェントデプロイメントガイドでは、パッチ適用ツールにてタスク定義にfalcon-sensor起動用のパッチを当てるが、本templateでは既にコメントとして定義済である  
以下の手順で適用＆踏査確認を行う
- パッチのコメントを解除することでコンテナ内に「falcon-sensor」を起動させる定義を有効
- ECSタスクを再起動
- ECSタスク再起動後、コンテナにログインする為の情報を取得
- コンテナにログインしてfalcon-sensorの正常起動を確認

<a id="sec3-1"></a>
### 3-1.コンテナ定義を変更
テンプレート内のコメントを解除することでfalcon-sensor起動を有効にする  
階層の移動
```
$ cd sceptre
```
コンテナ定義ファイルの変更
```
$ vi templates/app/taskdefinition.yaml

「:%s/###//g」にてコメントを解除する
```

<details>

<summary>パッチの内容について</summary>

「AWS::ECS::TaskDefinition」定義にパッチが適用される

- Fargateタスクのエフェメラルストレージを設定  
falcon-sensorイメージからコピーするバイナリ情報を格納するためのストレージを用意する
```
  Volumes:
    - Name: "crowdstrike-falcon-volume"
```

- falcon-sensor初期構築コンテナの追加  
本コンテナがfalcon-sensorイメージからバイナリ情報をFargateタスクのエフェメラルストレージへコピーを実施する  
コピーが完了次第、本コンテナは停止する
```
  - Name: "crowdstrike-falcon-init-container"
    ReadonlyRootFilesystem: true
    User: "0:0"
    EntryPoint:
      - "/bin/bash"
      - "-c"
      - "chmod u+rwx /tmp/CrowdStrike && mkdir /tmp/CrowdStrike/rootfs && cp -r /bin /etc /lib64 /usr /entrypoint-ecs.sh /tmp/CrowdStrike/rootfs && chmod -R a=rX /tmp/CrowdStrike"
    Essential: "false"
    Image: <ECRに登録したfalcon-sensorイメージのURI>
    MountPoints:
      - ContainerPath: "/tmp/CrowdStrike"
        ReadOnly: "false"
        SourceVolume: "crowdstrike-falcon-volume"
```

- falcon-sensorを起動させるコンテナへの設定追加
  - falcon-sensor初期構築コンテナが終了した後、起動させるために依存関係を設定
```
    DependsOn:
      - Condition: "COMPLETE"
        ContainerName: "crowdstrike-falcon-init-container"
```
  - falcon-sensorがシステムをトーレス可能とする為にSYS_PTRCEを有効にする
```
    LinuxParameters:
      Capabilities:
        Add:
          - "SYS_PTRACE"
```
  - バイナリ情報がコピーされたFargateタスクのエフェメラルストレージをマウント
```
    MountPoints:
      - SourceVolume: "crowdstrike-falcon-volume"
        ContainerPath: "/tmp/CrowdStrike"
        ReadOnly: "true"
```
  - falcon-sensorを起動させる為にEntryPointを変更
```
    EntryPoint:
      - "/tmp/CrowdStrike/rootfs/lib64/ld-linux-x86-64.so.2"
      - "--library-path"
      - "/tmp/CrowdStrike/rootfs/lib64"
      - "/tmp/CrowdStrike/rootfs/bin/bash"
      - "/tmp/CrowdStrike/rootfs/entrypoint-ecs.sh"
      - <本コンテナに設定されていたのエントリポイント>"
```
  - falcon-sensorを起動に必要なパラメータを変数に設定  
cidとtagsのパラメータ値はSecretsManagerから取得
```
    Environment:
      - Name: "FALCONCTL_OPTS"
        Value: !Join
          - ''
          - - '--cid='
            - '{{resolve:secretsmanager:'
            - !Sub ${EnvShort}${SystemName}-falcon-sensor
            - ':SecretString:cid::}}'
            - ' --tags='
            - '{{resolve:secretsmanager:'
            - !Sub ${EnvShort}${SystemName}-falcon-sensor
            - ':SecretString:falcon-sensor_tags::}}'
```

</details>

<a id="sec3-2"></a>
### 3-2.タスクを再起動させてfalcon-sensorを起動
コンテナ定義変更をECSタスクへ反映させる為にECSタスクを再起動させる必要があるが  
「tst/app/taskdefinition.yaml」を「sceptre launch」にて更新してもタスク定義のみ更新され、ECSタスクは再起動されない  
ECSタスクを再起動させるには「tst/app/deploy.yaml」を「sceptre launch」にて更新する必要がある  
階層の移動
```
$ cd sceptre
```
コンテナ定義変更を適用
```
$ sceptre launch tst/app/deploy.yaml
Do you want to launch 'tst/app/deploy.yaml' [y/N]: y
[2025-05-08 13:29:50] - tst/s3 - Launching Stack
[2025-05-08 13:29:50] - tst/app/ecr - Launching Stack
[2025-05-08 13:29:50] - tst/fixed-natgw-eip - Launching Stack
[2025-05-08 13:29:51] - tst/app/ecr - Stack is in the CREATE_COMPLETE state
[2025-05-08 13:29:51] - tst/app/ecr - Updating Stack
：
：中略
[2025-05-08 13:33:47] - tst/app/deploy ocx-standard-template-tst-app-deploy AWS::CloudFormation::Stack UPDATE_COMPLETE
```
「sceptre launch」が完了しない場合は、falcon-sensorが正常に起動できずにコンテナが起動、停止を繰り返している状態のため  
CloudFomationのコンソールにて「スタックの更新をキャンセル」にて更新をキャンセルさせる必要がある  
※原因の調査はログを確認となるが、標準templateではログが設定されていないので個別に設定したログにて確認(エラーの原因は「cid」誤りである可能性が高い)
```
[2025-05-08 15:39:06] - tst/app/deploy EcsService AWS::ECS::Service UPDATE_IN_PROGRESS
[2025-05-08 16:12:48] - tst/app/deploy ocx-standard-template-tst-app-deploy AWS::CloudFormation::Stack UPDATE_ROLLBACK_IN_PROGRESS User Initiated
[2025-05-08 16:12:48] - tst/app/deploy EcsService AWS::ECS::Service UPDATE_FAILED Resource update cancelled  ★キャンセルを確認

[2025-05-08 16:12:57] - tst/app/deploy EcsService AWS::ECS::Service UPDATE_IN_PROGRESS
[2025-05-08 16:21:07] - tst/app/deploy ocx-standard-template-tst-app-deploy AWS::CloudFormation::Stack UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS
[2025-05-08 16:21:07] - tst/app/deploy ocx-standard-template-tst-app-deploy AWS::CloudFormation::Stack UPDATE_ROLLBACK_COMPLETE  ★キャンセル完了するまで待つ（今回は9分近くかかっている）
```

<a id="sec3-3"></a>
### 3-3.falcon-sensorの起動確認用の情報取得
コンテナにログインする為の情報を取得する
- クラスタ名
- タスクARN  
- コンテナ名

クラスタ名の取得
```
$ aws ecs list-clusters
{
    "clusterArns": [
        "arn:aws:ecs:ap-northeast-1:875833169107:cluster/twg-web-cluster"
    ]
}

上記の場合「twg-web-cluster」がクラスタ名である
```
タスクARN＆タスクIDの取得
「--cluster」にはクラスタ名を指定する
```
$ aws ecs list-tasks --cluster twg-web-cluster
{
    "taskArns": [
        "arn:aws:ecs:ap-northeast-1:875833169107:task/twg-web-cluster/d7bd3dd0e02a4ca19b7e5b9610f3ba77"
    ]
}

上記の場合「d7bd3dd0e02a4ca19b7e5b9610f3ba77」がタスクIDである
```
コンテナ名の取得  
「--cluster」にはクラスタ名を指定  
「--tasks」にはタスクIDを指定する  
```
$ aws ecs describe-tasks --cluster twg-web-cluster --tasks d7bd3dd0e02a4ca19b7e5b9610f3ba77 |jq -r .tasks[].containers[].name
twg-app-container
crowdstrike-falcon-init-container
aws-guardduty-agent-fThKrDN

上記ではコンテナが3つ検知されるが、falcon-sensorが起動しているコンテナは「twg-app-container」となる
```

<a id="sec3-4"></a>
### 3-4.falcon-sensorの起動確認
コンテナへログインして、falconctlコマンドにて管理情報が設定されているか確認
「--cluster」にはクラスタ名を指定  
「--task」にはタスクARNを指定  
「--container」にはコンテナ名を指定する  
```
$ aws ecs execute-command \
    --interactive \
    --command "/bin/bash" \
    --cluster twg-web-cluster \
    --task arn:aws:ecs:ap-northeast-1:875833169107:task/twg-web-cluster/d7bd3dd0e02a4ca19b7e5b9610f3ba77 \
    --container twg-app-container

The Session Manager plugin was installed successfully. Use the AWS CLI to start a session.

Starting session with SessionId: ecs-execute-command-d5soseji57gsdz8hjziba2764q
root@ip-10-60-1-30:/usr/local/apache2#
```
falcon-sensorの起動確認
```
root@ip-10-60-1-30:/usr/local/apache2# /tmp/CrowdStrike/rootfs/bin/falconctl -g --aid
aid="0397073c58c3450797df710bbaa1ac3b".   ★エージェントIDが設定されていることを確認

root@ip-10-60-1-30:/usr/local/apache2# /tmp/CrowdStrike/rootfs/bin/falconctl -g --tags
tags=C_3xx12_608_dummy.  ★指定したタグが設定されていることを確認
```

<a id="sec4"></a>
## 4.falcon-sensorイメージ更新のスケジュール有効化
サーバ版falcon-sensorとは異なり、ECS Fargate用のfalcon-sensorは自動更新されない  
定期的にイメージを更新する為にCodeBuildの定期実行が必要  
※手動でCodeBuildを実行する場合は、有効化は不要
- Config内の「ScheduleState」を変更後、スケジュールを更新
- スケジュールが有効になったことを確認

<a id="sec4-1"></a>
### 4-1.falcon-sensorイメージ更新のスケジュール有効化
[EDR設計資料](../guideline/template/app/edr/README.md)の「4-2. イメージビルド(build.yaml)のパラメータについて」の以下パラメータを変更する
- ScheduleState
- CronSchedule  ※実行スケジュールを変更したい場合は、本パラメータも変更する  
階層の移動
```
$ cd sceptre
```
変更
```
[hsk-yasu-y@xadmin-30-aws-cli-008 sceptre]$ sceptre launch tst/app/edr/build.yaml
Do you want to launch 'tst/app/edr/build.yaml' [y/N]: y
[2025-05-08 14:26:49] - tst/app/ecr - Launching Stack
[2025-05-08 14:26:50] - tst/app/ecr - Stack is in the CREATE_COMPLETE state
[2025-05-08 14:26:50] - tst/app/ecr - Updating Stack
：
：中略
[2025-05-08 14:27:03] - tst/app/edr/build ocx-standard-template-tst-app-edr-build AWS::CloudFormation::Stack UPDATE_COMPLETE
```

<a id="sec4-2"></a>
### 4-2.スケジュールの確認
スケジュール名の取得
```
$ aws scheduler list-schedules|jq -r .Schedules[].Name|grep PushFalconSensorImage
twg-PushFalconSensorImage

■複数出力された場合
「EnvShort / SystemName」にて判断する
例：
EnvShort: t
SystemName: wg
接頭辞に「twg」が付与された物が今回確認するスケジュールである
```
スケジュールの確認
```
$ aws scheduler get-schedule --name twg-PushFalconSensorImage
{
    "ActionAfterCompletion": "NONE",
    "Arn": "arn:aws:scheduler:ap-northeast-1:875833169107:schedule/default/twg-PushFalconSensorImage",
    "CreationDate": "2025-05-08T11:36:13.563000+09:00",
    "Description": "Push falcon-sensor Image",
    "FlexibleTimeWindow": {
        "Mode": "OFF"
    },
    "GroupName": "default",
    "LastModificationDate": "2025-05-08T14:26:56.925000+09:00",
    "Name": "twg-PushFalconSensorImage",
    "ScheduleExpression": "cron(30 3 1 * ? *)",   ★指定したスケジュールであることを確認
    "ScheduleExpressionTimezone": "Asia/Tokyo",   ★TimeZoneが東京であることを確認
    "State": "ENABLED",                           ★有効になっていることを確認
  ：
  ：中略
}
```
