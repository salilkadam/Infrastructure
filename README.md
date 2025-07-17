# Infrastructure Repository

This repository contains Kubernetes manifests and ArgoCD applications for deploying infrastructure components on a K3s cluster using GitOps principles.

## Repository Structure

```
.
├── applications/           # Application-specific manifests
│   └── minio/             # MinIO object storage
│       ├── base/          # Base Kubernetes manifests
│       ├── overlays/      # Environment-specific overlays
│       └── argocd-app.yaml # ArgoCD Application manifest
├── docs/                  # Comprehensive documentation
│   ├── README.md         # Documentation index
│   └── minio/            # MinIO documentation
│       ├── README.md     # Main MinIO documentation
│       ├── SSL_CONFIGURATION.md  # SSL setup and configuration
│       └── DEPLOYMENT_GUIDE.md   # Deployment and troubleshooting
├── infrastructure/        # Base infrastructure components
│   └── base/             # NFS, MetalLB, and other base components
├── environments/          # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── scripts/               # Utility scripts and tools
├── projects/              # ArgoCD Project definitions
└── README.md             # This file
```

## Prerequisites

- **K3s cluster** with the following components:
  - **Storage Class**: `nfs-client` (for persistent storage)
  - **Cert-Manager**: For SSL certificate management
  - **NGINX Ingress Controller**: For external access
  - **ArgoCD**: For GitOps deployment management

## Applications

### [MinIO Object Storage](./docs/minio/)

**Overview**: Production-ready, scalable MinIO object storage deployment

**Features**:
- ✅ **Scalable Architecture**: 4-replica StatefulSet with 500Gi storage each
- ✅ **SSL Security**: Self-signed certificates for internal communication
- ✅ **External Access**: API available at `minio.askcollections.com`
- ✅ **Internal Console**: Console accessible via NodePort 30901
- ✅ **ArgoCD Integration**: Automated deployment and management

**Quick Start**:
```bash
# Deploy via ArgoCD
kubectl apply -f applications/minio/argocd-app.yaml

# Access external API
curl -I https://minio.askcollections.com

# Access internal console (replace with node IP)
curl -k https://<cluster-node-ip>:30901
```

**Documentation**: [Complete MinIO Documentation](./docs/minio/)

### etcd (Coming Soon)

**Overview**: Distributed key-value store for Kubernetes
**Status**: Planning phase
**Documentation**: Will be added to `docs/etcd/`

## Infrastructure Components

### Base Infrastructure (`infrastructure/base/`)

- **NFS Provisioner**: `00-nfs-rbac.yaml`, `01-nfs-provisioner.yaml`
- **Storage Classes**: `02-nfs-storage.yaml`
- **Load Balancer**: `03-metallb.yaml`

### Deployment

```bash
# Deploy base infrastructure
kubectl apply -f infrastructure/base/

# Verify components
kubectl get storageclass
kubectl get pods -n metallb-system
```

## Environment Management

### Environment Structure

Each application supports multiple environments:
- **Development**: Lightweight configuration for testing
- **Staging**: Production-like configuration for validation
- **Production**: Full production configuration with high availability

### Environment-Specific Deployment

```bash
# Deploy to specific environment
kubectl apply -k applications/minio/overlays/dev
kubectl apply -k applications/minio/overlays/staging
kubectl apply -k applications/minio/overlays/prod
```

## GitOps with ArgoCD

### ArgoCD Applications

Each application has an ArgoCD application manifest that:
- **Automated Sync**: Automatically deploys changes
- **Self-Healing**: Corrects drift from desired state
- **Pruning**: Removes resources not in Git
- **Health Monitoring**: Tracks application health

### Application Management

```bash
# List applications
kubectl get applications -n argocd

# Check application status
kubectl describe application minio -n argocd

# Force sync
kubectl patch application minio -n argocd --type='merge' -p='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

## Scripts and Tools

### Utility Scripts (`scripts/`)

- **`setup-repository.sh`**: Repository setup and configuration
- **`test-manifests.sh`**: Manifest validation and testing
- **`extract-minio-ca.sh`**: MinIO CA certificate extraction
- **`deploy-minio-certificates.sh`**: Certificate deployment
- **`test-minio-console.sh`**: Console connectivity testing

### Usage

```bash
# Setup repository
./scripts/setup-repository.sh prerequisites

# Test manifests
./scripts/test-manifests.sh

# Extract MinIO CA certificate
./scripts/extract-minio-ca.sh all
```

## Documentation

### Documentation Structure

- **`docs/README.md`**: Main documentation index
- **`docs/<application>/`**: Application-specific documentation
  - **README.md**: Overview and quick start
  - **DEPLOYMENT_GUIDE.md**: Complete deployment process
  - **Application-specific guides**: SSL, security, etc.

### Getting Started

1. **Choose an Application**: Browse applications in `docs/`
2. **Read the README**: Start with the main README for the application
3. **Follow Deployment Guide**: Use the deployment guide for step-by-step instructions
4. **Reference Specific Guides**: Use specialized guides for specific topics

## Security

### Current Security Features

- **SSL/TLS Encryption**: All communication is SSL secured
- **Self-Signed Certificates**: Internal communication uses self-signed certificates
- **Let's Encrypt**: External access uses Let's Encrypt certificates
- **Namespace Isolation**: Applications run in dedicated namespaces

### Security Recommendations

- **Change Default Credentials**: Update default credentials for production
- **Network Policies**: Implement network policies for additional security
- **RBAC**: Ensure proper RBAC configuration
- **Audit Logging**: Enable audit logging for compliance

## Monitoring and Maintenance

### Health Checks

```bash
# Check application status
kubectl get pods -n minio
kubectl get applications -n argocd

# Check SSL certificates
kubectl get certificate -n minio

# View logs
kubectl logs -l app.kubernetes.io/name=minio -n minio
```

### Backup and Recovery

- **Data Backup**: Backup NFS storage and application data
- **Configuration Backup**: Backup secrets and configmaps
- **Certificate Backup**: Backup certificate secrets

## Contributing

### Adding New Applications

1. **Create Application Manifests**: Add to `applications/<app-name>/`
2. **Create Documentation**: Add to `docs/<app-name>/`
3. **Update Main Index**: Add application to `docs/README.md`
4. **Follow Standards**: Use established patterns and structure

### Development Workflow

1. **Create Feature Branch**: `git checkout -b feature/new-application`
2. **Develop and Test**: Create manifests and documentation
3. **Validate**: Run validation scripts
4. **Submit PR**: Create pull request with comprehensive description
5. **Review and Merge**: Follow review process

## Troubleshooting

### Common Issues

1. **Storage Issues**: Verify NFS storage class availability
2. **SSL Issues**: Check cert-manager and certificate status
3. **Network Issues**: Verify ingress controller and service endpoints
4. **ArgoCD Issues**: Check application sync status and logs

### Debug Commands

```bash
# Comprehensive health check
kubectl get all,certificate,issuer,ingress -n minio

# Check all events
kubectl get events -n minio --sort-by='.lastTimestamp'

# Check ArgoCD status
kubectl describe application minio -n argocd
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 