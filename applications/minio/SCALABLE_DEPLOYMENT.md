# Scalable MinIO Deployment

## Overview

This deployment provides a scalable, production-ready MinIO object storage cluster with the following features:

- **Scalable Architecture**: Uses StatefulSet with 4 replicas for high availability
- **SSL Security**: Both internal and external communication are SSL secured
- **External API Access**: API available at `minio.askcollections.com`
- **Internal Console**: Console accessible only within the cluster
- **ArgoCD Integration**: Automated deployment and management through ArgoCD

## Architecture

### Components

1. **StatefulSet (minio)**: 
   - 4 replicas for distributed storage
   - Each pod gets a unique hostname: `minio-0`, `minio-1`, `minio-2`, `minio-3`
   - Persistent storage using NFS storage class

2. **Services**:
   - `minio-hl`: Headless service for internal pod-to-pod communication
   - `minio-api`: External API service exposed via ingress
   - `minio-console`: Internal console service (cluster-only access)

3. **SSL Infrastructure**:
   - Internal CA for pod-to-pod communication
   - Let's Encrypt certificates for external access
   - Automatic certificate renewal

### Network Flow

```
External Request → Ingress → minio-api Service → StatefulSet Pods
Internal Console → minio-console Service → StatefulSet Pods
Pod-to-Pod → minio-hl Headless Service → Direct Pod Communication
```

## Deployment

### Prerequisites

1. **Storage**: NFS storage class must be available
2. **Ingress**: NGINX ingress controller must be installed
3. **Cert-Manager**: Must be installed for SSL certificates
4. **ArgoCD**: Must be running for GitOps deployment

### Deployment Steps

1. **Apply ArgoCD Application**:
   ```bash
   kubectl apply -f applications/minio/argocd-app.yaml
   ```

2. **Monitor Deployment**:
   ```bash
   kubectl get pods -n minio
   kubectl get statefulset -n minio
   kubectl get services -n minio
   ```

3. **Verify SSL Certificates**:
   ```bash
   kubectl get certificates -n minio
   kubectl get secrets -n minio
   ```

## Access

### External API Access

- **URL**: https://minio.askcollections.com
- **Credentials**: 
  - Access Key: `minioadmin`
  - Secret Key: `minioadmin`

### Internal Console Access

```bash
# Port forward to access console from within cluster
kubectl port-forward svc/minio-console 9001:9001 -n minio
```

Then access: http://localhost:9001

### Programmatic Access

```python
from minio import Minio

client = Minio(
    "minio.askcollections.com",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=True
)
```

## Scaling

### Horizontal Scaling

To scale the cluster:

1. **Update StatefulSet replicas**:
   ```bash
   kubectl scale statefulset minio --replicas=6 -n minio
   ```

2. **Update ArgoCD application** (recommended):
   - Modify `applications/minio/overlays/prod/kustomization.yaml`
   - Change replicas value
   - Commit and push to trigger ArgoCD sync

### Storage Scaling

To increase storage per pod:

1. **Update volume claim template** in StatefulSet
2. **Note**: PVC storage cannot be decreased, only increased

## Monitoring

### Health Checks

- **Liveness Probe**: `/minio/health/live` on port 9000
- **Readiness Probe**: `/minio/health/ready` on port 9000

### Logs

```bash
# View logs for all pods
kubectl logs -l app.kubernetes.io/name=minio -n minio

# View logs for specific pod
kubectl logs minio-0 -n minio
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
# Check pod status
kubectl describe pod minio-0 -n minio

# Check service endpoints
kubectl get endpoints -n minio

# Check ingress status
kubectl describe ingress -n minio

# Check certificate status
kubectl describe certificate -n minio
```

## Security Considerations

1. **Change Default Credentials**: Update the secret with production credentials
2. **Network Policies**: Consider implementing network policies for additional security
3. **RBAC**: Ensure proper RBAC configuration
4. **Audit Logging**: Enable audit logging for compliance

## Backup and Recovery

### Data Backup

1. **MinIO Backup**: Use MinIO's built-in backup features
2. **PVC Backup**: Backup the underlying NFS storage
3. **Configuration Backup**: Backup secrets and configmaps

### Disaster Recovery

1. **Multi-Zone Deployment**: Deploy across multiple availability zones
2. **Cross-Region Replication**: Configure cross-region replication
3. **Regular Testing**: Test recovery procedures regularly

## Performance Tuning

### Resource Optimization

1. **Memory**: Adjust memory limits based on workload
2. **CPU**: Monitor CPU usage and adjust limits
3. **Storage**: Use SSD storage for better performance

### Network Optimization

1. **Pod Anti-Affinity**: Ensure pods are distributed across nodes
2. **Network Policies**: Optimize network policies for performance
3. **Load Balancing**: Monitor ingress load balancing

## Maintenance

### Updates

1. **Image Updates**: Update MinIO image version
2. **Security Patches**: Apply security patches promptly
3. **Certificate Renewal**: Monitor certificate expiration

### Monitoring

1. **Metrics**: Enable Prometheus metrics
2. **Alerts**: Configure alerts for critical issues
3. **Logging**: Centralize logs for analysis 