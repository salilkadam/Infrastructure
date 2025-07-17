# MinIO Application

This directory contains the Kubernetes manifests for the MinIO object storage deployment.

## Quick Start

```bash
# Deploy via ArgoCD
kubectl apply -f argocd-app.yaml
```

## Documentation

📚 **Complete documentation is available in [`docs/minio/`](../../docs/minio/)**

- [Main Documentation](../../docs/minio/README.md) - Overview, architecture, and quick start
- [SSL Configuration](../../docs/minio/SSL_CONFIGURATION.md) - SSL infrastructure and connection methods  
- [Deployment Guide](../../docs/minio/DEPLOYMENT_GUIDE.md) - Complete deployment and troubleshooting guide

## Manifest Structure

```
applications/minio/
├── README.md                 # This file
├── argocd-app.yaml          # ArgoCD application definition
└── base/                    # Kubernetes manifests
    ├── kustomization.yaml   # Kustomize configuration
    ├── namespace.yaml       # MinIO namespace
    ├── statefulset.yaml     # MinIO StatefulSet (4 replicas, 500Gi each)
    ├── service.yaml         # API service
    ├── service-hl.yaml      # Headless service
    ├── service-console.yaml # Console service (NodePort 30901)
    ├── ingress.yaml         # External ingress
    ├── configmap.yaml       # MinIO configuration
    ├── secret.yaml          # MinIO credentials
    ├── cert-clusterissuer-selfsigned.yaml  # Self-signed issuer
    ├── cert-internal-ca.yaml               # Internal CA
    ├── cert-ca-issuer.yaml                 # CA issuer
    └── cert-minio-tls.yaml                 # MinIO TLS certificate
```

## Access

- **External API**: https://minio.askcollections.com
- **Internal Console**: NodePort 30901 on any cluster node
- **Credentials**: minioadmin/minioadmin 