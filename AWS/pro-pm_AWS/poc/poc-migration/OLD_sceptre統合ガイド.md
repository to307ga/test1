# OLD_sceptre環境への統合ガイド

このドキュメントでは、poc-migrationパッケージをOLD_sceptre形式の既存環境に統合する方法を説明します。

## 前提条件

- 既存のOLD_sceptre環境がセットアップ済み
- VPC、セキュリティグループ、IAMロールなどの基盤リソースが構築済み
- Sceptreコマンドが実行可能

## 統合方法

### パターン1: 既存OLD_sceptreに追加デプロイ

既存のOLD_sceptre環境に、Jenkins/Gitea ECSスタックのみを追加する場合：

```bash
# 1. テンプレートファイルをコピー
cp poc-migration/sceptre/templates/ecs-jenkins.yaml OLD_sceptre/templates/
cp poc-migration/sceptre/templates/ecs-gitea.yaml OLD_sceptre/templates/
cp poc-migration/sceptre/templates/ecr-jenkins.yaml OLD_sceptre/templates/

# 2. 設定ファイルを作成（OLD_sceptre形式に変換）
# 例: OLD_sceptre/config/poc/ecs-jenkins.yaml
```

#### OLD_sceptre形式の設定ファイル例

**OLD_sceptre/config/poc/ecs-jenkins.yaml**:
```yaml
template:
  path: ecs-jenkins.yaml
  type: file
parameters:
  # System
  EnvShort: p
  SystemName: jenkins
  # Network Parameter
  VPCID: !stack_output poc/vpc.yaml::Vpc
  JenkinsSecurityGroupId: !stack_output poc/securitygroup.yaml::JenkinsSecurityGroupId
  InternalALBSecurityGroupId: !stack_output poc/securitygroup.yaml::InternalALBSecurityGroupId
  ECSSubnetIds:
    - !stack_output poc/vpc.yaml::PrivateSubnetA
    - !stack_output poc/vpc.yaml::PrivateSubnetC
    - !stack_output poc/vpc.yaml::PrivateSubnetD
  # ECR Jenkins Custom Image
  JenkinsImageUri: !Sub '${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/${EnvShort}-${SystemName}-custom:latest'
```

### パターン2: poc-migrationを独立環境として構築

新しい環境（dev/stg/prod）に、poc-migrationを独立した環境として構築する場合：

```bash
# 1. 環境ディレクトリ作成
cd poc-migration/sceptre/config
cp -r poc dev

# 2. 環境設定の調整
vim dev/config.yaml
# stack_tags:
#   Env: dev

# 3. パラメータの調整
vim dev/vpc.yaml
# VpcCidr: 10.1.0.0/16  # dev環境用CIDR

vim dev/ecs-jenkins.yaml
# JenkinsImageUri: <AccountId>.dkr.ecr.ap-northeast-1.amazonaws.com/dev-jenkins-custom:latest

# 4. デプロイ
cd ../..
uv run sceptre create dev/vpc.yaml -y
uv run sceptre create dev/securitygroup.yaml -y
# ... 以降のスタックを順次作成
```

## OLD_sceptreテンプレートとの主な互換性問題

### 1. パラメータ名の違い

POC環境のテンプレートをOLD_sceptre形式に変換する場合、以下のパラメータ名変換が必要：

| POC環境テンプレート | OLD_sceptre期待値 | 変換要否 |
|-------------------|------------------|---------|
| `VPCId` | `VPCID` | ✅ 必要 |
| `VpcCidr` | `VPCCIDR` | ✅ 必要 |
| `PublicSubnet1Cidr` | `PublicSubnetACIDR` | ✅ 必要 |
| `PrivateSubnet1Cidr` | `PrivateSubnetACIDR` | ✅ 必要 |
| `Environment` | `EnvShort` + `SystemName` | ✅ 必要 |

#### テンプレート修正スクリプト例

```bash
# vpc.yamlのパラメータ名をOLD_sceptre形式に変換
sed -i 's/VpcCidr/VPCCIDR/g' templates/vpc.yaml
sed -i 's/PublicSubnet1Cidr/PublicSubnetACIDR/g' templates/vpc.yaml
sed -i 's/PrivateSubnet1Cidr/PrivateSubnetACIDR/g' templates/vpc.yaml
sed -i 's/PublicSubnet2Cidr/PublicSubnetCCIDR/g' templates/vpc.yaml
sed -i 's/PrivateSubnet2Cidr/PrivateSubnetCCIDR/g' templates/vpc.yaml
sed -i 's/PublicSubnet3Cidr/PublicSubnetDCIDR/g' templates/vpc.yaml
sed -i 's/PrivateSubnet3Cidr/PrivateSubnetDCIDR/g' templates/vpc.yaml
```

