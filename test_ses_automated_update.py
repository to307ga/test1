#!/usr/bin/env python3
"""
Test script for SES BYODKIM automated update functionality
Tests the new update_ses_byodkim_automated action in Lambda function
"""

import json
import boto3
from datetime import datetime


def test_ses_automated_update():
    """
    Test the automated SES BYODKIM update function
    This simulates Phase-7 execution after DNS completion
    """

    # Lambda client
    lambda_client = boto3.client('lambda')

    # Test parameters - update these for your environment
    test_payload = {
        "action": "update_ses_byodkim_automated",
        "domain": "example.com",  # Replace with your test domain
        "selector": "selector1"   # Replace with your selector
    }

    print("=== SES BYODKIM Automated Update Test ===")
    print(f"Timestamp: {datetime.utcnow().isoformat()}Z")
    print(f"Test payload: {json.dumps(test_payload, indent=2)}")

    try:
        # Get Lambda function name from environment or use default
        function_name = "aws-ses-migration-prod-dkim-manager-v2"  # Update as needed

        print(f"\nInvoking Lambda function: {function_name}")

        # Invoke Lambda function
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(test_payload)
        )

        # Parse response
        response_payload = json.loads(response['Payload'].read().decode('utf-8'))

        print(f"\nLambda Response:")
        print(f"Status Code: {response['StatusCode']}")
        print(f"Response: {json.dumps(response_payload, indent=2)}")

        # Check if successful
        if response_payload.get('statusCode') == 200:
            print("\n✅ SUCCESS: SES BYODKIM automated update completed successfully")
            print(f"Domain: {response_payload.get('domain')}")
            print(f"Selector: {response_payload.get('selector')}")
            print(f"DKIM Status: {response_payload.get('final_dkim_status')}")
            print(f"Signing Origin: {response_payload.get('signing_origin')}")
        else:
            print(f"\n❌ FAILED: {response_payload.get('message', 'Unknown error')}")
            if 'error' in response_payload:
                print(f"Error Code: {response_payload['error']}")

    except Exception as e:
        print(f"\n❌ ERROR: Test failed with exception: {str(e)}")


def test_dns_validation_only():
    """
    Test only the DNS validation part without SES update
    """

    lambda_client = boto3.client('lambda')

    # Test payload for DNS validation
    test_payload = {
        "action": "validate_dns_only",  # We'll need to add this action
        "domain": "example.com",
        "selector": "selector1"
    }

    print("=== DNS Validation Test ===")
    print(f"Test payload: {json.dumps(test_payload, indent=2)}")

    # This test would need a separate validation-only action
    # For now, we can test using nslookup directly

    import subprocess

    domain = test_payload["domain"]
    selector = test_payload["selector"]
    dkim_domain = f"{selector}._domainkey.{domain}"

    print(f"\nTesting DNS lookup for: {dkim_domain}")

    try:
        result = subprocess.run([
            'nslookup', '-type=TXT', dkim_domain
        ], capture_output=True, text=True, timeout=30)

        print(f"nslookup return code: {result.returncode}")
        print(f"stdout: {result.stdout}")
        print(f"stderr: {result.stderr}")

        if 'v=DKIM1' in result.stdout and 'p=' in result.stdout:
            print("✅ DNS validation would succeed")
        else:
            print("❌ DNS validation would fail - DKIM record not found or invalid")

    except Exception as e:
        print(f"❌ DNS test error: {str(e)}")


if __name__ == "__main__":
    print("Choose test mode:")
    print("1. Full SES automated update test")
    print("2. DNS validation test only")

    choice = input("Enter choice (1 or 2): ").strip()

    if choice == "1":
        test_ses_automated_update()
    elif choice == "2":
        test_dns_validation_only()
    else:
        print("Invalid choice. Exiting.")
