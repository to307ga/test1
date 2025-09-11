#!/usr/bin/env python3
"""
SSL Certificate Verification Bypass for Sceptre
"""
import ssl
import urllib3
from urllib3.exceptions import InsecureRequestWarning

# Disable SSL verification warnings
urllib3.disable_warnings(InsecureRequestWarning)

# Override the default SSL context
ssl._create_default_https_context = ssl._create_unverified_context

# Set environment variables for SSL bypass
import os
os.environ['PYTHONHTTPSVERIFY'] = '0'
os.environ['SSL_VERIFY'] = 'false'
os.environ['REQUESTS_CA_BUNDLE'] = ''
os.environ['CURL_CA_BUNDLE'] = ''

print("SSL verification has been disabled for this session.")
