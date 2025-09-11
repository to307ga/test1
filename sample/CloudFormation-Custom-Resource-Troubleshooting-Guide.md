# CloudFormation Custom Resource削除問題 対応ガイド

## 概要
CloudFormationのCustom Resourceが削除時に応答しない問題の診断と解決方法をまとめたガイドです。

## 問題の症状

### 典型的な症状
- CloudFormationスタックが`DELETE_FAILED`状態で停止
- Custom Resourceが`DELETE_IN_PROGRESS`から進まない
- エラーメッセージ: "CloudFormation did not receive a response from your Custom Resource"

### 今回のケース
```
Resource: DKIMSetupTrigger (AWS::CloudFormation::CustomResource)
Status: DELETE_FAILED
Error: CloudFormation did not receive a response from your Custom Resource. 
       Please check your logs for requestId [c3d74bf0-82aa-4866-917e-37390e726298].
```

## 原因分析の手順

### 1. スタック状況の確認
```bash
# Sceptreでの確認
cd sceptre
uv run sceptre status prod/phase-3-ses-byodkim.yaml

# AWS CLIでの詳細確認
aws cloudformation describe-stack-events --stack-name STACK_NAME \
  --query "StackEvents[?ResourceStatus=='DELETE_FAILED'].{Resource:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason}" \
  --output table
```

### 2. Lambda関数ログの確認
```bash
# ロググループの確認
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/FUNCTION_NAME"

# 最新のログストリームを確認
aws logs describe-log-streams --log-group-name "/aws/lambda/FUNCTION_NAME" \
  --order-by LastEventTime --descending --max-items 5

# ログイベントの確認
aws logs get-log-events --log-group-name "/aws/lambda/FUNCTION_NAME" \
  --log-stream-name "LOG_STREAM_NAME" --query "events[-10:].message" --output text
```

### 3. Custom Resourceの物理IDの確認
```bash
aws cloudformation describe-stack-resources --stack-name STACK_NAME \
  --logical-resource-id CUSTOM_RESOURCE_NAME \
  --query "StackResources[0].PhysicalResourceId" --output text
```

## 根本原因

### 今回特定された問題
1. **Lambda関数の応答処理の不備**
   - `send_response`関数でのHTTPヘッダー設定ミス
   - `context`オブジェクトの null チェック不足
   - 削除処理での例外ハンドリング不備

2. **Custom Resource削除ロジックの問題**
   - 削除時の応答が適切に送信されない
   - エラー発生時のフォールバック処理がない

## 解決方法

### 1. Lambda関数の修正

#### send_response関数の改善
```python
def send_response(response_url, status, response_data, logical_resource_id, stack_id, request_id, context=None):
    """Send response to CloudFormation"""
    import urllib3
    import json
    
    try:
        # Create response body
        response_body = {
            'Status': status,
            'Reason': f'See CloudWatch Log Stream: {context.log_stream_name}' if context and hasattr(context, 'log_stream_name') else 'Custom Resource completed',
            'PhysicalResourceId': logical_resource_id,
            'StackId': stack_id,
            'RequestId': request_id,
            'LogicalResourceId': logical_resource_id,
            'Data': response_data
        }
        
        json_response_body = json.dumps(response_body)
        
        # Send response to CloudFormation
        http = urllib3.PoolManager()
        response = http.request(
            'PUT', 
            response_url, 
            body=json_response_body,
            headers={
                'Content-Type': 'application/json',  # 修正: 'content-type' → 'Content-Type'
                'Content-Length': str(len(json_response_body))
            }
        )
        
        logger.info(f"Response sent to CloudFormation: {response.status}")
        
        if response.status != 200:
            logger.error(f"Failed to send response: {response.status} - {response.data}")
            
    except Exception as e:
        logger.error(f"Error sending response to CloudFormation: {str(e)}")
        raise
```

#### 削除処理の堅牢化
```python
elif request_type == 'Delete':
    # Handle deletion (cleanup if needed)
    logger.info(f"Processing DELETE request for Custom Resource: {logical_resource_id}")
    
    try:
        # Perform any necessary cleanup here
        # For DKIM setup, we don't need to clean up anything specific
        # as SES email identity and configuration will be managed by CloudFormation
        
        response_data = {
            'Message': 'DKIM cleanup completed successfully',
            'Action': 'Delete',
            'Status': 'Success'
        }
        
        logger.info("Sending SUCCESS response for DELETE request")
        send_response(response_url, 'SUCCESS', response_data, 
                     logical_resource_id, stack_id, request_id, context)
        
    except Exception as cleanup_error:
        logger.error(f"Error during cleanup: {str(cleanup_error)}")
        # Even if cleanup fails, we should still respond with SUCCESS
        # to allow CloudFormation to continue with stack deletion
        response_data = {
            'Message': f'DKIM cleanup completed with warnings: {str(cleanup_error)}',
            'Action': 'Delete',
            'Status': 'Success'
        }
        send_response(response_url, 'SUCCESS', response_data, 
                     logical_resource_id, stack_id, request_id, context)
```

### 2. 修正の適用手順

