.PHONY: help init validate test test-unit test-integration plan apply destroy clean fmt lint security

# Default target
help:
	@echo "Available targets:"
	@echo "  init          - Initialize Terraform"
	@echo "  validate      - Validate Terraform configuration"
	@echo "  test          - Run all tests (unit + integration)"
	@echo "  test-unit     - Run unit tests only"
	@echo "  test-integration - Run integration tests only"
	@echo "  plan          - Create Terraform plan"
	@echo "  apply         - Apply Terraform configuration"
	@echo "  destroy       - Destroy Terraform resources"
	@echo "  clean         - Clean up temporary files"
	@echo "  fmt           - Format Terraform files"
	@echo "  lint          - Lint Terraform files"
	@echo "  security      - Run security scans"

# Initialize Terraform
init:
	terraform init

# Validate Terraform configuration
validate: init
	terraform validate

# Run all tests
test: test-unit test-integration

# Run unit tests
test-unit: init
	@echo "Running UNIT tests..."
	terraform test tests/unit/

# Run integration tests
test-integration: init
	@echo "Running Integration tests..."
	terraform test tests/integration/

# Create Terraform plan
plan: validate
	terraform plan -var-file="test.tfvars" -out=tfplan

# Apply Terraform configuration
apply: plan
	terraform apply tfplan

# Destroy Terraform resources
destroy:
	terraform destroy -var-file="test.tfvars" -auto-approve

# Clean up temporary files
clean:
	rm -f tfplan
	rm -f *.tfstate*
	rm -f .terraform.lock.hcl
	rm -rf .terraform/

# Format Terraform files
fmt:
	terraform fmt -recursive

# Lint Terraform files
lint: fmt
	@echo "Running Terraform linting..."
	@if command -v tflint >/dev/null 2>&1; then \
		tflint; \
	else \
		echo "tflint not installed. Install with: go install github.com/terraform-linters/tflint/cmd/tflint@latest"; \
	fi

# Run security scans
security:
	@echo "Running Checkov security scan..."
	@if command -v checkov >/dev/null 2>&1; then \
		checkov -d . --framework terraform; \
	else \
		echo "Checkov not installed. Install with: pip install checkov"; \
	fi

# Install development tools
install-tools:
	@echo "Installing development tools..."
	@if command -v pip >/dev/null 2>&1; then \
		pip install checkov; \
	else \
		echo "pip not available. Please install Python and pip first."; \
	fi
	@if command -v go >/dev/null 2>&1; then \
		go install github.com/terraform-linters/tflint/cmd/tflint@latest; \
	else \
		echo "go not available. Please install Go first."; \
	fi

# Show current status
status:
	@echo "Terraform Status:"
	@if [ -f .terraform/terraform.tfstate ]; then \
		terraform show -json | jq -r '.values.root_module.resources[] | "\(.address): \(.values.id // "created")"'; \
	else \
		echo "No Terraform state found. Run 'make init' first."; \
	fi

# Test specific module
test-module-%: init
	@echo "Testing module: $*"
	@if [ -d "tests/unit/$*" ]; then \
		terraform test tests/unit/$*/; \
	else \
		echo "No tests found for module: $*"; \
	fi

# Quick test (unit tests only, no apply)
quick-test: test-unit

# Full test cycle (init, validate, test, plan)
full-test: init validate test plan
