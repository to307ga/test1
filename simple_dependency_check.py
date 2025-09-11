#!/usr/bin/env python3
"""
シンプルな依存関係チェックスクリプト - 標準ライブラリのみ使用
"""

import yaml
import os

def check_dependencies(environment='dev'):
    """設定ファイルの依存関係をチェックする"""

    # 各設定ファイルを読み込み
    configs = [
        f'sceptre/config/{environment}/base.yaml',
        f'sceptre/config/{environment}/ses.yaml',
        f'sceptre/config/{environment}/security.yaml',
        f'sceptre/config/{environment}/monitoring.yaml',
        f'sceptre/config/{environment}/enhanced-kinesis.yaml'
    ]

    print(f"🔍 {environment.upper()}環境の依存関係を分析中...")

    stack_dependencies = {}
    all_stacks = []

    for config_file in configs:
        try:
            if not os.path.exists(config_file):
                print(f"⚠️  設定ファイルが見つかりません: {config_file}")
                continue

            with open(config_file, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
                stack_name = os.path.basename(config_file).replace('.yaml', '')
                dependencies = config.get('dependencies', [])

                # 依存関係を正規化 (dev/base.yaml -> base)
                normalized_deps = []
                for dep in dependencies:
                    if isinstance(dep, str):
                        dep_name = dep.split('/')[-1].replace('.yaml', '') if '/' in dep else dep
                        normalized_deps.append(dep_name)

                stack_dependencies[stack_name] = normalized_deps
                all_stacks.append(stack_name)
                print(f"  📋 {stack_name}: {normalized_deps}")

        except Exception as e:
            print(f'❌ Error reading {config_file}: {e}')

    return stack_dependencies, all_stacks

def find_cycles(stack_dependencies):
    """単純な循環参照検出"""
    def has_cycle_from(start, visited, rec_stack):
        visited.add(start)
        rec_stack.add(start)

        for neighbor in stack_dependencies.get(start, []):
            if neighbor not in visited:
                if has_cycle_from(neighbor, visited, rec_stack):
                    return True
            elif neighbor in rec_stack:
                return True

        rec_stack.remove(start)
        return False

    visited = set()
    for stack in stack_dependencies:
        if stack not in visited:
            if has_cycle_from(stack, visited, set()):
                return True
    return False

def get_deployment_order(stack_dependencies):
    """デプロイ順序を計算（トポロジカルソート的処理）"""
    # 依存関係カウント
    in_degree = {stack: 0 for stack in stack_dependencies}

    for stack in stack_dependencies:
        for dep in stack_dependencies[stack]:
            if dep in in_degree:
                in_degree[dep] += 1

    # 依存関係のないスタックから開始
    queue = [stack for stack, degree in in_degree.items() if degree == 0]
    order = []

    while queue:
        current = queue.pop(0)
        order.append(current)

        # 依存していたスタックの依存カウントを減らす
        for stack in stack_dependencies:
            if current in stack_dependencies[stack]:
                in_degree[stack] -= 1
                if in_degree[stack] == 0:
                    queue.append(stack)

    return order

def analyze_environment(environment):
    """環境の依存関係を分析"""
    stack_dependencies, all_stacks = check_dependencies(environment)

    if not stack_dependencies:
        print(f"❌ {environment}環境の設定ファイルが見つかりませんでした")
        return False

    # 循環参照のチェック
    has_cycle = find_cycles(stack_dependencies)

    if has_cycle:
        print('\n🚨 循環参照が検出されました！')
        return False
    else:
        print('\n✅ 循環参照は見つかりませんでした')

    # デプロイ順序の計算
    deployment_order = get_deployment_order(stack_dependencies)

    print(f'\n🚀 推奨デプロイ順序:')
    for i, stack in enumerate(deployment_order, 1):
        deps = stack_dependencies.get(stack, [])
        if deps:
            print(f"  {i}. {stack} (依存: {', '.join(deps)})")
        else:
            print(f"  {i}. {stack} (依存なし)")

    print(f'\n🗑️  推奨削除順序 (デプロイの逆順):')
    for i, stack in enumerate(reversed(deployment_order), 1):
        print(f"  {i}. {stack}")

    # 詳細な依存関係マップ
    print(f'\n📋 詳細な依存関係マップ:')
    for stack in sorted(stack_dependencies.keys()):
        deps = stack_dependencies[stack]
        # このスタックに依存するスタックを探す
        dependents = [s for s, d in stack_dependencies.items() if stack in d]

        print(f"\n  📦 {stack}:")
        print(f"    📥 依存するスタック: {deps if deps else 'なし'}")
        print(f"    📤 このスタックに依存するスタック: {dependents if dependents else 'なし'}")

    return True

def main():
    """メイン関数"""
    import sys

    if len(sys.argv) > 1 and sys.argv[1] in ['dev', 'prod']:
        environments = [sys.argv[1]]
    else:
        environments = ['dev', 'prod']

    all_valid = True

    for env in environments:
        result = analyze_environment(env)
        all_valid = all_valid and result

        if len(environments) > 1:
            print(f"\n{'-'*40}")

    if all_valid:
        print(f"\n🎉 すべての環境で依存関係は正常です！")
        return 0
    else:
        print(f"\n💥 依存関係に問題があります。修正が必要です。")
        return 1

if __name__ == "__main__":
    exit(main())
