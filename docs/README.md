# Infrastructure Documentation

This directory contains comprehensive documentation for all applications deployed in this infrastructure.

## Applications

### [MinIO Object Storage](./minio/)
- **Overview**: Production-ready, scalable MinIO object storage deployment
- **Features**: SSL security, external API access, internal console, ArgoCD management
- **Architecture**: 4-replica StatefulSet with 500Gi storage each
- **Access**: External API at `minio.askcollections.com`, internal console via NodePort 30901

**Documentation:**
- [README](./minio/README.md) - Main documentation and overview
- [SSL Configuration](./minio/SSL_CONFIGURATION.md) - SSL infrastructure and connection methods
- [Deployment Guide](./minio/DEPLOYMENT_GUIDE.md) - Complete deployment and troubleshooting guide

### etcd (Coming Soon)
- **Overview**: Distributed key-value store for Kubernetes
- **Status**: Planning phase
- **Documentation**: Will be added to `docs/etcd/`

## Documentation Structure

```
docs/
├── README.md              # This index file
├── minio/                 # MinIO application documentation
│   ├── README.md         # Main MinIO documentation
│   ├── SSL_CONFIGURATION.md  # SSL setup and configuration
│   └── DEPLOYMENT_GUIDE.md   # Deployment and troubleshooting
└── etcd/                 # etcd documentation (future)
    └── ...
```

## Common Patterns

### Application Structure
Each application follows a consistent structure:
- **Kubernetes Manifests**: Located in `applications/<app-name>/base/`
- **ArgoCD Application**: Located in `applications/<app-name>/argocd-app.yaml`
- **Documentation**: Located in `docs/<app-name>/`

### Documentation Standards
Each application documentation includes:
- **README.md**: Overview, architecture, and quick start
- **DEPLOYMENT_GUIDE.md**: Complete deployment process and troubleshooting
- **Application-specific guides**: SSL, security, scaling, etc.

## Getting Started

1. **Choose an Application**: Browse the applications above
2. **Read the README**: Start with the main README for the application
3. **Follow Deployment Guide**: Use the deployment guide for step-by-step instructions
4. **Reference Specific Guides**: Use specialized guides for specific topics

## Contributing

When adding new applications:
1. Create application manifests in `applications/<app-name>/`
2. Create documentation in `docs/<app-name>/`
3. Update this index with application details
4. Follow the established documentation patterns 