# Agent Instructions

## Overview
This document provides specific instructions for AI agents working on the AWS BYODMIM project. Follow these rules consistently when creating files, proposing commands, or making any changes to the project.

## File Creation Rules

### Code Files (English Only)
**Extensions**: `.py`, `.yaml`, `.yml`, `.json`, `.toml`, `.tf`, `.sh`, `.ps1`

**Requirements**:
- Use English only for all content
- UTF-8 encoding with LF line endings
- No BOM
- kebab-case naming convention

**Examples**:
```python
# ✅ Good
def create_dkim_certificate():
    """Create DKIM certificate for email authentication"""
    pass

# ❌ Bad
def create_dkim_certificate():
    """DKIM証明書を作成する"""
    pass
```

### Documentation Files (Japanese Allowed)
**Extensions**: `.md`, `.txt`

**Requirements**:
- Japanese allowed for content
- UTF-8 encoding with LF line endings
- No BOM
- kebab-case naming convention

## Template Creation Rules

### Template and Parameter Separation
**Rule**: Templates and parameter sheets must be created separately in different directories

### Template Files
**Location**: `templates/`
**Extensions**: `.yaml`, `.json`
**Naming**: kebab-case
**Examples**:
- `templates/dkim-manager.yaml`
- `templates/kms-keys.yaml`
- `templates/monitoring.yaml`

### Parameter Sheets
**Location**: `config/` with environment subdirectories
**Extensions**: `.yaml`
**Naming**: kebab-case with `-params` suffix
**Environment Directories**:
- `config/development/`
- `config/staging/`
- `config/production/`

**Examples**:
- `config/development/dkim-manager-params.yaml`
- `config/staging/dkim-manager-params.yaml`
- `config/production/dkim-manager-params.yaml`

### Directory Structure
```
templates/
├── dkim-manager.yaml
├── kms-keys.yaml
└── monitoring.yaml

config/
├── development/
│   ├── dkim-manager-params.yaml
│   ├── kms-keys-params.yaml
│   └── monitoring-params.yaml
├── staging/
│   ├── dkim-manager-params.yaml
│   ├── kms-keys-params.yaml
│   └── monitoring-params.yaml
└── production/
    ├── dkim-manager-params.yaml
    ├── kms-keys-params.yaml
    └── monitoring-params.yaml
```

### Template Creation Process
1. **Create Template File**: Place in `templates/` directory
2. **Create Parameter Files**: Create environment-specific parameter files in `config/{environment}/`
3. **Naming Convention**: Use kebab-case for all files
4. **File Separation**: Never mix templates and parameters in the same file

## Command Execution Rules

### Python Execution
**Always use**: `uv run` prefix

**Examples**:
- `uv run python script.py`
- `uv run pytest`
- `uv run black --check .`

### Sceptre Commands

#### Change Commands (Require --yes)
**Commands**: `create`, `launch`, `delete`, `update`, `execute`

**Format**: `uv run sceptre <command> <stack-name> --yes`

**Examples**:
- `uv run sceptre launch dkim-manager --yes`
- `uv run sceptre delete old-stack --yes`
- `uv run sceptre update dkim-manager --yes`

#### Reference Commands (No --yes)
**Commands**: `list`, `describe`, `get`, `status`, `validate`

**Format**: `uv run sceptre <command> <stack-name>`

**Examples**:
- `uv run sceptre list stacks`
- `uv run sceptre describe dkim-manager`
- `uv run sceptre status dkim-manager`

## Code Standards

### Python
- **Comments**: English only
- **Function names**: snake_case
- **Variable names**: snake_case
- **Class names**: PascalCase
- **Error messages**: English only
- **Log messages**: English only
- **Docstrings**: English only

### YAML
- **Keys**: English only
- **Values**: English only
- **Comments**: English only

### JSON
- **Keys**: English only
- **Values**: English only

## File Naming

### Good Examples
- `dkim-certificate-manager.py`
- `sceptre-config.yaml`
- `cloudformation-template.json`
- `lambda-function-handler.py`

### Bad Examples
- `dkim証明書管理.py`
- `sceptre_config.yaml`
- `CloudFormationテンプレート.json`
- `lambda関数ハンドラー.py`

## Error Handling

### Error Messages
**Always use English**:

```python
# ✅ Good
raise ValueError("Invalid DKIM key length. Must be 2048 or 4096 bits")

# ❌ Bad
raise ValueError("無効なDKIMキー長です。2048または4096ビットである必要があります")
```

### Log Messages
**Always use English**:

```python
# ✅ Good
logger.info("DKIM certificate created successfully")
logger.error("Failed to create DKIM certificate: %s", str(e))

# ❌ Bad
logger.info("DKIM証明書が正常に作成されました")
logger.error("DKIM証明書の作成に失敗しました: %s", str(e))
```

## Environment Variables

### Naming Convention
**Format**: UPPER_SNAKE_CASE

### Good Examples
- `DKIM_KEY_LENGTH`
- `SES_REGION`
- `NOTIFICATION_EMAIL`
- `KMS_KEY_ID`

### Bad Examples
- `DKIMキー長`
- `SESリージョン`
- `通知メール`
- `KMSキーID`

## Testing

### Test File Naming
**Format**: `test_*.py`

### Test Function Naming
**Format**: `test_*`

### Examples
```python
# ✅ Good
def test_create_dkim_certificate():
    pass

def test_validate_key_length():
    pass

# ❌ Bad
def test_dkim証明書作成():
    pass

def test_キー長検証():
    pass
```

## Project Structure

### Directory Structure
```
AWS_BYODMIM/
├── scripts/          # Utility scripts
├── config/           # Sceptre configuration
├── templates/        # CloudFormation templates
├── lambda/           # Lambda function code
├── docs/             # Documentation
└── tests/            # Test files
```

### File Organization
- **Scripts**: Utility and automation tools
- **Config**: Sceptre configuration files
- **Templates**: CloudFormation templates
- **Lambda**: Lambda function code
- **Docs**: Documentation files
- **Tests**: Test files

## Validation

### Automatic Checks
- UTF-8 encoding
- LF line endings
- Naming convention compliance
- Language consistency

### Tools Used
- pre-commit
- black
- flake8
- isort

## Exceptions

### Allowed Cases
- External system integration requiring Japanese
- Legacy system compatibility
- Legal requirements

### Approval Process
1. Document exception reason
2. Consider alternatives
3. Team approval
4. Documentation update

## Quick Reference

### Command Templates
```bash
# Python execution
uv run python <script.py>

# Sceptre change commands
uv run sceptre <create|launch|delete|update|execute> <stack-name> --yes

# Sceptre reference commands
uv run sceptre <list|describe|get|status|validate> <stack-name>

# Package management
uv add <package-name>
uv add --dev <package-name>
```

### File Creation Checklist
- [ ] Correct file extension
- [ ] English only (for code files)
- [ ] UTF-8 encoding
- [ ] LF line endings
- [ ] kebab-case naming
- [ ] Proper directory structure

### Code Quality Checklist
- [ ] English comments
- [ ] English error messages
- [ ] English log messages
- [ ] Proper naming conventions
- [ ] Consistent formatting

---

**Remember**: These rules ensure consistency and maintainability across the project. Follow them strictly when working as an AI agent on this project.
