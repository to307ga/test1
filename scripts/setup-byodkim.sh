#!/bin/bash

# BYODKIM RSA Key Generation and SSM Parameter Store Setup Script
# Usage: ./setup-byodkim.sh

set -e

echo "=== AWS SES BYODKIM Setup Script ==="
echo "Generating RSA 2048-bit key pair for BYODKIM..."

# Generate RSA private key (2048-bit)
openssl genpkey -algorithm RSA -out byodkim_private.pem -pkcs8 -pkeyopt rsa_keygen_bits:2048

# Extract public key
openssl rsa -in byodkim_private.pem -pubout -out byodkim_public.pem

# Convert private key to base64 (single line for CloudFormation)
PRIVATE_KEY_BASE64=$(openssl base64 -in byodkim_private.pem -A)

# Extract public key for DNS TXT record
PUBLIC_KEY_DNS=$(openssl rsa -in byodkim_private.pem -pubout -outform DER | openssl base64 -A)

echo ""
echo "=== Key Generation Complete ==="
echo ""

# Store private key in SSM Parameter Store
echo "Storing private key in SSM Parameter Store..."
aws ssm put-parameter \
    --name "/ses/byodkim/private-key" \
    --value "$PRIVATE_KEY_BASE64" \
    --type "SecureString" \
    --description "BYODKIM private key for SES (base64 encoded)" \
    --overwrite

echo "✅ Private key stored in SSM: /ses/byodkim/private-key"
echo ""

# Store public key for reference
aws ssm put-parameter \
    --name "/ses/byodkim/public-key-dns" \
    --value "$PUBLIC_KEY_DNS" \
    --type "String" \
    --description "BYODKIM public key for DNS TXT record" \
    --overwrite

echo "✅ Public key stored in SSM: /ses/byodkim/public-key-dns"
echo ""

echo "=== DNS Configuration Required ==="
echo "Add this TXT record to your DNS:"
echo ""
echo "Record Name: gooid-21-prod._domainkey.goo.ne.jp"
echo "Record Type: TXT"
echo "Record Value: v=DKIM1; k=rsa; p=$PUBLIC_KEY_DNS"
echo ""

echo "=== CloudFormation Ready ==="
echo "Your BYODKIM keys are now stored in SSM Parameter Store."
echo "You can deploy the CloudFormation template which will reference:"
echo "- /ses/byodkim/private-key (SecureString)"
echo ""

# Clean up local files for security
echo "Cleaning up local key files for security..."
rm -f byodkim_private.pem byodkim_public.pem

echo "✅ Setup complete! Deploy your CloudFormation stack now."
