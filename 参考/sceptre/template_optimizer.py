#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Optimize CloudFormation template size by removing unnecessary content
"""

def optimize_template():
    with open('templates/ses.yaml', 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove excessive comments and documentation
    lines = content.split('\n')
    optimized_lines = []

    skip_patterns = [
        '              """',  # Remove docstrings
        '              #',    # Remove excessive comments
        '                  #', # Remove excessive comments
    ]

    i = 0
    while i < len(lines):
        line = lines[i]

        # Skip docstring blocks
        if '"""' in line and line.strip().startswith('"""'):
            # Skip until closing docstring
            while i < len(lines) and not (i > 0 and '"""' in lines[i] and not lines[i].strip().startswith('"""')):
                i += 1
            i += 1
            continue

        # Skip excessive comment lines in Lambda code
        if any(pattern in line for pattern in skip_patterns):
            i += 1
            continue

        # Remove excessive empty lines (keep only one)
        if line.strip() == '':
            if optimized_lines and optimized_lines[-1].strip() != '':
                optimized_lines.append('')
        else:
            optimized_lines.append(line)

        i += 1

    # Join lines and remove excessive whitespace
    optimized_content = '\n'.join(optimized_lines)

    # Remove trailing whitespace
    optimized_content = '\n'.join(line.rstrip() for line in optimized_content.split('\n'))

    # Save optimized version
    with open('templates/ses.yaml', 'w', encoding='utf-8', newline='') as f:
        f.write(optimized_content)

    original_size = len(content)
    optimized_size = len(optimized_content)
    savings = original_size - optimized_size

    print(f"Template optimization completed:")
    print(f"Original size: {original_size} characters")
    print(f"Optimized size: {optimized_size} characters")
    print(f"Savings: {savings} characters ({savings/original_size*100:.1f}%)")
    print(f"CloudFormation limit: 51200 characters")
    print(f"Status: {'UNDER LIMIT' if optimized_size <= 51200 else 'STILL OVER LIMIT'}")

if __name__ == "__main__":
    optimize_template()
