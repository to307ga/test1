# Packer Template for Golden AMI Creation
# This template creates a golden AMI with the latest patches and application deployment

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# Variables
variable "aws_region" {
  type        = string
  default     = "ap-northeast-1"
  description = "AWS region for AMI creation"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Instance type for AMI building"
}

variable "ssh_username" {
  type        = string
  default     = "ec2-user"
  description = "SSH username for connecting to the instance"
}

variable "environment" {
  type        = string
  default     = "poc"
  description = "Environment name for tagging"
}

variable "project_code" {
  type        = string
  default     = "poc"
  description = "Project code for naming and tagging"
}

variable "ami_version" {
  type        = string
  default     = "{{timestamp}}"
  description = "Version tag for the AMI"
}

variable "base_ami_name_filter" {
  type        = string
  default     = "al2023-ami-*-x86_64"
  description = "Name filter for base AMI selection (Amazon Linux 2023)"
}

variable "base_ami_owner" {
  type        = string
  default     = "amazon"
  description = "Owner of the base AMI"
}

# Data source to find the latest base AMI
data "amazon-ami" "base" {
  filters = {
    name                = var.base_ami_name_filter
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = [var.base_ami_owner]
  region      = var.aws_region
}

# Source configuration
source "amazon-ebs" "golden_ami" {
  ami_name      = "${var.project_code}-golden-ami-${var.ami_version}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = data.amazon-ami.base.id
  ssh_username  = var.ssh_username

  # Networking configuration
  vpc_filter {
    filters = {
      "tag:Name" = "${var.project_code}-vpc-${var.environment}"
    }
  }

  subnet_filter {
    filters = {
      "tag:Name" = "${var.project_code}-private-subnet-1a-${var.environment}"
    }
    most_free = true
  }

  # Security group for Packer build
  security_group_filter {
    filters = {
      "tag:Name" = "${var.project_code}-ec2-sg-${var.environment}"
    }
  }

  # Associate public IP for connectivity (if building in private subnet)
  associate_public_ip_address = false

  # Use SSM for connectivity instead of SSH
  communicator = "ssh"
  ssh_interface = "session_manager"

  # EBS settings
  ebs_optimized = true
  encrypt_boot  = true

  # Instance metadata settings
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  # Tags for the instance during build
  run_tags = {
    Name        = "${var.project_code}-packer-build-${var.ami_version}"
    Environment = var.environment
    Project     = var.project_code
    Purpose     = "AMI-Build"
    Builder     = "Packer"
  }

  # Tags for the resulting AMI
  tags = {
    Name               = "${var.project_code}-golden-ami-${var.ami_version}"
    Environment        = var.environment
    Project            = var.project_code
    BaseAMI            = data.amazon-ami.base.id
    BaseAMIName        = data.amazon-ami.base.name
    CreatedBy          = "Packer"
    BuildDate          = "{{timestamp}}"
    Version            = var.ami_version
    Type               = "Golden"
    OS                 = "Amazon-Linux-2023"
    PatchLevel         = "Latest"
    ApplicationReady   = "false"
  }

  # Snapshot tags
  snapshot_tags = {
    Name        = "${var.project_code}-golden-ami-snapshot-${var.ami_version}"
    Environment = var.environment
    Project     = var.project_code
    CreatedBy   = "Packer"
    BuildDate   = "{{timestamp}}"
  }
}

# Build configuration
build {
  name = "golden-ami-build"
  sources = [
    "source.amazon-ebs.golden_ami"
  ]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed successfully'"
    ]
  }

  # System update and basic security patches
  provisioner "shell" {
    inline = [
      "echo 'Starting system updates...'",
      "sudo dnf update -y",
      "sudo dnf install -y amazon-ssm-agent",
      "sudo systemctl enable amazon-ssm-agent",
      "sudo systemctl start amazon-ssm-agent",
      "echo 'System updates completed'"
    ]
  }

  # Install additional required packages
  provisioner "shell" {
    inline = [
      "echo 'Installing additional packages...'",
      "sudo dnf install -y",
      "  htop",
      "  tmux",
      "  git",
      "  curl",
      "  wget",
      "  unzip",
      "  jq",
      "  python3",
      "  python3-pip",
      "echo 'Additional packages installed'"
    ]
  }

  # Run Ansible playbook for middleware and base system setup
  # Note: Application code deployment is handled separately via Jenkins + Gitea
  provisioner "ansible" {
    playbook_file = "../ansible-playbooks/site.yml"
    inventory_directory = "../ansible-playbooks/inventory"
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_STDOUT_CALLBACK=yaml"
    ]
    extra_arguments = [
      "--extra-vars", "packer_build=true",
      "--extra-vars", "environment=${var.environment}",
      "--tags", "base,middleware",
      "--skip-tags", "application"
    ]
    user = var.ssh_username
  }

  # Final security hardening and cleanup
  provisioner "shell" {
    inline = [
      "echo 'Performing final hardening and cleanup...'",
      "# Remove sensitive files",
      "sudo rm -rf /root/.ssh/authorized_keys",
      "sudo rm -rf /home/${var.ssh_username}/.ssh/authorized_keys",
      "sudo rm -rf /var/log/cloud-init*.log",
      "# Clear bash history",
      "history -c",
      "sudo rm -rf /root/.bash_history",
      "sudo rm -rf /home/${var.ssh_username}/.bash_history",
      "# Clean package cache",
      "sudo dnf clean all",
      "# Ensure services are properly configured",
      "sudo systemctl enable amazon-ssm-agent",
      "echo 'Final cleanup completed'"
    ]
  }

  # Generate build manifest
  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
    custom_data = {
      build_time     = "{{timestamp}}"
      build_user     = "{{user `build_user`}}"
      base_ami_id    = "{{.SourceAMI}}"
      base_ami_name  = "{{.SourceAMIName}}"
      environment    = "${var.environment}"
      project_code   = "${var.project_code}"
    }
  }
}
