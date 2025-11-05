# GitHub Actions Pipeline Setup Guide

## Overview

This GitHub Actions workflow automates the deployment of your MediPlus infrastructure to AWS using Terraform. It supports three operations: **plan**, **apply**, and **destroy**.

## Required GitHub Secrets

Configure the following secrets in your GitHub repository:

1. Go to: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

### Required Secrets

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `SSH_PRIVATE_KEY` | Your SSH private key content (PEM format) | Entire content of your `.pem` file |

### Optional Secrets (with defaults)

| Secret Name | Description | Default Value |
|------------|-------------|---------------|
| `DOMAIN_NAME` | Your domain name | `mypodsix.online` |
| `EMAIL` | Email for Let's Encrypt certificates | `okoro.christianpeace@gmail.com` |
| `KEY_NAME` | AWS EC2 Key Pair name | `stagging-key` |
| `SSH_ALLOWED_CIDR` | CIDR block allowed for SSH access | `0.0.0.0/0` (allow all) |

## Workflow Triggers

### Automatic Triggers

- **Push to `main` branch**: Automatically runs `terraform plan` and `terraform apply` if changes are in:
  - `terraform/**` directory
  - `.github/workflows/deploy.yml`

### Manual Triggers (workflow_dispatch)

You can manually trigger the workflow with three actions:

1. **Plan**: Preview changes without applying
   - Go to **Actions** tab → **Deploy MediPlus Infrastructure to AWS** → **Run workflow** → Select `plan`

2. **Apply**: Deploy infrastructure
   - Go to **Actions** tab → **Deploy MediPlus Infrastructure to AWS** → **Run workflow** → Select `apply`

3. **Destroy**: Tear down infrastructure
   - Go to **Actions** tab → **Deploy MediPlus Infrastructure to AWS** → **Run workflow** → Select `destroy`

## Workflow Steps

### 1. Terraform Job

1. **Checkout code**: Retrieves your repository code
2. **Configure AWS credentials**: Sets up AWS authentication
3. **Setup Terraform**: Installs Terraform 1.7.5
4. **Setup Terraform Variables**: Configures all required Terraform variables from secrets
5. **Terraform Init**: Initializes Terraform backend and providers
6. **Terraform Format Check**: Validates code formatting
7. **Terraform Validate**: Validates Terraform configuration
8. **Terraform Plan**: Generates execution plan (for plan/apply actions)
9. **Terraform Apply**: Applies infrastructure changes (for apply action)
10. **Terraform Destroy**: Destroys infrastructure (for destroy action)
11. **Get Terraform Outputs**: Retrieves public IPs of deployed instances
12. **Display Infrastructure Info**: Shows deployment summary in GitHub Actions UI

### 2. Verify Deployment Job

Runs after successful apply to verify:
- Web server HTTP response
- Reverse proxy HTTP response

## Workflow Features

### ✅ Security

- Secrets are stored securely in GitHub Secrets
- SSH private key is handled as sensitive Terraform variable
- No credentials are logged in workflow output

### ✅ Reliability

- Format and validation checks before deployment
- Plan artifacts saved for review
- Deployment verification step

### ✅ Flexibility

- Supports manual triggers with action selection
- Optional secrets with sensible defaults
- Works with existing AWS resources (key pairs, etc.)

### ✅ Visibility

- Detailed step-by-step logs
- Deployment summary in GitHub Actions UI
- Infrastructure IPs displayed after deployment

## Setting Up SSH Private Key Secret

1. **Get your private key content**:
   ```powershell
   # On Windows
   Get-Content -Raw "C:\Users\user\Downloads\stagging-key (1).pem"
   ```

2. **Copy the entire output** (including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`)

3. **Add to GitHub Secrets**:
   - Go to your repository → **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `SSH_PRIVATE_KEY`
   - Value: Paste the entire private key content
   - Click **Add secret**

## Setting Up AWS Credentials

1. **Create IAM User** (if you don't have one):
   - Go to AWS IAM Console → **Users** → **Add users**
   - Enable **Programmatic access**
   - Attach policy: `AmazonEC2FullAccess` (or more restrictive custom policy)
   - Save the **Access Key ID** and **Secret Access Key**

2. **Add to GitHub Secrets**:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key ID
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key

## Workflow Output Example

After a successful deployment, you'll see:

```
## 🚀 Infrastructure Deployment Summary

### Web Server
- **Public IP:** `13.51.178.39`

### Reverse Proxy
- **Public IP:** `13.51.180.50`

### ⚠️ Next Steps
1. Update DNS A record for `mypodsix.online` to point to `13.51.180.50`
2. Wait for DNS propagation (usually 5-15 minutes)
3. The reverse proxy will automatically obtain SSL certificate once DNS is ready

### 📝 Access Information
- Web Server: http://13.51.178.39
- Reverse Proxy: http://13.51.180.50
- Domain (after DNS): http://mypodsix.online
```

## Troubleshooting

### Workflow Fails at Terraform Apply

**Issue**: Provisioner errors (SSH timeout, connection issues)

**Solutions**:
- Ensure `SSH_ALLOWED_CIDR` includes GitHub Actions runner IPs (or use `0.0.0.0/0` temporarily)
- Verify `KEY_NAME` matches an existing AWS EC2 key pair
- Check that `SSH_PRIVATE_KEY` secret contains the correct private key content

### Terraform Plan Shows No Changes

**Issue**: Infrastructure already exists and matches configuration

**Solution**: This is normal. The workflow will skip apply if no changes are detected.

### Certbot Fails in Provisioner

**Issue**: DNS not pointing to reverse proxy yet

**Solution**: This is expected. The script will retry. After DNS propagation, you can manually run:
```bash
sudo certbot --nginx -d yourdomain.com --non-interactive --agree-tos -m your@email.com --redirect
```

### SSH Key Format Issues

**Issue**: Invalid key format errors

**Solution**: 
- Ensure the key is in OpenSSH format (`.pem` or `id_rsa` format)
- If you have a `.ppk` file, convert it using PuTTYgen
- Make sure the entire key (including BEGIN/END markers) is in the secret

## Best Practices

1. **Limit SSH Access**: Set `SSH_ALLOWED_CIDR` to your specific IP range instead of `0.0.0.0/0`
2. **Review Plans**: Always review the Terraform plan before applying in production
3. **Test First**: Use the `plan` action to preview changes before applying
4. **Monitor Costs**: Use `destroy` action when infrastructure is not needed
5. **Rotate Secrets**: Regularly rotate AWS credentials and SSH keys
6. **Use Branch Protection**: Protect your `main` branch to prevent accidental deployments

## Workflow File Location

- **Path**: `.github/workflows/deploy.yml`
- **Edit**: Modify this file to customize the workflow behavior

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS EC2 Key Pairs Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)

