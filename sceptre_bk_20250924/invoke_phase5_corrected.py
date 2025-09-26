#!/usr/bin/env python3
import boto3
import json

# Lambda client
lambda_client = boto3.client('lambda', region_name='ap-northeast-1')

# Phase 5 payload
payload = {
    "action": "phase_manager",
    "phase": "5",
    "domain": "goo.ne.jp",
    "environment": "dev",
    "projectName": "aws-ses-migration",
    "dkimSeparator": "gooid-21-dev"
}

print("Invoking Lambda function for Phase 5 with corrected DKIM separator...")

try:
    response = lambda_client.invoke(
        FunctionName='aws-ses-migration-dev-dkim-manager',
        Payload=json.dumps(payload)
    )

    # Read response
    response_payload = response['Payload'].read()
    result = json.loads(response_payload)

    print(f"Lambda Response:")
    print(json.dumps(result, indent=2))

    # Save response to file
    with open('response-phase5-corrected.json', 'w') as f:
        json.dump(result, f, indent=2)

    print("\nResponse saved to response-phase5-corrected.json")

except Exception as e:
    print(f"Error: {e}")
