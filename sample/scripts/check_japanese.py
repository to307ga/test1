#!/usr/bin/env python3
"""
Check for Japanese characters in code files.
Only .md files are allowed to contain Japanese characters.
"""

import re
import sys
from pathlib import Path


def contains_japanese(text):
    """Check if text contains Japanese characters."""
    # Hiragana, Katakana, and Kanji ranges
    japanese_pattern = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]')
    return bool(japanese_pattern.search(text))


def check_file(file_path):
    """Check a single file for Japanese characters."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if contains_japanese(content):
            print(f"❌ Japanese characters found in {file_path}")
            print("   Only .md files are allowed to contain Japanese characters.")
            return False
        return True
    except Exception as e:
        print(f"❌ Error reading {file_path}: {e}")
        return False


def main():
    """Main function to check all files."""
    if len(sys.argv) < 2:
        print("Usage: python check_japanese.py <file1> [file2] ...")
        sys.exit(1)
    
    files = sys.argv[1:]
    all_passed = True
    
    for file_path in files:
        if not check_file(file_path):
            all_passed = False
    
    if not all_passed:
        print("\n❌ Japanese character check failed!")
        print("Please remove Japanese characters from code files.")
        print("Only .md files are allowed to contain Japanese characters.")
        sys.exit(1)
    else:
        print("✅ Japanese character check passed!")


if __name__ == "__main__":
    main()
