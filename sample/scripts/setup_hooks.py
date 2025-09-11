#!/usr/bin/env python3
"""
Setup pre-commit hooks for the project.
"""

import subprocess
import sys
from pathlib import Path


def run_command(command, description):
    """Run a command and handle errors."""
    print(f"🔧 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed:")
        print(f"   Command: {command}")
        print(f"   Error: {e.stderr}")
        return False


def main():
    """Main function to setup pre-commit hooks."""
    print("🚀 Setting up pre-commit hooks for AWS BYODMIM project...")
    
    # Check if pre-commit is installed
    if not run_command("pre-commit --version", "Checking pre-commit installation"):
        print("❌ pre-commit is not installed. Please install it first:")
        print("   pip install pre-commit")
        print("   or")
        print("   uv add --dev pre-commit")
        sys.exit(1)
    
    # Install pre-commit hooks
    if not run_command("pre-commit install", "Installing pre-commit hooks"):
        sys.exit(1)
    
    # Run pre-commit on all files
    if not run_command("pre-commit run --all-files", "Running pre-commit on all files"):
        print("⚠️  Some pre-commit checks failed. Please fix the issues and try again.")
        sys.exit(1)
    
    print("🎉 Pre-commit hooks setup completed successfully!")
    print("\n📋 Project rules summary:")
    print("   - Use 'uv run' prefix for Python and Sceptre commands")
    print("   - Add '--yes' flag to Sceptre change commands")
    print("   - No '--yes' flag for Sceptre reference commands")
    print("   - No Japanese characters in code files (.py, .yaml, .json, etc.)")
    print("   - Japanese allowed only in .md files")
    print("   - Use UTF-8 with LF line endings")
    print("\n🔍 Hooks will run automatically on git commit.")


if __name__ == "__main__":
    main()
