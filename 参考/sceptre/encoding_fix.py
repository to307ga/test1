#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix encoding issues in ses.yaml by removing Unicode emojis
"""

def fix_encoding():
    # Read with UTF-8 encoding
    with open('templates/ses.yaml', 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace Unicode emojis with ASCII equivalents
    replacements = {
        '🔄': '[ROTATION]',
        '⚠️': '[WARNING]',
        '✅': '[OK]',
        '❌': '[ERROR]',
        '📋': '[INFO]',
        '🌐': '[DNS]',
        '🚀': '[DEPLOY]',
        '📞': '[SUPPORT]'
    }

    for emoji, replacement in replacements.items():
        content = content.replace(emoji, replacement)

    # Save with UTF-8 encoding (compatible with CloudFormation)
    with open('templates/ses.yaml', 'w', encoding='utf-8', newline='') as f:
        f.write(content)

    print("Successfully fixed encoding issues in ses.yaml")

if __name__ == "__main__":
    fix_encoding()
