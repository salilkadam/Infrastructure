# MinIO Deployment

## Overview

This is a production-ready, scalable MinIO object storage deployment managed by ArgoCD. The deployment provides a distributed MinIO cluster with SSL security, external API access, and internal console access.

## Architecture

### Components

- **StatefulSet**: 4 replicas for distributed storage with 500Gi each
- **Services**: 
  - `minio-hl`: Headless service for pod-to-pod communication
  - `minio`: API service exposed via ingress
  - `minio-console`: NodePort service for internal console access
- **SSL Infrastructure**: Self-signed certificates for internal communication
- **Ingress**: External access at `minio.askcollections.com`
- **Storage**: NFS-based persistent storage

### Network Flow

```
External API: minio.askcollections.com → Ingress → minio Service → StatefulSet Pods
Internal Console: NodePort 30901 → minio-console Service → StatefulSet Pods
Pod-to-Pod: minio-hl Headless Service → Direct Pod Communication
```

## Deployment

### Prerequisites

- K3s cluster with NFS storage class
- NGINX ingress controller
- cert-manager for SSL certificates
- ArgoCD for GitOps deployment

### Quick Start

1. **Deploy via ArgoCD**:
   ```bash
   kubectl apply -f applications/minio/argocd-app.yaml
   ```

2. **Monitor deployment**:
   ```bash
   kubectl get pods -n minio
   kubectl get statefulset -n minio
   kubectl get services -n minio
   ```

## Access

### External API Access

- **URL**: https://minio.askcollections.com
- **Credentials**: 
  - Access Key: `minioadmin`
  - Secret Key: `minioadmin`

### Internal Console Access

- **NodePort**: 30901 on any cluster node
- **Example**: `https://<cluster-node-ip>:30901`

### Programmatic Access

```python
from minio import Minio

# External access
client = Minio(
    "minio.askcollections.com",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=True
)

# Internal access (from within cluster)
client = Minio(
    "minio.minio.svc.cluster.local:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=True
)
```

## Configuration

### Storage

- **Per Pod**: 500Gi NFS storage
- **Total Storage**: 2TB (4 × 500Gi)
- **Storage Class**: NFS

### SSL Certificates

- **Internal**: Self-signed certificates for pod-to-pod communication
- **External**: Let's Encrypt certificates via ingress
- **Auto-renewal**: Enabled via cert-manager

### Scaling

- **Current**: 4 replicas
- **Horizontal**: Update StatefulSet replicas
- **Storage**: Update PVC size (increases only)

## Monitoring

### Health Checks

```bash
# Check pod status
kubectl get pods -n minio

# Check service endpoints
kubectl get endpoints -n minio

# Check ingress status
kubectl get ingress -n minio

# View logs
kubectl logs -l app.kubernetes.io/name=minio -n minio
```

### SSL Verification

```bash
# Test external SSL
curl -I https://minio.askcollections.com

# Test internal SSL
kubectl exec -it minio-0 -n minio -- curl -I https://minio-hl.minio.svc.cluster.local:9000/minio/health/live
```

## Troubleshooting

### Common Issues

1. **Pod Startup Issues**:
   - Check storage class availability
   - Verify NFS mount points
   - Check resource limits

2. **SSL Certificate Issues**:
   - Verify cert-manager is running
   - Check certificate status
   - Verify DNS resolution

3. **Network Issues**:
   - Check service endpoints
   - Verify ingress configuration
   - Check firewall rules

### Debug Commands

```bash
# Check pod details
kubectl describe pod minio-0 -n minio

# Check certificate status
kubectl get certificate -n minio

# Check service details
kubectl describe service minio -n minio

# Check ingress details
kubectl describe ingress -n minio
```

## Security

### Current Security Features

- SSL/TLS encryption for all communication
- Self-signed certificates for internal communication
- Let's Encrypt certificates for external access
- Namespace isolation

### Recommendations

- Change default credentials for production
- Implement network policies
- Enable audit logging
- Regular security updates

## Maintenance

### Updates

- **Image Updates**: Update MinIO image version in StatefulSet
- **Security Patches**: Apply security patches promptly
- **Certificate Renewal**: Automatic via cert-manager

### Backup

- **Data**: Backup NFS storage
- **Configuration**: Backup secrets and configmaps
- **Certificates**: Backup certificate secrets

## File Structure

```
applications/minio/
├── README.md                 # This documentation
├── argocd-app.yaml          # ArgoCD application definition
└── base/                    # Kubernetes manifests
    ├── kustomization.yaml   # Kustomize configuration
    ├── namespace.yaml       # MinIO namespace
    ├── statefulset.yaml     # MinIO StatefulSet
    ├── service.yaml         # API service
    ├── service-hl.yaml      # Headless service
    ├── service-console.yaml # Console service (NodePort)
    ├── ingress.yaml         # External ingress
    ├── configmap.yaml       # MinIO configuration
    ├── secret.yaml          # MinIO credentials
    ├── cert-clusterissuer-selfsigned.yaml  # Self-signed issuer
    ├── cert-internal-ca.yaml               # Internal CA
    ├── cert-ca-issuer.yaml                 # CA issuer
    └── cert-minio-tls.yaml                 # MinIO TLS certificate
``` 