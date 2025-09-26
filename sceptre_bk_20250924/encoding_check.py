import os
import glob

def check_file_encoding(file_path):
    result = {
        'path': file_path,
        'size': 0,
        'utf8_ok': False,
        'error_position': None,
        'has_japanese': False
    }

    try:
        with open(file_path, 'rb') as f:
            data = f.read()

        result['size'] = len(data)

        try:
            content = data.decode('utf-8')
            result['utf8_ok'] = True

            # 日本語文字の簡易検出
            has_jp = any(ord(c) > 127 and
                        (0x3040 <= ord(c) <= 0x309F or  # ひらがな
                         0x30A0 <= ord(c) <= 0x30FF or  # カタカナ
                         0x4E00 <= ord(c) <= 0x9FAF)    # 漢字
                        for c in content)
            result['has_japanese'] = has_jp

        except UnicodeDecodeError as e:
            result['utf8_ok'] = False
            result['error_position'] = e.start

    except Exception as e:
        result['error'] = str(e)

    return result

# ファイル収集
files_to_check = []
for pattern in ['templates/*.yaml', 'templates/*.yml']:
    files_to_check.extend(glob.glob(pattern))

for root, dirs, files in os.walk('config'):
    for file in files:
        if file.endswith(('.yaml', '.yml', '.md')):
            files_to_check.append(os.path.join(root, file))

print('=== ENCODING CHECK RESULTS ===')
problematic_files = []
japanese_files = []

for file_path in sorted(files_to_check):
    result = check_file_encoding(file_path)

    status = 'OK' if result['utf8_ok'] else 'ERROR'
    jp_status = 'JP' if result['has_japanese'] else 'EN'

    print(f'{status:5} {jp_status:2} {result["size"]:6} bytes - {file_path}')

    if not result['utf8_ok']:
        problematic_files.append(result)
        print(f'       ERROR at position: {result["error_position"]}')

    if result['has_japanese']:
        japanese_files.append(result)

print(f'\nSUMMARY:')
print(f'  Encoding errors: {len(problematic_files)} files')
print(f'  Japanese text: {len(japanese_files)} files')
print(f'  Total checked: {len(files_to_check)} files')

if problematic_files:
    print('\nFILES WITH ENCODING ERRORS:')
    for result in problematic_files:
        print(f'  {result["path"]} (error at position {result["error_position"]})')

if japanese_files:
    print('\nFILES WITH JAPANESE TEXT:')
    for result in japanese_files:
        print(f'  {result["path"]}')
