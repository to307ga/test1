#!/usr/bin/env python3
"""
依存関係の循環チェックスクリプト - 最新版
Enhanced Kinesisスタックを含むすべてのスタックの依存関係をチェック
"""

import yaml
import networkx as nx
import os
import argparse

def check_circular_dependencies(environment='dev'):
    """設定ファイルの循環参照をチェックする"""
    # 依存関係グラフの構築
    G = nx.DiGraph()

    # 各設定ファイルを読み込み (enhanced-kinesis追加)
    configs = [
        f'sceptre/config/{environment}/base.yaml',
        f'sceptre/config/{environment}/ses.yaml',
        f'sceptre/config/{environment}/security.yaml',
        f'sceptre/config/{environment}/monitoring.yaml',
        f'sceptre/config/{environment}/enhanced-kinesis.yaml'
    ]

    print(f"🔍 {environment.upper()}環境の依存関係を分析中...")

    stack_dependencies = {}

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
                        # "dev/base.yaml" -> "base" に正規化
                        dep_name = dep.split('/')[-1].replace('.yaml', '') if '/' in dep else dep
                        normalized_deps.append(dep_name)

                stack_dependencies[stack_name] = normalized_deps
                print(f"  📋 {stack_name}: {normalized_deps}")

                # グラフにエッジを追加
                for dep in normalized_deps:
                    G.add_edge(stack_name, dep)

        except Exception as e:
            print(f'❌ Error reading {config_file}: {e}')

    return G, stack_dependencies

def analyze_dependencies(environment='dev'):
    """依存関係の詳細分析"""
    print(f"\n{'='*60}")
    print(f"📊 {environment.upper()}環境 依存関係分析レポート")
    print(f"{'='*60}")

    G, stack_dependencies = check_circular_dependencies(environment)

    # 循環参照のチェック
    try:
        cycles = list(nx.simple_cycles(G))
        if cycles:
            print('\n🚨 循環参照が検出されました:')
            for cycle in cycles:
                print(f'  🔄 {" -> ".join(cycle)} -> {cycle[0]}')
            return False
        else:
            print('\n✅ 循環参照は見つかりませんでした')

        # 依存関係グラフの可視化
        print(f'\n📈 依存関係グラフ:')

        # トポロジカルソート（デプロイ順序）
        try:
            topo_order = list(nx.topological_sort(G))
            print(f"\n🚀 推奨デプロイ順序:")
            for i, stack in enumerate(reversed(topo_order), 1):
                deps = stack_dependencies.get(stack, [])
                if deps:
                    print(f"  {i}. {stack} (依存: {', '.join(deps)})")
                else:
                    print(f"  {i}. {stack} (依存なし)")
        except nx.NetworkXError as e:
            print(f"❌ トポロジカルソートエラー: {e}")

        # 各ノードの依存関係詳細
        print(f'\n📋 詳細な依存関係:')
        for stack in sorted(stack_dependencies.keys()):
            deps = stack_dependencies[stack]
            predecessors = list(G.predecessors(stack))  # このスタックが依存するスタック
            successors = list(G.successors(stack))      # このスタックに依存するスタック

            print(f"\n  📦 {stack}:")
            print(f"    📥 依存するスタック: {deps if deps else 'なし'}")
            print(f"    📤 このスタックに依存するスタック: {successors if successors else 'なし'}")

        # 削除順序の提案
        print(f'\n🗑️  推奨削除順序 (依存関係の逆順):')
        if topo_order:
            for i, stack in enumerate(topo_order, 1):
                print(f"  {i}. {stack}")

        return True

    except Exception as e:
        print(f'❌ 依存関係チェック中にエラーが発生: {e}')
        return False

def main():
    """メイン関数"""
    parser = argparse.ArgumentParser(description='Sceptre スタック依存関係チェッカー')
    parser.add_argument('--env', choices=['dev', 'prod', 'both'], default='both',
                       help='チェックする環境 (dev, prod, または both)')

    args = parser.parse_args()

    if args.env == 'both':
        environments = ['dev', 'prod']
    else:
        environments = [args.env]

    all_valid = True

    for env in environments:
        result = analyze_dependencies(env)
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
