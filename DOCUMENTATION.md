# MediPlus Infrastructure Deployment Guide: AWS Terraform Automation with CI/CD Pipeline

## Executive Summary

This comprehensive documentation outlines the complete infrastructure deployment solution for the MediPlus web application, leveraging **AWS cloud services**, **Terraform infrastructure-as-code**, and **GitHub Actions CI/CD pipeline**. The solution implements a production-ready, scalable, two-tier architecture with automated SSL certificate management, reverse proxy configuration, and seamless deployment workflows.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture Design](#architecture-design)
3. [Infrastructure Components](#infrastructure-components)
4. [File Structure and Scripts](#file-structure-and-scripts)
5. [Prerequisites and Setup](#prerequisites-and-setup)
6. [Deployment Methods](#deployment-methods)
7. [GitHub Actions CI/CD Pipeline](#github-actions-cicd-pipeline)
8. [Security Considerations](#security-considerations)
9. [Operational Procedures](#operational-procedures)
10. [Troubleshooting Guide](#troubleshooting-guide)
11. [Best Practices and Recommendations](#best-practices-and-recommendations)

---

## Project Overview

### Purpose

The MediPlus infrastructure project automates the provisioning and management of a complete web application hosting environment on AWS. It provides:

- **Automated Infrastructure Deployment**: One-command infrastructure provisioning using Terraform
- **High Availability**: Redundant web server and reverse proxy architecture
- **SSL/TLS Encryption**: Automated Let's Encrypt certificate management
- **CI/CD Integration**: GitHub Actions workflow for automated deployments
- **Scalable Architecture**: Easily expandable infrastructure design

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Infrastructure as Code | Terraform | ≥1.7.0 |
| Cloud Provider | AWS | Multiple Regions |
| Operating System | Ubuntu | 24.04 LTS |
| Web Server | Nginx | Latest Stable |
| SSL Certificates | Let's Encrypt (Certbot) | Latest |
| CI/CD Platform | GitHub Actions | - |
| Container Runtime | Docker (Optional) | Latest |

### Key Features

✅ **Automated VPC and Networking Setup**  
✅ **Security Group Configuration with SSH Access Control**  
✅ **Dual EC2 Instance Deployment (Web Server + Reverse Proxy)**  
✅ **Automated Nginx Reverse Proxy Configuration**  
✅ **Let's Encrypt SSL Certificate Automation**  
✅ **DNS Readiness Verification**  
✅ **GitHub Actions CI/CD Integration**  
✅ **Infrastructure State Management**  
✅ **Comprehensive Error Handling and Retry Logic**

---

## Architecture Design

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet / Users                        │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           │ HTTPS (443) / HTTP (80)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              AWS Region: eu-north-1 (Default)               │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              VPC (10.0.0.0/16)                      │  │
│  │                                                       │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │     Public Subnet (10.0.1.0/24)              │  │  │
│  │  │                                               │  │  │
│  │  │  ┌──────────────────────────────────────┐   │  │  │
│  │  │  │   Reverse Proxy Instance             │   │  │  │
│  │  │  │   - Nginx                            │   │  │  │
│  │  │  │   - Certbot                          │   │  │  │
│  │  │  │   - SSL Termination                  │   │  │  │
│  │  │  └───────────┬──────────────────────────┘   │  │  │
│  │  │              │ HTTP Proxy                    │  │  │
│  │  │              ▼                               │  │  │
│  │  │  ┌──────────────────────────────────────┐   │  │  │
│  │  │  │   Web Server Instance                │   │  │  │
│  │  │  │   - Nginx                            │   │  │  │
│  │  │  │   - Static Content                   │   │  │  │
│  │  │  │   - Application Files                │   │  │  │
│  │  │  └──────────────────────────────────────┘   │  │  │
│  │  │                                               │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │     Internet Gateway                        │  │  │
│  │  │     Route Table (0.0.0.0/0 → IGW)          │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                    │  │
│  └────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Network Architecture

#### VPC Configuration
- **CIDR Block**: `10.0.0.0/16`
- **DNS Support**: Enabled
- **DNS Hostnames**: Enabled
- **Purpose**: Isolated network environment for MediPlus infrastructure

#### Subnet Configuration
- **Type**: Public Subnet
- **CIDR Block**: `10.0.1.0/24`
- **Availability Zone**: `{region}a` (e.g., `eu-north-1a`)
- **Auto-assign Public IP**: Enabled
- **Purpose**: Hosts EC2 instances with direct internet access

#### Routing
- **Internet Gateway**: Provides internet connectivity
- **Route Table**: Routes all traffic (0.0.0.0/0) to Internet Gateway
- **Public Access**: Full internet connectivity for both instances

### Security Architecture

#### Security Groups

**Web Server Security Group (`web_sg`)**
- **Inbound Rules**:
  - Port 22 (SSH): Restricted to `var.ssh_allowed_cidr` (configurable)
  - Port 80 (HTTP): Open to `0.0.0.0/0` (public access)
  - Port 443 (HTTPS): Open to `0.0.0.0/0` (public access)
- **Outbound Rules**: All traffic allowed (`0.0.0.0/0`)
- **Purpose**: Hosts web application content

**Reverse Proxy Security Group (`proxy_sg`)**
- **Inbound Rules**:
  - Port 22 (SSH): Restricted to `var.ssh_allowed_cidr` (configurable)
  - Port 80 (HTTP): Open to `0.0.0.0/0` (for Let's Encrypt validation)
  - Port 443 (HTTPS): Open to `0.0.0.0/0` (SSL/TLS termination)
- **Outbound Rules**: All traffic allowed (`0.0.0.0/0`)
- **Purpose**: Handles SSL termination and routes traffic to web server

### Application Flow

1. **User Request**: User accesses `https://yourdomain.com`
2. **DNS Resolution**: DNS resolves to Reverse Proxy public IP
3. **SSL Termination**: Reverse Proxy handles SSL/TLS encryption
4. **Proxy Forwarding**: Reverse Proxy forwards HTTP request to Web Server
5. **Content Delivery**: Web Server serves static content or application
6. **Response Path**: Response flows back through Reverse Proxy to user

---

## Infrastructure Components

### Terraform Resources

#### Networking Resources

**`aws_vpc.main`**
- Creates isolated VPC environment
- Enables DNS support and hostnames
- Tags: `Name = "mediplus-vpc"`

**`aws_subnet.public`**
- Public subnet for internet-facing resources
- Auto-assigns public IP addresses
- Tags: `Name = "public-subnet"`

**`aws_internet_gateway.gw`**
- Provides internet connectivity to VPC
- Tags: `Name = "internet-gateway"`

**`aws_route_table.public`**
- Routes all internet traffic through Internet Gateway
- Tags: `Name = "public-route-table"`

**`aws_route_table_association.public_assoc`**
- Associates public subnet with public route table

#### Security Resources

**`aws_security_group.web_sg`**
- Web server security group
- Configurable SSH access via `var.ssh_allowed_cidr`
- Public HTTP/HTTPS access

**`aws_security_group.proxy_sg`**
- Reverse proxy security group
- Configurable SSH access via `var.ssh_allowed_cidr`
- Public HTTP/HTTPS access

#### Compute Resources

**`aws_instance.web_server`**
- **AMI**: Ubuntu 24.04 LTS (configurable via `var.ami`)
- **Instance Type**: `t3.micro` (configurable via `var.instance_type`)
- **Key Pair**: Configurable via `var.key_name`
- **Subnet**: Public subnet
- **Security Group**: `web_sg`
- **Provisioning**:
  - Copies `install_and_deploy_web.sh` script
  - Executes script to install and configure web server
  - Deploys static content from GitHub repository

**`aws_instance.reverse_proxy`**
- **AMI**: Ubuntu 24.04 LTS (configurable via `var.ami`)
- **Instance Type**: `t3.micro` (configurable via `var.instance_type`)
- **Key Pair**: Configurable via `var.key_name`
- **Subnet**: Public subnet
- **Security Group**: `proxy_sg`
- **Dependencies**: Waits 180 seconds after web server creation
- **Provisioning**:
  - Copies `install_and_configure_proxy.sh` script
  - Executes script to:
    - Install Nginx and Certbot
    - Configure reverse proxy to web server
    - Wait for DNS propagation
    - Obtain and configure SSL certificate

**`time_sleep.wait_180_seconds`**
- Ensures web server is ready before proxy configuration
- Prevents race conditions in provisioning

#### Outputs

**`web_server_public_ip`**
- Public IP address of web server instance
- Used for direct access or debugging

**`reverse_proxy_public_ip`**
- Public IP address of reverse proxy instance
- **Important**: This IP should be used for DNS A record configuration

---

## File Structure and Scripts

### Repository Structure

```
mediplus/
├── .github/
│   ├── workflows/
│   │   └── deploy.yml              # GitHub Actions CI/CD workflow
│   └── GITHUB_ACTIONS_SETUP.md     # GitHub Actions setup guide
├── terraform/
│   ├── main.tf                     # Main Terraform configuration
│   ├── variables.tf                # Variable definitions
│   ├── output.tf                   # Output definitions
│   ├── scripts/
│   │   ├── install_and_deploy_web.sh      # Web server setup script
│   │   └── install_and_configure_proxy.sh # Reverse proxy setup script
│   └── terraform.tfstate          # Terraform state (gitignored)
├── .gitignore                      # Git ignore rules
├── Dockerfile                      # Container configuration (optional)
├── index.html                      # Web application files
├── blog-single.html
├── contact.html
└── [other static files]
```

### Key Files Description

#### `terraform/main.tf`

The main Terraform configuration file containing:

- **Provider Configuration**: AWS and Time providers
- **Local Values**: SSH private key resolution logic
- **VPC and Networking**: Complete network infrastructure
- **Security Groups**: Web and proxy security configurations
- **EC2 Instances**: Web server and reverse proxy instances with provisioners
- **Resource Dependencies**: Proper dependency management

**Key Features**:
- Uses `local.ssh_private_key` for flexible SSH key handling
- Implements preconditions to validate SSH key availability
- Includes connection blocks for SSH provisioning
- File and remote-exec provisioners for instance configuration

#### `terraform/variables.tf`

Defines all configurable variables:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `region` | string | `eu-north-1` | AWS region for deployment |
| `ami` | string | `ami-0fa91bc90632c73c9` | Ubuntu 24.04 AMI ID |
| `instance_type` | string | `t3.micro` | EC2 instance type |
| `key_name` | string | `stagging-key` | AWS EC2 Key Pair name |
| `private_key_path` | string | Windows path | Path to SSH private key file |
| `private_key` | string (sensitive) | - | Inline SSH private key content |
| `domain_name` | string | `mypodsix.online` | Domain name for SSL certificate |
| `email` | string | - | Email for Let's Encrypt notifications |
| `ssh_allowed_cidr` | string | `0.0.0.0/0` | CIDR block for SSH access |

#### `terraform/output.tf`

Defines infrastructure outputs:

- `web_server_public_ip`: Public IP of web server
- `reverse_proxy_public_ip`: Public IP of reverse proxy (use for DNS)

#### `terraform/scripts/install_and_deploy_web.sh`

**Purpose**: Configures and deploys web server content

**Actions**:
1. Waits 180 seconds for instance stabilization
2. Updates package manager (`apt update`)
3. Installs Nginx and Git
4. Clones MediPlus repository from GitHub
5. Copies content to `/var/www/html/`
6. Enables and starts Nginx service

**Parameters**: None (uses hardcoded GitHub repository URL)

**Note**: Currently clones from `https://github.com/Christianchika/mediplus.git`

#### `terraform/scripts/install_and_configure_proxy.sh`

**Purpose**: Configures reverse proxy with SSL certificate

**Parameters**:
- `$1`: Web server IP address
- `$2`: Domain name
- `$3`: Email address for Let's Encrypt

**Actions**:
1. Waits 180 seconds for instance stabilization
2. Installs Nginx, Certbot, and Python3 Certbot plugin
3. Creates Nginx reverse proxy configuration:
   - Listens on port 80
   - Proxies to web server IP
   - Sets appropriate headers
4. Enables site configuration and restarts Nginx
5. **DNS Readiness Check**:
   - Detects instance public IP
   - Waits up to 40 attempts (15 seconds each) for DNS to resolve
   - Verifies HTTP accessibility (200/301/302 status codes)
6. Obtains SSL certificate via Certbot:
   - Uses Nginx plugin
   - Non-interactive mode
   - Configures HTTP to HTTPS redirect
   - Gracefully handles failures (keeps HTTP-only if certificate fails)

**Intelligent Features**:
- Automatic DNS propagation detection
- HTTP readiness verification
- Retry logic for certificate acquisition
- Graceful degradation (HTTP-only if SSL fails)

---

## Prerequisites and Setup

### Required Accounts and Services

1. **AWS Account**
   - Active AWS account with billing enabled
   - IAM user with programmatic access
   - Appropriate permissions (EC2, VPC, IAM)
   - EC2 Key Pair created in target region

2. **GitHub Account**
   - Repository access
   - GitHub Actions enabled
   - Secrets management access

3. **Domain Name** (Optional but recommended)
   - Registered domain name
   - DNS management access
   - Ability to create A records

### Local Development Environment

#### Required Software

**Terraform**
```bash
# Windows (using Chocolatey)
choco install terraform

# macOS (using Homebrew)
brew install terraform

# Linux
# Download from https://www.terraform.io/downloads
```

**AWS CLI** (Optional but recommended)
```bash
# Windows (using Chocolatey)
choco install awscli

# macOS (using Homebrew)
brew install awscli

# Linux
sudo apt-get install awscli
```

**Git**
```bash
# Windows: Download from https://git-scm.com/download/win
# macOS: Xcode Command Line Tools or Homebrew
# Linux: sudo apt-get install git
```

#### AWS Credentials Configuration

**Option 1: AWS CLI Configuration**
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format
```

**Option 2: Environment Variables**
```powershell
# Windows PowerShell
$env:AWS_ACCESS_KEY_ID = "your-access-key-id"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-access-key"
$env:AWS_DEFAULT_REGION = "eu-north-1"
```

**Option 3: AWS Credentials File**
```
# ~/.aws/credentials (Linux/Mac)
# C:\Users\YourUsername\.aws\credentials (Windows)

[default]
aws_access_key_id = your-access-key-id
aws_secret_access_key = your-secret-access-key
```

### EC2 Key Pair Setup

1. **Create Key Pair in AWS Console**:
   - Navigate to EC2 → Key Pairs
   - Click "Create key pair"
   - Name: `stagging-key` (or your preferred name)
   - Format: `.pem` (for OpenSSH)
   - Download and save securely

2. **Store Private Key**:
   - Windows: Save to `C:\Users\user\Downloads\stagging-key.pem`
   - Linux/Mac: Save to `~/.ssh/stagging-key.pem`
   - Set appropriate permissions (Linux/Mac: `chmod 400 ~/.ssh/stagging-key.pem`)

### GitHub Repository Setup

1. **Clone Repository**:
   ```bash
   git clone https://github.com/Christianchika/mediplus.git
   cd mediplus
   ```

2. **Configure Git** (if not already done):
   ```bash
   git config user.name "Your Name"
   git config user.email "your.email@example.com"
   ```

---

## Deployment Methods

### Method 1: Local Deployment (Manual)

#### Step 1: Configure Variables

Create `terraform/terraform.tfvars`:
```hcl
region            = "eu-north-1"
domain_name       = "yourdomain.com"
email             = "your-email@example.com"
key_name          = "stagging-key"
private_key_path  = "C:\\Users\\user\\Downloads\\stagging-key.pem"
ssh_allowed_cidr  = "YOUR.PUBLIC.IP.ADDR/32"
```

Or use environment variables:
```powershell
$env:TF_VAR_private_key = Get-Content -Raw "C:\Users\user\Downloads\stagging-key.pem"
$env:TF_VAR_domain_name = "yourdomain.com"
$env:TF_VAR_email = "your-email@example.com"
```

#### Step 2: Initialize Terraform

```powershell
cd terraform
terraform init
```

#### Step 3: Review Planned Changes

```powershell
terraform plan
```

#### Step 4: Deploy Infrastructure

```powershell
terraform apply
# Type 'yes' when prompted
```

#### Step 5: Get Outputs

```powershell
terraform output
# Or get specific output:
terraform output reverse_proxy_public_ip
```

#### Step 6: Configure DNS

1. Log in to your domain registrar/DNS provider
2. Create/Update A record:
   - **Name**: `@` or your subdomain
   - **Type**: `A`
   - **Value**: Use `reverse_proxy_public_ip` output
   - **TTL**: 300 (5 minutes) or default

#### Step 7: Verify Deployment

```powershell
# Wait 5-15 minutes for DNS propagation
# Then test:
curl http://yourdomain.com
curl https://yourdomain.com
```

### Method 2: GitHub Actions Deployment (Automated)

See [GitHub Actions CI/CD Pipeline](#github-actions-cicd-pipeline) section for detailed instructions.

---

## GitHub Actions CI/CD Pipeline

### Overview

The GitHub Actions workflow automates the entire deployment process, providing:

- **Automated Infrastructure Provisioning**: Terraform apply on push
- **Validation and Formatting Checks**: Ensures code quality
- **Plan Review**: Preview changes before applying
- **Manual Control**: Workflow dispatch for plan/apply/destroy
- **Deployment Verification**: HTTP health checks
- **Infrastructure Summary**: Detailed deployment information

### Workflow Configuration

#### Trigger Events

**Automatic Triggers**:
- Push to `main` branch (when Terraform files change)
- Path filters: `terraform/**` and `.github/workflows/deploy.yml`

**Manual Triggers** (workflow_dispatch):
- **Plan**: Preview infrastructure changes
- **Apply**: Deploy infrastructure
- **Destroy**: Tear down infrastructure

### Required GitHub Secrets

Configure these in: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

#### Required Secrets

| Secret Name | Description | Example |
|------------|-------------|----------|
| `AWS_ACCESS_KEY_ID` | AWS IAM user access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM user secret key | `wJalrXUtnFEMI/K7MDENG...` |
| `SSH_PRIVATE_KEY` | Complete SSH private key content | Full PEM file content |

#### Optional Secrets (with defaults)

| Secret Name | Default | Description |
|------------|---------|-------------|
| `DOMAIN_NAME` | `mypodsix.online` | Your domain name |
| `EMAIL` | `okoro.christianpeace@gmail.com` | Let's Encrypt email |
| `KEY_NAME` | `stagging-key` | AWS EC2 Key Pair name |
| `SSH_ALLOWED_CIDR` | `0.0.0.0/0` | SSH access CIDR block |

### Workflow Steps Breakdown

#### Job 1: Terraform

1. **Checkout Code**: Retrieves repository code
2. **Configure AWS Credentials**: Sets up AWS authentication
3. **Setup Terraform**: Installs Terraform 1.7.5
4. **Setup Terraform Variables**: Configures all variables from secrets
5. **Terraform Init**: Initializes Terraform backend
6. **Terraform Format Check**: Validates code formatting
7. **Terraform Validate**: Validates Terraform syntax
8. **Terraform Plan**: Generates execution plan
9. **Terraform Apply**: Applies infrastructure (on push/apply)
10. **Terraform Destroy**: Destroys infrastructure (on destroy)
11. **Get Terraform Outputs**: Retrieves instance public IPs
12. **Display Infrastructure Info**: Creates deployment summary

#### Job 2: Verify Deployment

1. **Checkout Code**: Retrieves repository
2. **Configure AWS Credentials**: AWS authentication
3. **Setup Terraform**: Terraform installation
4. **Get Terraform Outputs**: Retrieves instance IPs
5. **Wait for EC2 Instances**: 60-second initialization wait
6. **Verify Web Server HTTP**: Tests web server accessibility
7. **Verify Reverse Proxy HTTP**: Tests reverse proxy accessibility

### Setting Up GitHub Secrets

#### Step 1: Get SSH Private Key Content

**Windows PowerShell**:
```powershell
Get-Content -Raw "C:\Users\user\Downloads\stagging-key.pem"
```

**Linux/Mac**:
```bash
cat ~/.ssh/stagging-key.pem
```

#### Step 2: Add to GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. For each secret:
   - **Name**: Enter secret name (e.g., `SSH_PRIVATE_KEY`)
   - **Secret**: Paste the value
   - **Add secret**

#### Step 3: Test Workflow

1. Make a small change to `terraform/main.tf` (e.g., add a comment)
2. Commit and push:
   ```bash
   git add terraform/main.tf
   git commit -m "Test GitHub Actions workflow"
   git push origin main
   ```
3. Go to **Actions** tab to monitor workflow execution

### Workflow Output and Summary

After successful deployment, the workflow provides:

#### Deployment Summary
- Web Server Public IP
- Reverse Proxy Public IP
- DNS configuration instructions
- Access URLs

#### Verification Results
- HTTP status codes for both instances
- Health check results

### Troubleshooting GitHub Actions

#### Common Issues

**"Unable to process file command 'env'"**
- **Cause**: Multiline environment variable formatting issue
- **Solution**: Fixed in latest workflow version (uses `TFKEYEOF` delimiter)

**"No outputs found"**
- **Cause**: Outputs not available (plan-only run or first deployment)
- **Solution**: Workflow handles this gracefully, shows "N/A" until outputs exist

**"Terraform files are not formatted"**
- **Cause**: Code formatting issues
- **Solution**: Run `terraform fmt -recursive terraform` locally before pushing

**"SSH connection timeout"**
- **Cause**: Security group not allowing GitHub Actions runner IPs
- **Solution**: Ensure `SSH_ALLOWED_CIDR` includes `0.0.0.0/0` or GitHub Actions IP ranges

---

## Security Considerations

### SSH Access Control

**Current Configuration**:
- Default: `ssh_allowed_cidr = "0.0.0.0/0"` (allows SSH from anywhere)

**Recommended Configuration**:
```hcl
ssh_allowed_cidr = "YOUR.PUBLIC.IP.ADDR/32"
```

**For GitHub Actions**:
- Use `0.0.0.0/0` temporarily during deployment
- Or configure GitHub Actions IP ranges (requires maintenance)

### Secret Management

**Never Commit**:
- SSH private keys
- AWS access keys
- Terraform state files
- `.tfvars` files with secrets

**Use**:
- GitHub Secrets for CI/CD
- Environment variables for local development
- AWS Secrets Manager for production (advanced)

### Network Security

**Current Configuration**:
- Public subnets with internet-facing instances
- Security groups restrict SSH access
- HTTP/HTTPS open for public access

**Production Recommendations**:
- Consider private subnets for web servers
- Use Application Load Balancer (ALB) instead of direct EC2 access
- Implement WAF (Web Application Firewall)
- Use AWS Systems Manager Session Manager instead of SSH

### SSL/TLS Security

- **Certificate Provider**: Let's Encrypt (free, automated)
- **Certificate Renewal**: Automatic via Certbot
- **HTTP to HTTPS Redirect**: Automatic configuration
- **Certificate Validity**: 90 days (auto-renewed)

### Infrastructure Security

**Terraform State**:
- **Never commit** `terraform.tfstate` files
- Consider using remote state (S3 backend)
- Enable state encryption
- Use state locking (DynamoDB)

**IAM Permissions**:
- Use least-privilege principle
- Create dedicated IAM user for Terraform
- Attach only necessary policies:
  - `AmazonEC2FullAccess` (or more restrictive)
  - `AmazonVPCFullAccess` (or more restrictive)

---

## Operational Procedures

### Monitoring Infrastructure

#### Check Instance Status

```bash
# Via AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web-server,reverse-proxy" \
  --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value|[0],State.Name,PublicIpAddress]"
```

#### View Security Groups

```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=web-sg,proxy-sg"
```

### Updating Infrastructure

#### Modify Configuration

1. Edit `terraform/main.tf` or `terraform/variables.tf`
2. Review changes:
   ```bash
   terraform plan
   ```
3. Apply changes:
   ```bash
   terraform apply
   ```

#### Update Application Content

**Current Setup**: Content is cloned from GitHub during provisioning

**To Update**:
1. Push changes to GitHub repository
2. SSH into web server:
   ```bash
   ssh -i ~/.ssh/stagging-key.pem ubuntu@<web_server_ip>
   ```
3. Pull latest changes:
   ```bash
   cd /var/www/html
   sudo git pull origin main
   ```

### Scaling Infrastructure

#### Vertical Scaling (Larger Instances)

Edit `terraform/variables.tf`:
```hcl
variable "instance_type" {
  default = "t3.small"  # or t3.medium, t3.large, etc.
}
```

Or set via environment variable:
```bash
export TF_VAR_instance_type="t3.small"
terraform apply
```

#### Horizontal Scaling (Multiple Instances)

Requires Terraform configuration changes:
- Use `count` or `for_each` meta-arguments
- Update load balancer configuration
- Modify reverse proxy to handle multiple backend servers

### Backup and Recovery

#### Backup Terraform State

```bash
# Copy state file
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup

# Or use remote state (recommended)
# Configure S3 backend in terraform block
```

#### Disaster Recovery

1. **Infrastructure Recovery**:
   ```bash
   terraform apply  # Recreates infrastructure from configuration
   ```

2. **Application Recovery**:
   - Content is version-controlled in GitHub
   - Re-provisioning automatically deploys latest version

### Maintenance Tasks

#### Renew SSL Certificate Manually

```bash
ssh -i ~/.ssh/stagging-key.pem ubuntu@<reverse_proxy_ip>
sudo certbot renew --dry-run  # Test renewal
sudo certbot renew            # Actual renewal
sudo systemctl reload nginx
```

#### Update System Packages

```bash
ssh -i ~/.ssh/stagging-key.pem ubuntu@<instance_ip>
sudo apt update
sudo apt upgrade -y
```

#### View Nginx Logs

```bash
ssh -i ~/.ssh/stagging-key.pem ubuntu@<instance_ip>
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: SSH Connection Timeout

**Symptoms**:
- `terraform apply` fails with SSH timeout
- Cannot connect to instances

**Solutions**:
1. Check security group rules:
   ```bash
   aws ec2 describe-security-groups --group-names web-sg proxy-sg
   ```
2. Verify `ssh_allowed_cidr` includes your IP
3. Check instance status:
   ```bash
   aws ec2 describe-instance-status --instance-ids <instance-id>
   ```
4. Wait 2-3 minutes after instance creation before SSH

#### Issue: Certbot Certificate Acquisition Fails

**Symptoms**:
- Provisioner error: "Some challenges have failed"
- Certificate not obtained

**Solutions**:
1. **Verify DNS Configuration**:
   ```bash
   dig yourdomain.com
   # Should resolve to reverse_proxy_public_ip
   ```

2. **Check Port 80 Accessibility**:
   ```bash
   curl -I http://yourdomain.com
   # Should return 200, 301, or 302
   ```

3. **Manual Certificate Request**:
   ```bash
   ssh -i ~/.ssh/stagging-key.pem ubuntu@<reverse_proxy_ip>
   sudo certbot --nginx -d yourdomain.com \
     --non-interactive --agree-tos \
     -m your-email@example.com --redirect
   ```

4. **Check Let's Encrypt Rate Limits**:
   - Limited to 5 certificates per domain per week
   - Use staging environment for testing:
     ```bash
     sudo certbot --nginx -d yourdomain.com --staging
     ```

#### Issue: Web Server Not Responding

**Symptoms**:
- HTTP 502 Bad Gateway
- Connection refused

**Solutions**:
1. **Check Web Server Status**:
   ```bash
   ssh -i ~/.ssh/stagging-key.pem ubuntu@<web_server_ip>
   sudo systemctl status nginx
   ```

2. **Verify Nginx Configuration**:
   ```bash
   sudo nginx -t
   sudo systemctl restart nginx
   ```

3. **Check Content Deployment**:
   ```bash
   ls -la /var/www/html/
   # Should contain index.html and other files
   ```

4. **Verify Security Group**:
   - Ensure port 80 is open in `web_sg`

#### Issue: Terraform State Lock

**Symptoms**:
- `Error: Error acquiring the state lock`
- Cannot run `terraform apply`

**Solutions**:
1. **Check for other Terraform processes**:
   ```bash
   ps aux | grep terraform
   ```

2. **Force unlock** (use with caution):
   ```bash
   terraform force-unlock <lock-id>
   ```

3. **If using remote state**, check for stuck locks in DynamoDB

#### Issue: "No outputs found" in GitHub Actions

**Symptoms**:
- Workflow shows "No outputs found" warning
- Outputs not available

**Solutions**:
- This is expected during plan-only runs
- Outputs are only available after successful `terraform apply`
- Workflow handles this gracefully (shows "N/A")

#### Issue: Provisioner Timeout

**Symptoms**:
- Provisioner fails after 2 minutes
- Script execution incomplete

**Solutions**:
1. **Increase Timeout**:
   Edit `main.tf` connection block:
   ```hcl
   connection {
     timeout = "5m"  # Increase from 2m
   }
   ```

2. **Check Instance Resources**:
   - Ensure instance type has sufficient resources
   - Check CloudWatch metrics for CPU/memory

3. **Review Script Execution**:
   - SSH into instance and run script manually
   - Check for errors in script execution

### Debugging Commands

#### Check Terraform State

```bash
terraform show
terraform state list
terraform state show aws_instance.web_server
```

#### Validate Configuration

```bash
terraform validate
terraform fmt -check
terraform fmt -diff
```

#### View Instance Details

```bash
# Get instance IDs
terraform output -json

# Describe instances
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw web_server_id) \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,PrivateIpAddress]'
```

#### Test SSH Connection

```bash
ssh -i ~/.ssh/stagging-key.pem \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=10 \
  ubuntu@<instance_ip> \
  "echo 'SSH connection successful'"
```

---

## Best Practices and Recommendations

### Infrastructure as Code

✅ **Version Control Everything**
- All Terraform files in Git
- Use meaningful commit messages
- Tag releases for infrastructure versions

✅ **Modularize Configuration**
- Consider breaking into modules for reusability
- Separate environments (dev/staging/prod)

✅ **State Management**
- Use remote state (S3 + DynamoDB)
- Enable state encryption
- Enable state locking

### Security

✅ **Least Privilege**
- Minimal IAM permissions
- Restrict SSH access to known IPs
- Use AWS Systems Manager Session Manager

✅ **Secret Management**
- Never commit secrets
- Use AWS Secrets Manager for production
- Rotate credentials regularly

✅ **Network Security**
- Consider private subnets for web servers
- Use Application Load Balancer
- Implement WAF rules

### Monitoring and Alerting

**Recommended Monitoring**:
- CloudWatch metrics (CPU, memory, network)
- CloudWatch alarms for instance health
- Application health checks
- SSL certificate expiration monitoring

**Example CloudWatch Alarm**:
```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "web-server-high-cpu"
  comparison_operator  = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when CPU exceeds 80%"
}
```

### Cost Optimization

**Current Setup**:
- 2x `t3.micro` instances: ~$15-20/month
- Data transfer: Variable
- EBS storage: Minimal

**Optimization Tips**:
- Use Reserved Instances for long-term deployments
- Stop instances when not in use (dev/staging)
- Monitor and optimize data transfer
- Use CloudWatch to identify unused resources

### Disaster Recovery

**Backup Strategy**:
1. **Infrastructure**: Terraform code in Git
2. **Application**: GitHub repository
3. **State**: Remote state in S3
4. **Configuration**: Version-controlled scripts

**Recovery Procedures**:
1. Infrastructure: `terraform apply` (recreates from code)
2. Application: Re-provisioning deploys from GitHub
3. Data: Consider separate backup strategy for databases

### Future Enhancements

**Recommended Improvements**:

1. **Load Balancing**:
   - Add Application Load Balancer (ALB)
   - Multiple web server instances
   - Health checks and auto-scaling

2. **High Availability**:
   - Multiple availability zones
   - Auto Scaling Groups
   - Multi-region deployment

3. **Containerization**:
   - Migrate to ECS/EKS
   - Container-based deployments
   - CI/CD for containers

4. **Monitoring**:
   - CloudWatch dashboards
   - Application performance monitoring (APM)
   - Log aggregation (CloudWatch Logs)

5. **Backup and Recovery**:
   - Automated snapshots
   - Point-in-time recovery
   - Disaster recovery procedures

6. **Security Enhancements**:
   - WAF integration
   - DDoS protection (AWS Shield)
   - Security scanning in CI/CD

---

## Conclusion

This documentation provides a comprehensive guide to the MediPlus infrastructure deployment solution. The architecture is designed to be:

- **Scalable**: Easy to expand and modify
- **Secure**: Implements security best practices
- **Automated**: CI/CD integration for seamless deployments
- **Maintainable**: Well-documented and version-controlled
- **Cost-Effective**: Uses appropriate AWS services for the use case

For questions, issues, or contributions, please refer to the repository or contact the development team.

---

## Appendix

### A. Terraform Variable Reference

See `terraform/variables.tf` for complete variable definitions.

### B. AWS Resource Limits

- Default VPC limit: 5 per region
- Default subnet limit: 200 per VPC
- Default security group limit: 250 per VPC
- Default EC2 instance limit: Varies by instance type

### C. Let's Encrypt Rate Limits

- **Certificates per Registered Domain**: 50 per week
- **Duplicate Certificate Limit**: 5 per week
- **Failed Validation Limit**: 5 per account per hostname per hour

### D. Useful Commands Reference

```bash
# Terraform
terraform init              # Initialize Terraform
terraform plan              # Preview changes
terraform apply             # Apply changes
terraform destroy           # Destroy infrastructure
terraform output            # Show outputs
terraform fmt               # Format code
terraform validate          # Validate configuration

# AWS CLI
aws ec2 describe-instances  # List instances
aws ec2 describe-vpcs       # List VPCs
aws ec2 describe-security-groups  # List security groups

# SSH
ssh -i key.pem ubuntu@IP    # Connect to instance
scp -i key.pem file ubuntu@IP:/path  # Copy file

# DNS
dig domain.com              # Check DNS resolution
nslookup domain.com         # Alternative DNS lookup
```

### E. Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Maintained By**: MediPlus Infrastructure Team

