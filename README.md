# Infrastructure K8s - ArgoCD Applications

This repository contains Kubernetes manifests and ArgoCD applications for deploying infrastructure components on a K3s cluster using GitOps principles.

## Repository Structure

```
.
├── applications/           # Application-specific manifests
│   └── minio/             # MinIO object storage
│       ├── base/          # Base Kubernetes manifests
│       ├── overlays/      # Environment-specific overlays
│       │   ├── dev/       # Development environment
│       │   ├── staging/   # Staging environment
│       │   └── prod/      # Production environment
│       └── argocd-app.yaml # ArgoCD Application manifest
├── environments/          # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── projects/              # ArgoCD Project definitions
└── README.md
```

## Prerequisites

- K3s cluster with the following components already configured:
  - **Storage Class**: `nfs-client` (for persistent storage)
  - **SSL/TLS**: `letsencrypt-staging` cluster issuer (for SSL certificates)
  - **Ingress Controller**: NGINX Ingress Controller
  - **ArgoCD**: Installed and configured

## Applications

### MinIO Object Storage

MinIO is configured with:
- **Storage**: Uses `nfs-client` storage class
- **SSL**: Uses `letsencrypt-staging` for SSL certificates (API only)
- **Ingress**: Exposes only the API (port 9000) with SSL
- **Console**: Available internally via NodePort (port 30001) 
- **High Availability**: Configured for production with multiple replicas

#### Environment-Specific Configurations

| Environment | Storage | Replicas | API Hostname | Console Access |
|-------------|---------|----------|--------------|----------------|
| Development | 20Gi    | 1        | minio-dev.askcollections.com | NodePort 30001 |
| Staging     | 50Gi    | 1        | minio-staging.askcollections.com | NodePort 30001 |
| Production  | 200Gi   | 2        | minio-prod.askcollections.com | NodePort 30001 |

#### Default Credentials

- **Username**: `admin`
- **Password**: `password`

> **⚠️ Important**: Change these credentials in production environments by updating the secret in the respective overlay.

## Deployment

### Option 1: CI/CD with GitHub Actions (Recommended)

This repository includes comprehensive CI/CD pipelines for automated deployment with SSL certificate management.

#### Quick Setup

1. **Configure GitHub Repository**
   ```bash
   # Check prerequisites
   ./scripts/setup-repository.sh prerequisites
   
   # Configure your GitHub repository
   ./scripts/setup-repository.sh configure-remote https://github.com/USERNAME/k3s-minio-infrastructure.git
   
   # Generate secrets for GitHub
   ./scripts/setup-repository.sh secrets
   
   # Push to GitHub
   ./scripts/setup-repository.sh push
   ```

2. **Deploy via GitHub Actions**
   ```bash
   # Manual deployment trigger
   gh workflow run deploy-minio.yml -f environment=prod
   
   # Check deployment status
   gh run list
   ```

3. **Monitor certificates**
   ```bash
   # Check certificate status
   gh workflow run certificate-monitoring.yml -f action=check
   ```

#### CI/CD Features

- ✅ **Automated SSL Certificate Management** - Self-signed CA with auto-renewal
- ✅ **Multi-Environment Support** - dev, staging, prod with protection rules
- ✅ **Security Scanning** - Trivy security scans and secret detection
- ✅ **SSL Testing** - Automated SSL connectivity verification
- ✅ **Certificate Monitoring** - Daily certificate health checks
- ✅ **Deployment Validation** - Manifest validation and dry-run testing

For detailed CI/CD setup instructions, see [`CICD_SETUP.md`](CICD_SETUP.md).

### Option 2: Using ArgoCD

1. Apply the ArgoCD application:
```bash
kubectl apply -f applications/minio/argocd-app.yaml
```

2. Access ArgoCD UI and sync the application

### Option 3: Manual Deployment

For testing or manual deployment:

```bash
# Deploy certificates first
./scripts/deploy-minio-certificates.sh deploy

# Deploy to development
kubectl apply -k applications/minio/overlays/dev

# Deploy to staging
kubectl apply -k applications/minio/overlays/staging

# Deploy to production
kubectl apply -k applications/minio/overlays/prod
```

## Customization

### Updating Hostnames

Update the hostnames in the environment-specific overlays:
- `applications/minio/overlays/{env}/kustomization.yaml`

### Updating Storage

Modify the storage size in the PVC patches within the overlay files.

### Updating Credentials

Create new base64 encoded credentials:
```bash
echo -n "your-username" | base64
echo -n "your-password" | base64
```

Update the secret in the base configuration or create an overlay patch.

## Monitoring

MinIO includes built-in health checks:
- **Liveness Probe**: `/minio/health/live`
- **Readiness Probe**: `/minio/health/ready`

## Security Considerations

1. **Credentials**: Update default credentials for production
2. **SSL**: Switch to `letsencrypt-prod` for production environments
3. **Network Policies**: Consider implementing network policies for enhanced security
4. **RBAC**: Implement proper RBAC for MinIO access

## Troubleshooting

### Common Issues

1. **Storage Class Not Found**: Ensure `nfs-client` storage class is installed
2. **SSL Certificate Issues**: Verify `letsencrypt-staging` cluster issuer is working
3. **Ingress Issues**: Check NGINX ingress controller status

### Useful Commands

```bash
# Check MinIO pods
kubectl get pods -n minio

# Check MinIO services (API ClusterIP + Console NodePort)
kubectl get svc -n minio

# Check ingress (API only)
kubectl get ingress -n minio

# Check PVC
kubectl get pvc -n minio

# View logs
kubectl logs -n minio deployment/minio-deployment

# Access console internally (replace NODE_IP with your K3s node IP)
# Console URL: http://NODE_IP:30001
```

## Contributing

1. Make changes to the appropriate overlay or base configuration
2. Test changes in development environment first
3. Commit changes with descriptive messages
4. ArgoCD will automatically sync changes based on the configured sync policy

## License

This project is licensed under the MIT License. 