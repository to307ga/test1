# Packer variables file
# Override default values for different environments

# Environment-specific settings
environment = "poc"
project_code = "poc"

# Instance configuration
instance_type = "t3.medium"
ssh_username = "ec2-user"

# AMI configuration
base_ami_name_filter = "al2023-ami-*-x86_64"
base_ami_owner = "amazon"

# Build configuration
ami_version = ""  # Will use timestamp if empty
