import sys, json
data = json.loads(sys.stdin.read())
print('ウィジェット数:', len(data['widgets']))
for w in data['widgets']:
    print(f'- {w["properties"]["title"]}: {w["type"]}')
