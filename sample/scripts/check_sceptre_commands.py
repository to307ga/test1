#!/usr/bin/env python3
"""
Check Sceptre command format in files.
- Commands should use 'uv run sceptre'
- Change commands should have '--yes' flag
- Reference commands should not have '--yes' flag
"""

import re
import sys
from pathlib import Path


def check_sceptre_commands(content, file_path):
    """Check Sceptre commands in file content."""
    errors = []
    
    # Find all sceptre commands with uv run prefix
    sceptre_pattern = r'uv\s+run\s+sceptre\s+(\w+)\s+([^\s\n]+)(?:\s+--yes)?'
    commands = re.findall(sceptre_pattern, content)
    
    # Change commands that require --yes
    change_commands = {'create', 'launch', 'delete', 'update', 'execute'}
    
    # Reference commands that should not have --yes
    reference_commands = {'list', 'describe', 'get', 'status', 'validate'}
    
    for command, stack_name in commands:
        # Check if command uses 'uv run' (already filtered by regex)
        
        # Check --yes flag usage
        if command in change_commands:
            # Look for the specific command line
            command_line_pattern = rf'uv\s+run\s+sceptre\s+{command}\s+{re.escape(stack_name)}(?:\s+--yes)?'
            command_matches = re.findall(command_line_pattern, content)
            
            for match in command_matches:
                if '--yes' not in match:
                    errors.append(f"❌ Change command '{command}' should have '--yes' flag")
                    
        elif command in reference_commands:
            # Look for the specific command line
            command_line_pattern = rf'uv\s+run\s+sceptre\s+{command}\s+{re.escape(stack_name)}(?:\s+--yes)?'
            command_matches = re.findall(command_line_pattern, content)
            
            for match in command_matches:
                if '--yes' in match:
                    errors.append(f"❌ Reference command '{command}' should not have '--yes' flag")
    
    return errors


def check_file(file_path):
    """Check a single file for Sceptre command format."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        errors = check_sceptre_commands(content, file_path)
        
        if errors:
            print(f"❌ Sceptre command format errors in {file_path}:")
            for error in errors:
                print(f"   {error}")
            return False
        return True
    except Exception as e:
        print(f"❌ Error reading {file_path}: {e}")
        return False


def main():
    """Main function to check all files."""
    if len(sys.argv) < 2:
        print("Usage: python check_sceptre_commands.py <file1> [file2] ...")
        sys.exit(1)
    
    files = sys.argv[1:]
    all_passed = True
    
    for file_path in files:
        if not check_file(file_path):
            all_passed = False
    
    if not all_passed:
        print("\n❌ Sceptre command format check failed!")
        print("Please follow the project rules for Sceptre commands:")
        print("- Use 'uv run sceptre' prefix")
        print("- Add '--yes' flag to change commands (create, launch, delete, update, execute)")
        print("- Do not add '--yes' flag to reference commands (list, describe, get, status, validate)")
        sys.exit(1)
    else:
        print("✅ Sceptre command format check passed!")


if __name__ == "__main__":
    main()