### 2. Output名の違い

POC環境とOLD_sceptreでOutput名が異なる場合の対応：

**POC環境のOutputs**:
```yaml
Outputs:
  VpcId:
    Value: !Ref VPC
  PrivateSubnets:
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2, !Ref PrivateSubnet3]]
```

**OLD_sceptre形式のOutputs**:
```yaml
Outputs:
  Vpc:
    Value: !Ref VPC
  PrivateSubnetA:
    Value: !Ref PrivateSubnetA
  PrivateSubnetC:
    Value: !Ref PrivateSubnetC
  PrivateSubnetD:
    Value: !Ref PrivateSubnetD
```

#### 修正方法

1. テンプレートの Outputs セクションをOLD_sceptre形式に統一
2. または、config.yamlで`!stack_output`参照を調整

### 3. 依存関係の管理

OLD_sceptreでは明示的な`dependencies`指定が推奨されます：

**POC環境**:
```yaml
dependencies:
  - poc/vpc.yaml
  - poc/securitygroup.yaml
```

**OLD_sceptre形式（推奨）**:
```yaml
# dependenciesは暗黙的に!stack_outputで解決される
# 明示的に指定する場合:
dependencies:
  - poc/vpc.yaml
  - poc/securitygroup.yaml
```

## デプロイ順序

### 最小構成（Jenkins ECSのみ）

```bash
# 基盤（既存環境の場合はスキップ）
uv run sceptre create poc/fixed-natgw-eip.yaml -y
uv run sceptre create poc/vpc.yaml -y
uv run sceptre create poc/securitygroup.yaml -y
uv run sceptre create poc/iam-group.yaml -y

# VPCエンドポイント（SSM必須）
uv run sceptre create poc/vpc-endpoints.yaml -y

# Jenkins ECS
uv run sceptre create poc/ecr-jenkins.yaml -y
# ECRにイメージプッシュ（jenkins-docker/参照）
uv run sceptre create poc/ecs-jenkins.yaml -y
```

### フル構成（Jenkins + Gitea + 監視）

```bash
# 基盤
uv run sceptre create poc/fixed-natgw-eip.yaml -y
uv run sceptre create poc/vpc.yaml -y
uv run sceptre create poc/securitygroup.yaml -y
uv run sceptre create poc/iam-group.yaml -y
uv run sceptre create poc/vpc-endpoints.yaml -y

# S3バケット（ログ保存用）
uv run sceptre create poc/s3.yaml -y

# ECR
uv run sceptre create poc/ecr-jenkins.yaml -y

# Jenkins/Gitea ECS
uv run sceptre create poc/ecs-jenkins.yaml -y
uv run sceptre create poc/ecs-gitea.yaml -y

# 監視（オプション）
uv run sceptre create poc/monitoring-alerts.yaml -y
```

## トラブルシューティング

### エラー: Parameter XXX not found in template

**原因**: config.yamlのパラメータ名とテンプレートのパラメータ名が一致しない

**解決方法**:
1. テンプレートファイルの`Parameters:`セクションを確認
2. config.yamlのパラメータ名を修正
3. または、テンプレートのパラメータ名を統一

### エラー: Stack output XXX::YYY not found

**原因**: 依存スタックが存在しないか、Output名が間違っている

**解決方法**:
1. 依存スタックがデプロイ済みか確認: `uv run sceptre list poc/`
2. 依存スタックのOutputs確認: `aws cloudformation describe-stacks --stack-name XXX --query 'Stacks[0].Outputs'`
3. config.yamlの`!stack_output`参照を修正

### OLD_sceptreとの共存

OLD_sceptre環境に追加する場合、以下を確認：

1. **project_code**: OLD_sceptreとpoc-migrationで異なる場合、スタック名が衝突しない
2. **リソース名**: VPC、SecurityGroupなどのリソース名が重複しないよう命名規則を確認
3. **タグ**: `stack_tags`でコスト配分タグなどを統一

```yaml
# OLD_sceptre/config/config.yaml
project_code: ocx-standard-template
stack_tags:
  system_name: ocx-standard-template
  PJCD: 4224396UB00000300000001

# poc-migration/sceptre/config/config.yaml
project_code: jenkins-gitea
stack_tags:
  system_name: jenkins-gitea-platform
  ManagedBy: sceptre
```

## まとめ

- **既存環境への追加**: テンプレートとconfigをOLD_sceptre形式に変換して追加
- **新規独立環境**: poc-migrationをそのまま使用（動作確認済み）
- **パラメータ名統一**: OLD_sceptre形式（VPCCIDR等）かPOC形式（VpcCidr等）かを決定
- **依存関係管理**: `!stack_output`参照が正しく解決されるか事前確認

詳細な手順は`ECS移行用パラメータファイル.md`を参照してください。
