# CI/CD Setup Guide for MinIO Infrastructure

## Overview
This guide explains how to set up the complete CI/CD pipeline for MinIO with SSL certificate infrastructure using GitHub Actions.

## Prerequisites

### 1. GitHub Repository Setup
- GitHub repository with proper permissions
- Access to repository settings for secrets configuration
- Kubernetes cluster with `kubectl` access

### 2. Required Tools in Cluster
- **cert-manager**: For SSL certificate management
- **nginx-ingress**: For ingress routing
- **kubectl**: For cluster management

### 3. Required Secrets
The following secrets must be configured in GitHub repository settings:

#### `KUBE_CONFIG`
Base64-encoded Kubernetes configuration file for cluster access.

```bash
# Generate the secret value
cat ~/.kube/config | base64 -w 0
```

## Repository Configuration

### 1. Clone or Initialize Repository

```bash
# Option 1: Initialize new repository
git init
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git

# Option 2: Clone existing repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```

### 2. Configure GitHub Secrets

Navigate to your GitHub repository settings:
`Settings` → `Secrets and variables` → `Actions`

Add the following secrets:

| Secret Name | Description | How to Generate |
|------------|-------------|-----------------|
| `KUBE_CONFIG` | Base64-encoded kubeconfig | `cat ~/.kube/config \| base64 -w 0` |

### 3. Environment Protection (Optional)

For production deployments, configure environment protection:
1. Go to `Settings` → `Environments`
2. Create environments: `dev`, `staging`, `prod`
3. Configure protection rules for `prod`:
   - Required reviewers
   - Wait timer
   - Deployment branches

## Workflow Files

### 1. Manifest Validation (`.github/workflows/validate-manifests.yml`)
- **Trigger**: Push/PR to main branches
- **Purpose**: Validate Kubernetes manifests
- **Actions**: 
  - Lint YAML files
  - Dry-run kubectl apply
  - Check for hardcoded secrets

### 2. MinIO Deployment (`.github/workflows/deploy-minio.yml`)
- **Trigger**: Changes to MinIO files, manual dispatch
- **Purpose**: Deploy MinIO with SSL infrastructure
- **Jobs**:
  - Validate manifests
  - Security scanning
  - Deploy certificates
  - Deploy MinIO
  - Test SSL configuration

### 3. Certificate Monitoring (`.github/workflows/certificate-monitoring.yml`)
- **Trigger**: Daily schedule (6 AM UTC), manual dispatch
- **Purpose**: Monitor and maintain SSL certificates
- **Jobs**:
  - Check certificate status
  - Auto-renew expiring certificates
  - Generate status reports

## Deployment Process

### 1. Initial Setup

```bash
# 1. Ensure cluster prerequisites
kubectl get namespace cert-manager || {
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
}

# 2. Configure repository secrets (via GitHub UI)
# - Add KUBE_CONFIG secret

# 3. Push code to trigger initial deployment
git add .
git commit -m "feat: Initial MinIO infrastructure setup"
git push origin main
```

### 2. Manual Deployment

```bash
# Deploy certificates only
gh workflow run deploy-minio.yml -f environment=prod -f force_cert_renewal=true

# Deploy full MinIO stack
gh workflow run deploy-minio.yml -f environment=prod

# Check certificate status
gh workflow run certificate-monitoring.yml -f action=check
```

### 3. Environment-Specific Deployment

```bash
# Development environment
gh workflow run deploy-minio.yml -f environment=dev

# Staging environment
gh workflow run deploy-minio.yml -f environment=staging

# Production environment (requires approval if protection enabled)
gh workflow run deploy-minio.yml -f environment=prod
```

## Monitoring and Maintenance

### 1. Automatic Certificate Monitoring
- **Schedule**: Daily at 6 AM UTC
- **Actions**: 
  - Check certificate expiration
  - Test SSL connectivity
  - Auto-renew certificates < 15 days expiry
  - Generate status reports

