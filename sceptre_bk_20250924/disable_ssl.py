import ssl
import urllib3
import warnings

# SSL検証を無効化
ssl._create_default_https_context = ssl._create_unverified_context

# urllib3の警告を無効化
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# SSL関連の警告を無効化
warnings.filterwarnings('ignore', message='Unverified HTTPS request')

print("SSL verification disabled")
