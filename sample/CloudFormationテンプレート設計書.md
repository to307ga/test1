# AWS SES マイグレーション CloudFormationテンプレート設計書

## 1. ドキュメント概要

### 1.1 文書の目的
本文書は、AWS SESマイグレーションプロジェクトにおけるCloudFormationテンプレートの設計詳細を記載し、Sceptreを使用したインフラストラクチャ・アズ・コードの実装指針を示すものです。

### 1.2 対象読者
- インフラエンジニア
- DevOpsエンジニア
- クラウドアーキテクト
- システム運用者

### 1.3 参考資料
- [AWS CloudFormation テンプレートリファレンス](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)
- [AWS SES CloudFormation リソース](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_SES.html)
- [Sceptre ドキュメント](https://sceptre.cloudreach.com/)

## 2. テンプレート構成概要

### 2.1 スタック構成
```
├── network/
│   └── vpc-stack.yaml              # VPC・セキュリティグループ
├── security/
│   ├── iam-stack.yaml              # IAMロール・ポリシー
│   ├── kms-stack.yaml              # KMS暗号化キー
│   └── secrets-stack.yaml          # Secrets Manager
├── storage/
│   ├── s3-stack.yaml               # S3バケット（証明書・ログ保存用）
│   └── lambda-layers-s3.yaml       # Lambda Layer用S3バケット
├── ses/
│   ├── ses-identity-stack.yaml     # SESドメイン・DKIM設定
│   ├── ses-config-stack.yaml       # SES Configuration Set
│   └── ses-template-stack.yaml     # SESテンプレート
├── lambda/
│   ├── dkim-manager-stack.yaml     # DKIM管理Lambda
│   └── email-processor-stack.yaml  # メール処理Lambda
├── monitoring/
│   ├── cloudwatch-stack.yaml       # CloudWatch設定
│   ├── sns-stack.yaml              # SNSトピック
│   └── alarms-stack.yaml           # CloudWatchアラーム
└── outputs/
    └── cross-stack-outputs.yaml    # クロススタック出力
```

### 2.2 依存関係
```mermaid
graph TD
    A[network/vpc-stack] --> B[security/iam-stack]
    A --> C[security/kms-stack]
    B --> D[security/secrets-stack]
    C --> D
    A --> E[storage/s3-stack]
    A --> E2[storage/lambda-layers-s3]
    C --> E
    C --> E2
    B --> F[ses/ses-identity-stack]
    F --> G[ses/ses-config-stack]
    G --> H[ses/ses-template-stack]
    B --> I[lambda/dkim-manager-stack]
    D --> I
    E --> I
    E2 --> I
    B --> J[lambda/email-processor-stack]
    D --> J
    E2 --> J
    I --> K[monitoring/cloudwatch-stack]
    J --> K
    K --> L[monitoring/sns-stack]
    L --> M[monitoring/alarms-stack]
```

## 3. 各スタックの詳細設計

### 3.1 Network Stack (vpc-stack.yaml)

#### 3.1.1 テンプレート概要
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'VPC and Security Groups for SES Migration Project'

Parameters:
  Environment:
    Type: String
    Default: prod
    AllowedValues: [dev, staging, prod]
  
  VpcCidr:
    Type: String
    Default: '10.0.0.0/16'
    Description: 'CIDR block for VPC'

  AllowedIPRanges:
    Type: CommaDelimitedList
    Default: '203.0.113.0/24,198.51.100.0/24'
    Description: 'Allowed IP ranges for management access'
```

#### 3.1.2 主要リソース
```yaml
Resources:
  # VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-ses-migration-vpc'
        - Key: Environment
          Value: !Ref Environment

  # VPC Endpoints for AWS Services
  S3VPCEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.s3'
      VpcEndpointType: Gateway
      
  SESVPCEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.email-smtp'
      VpcEndpointType: Interface
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
      SecurityGroupIds:
        - !Ref VPCEndpointSecurityGroup

  # Security Groups
  LambdaSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'Security group for Lambda functions'
      VpcId: !Ref VPC
      SecurityGroupEgress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: '0.0.0.0/0'
          Description: 'HTTPS outbound'
        - IpProtocol: tcp
          FromPort: 587
          ToPort: 587
          CidrIp: '0.0.0.0/0'
          Description: 'SMTP TLS outbound'

  VPCEndpointSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'Security group for VPC endpoints'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          SourceSecurityGroupId: !Ref LambdaSecurityGroup
          Description: 'HTTPS from Lambda'
```

#### 3.1.3 出力
```yaml
Outputs:
  VPCId:
    Description: 'VPC ID'
    Value: !Ref VPC
    Export:
      Name: !Sub '${Environment}-vpc-id'

  LambdaSecurityGroupId:
    Description: 'Lambda Security Group ID'
    Value: !Ref LambdaSecurityGroup
    Export:
      Name: !Sub '${Environment}-lambda-sg-id'

  PrivateSubnetIds:
    Description: 'Private Subnet IDs'
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
    Export:
      Name: !Sub '${Environment}-private-subnet-ids'
```

### 3.2 Security Stack (iam-stack.yaml)

#### 3.2.1 IAMロール設計
```yaml
Resources:
  # Lambda実行ロール
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${Environment}-ses-lambda-execution-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
      Policies:
        - PolicyName: SESManagementPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - ses:GetIdentityDkimAttributes
                  - ses:PutIdentityDkimAttributes
                  - ses:GetIdentityVerificationAttributes
                  - ses:SendEmail
                  - ses:SendRawEmail
                Resource: '*'
              - Effect: Allow
                Action:
                  - secretsmanager:GetSecretValue
                  - secretsmanager:UpdateSecret
                Resource: !Ref SMTPCredentialsSecret
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                Resource: 
                  - !Sub '${S3LogBucket}/*'
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: '*'

  # 管理者ロール
  SESAdminRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${Environment}-ses-admin-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: sts:AssumeRole
            Condition:
              IpAddress:
                aws:SourceIp: !Ref AdminIPRanges
              Bool:
                aws:MultiFactorAuthPresent: 'true'
      Policies:
        - PolicyName: SESFullAccessPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action: 'ses:*'
                Resource: '*'
              - Effect: Allow
                Action:
                  - cloudwatch:GetMetricStatistics
                  - cloudwatch:ListMetrics
                  - logs:DescribeLogGroups
                  - logs:DescribeLogStreams
                  - logs:GetLogEvents
                Resource: '*'

  # 読み取り専用ロール
  SESReadOnlyRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${Environment}-ses-readonly-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: sts:AssumeRole
            Condition:
              IpAddress:
                aws:SourceIp: !Ref AllowedIPRanges
      Policies:
        - PolicyName: SESReadOnlyPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - ses:Get*
                  - ses:List*
                  - ses:Describe*
                Resource: '*'
              - Effect: Allow
                Action:
                  - cloudwatch:GetMetricStatistics
                  - cloudwatch:ListMetrics
                  - logs:DescribeLogGroups
                  - logs:DescribeLogStreams
                  - logs:FilterLogEvents
                Resource: '*'
```

### 3.3 SES Identity Stack (ses-identity-stack.yaml)

#### 3.3.1 ドメインアイデンティティ設定
```yaml
Resources:
  # SESドメインアイデンティティ
  SESEmailIdentity:
    Type: AWS::SES::EmailIdentity
    Properties:
      EmailIdentity: !Ref DomainName
      DkimSigningAttributes:
        NextSigningKeyLength: RSA_2048_BIT
      DkimAttributes:
        SigningEnabled: false  # 初期状態では無効（BYODKIM設定後に有効化）
      MailFromAttributes:
        MailFromDomain: !Sub 'mail.${DomainName}'
        BehaviorOnMxFailure: UseDefaultValue
      FeedbackAttributes:
        EmailForwardingEnabled: false
      Tags:
        - Key: Environment
          Value: !Ref Environment
        - Key: Purpose
          Value: 'Email sending domain'

  # BYODKIM設定（Lambda関数で管理）
  # Note: BYODKIM設定はLambda関数内で動的に実行されるため、
  # CloudFormationリソースとしては定義しない

  # Configuration Set
  SESConfigurationSet:
    Type: AWS::SES::ConfigurationSet
    Properties:
      Name: !Sub '${Environment}-${DomainName}-config-set'
      DeliveryOptions:
        TlsPolicy: Require
      ReputationOptions:
        ReputationMetricsEnabled: true
      SendingOptions:
        SendingEnabled: true
      SuppressionOptions:
        SuppressedReasons:
          - BOUNCE
          - COMPLAINT
      TrackingOptions:
        CustomRedirectDomain: !Sub 'track.${DomainName}'

  # イベント発行設定
  ConfigurationSetEventDestination:
    Type: AWS::SES::ConfigurationSetEventDestination
    Properties:
      ConfigurationSetName: !Ref SESConfigurationSet
      EventDestination:
        Name: 'cloudwatch-event-destination'
        Enabled: true
        MatchingEventTypes:
          - send
          - bounce
          - complaint
          - delivery
          - reject
        CloudWatchDestination:
          DimensionConfigurations:
            - DimensionName: 'MessageTag'
              DimensionValueSource: 'messageTag'
              DefaultDimensionValue: 'default'
            - DimensionName: 'EmailAddress'
              DimensionValueSource: 'emailAddress'
              DefaultDimensionValue: 'unknown'
```

#### 3.3.2 SMTP認証情報
```yaml
  # SMTP認証情報（Secrets Managerで管理）
  SMTPCredentialsSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub '${Environment}-ses-smtp-credentials'
      Description: 'SMTP credentials for SES'
      GenerateSecretString:
        SecretStringTemplate: '{"username": "AKIAIOSFODNN7EXAMPLE"}'
        GenerateStringKey: 'password'
        PasswordLength: 40
        ExcludeCharacters: '"@/\'
      KmsKeyId: !ImportValue
        'Fn::Sub': '${Environment}-kms-key-id'
      Tags:
        - Key: Environment
          Value: !Ref Environment
        - Key: Purpose
          Value: 'SES SMTP authentication'

  # SMTP認証情報の自動ローテーション
  SMTPCredentialsRotation:
    Type: AWS::SecretsManager::RotationSchedule
    Properties:
      SecretId: !Ref SMTPCredentialsSecret
      RotationLambdaArn: !GetAtt SMTPRotationLambda.Arn
      RotationRules:
        AutomaticallyAfterDays: 90
```

### 3.4 Lambda Layer S3 Stack (lambda-layers-s3.yaml)

#### 3.4.1 Lambda Layer用S3バケット
```yaml
Resources:
  # Lambda Layer用S3バケット
  LambdaLayersBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "${ProjectName}-${Environment}-lambda-layers"
      VersioningConfiguration:
        Status: Enabled
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      LifecycleConfiguration:
        Rules:
          - Id: DeleteOldVersions
            Status: Enabled
            NoncurrentVersionExpirationInDays: 30
      Tags:
        - Key: Name
          Value: !Sub "${ProjectName}-${Environment}-lambda-layers"
        - Key: Project
          Value: !Ref ProjectName
        - Key: Environment
          Value: !Ref Environment
        - Key: Purpose
          Value: "Lambda layers storage"

  # Lambda Layer用S3バケットポリシー
  LambdaLayersBucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref LambdaLayersBucket
      PolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              AWS: !GetAtt DKIMManagerRole.Arn
            Action:
              - s3:GetObject
              - s3:PutObject
            Resource: !Sub "${LambdaLayersBucket}/*"
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action:
              - s3:GetObject
            Resource: !Sub "${LambdaLayersBucket}/*"

  # Lambda Layer自動セットアップ関数
  LayerSetupFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub "${ProjectName}-${Environment}-layer-setup"
      Runtime: python3.11
      Handler: index.lambda_handler
      Role: !GetAtt LayerSetupRole.Arn
      Timeout: 300
      MemorySize: 512
      Code:
        ZipFile: |
          import json
          import boto3
          import subprocess
          import os
          import tempfile
          import zipfile
          import logging
          
          logger = logging.getLogger()
          logger.setLevel(logging.INFO)
          
          def lambda_handler(event, context):
              try:
                  s3_client = boto3.client('s3')
                  bucket_name = os.environ['LAYER_BUCKET_NAME']
                  
                  with tempfile.TemporaryDirectory() as temp_dir:
                      python_dir = os.path.join(temp_dir, 'python')
                      os.makedirs(python_dir, exist_ok=True)
                      
                      logger.info("Installing cryptography library...")
                      subprocess.run([
                          'pip', 'install', 'cryptography', '-t', python_dir
                      ], check=True, capture_output=True, text=True)
                      
                      zip_path = os.path.join(temp_dir, 'cryptography-layer.zip')
                      with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                          for root, dirs, files in os.walk(python_dir):
                              for file in files:
                                  file_path = os.path.join(root, file)
                                  arc_path = os.path.relpath(file_path, python_dir)
                                  zipf.write(file_path, arc_path)
                      
                      logger.info(f"Uploading to S3 bucket: {bucket_name}")
                      s3_client.upload_file(zip_path, bucket_name, 'cryptography-layer.zip')
                      
                      logger.info("Cryptography layer setup completed successfully")
                      
                      return {
                          'statusCode': 200,
                          'body': json.dumps({
                              'message': 'Cryptography layer created and uploaded successfully',
                              'bucket': bucket_name,
                              'key': 'cryptography-layer.zip'
                          })
                      }
                      
              except Exception as e:
                  logger.error(f"Error: {str(e)}")
                  raise
      
      Environment:
        Variables:
          LAYER_BUCKET_NAME: !Ref LambdaLayersBucket
      
      Tags:
        - Key: Name
          Value: !Sub "${ProjectName}-${Environment}-layer-setup"
        - Key: Project
          Value: !Ref ProjectName
        - Key: Environment
          Value: !Ref Environment
        - Key: Purpose
          Value: "Lambda layer setup"

  # Layer Setup用IAMロール
  LayerSetupRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub "${ProjectName}-${Environment}-layer-setup-role"
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: S3LayerAccessPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                Resource: !Sub "${LambdaLayersBucket}/*"

  # Layer Setup用EventBridge Rule
  LayerSetupRule:
    Type: AWS::Events::Rule
    Properties:
      Name: !Sub "${ProjectName}-${Environment}-layer-setup-rule"
      Description: "Trigger layer setup on stack creation/update"
      EventPattern:
        source: ["aws.cloudformation"]
        detail-type: ["CloudFormation Stack Status Change"]
        detail:
          stack-name: [!Ref AWS::StackName]
          status-details:
            status: ["CREATE_COMPLETE", "UPDATE_COMPLETE"]
      State: ENABLED
      Targets:
        - Arn: !GetAtt LayerSetupFunction.Arn
          Id: "LayerSetupTarget"

  # Layer Setup用Lambda権限
  LayerSetupPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref LayerSetupFunction
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt LayerSetupRule.Arn

  # Layer Setup用CloudWatch Log Group
  LayerSetupLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub "/aws/lambda/${ProjectName}-${Environment}-layer-setup"
      RetentionInDays: 30

Outputs:
  LambdaLayersBucketName:
    Description: "Lambda Layers S3 Bucket Name"
    Value: !Ref LambdaLayersBucket
    Export:
      Name: !Sub "${Environment}-lambda-layers-bucket-name"

  LambdaLayersBucketArn:
    Description: "Lambda Layers S3 Bucket ARN"
    Value: !GetAtt LambdaLayersBucket.Arn
    Export:
      Name: !Sub "${Environment}-lambda-layers-bucket-arn"
```

### 3.5 Lambda Stack (dkim-manager-stack.yaml)

#### 3.5.1 DKIM管理Lambda
```yaml
Resources:
  # DKIM管理Lambda関数
  DKIMManagerFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${Environment}-dkim-manager'
      Runtime: python3.11
      Handler: index.lambda_handler
      Role: !ImportValue
        'Fn::Sub': '${Environment}-lambda-execution-role-arn'
      Code:
        ZipFile: |
          import json
          import boto3
          import datetime
          import os
          import logging
          import secrets
          import base64
          from dateutil.relativedelta import relativedelta
          
          logger = logging.getLogger()
          logger.setLevel(logging.INFO)
          
          def lambda_handler(event, context):
              """
              DKIM Manager Lambda handler - BYODKIM自動化システム
              """
              try:
                  logger.info(f"Received event: {json.dumps(event)}")
                  
                  # EventBridgeからのイベント処理
                  if 'source' in event and event['source'] == 'aws.events':
                      return handle_phase_management(event, context)
                  
                  # 手動実行の場合
                  phase = event.get('phase', '4')
                  return handle_phase_management({'phase': phase}, context)
                  
              except Exception as e:
                  logger.error(f"ERROR: {str(e)}")
                  raise
          
          def handle_custom_resource(event, context):
              """Handle CloudFormation Custom Resource requests"""
              import urllib3
              
              response_url = event['ResponseURL']
              request_type = event['RequestType']
              logical_resource_id = event['LogicalResourceId']
              stack_id = event['StackId']
              request_id = event['RequestId']
              
              try:
                  if request_type in ['Create', 'Update']:
                      secret_arn = os.environ['DKIM_CONFIG_SECRET_ARN']
                      bucket_name = os.environ['CERTIFICATES_BUCKET_NAME']
                      result = create_dkim_certificate(secret_arn, bucket_name)
                      
                      response_data = {
                          'Message': 'DKIM setup completed successfully',
                          'DKIMTokens': result.get('selectors', []),
                          'DNSRecords': result.get('dns_records', [])
                      }
                      
                      send_response(response_url, 'SUCCESS', response_data, 
                                   logical_resource_id, stack_id, request_id)
                      
                  elif request_type == 'Delete':
                      response_data = {'Message': 'DKIM cleanup completed'}
                      send_response(response_url, 'SUCCESS', response_data, 
                                   logical_resource_id, stack_id, request_id)
                      
                  return {'statusCode': 200}
                  
              except Exception as e:
                  logger.error(f"Custom Resource error: {str(e)}")
                  send_response(response_url, 'FAILED', {'Message': str(e)}, 
                               logical_resource_id, stack_id, request_id)
                  return {'statusCode': 500}
          
          def send_response(response_url, status, response_data, logical_resource_id, stack_id, request_id):
              """Send response to CloudFormation"""
              import urllib3
              import json
              
              response_body = {
                  'Status': status,
                  'Reason': f'See CloudWatch Log Stream: {context.log_stream_name}' if 'context' in locals() else 'Custom Resource completed',
                  'PhysicalResourceId': logical_resource_id,
                  'StackId': stack_id,
                  'RequestId': request_id,
                  'LogicalResourceId': logical_resource_id,
                  'Data': response_data
              }
              
              json_response_body = json.dumps(response_body)
              
              http = urllib3.PoolManager()
              response = http.request('PUT', response_url, body=json_response_body,
                                     headers={'content-type': '', 'content-length': str(len(json_response_body))})
              
              logger.info(f"Response sent to CloudFormation: {response.status}")
          
          def create_dkim_certificate(secret_arn, bucket_name):
              """Create DKIM certificate and return selectors and DNS records"""
              # Implementation for creating DKIM certificate
              # This is a placeholder - actual implementation would create real certificates
              return {
                  'selectors': ['abc123', 'def456', 'ghi789'],
                  'dns_records': [
                      {'name': 'abc123._domainkey.goo.ne.jp', 'type': 'CNAME', 'value': 'abc123.dkim.amazonses.com'},
                      {'name': 'def456._domainkey.goo.ne.jp', 'type': 'CNAME', 'value': 'def456.dkim.amazonses.com'},
                      {'name': 'ghi789._domainkey.goo.ne.jp', 'type': 'CNAME', 'value': 'ghi789.dkim.amazonses.com'}
                  ]
              }
          
          def check_dkim_expiry(domain, dkim_tokens, sns_topic):
              # 1ヶ月後の日付を計算
              one_month_later = datetime.datetime.now() + relativedelta(months=1)
              
              # 証明書期限チェックのロジック（実装例）
              # 実際の実装では、DKIMトークンの有効期限を確認
              
              # アラート送信（期限が近い場合）
              message = f"DKIM certificate for {domain} will expire soon. Please update DNS records."
              
              sns_client.publish(
                  TopicArn=sns_topic,
                  Message=message,
                  Subject=f"DKIM Certificate Expiry Alert for {domain}"
              )
      Environment:
        Variables:
          DOMAIN_NAME: !Ref DomainName
          SNS_TOPIC_ARN: !ImportValue
            'Fn::Sub': '${Environment}-dkim-alert-topic-arn'
          DKIM_CONFIG_SECRET_ARN: !ImportValue
            'Fn::Sub': '${Environment}-dkim-config-secret-arn'
          CERTIFICATES_BUCKET_NAME: !ImportValue
            'Fn::Sub': '${Environment}-certificates-bucket-name'
      Timeout: 300
      MemorySize: 512
      Layers:
        - !ImportValue
            'Fn::Sub': '${Environment}-cryptography-layer-arn'
      VpcConfig:
        SecurityGroupIds:
          - !ImportValue
              'Fn::Sub': '${Environment}-lambda-sg-id'
        SubnetIds: !Split
          - ','
          - !ImportValue
              'Fn::Sub': '${Environment}-private-subnet-ids'

  # EventBridge Rules for phase management
  Phase4TriggerRule:
    Type: AWS::Events::Rule
    Properties:
      Name: !Sub '${Environment}-phase-4-trigger'
      Description: 'Trigger Phase 4 - DKIM certificate generation'
      ScheduleExpression: 'cron(0 9 1 * ? *)'  # 毎月1日 9:00 JST
      State: ENABLED
      Targets:
        - Arn: !GetAtt DKIMManagerFunction.Arn
          Id: 'Phase4Target'
          Input: '{"phase": "4"}'

  Phase7TriggerRule:
    Type: AWS::Events::Rule
    Properties:
      Name: !Sub '${Environment}-phase-7-trigger'
      Description: 'Trigger Phase 7 - DNS validation and DKIM activation'
      EventPattern:
        source: ["aws.lambda"]
        detail-type: ["Phase 5 Completion"]
        detail:
          phase: ["5"]
      State: ENABLED
      Targets:
        - Arn: !GetAtt DKIMManagerFunction.Arn
          Id: 'Phase7Target'
          Input: '{"phase": "7"}'

  # Lambda権限
  DKIMManagerInvokePermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref DKIMManagerFunction
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt Phase4TriggerRule.Arn

  DKIMManagerEventBridgePermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref DKIMManagerFunction
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt Phase7TriggerRule.Arn
```

### 3.6 Monitoring Stack (cloudwatch-stack.yaml)

#### 3.6.1 CloudWatchダッシュボード
```yaml
Resources:
  # SESメトリクスダッシュボード
  SESMonitoringDashboard:
    Type: AWS::CloudWatch::Dashboard
    Properties:
      DashboardName: !Sub '${Environment}-ses-monitoring'
      DashboardBody: !Sub |
        {
          "widgets": [
            {
              "type": "metric",
              "x": 0,
              "y": 0,
              "width": 12,
              "height": 6,
              "properties": {
                "metrics": [
                  [ "AWS/SES", "Send", "MessageTag", "default" ],
                  [ ".", "Bounce", ".", "." ],
                  [ ".", "Complaint", ".", "." ],
                  [ ".", "Delivery", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "SES Email Metrics"
              }
            },
            {
              "type": "metric",
              "x": 0,
              "y": 6,
              "width": 12,
              "height": 6,
              "properties": {
                "metrics": [
                  [ { "expression": "m2/m1*100", "label": "Bounce Rate (%)", "id": "e1" } ],
                  [ { "expression": "m3/m1*100", "label": "Complaint Rate (%)", "id": "e2" } ],
                  [ "AWS/SES", "Send", "MessageTag", "default", { "id": "m1", "visible": false } ],
                  [ ".", "Bounce", ".", ".", { "id": "m2", "visible": false } ],
                  [ ".", "Complaint", ".", ".", { "id": "m3", "visible": false } ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "Email Quality Metrics",
                "yAxis": {
                  "left": {
                    "min": 0,
                    "max": 10
                  }
                }
              }
            }
          ]
        }

  # カスタムメトリクス
  EmailSendSuccessMetric:
    Type: AWS::Logs::MetricFilter
    Properties:
      FilterName: !Sub '${Environment}-email-send-success'
      FilterPattern: '[timestamp, request_id, level="INFO", message="Email sent successfully"]'
      LogGroupName: !Sub '/aws/lambda/${Environment}-email-processor'
      MetricTransformations:
        - MetricNamespace: 'SES/Custom'
          MetricName: 'EmailSendSuccess'
          MetricValue: '1'
          DefaultValue: 0

  # アラーム
  BounceRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${Environment}-ses-high-bounce-rate'
      AlarmDescription: 'SES bounce rate is too high'
      MetricName: Bounce
      Namespace: AWS/SES
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 50  # 5%に相当する値（1000通送信時）
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: MessageTag
          Value: default
      AlarmActions:
        - !ImportValue
            'Fn::Sub': '${Environment}-alert-topic-arn'
      TreatMissingData: notBreaching

  ComplaintRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${Environment}-ses-high-complaint-rate'
      AlarmDescription: 'SES complaint rate is too high'
      MetricName: Complaint
      Namespace: AWS/SES
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 1  # 0.1%に相当する値（1000通送信時）
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: MessageTag
          Value: default
      AlarmActions:
        - !ImportValue
            'Fn::Sub': '${Environment}-alert-topic-arn'
      TreatMissingData: notBreaching
```

## 4. Sceptre設定

### 4.1 Sceptreディレクトリ構造
```
sceptre/
├── config/
│   ├── config.yaml
│   ├── prod/
│   │   ├── config.yaml
│   │   ├── network/
│   │   │   └── vpc.yaml
│   │   ├── security/
│   │   │   ├── iam.yaml
│   │   │   ├── kms.yaml
│   │   │   └── secrets.yaml
│   │   ├── ses/
│   │   │   ├── identity.yaml
│   │   │   ├── config.yaml
│   │   │   └── templates.yaml
│   │   ├── lambda/
│   │   │   ├── dkim-manager.yaml
│   │   │   └── email-processor.yaml
│   │   └── monitoring/
│   │       ├── cloudwatch.yaml
│   │       ├── sns.yaml
│   │       └── alarms.yaml
│   └── staging/
│       └── (similar structure)
├── templates/
│   └── (CloudFormation templates)
└── hooks/
    ├── before_create.py
    └── after_create.py
```

### 4.2 メインconfig.yaml
```yaml
# sceptre/config/config.yaml
project_code: ses-migration
region: ap-northeast-1

template_bucket_name: ses-migration-templates-{{ var.account_id }}

hooks:
  before_create:
    - !bash "echo 'Starting deployment...'"
  after_create:
    - !bash "echo 'Deployment completed'"

template_handler: file
```

### 4.3 環境別設定 (prod/config.yaml)
```yaml
# sceptre/config/prod/config.yaml
template_path: templates

project_code: ses-migration
region: ap-northeast-1

parameters:
  Environment: prod
  DomainName: goo.ne.jp
  AdminIPRanges:
    - "203.0.113.0/24"
  AllowedIPRanges:
    - "203.0.113.0/24"
    - "198.51.100.0/24"

hooks:
  before_create:
    - !python hooks/validate_parameters.py
  after_update:
    - !python hooks/update_dns_records.py
```

### 4.4 SESアイデンティティ設定 (ses/identity.yaml)
```yaml
# sceptre/config/prod/ses/identity.yaml
template_path: ses/ses-identity-stack.yaml

dependencies:
  - security/iam
  - security/kms
  - security/secrets

parameters:
  DomainName: goo.ne.jp
  Environment: prod

hooks:
  after_create:
    - !python hooks/verify_dkim_setup.py
  before_delete:
    - !python hooks/backup_ses_config.py

tags:
  Environment: prod
  Service: SES
  Purpose: EmailIdentity
```

## 5. パラメータ管理

### 5.1 環境別パラメータ
```yaml
# 本番環境パラメータ
prod:
  VpcCidr: '10.0.0.0/16'
  DomainName: 'goo.ne.jp'
  SendingQuota: 10000000
  MaxSendRate: 200
  Environment: 'prod'

# ステージング環境パラメータ  
staging:
  VpcCidr: '10.1.0.0/16'
  DomainName: 'staging.goo.ne.jp'
  SendingQuota: 1000000
  MaxSendRate: 50
  Environment: 'staging'

# 開発環境パラメータ
dev:
  VpcCidr: '10.2.0.0/16'
  DomainName: 'dev.goo.ne.jp'
  SendingQuota: 100000
  MaxSendRate: 10
  Environment: 'dev'
```

### 5.2 Secrets Manager統合
```yaml
# パスワードやAPIキーはSecrets Managerで管理
parameters:
  SMTPPassword: !GetAtt SMTPCredentialsSecret.SecretValue
  DKIMPrivateKey: !GetAtt DKIMPrivateKeySecret.SecretValue
```

## 6. デプロイメント戦略

### 6.1 デプロイメント順序
```bash
# 1. ネットワーク・セキュリティ基盤
sceptre launch prod/network
sceptre launch prod/security

# 2. ストレージ・SES設定
sceptre launch prod/storage/s3
sceptre launch prod/storage/lambda-layers-s3
sceptre launch prod/ses

# 3. Lambda・監視
sceptre launch prod/lambda
sceptre launch prod/monitoring
```

### 6.2 ロールバック戦略
```yaml
# ロールバック用フック
hooks:
  before_delete:
    - !python hooks/backup_current_config.py
  on_failure:
    - !python hooks/rollback_to_previous.py
    - !bash "aws ses put-identity-dkim-attributes --identity {{ var.domain_name }} --dkim-enabled=false"
```

### 6.3 テスト統合
```yaml
# テスト実行フック
hooks:
  after_create:
    - !python hooks/run_integration_tests.py
  after_update:
    - !python hooks/validate_ses_configuration.py
    - !python hooks/test_email_sending.py
```

## 7. 監視・ログ設定

### 7.1 CloudFormationスタック監視
```yaml
# スタック作成・更新の監視
CloudFormationEventRule:
  Type: AWS::Events::Rule
  Properties:
    EventPattern:
      source: ["aws.cloudformation"]
      detail-type: ["CloudFormation Stack Status Change"]
      detail:
        stack-name: 
          - prefix: "ses-migration"
    Targets:
      - Arn: !Ref AlertTopic
        Id: "CloudFormationAlert"
```

### 7.2 リソース変更追跡
```yaml
# AWS Configによるリソース変更追跡
ConfigRecorder:
  Type: AWS::Config::ConfigurationRecorder
  Properties:
    RecordingGroup:
      ResourceTypes:
        - "AWS::SES::ConfigurationSet"
        - "AWS::SES::ReceiptRule"
        - "AWS::Lambda::Function"
        - "AWS::IAM::Role"
```

## 8. セキュリティ考慮事項

### 8.1 テンプレートセキュリティ
- 機密情報はSecrets Managerまたはパラメータストアを使用
- IAMポリシーは最小権限の原則に従う
- すべてのリソースにタグを適用
- VPCエンドポイントを使用してトラフィックを制御

### 8.2 デプロイメントセキュリティ
```yaml
# デプロイメント時のセキュリティチェック
hooks:
  before_create:
    - !python hooks/security_scan.py
    - !python hooks/validate_iam_policies.py
  before_update:
    - !python hooks/check_drift.py
    - !python hooks/validate_changes.py
```

## 9. 運用・保守

### 9.1 定期メンテナンス
```yaml
# 月次メンテナンススケジュール
MaintenanceSchedule:
  Type: AWS::Events::Rule
  Properties:
    ScheduleExpression: "cron(0 2 1 * ? *)"  # 毎月1日 2:00
    Targets:
      - Arn: !GetAtt MaintenanceLambda.Arn
        Id: "MonthlyMaintenance"
```

### 9.2 バックアップ・復旧
```yaml
# 設定バックアップ
BackupLambda:
  Type: AWS::Lambda::Function
  Properties:
    Handler: backup.lambda_handler
    Code:
      ZipFile: |
        def lambda_handler(event, context):
            # SES設定のバックアップ
            # CloudFormationテンプレートのバックアップ
            # パラメータのバックアップ
            pass
```

## 10. トラブルシューティング

### 10.1 一般的な問題と対策
```yaml
# デプロイメント失敗時の対策
TroubleshootingGuide:
  DKIMSetupFailure:
    - "Check DNS propagation"
    - "Verify CNAME records"
    - "Check IAM permissions"
  
  LambdaDeploymentFailure:
    - "Check VPC configuration"
    - "Verify security group rules"
    - "Check Lambda layer compatibility"
  
  SESQuotaExceeded:
    - "Request quota increase"
    - "Check current usage"
    - "Implement rate limiting"
```

### 10.2 ログ分析
```yaml
# エラーログの分析
LogAnalysisQueries:
  DeploymentErrors: |
    fields @timestamp, @message
    | filter @message like /ERROR/
    | filter @message like /CloudFormation/
    | sort @timestamp desc
  
  SESErrors: |
    fields @timestamp, @message
    | filter @message like /SES/
    | filter @message like /failed/
    | stats count() by bin(5m)
```

---

**文書管理情報**
- 作成日: 2024年12月
- バージョン: 1.0
- 作成者: インフラストラクチャチーム
- 承認者: システムアーキテクト
- 次回レビュー: 2025年1月