### 2. Manual Certificate Operations

```bash
# Force certificate renewal
gh workflow run certificate-monitoring.yml -f action=renew

# Generate certificate report
gh workflow run certificate-monitoring.yml -f action=report

# Check certificate status
gh workflow run certificate-monitoring.yml -f action=check
```

### 3. Troubleshooting Failed Deployments

```bash
# Check workflow logs
gh run list --workflow=deploy-minio.yml
gh run view RUN_ID --log

# Check cluster status
kubectl get pods -n minio
kubectl describe certificate -n minio
kubectl logs -n cert-manager deployment/cert-manager
```

## Security Considerations

### 1. Secret Management
- ✅ Use GitHub secrets for sensitive data
- ✅ Rotate kubeconfig regularly
- ✅ Limit secret access to necessary workflows
- ❌ Never commit secrets to repository

### 2. Environment Protection
- ✅ Require approvals for production deployments
- ✅ Use environment-specific secrets
- ✅ Implement branch protection rules
- ✅ Enable deployment logging

### 3. Certificate Security
- ✅ Monitor certificate expiration
- ✅ Auto-renew certificates
- ✅ Use internal CA for cluster communication
- ✅ Regular security scans with Trivy

## Workflow Features

### 1. Conditional Execution
- Only runs when relevant files change
- Skips unnecessary deployments
- Environment-specific logic

### 2. Security Scanning
- Trivy security scanning
- Secret detection
- Configuration validation

### 3. Testing and Verification
- SSL connectivity tests
- Certificate validation
- Health checks

### 4. Reporting
- Deployment status notifications
- Certificate status reports
- Artifact uploads

## Common Issues and Solutions

### 1. Certificate Issues

**Problem**: Certificates not ready
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl describe certificate minio-internal-tls -n minio

# Force renewal
kubectl delete secret minio-internal-tls -n minio
```

**Problem**: SSL connection failed
```bash
# Extract and test CA certificate
./scripts/extract-minio-ca.sh test

# Check pod logs
kubectl logs -n minio deployment/prod-minio-deployment-prod
```

### 2. Deployment Issues

**Problem**: Workflow fails with kubectl errors
```bash
# Verify kubeconfig secret
echo $KUBE_CONFIG | base64 -d > test-config
kubectl --kubeconfig=test-config get nodes

# Check cluster connectivity
kubectl cluster-info
```

**Problem**: Environment protection blocking deployment
- Check GitHub environment settings
- Ensure proper approvals
- Verify branch protection rules

### 3. Permission Issues

**Problem**: Insufficient permissions
- Verify GitHub repository permissions
- Check Kubernetes RBAC
- Ensure secret access permissions

## Best Practices

### 1. Development Workflow
1. ✅ Work on feature branches
2. ✅ Test in development environment first
3. ✅ Use pull requests for code review
4. ✅ Validate manifests locally before pushing

### 2. Deployment Strategy
1. ✅ Deploy to environments in order: dev → staging → prod
2. ✅ Use manual approval for production
3. ✅ Monitor certificate expiration
4. ✅ Regular backup of certificates and configs

### 3. Monitoring
1. ✅ Set up alerts for certificate expiration
2. ✅ Monitor deployment success/failure
3. ✅ Regular security scans
4. ✅ Performance monitoring

## Integration with ArgoCD (Optional)

If using ArgoCD for GitOps:

```bash
# Create ArgoCD application
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minio-ssl
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
    targetRevision: HEAD
    path: applications/minio/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: minio
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

---

## Summary

This CI/CD setup provides:
- ✅ **Automated deployment** of MinIO with SSL
- ✅ **Certificate management** with auto-renewal
- ✅ **Security scanning** and validation
- ✅ **Environment protection** for production
- ✅ **Monitoring and reporting** capabilities

The pipeline ensures secure, reliable deployment of MinIO infrastructure with comprehensive SSL/TLS support. 