#### Step 1: Lambda関数の更新
```bash
cd sceptre
uv run sceptre update prod/phase-2-dkim-system.yaml --yes
```

#### Step 2: 削除の再試行
```bash
uv run sceptre delete prod/phase-3-ses-byodkim.yaml --yes
```

#### Step 3: 強制削除（通常の削除が失敗した場合）
```bash
# Custom Resourceを保持してスタックを削除
aws cloudformation delete-stack --stack-name STACK_NAME --retain-resources CUSTOM_RESOURCE_NAME
```

## 緊急対応手順

### Custom Resource削除が完全に停止した場合

#### 1. 即座に実行可能な対応
```bash
# スタックの強制削除
aws cloudformation delete-stack --stack-name STACK_NAME --retain-resources CUSTOM_RESOURCE_NAME
```

#### 2. Lambda関数を手動でテスト
```json
// test-payload.json
{
  "RequestType": "Delete",
  "ResponseURL": "https://httpbin.org/put",
  "LogicalResourceId": "CustomResourceName",
  "StackId": "stack-id",
  "RequestId": "manual-test",
  "ResourceProperties": {}
}
```

```bash
# Lambda関数の手動実行
aws lambda invoke --function-name FUNCTION_NAME --payload file://test-payload.json response.json
```

#### 3. ログの詳細確認
```bash
# 最新のエラーログを確認
aws logs filter-log-events --log-group-name "/aws/lambda/FUNCTION_NAME" \
  --filter-pattern "ERROR" --start-time $(date -d "1 hour ago" +%s)000
```

## 予防策

### 1. Lambda関数設計のベストプラクティス

#### 堅牢なエラーハンドリング
```python
def handle_custom_resource(event, context):
    """Handle CloudFormation Custom Resource requests"""
    response_url = event['ResponseURL']
    request_type = event['RequestType']
    logical_resource_id = event['LogicalResourceId']
    stack_id = event['StackId']
    request_id = event['RequestId']
    
    try:
        if request_type == 'Delete':
            # 削除処理は常にSUCCESSを返す
            # 実際のリソース削除はCloudFormationが管理
            response_data = {'Message': 'Deletion completed'}
            send_response(response_url, 'SUCCESS', response_data, 
                         logical_resource_id, stack_id, request_id, context)
        # ... other request types
        
    except Exception as e:
        logger.error(f"Custom Resource error: {str(e)}")
        # エラーが発生してもFAILEDレスポンスを必ず送信
        send_response(response_url, 'FAILED', {'Message': str(e)}, 
                     logical_resource_id, stack_id, request_id, context)
    
    return {'statusCode': 200}
```

#### タイムアウト設定
```yaml
# CloudFormationテンプレートで適切なタイムアウトを設定
LambdaFunction:
  Type: AWS::Lambda::Function
  Properties:
    Timeout: 300  # 5分（Custom Resourceのデフォルトタイムアウトは1時間）
    MemorySize: 512
```

### 2. デバッグ機能の組み込み

#### 詳細ログ出力
```python
def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event, indent=2)}")
    logger.info(f"Context: {vars(context) if context else 'None'}")
    
    # Custom Resourceの処理
    if 'RequestType' in event:
        logger.info(f"Processing Custom Resource request: {event['RequestType']}")
        return handle_custom_resource(event, context)
```

#### レスポンス送信の確認
```python
def send_response(response_url, status, response_data, logical_resource_id, stack_id, request_id, context=None):
    logger.info(f"Sending response to CloudFormation:")
    logger.info(f"  Status: {status}")
    logger.info(f"  ResponseURL: {response_url}")
    logger.info(f"  Data: {json.dumps(response_data, indent=2)}")
    
    # 実際の送信処理...
```

### 3. テスト手順

#### 開発環境でのテスト
```bash
# 開発環境でCustom Resourceのテスト
cd sceptre
uv run sceptre create dev/phase-3-ses-byodkim.yaml --yes
uv run sceptre delete dev/phase-3-ses-byodkim.yaml --yes
```

#### 本番環境デプロイ前のチェックリスト
- [ ] Lambda関数のログ出力が適切に設定されている
- [ ] Custom Resourceの削除処理が実装されている
- [ ] エラーハンドリングでFAILEDレスポンスを送信している
- [ ] タイムアウト設定が適切である
- [ ] 開発環境でのテストが完了している

## まとめ

### 重要なポイント
1. **Custom Resourceは必ずレスポンスを返す**: 成功・失敗に関わらず、CloudFormationにレスポンスを送信する
2. **削除処理は寛容に**: 削除時のエラーでもSUCCESSを返し、スタック削除を妨げない
3. **詳細なログ出力**: 問題発生時の調査を迅速化するため
4. **段階的デプロイ**: 開発環境での十分なテストを実施してから本番適用

### 今回の教訓
- Custom Resourceの削除エラーは数時間単位でプロジェクトを停止させる可能性がある
- Lambda関数の軽微なコードミスが大きな影響を与える
- 事前のテストと堅牢なエラーハンドリングが重要

このガイドを参考に、今後同様の問題を迅速に解決できるよう準備しておくことを推奨します。
