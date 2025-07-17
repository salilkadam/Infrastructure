# MinIO Deployment Guide

## Prerequisites

### Cluster Requirements

- **Kubernetes**: K3s cluster (tested with v1.28+)
- **Storage**: NFS storage class available
- **Ingress**: NGINX ingress controller installed
- **Cert-Manager**: Installed and running
- **ArgoCD**: Installed and configured for GitOps

### Verify Prerequisites

```bash
# Check storage classes
kubectl get storageclass

# Check ingress controller
kubectl get pods -n ingress-nginx

# Check cert-manager
kubectl get pods -n cert-manager

# Check ArgoCD
kubectl get pods -n argocd
```

## Deployment Process

### Step 1: Deploy ArgoCD Application

```bash
# Apply the ArgoCD application
kubectl apply -f applications/minio/argocd-app.yaml

# Verify application creation
kubectl get application minio -n argocd
```

### Step 2: Monitor Deployment

```bash
# Watch ArgoCD sync status
kubectl get application minio -n argocd -w

# Monitor namespace creation
kubectl get namespace minio

# Monitor certificate creation
kubectl get certificate -n minio -w

# Monitor StatefulSet creation
kubectl get statefulset -n minio -w
```

### Step 3: Verify Components

```bash
# Check all resources
kubectl get all -n minio

# Check certificates
kubectl get certificate,issuer,clusterissuer -n minio

# Check services
kubectl get services -n minio

# Check ingress
kubectl get ingress -n minio
```

## Post-Deployment Verification

### Step 1: Verify Pod Status

```bash
# Check all pods are running
kubectl get pods -n minio

# Expected output:
# NAME      READY   STATUS    RESTARTS   AGE
# minio-0   1/1     Running   0          2m
# minio-1   1/1     Running   0          2m
# minio-2   1/1     Running   0          2m
# minio-3   1/1     Running   0          2m
```

### Step 2: Verify SSL Certificates

```bash
# Check certificate status
kubectl get certificate -n minio

# Expected output:
# NAME                READY   SECRET              AGE
# minio-internal-ca   True    minio-internal-ca   5m
# minio-internal-tls  True    minio-internal-tls  4m

# Check certificate details
kubectl describe certificate minio-internal-tls -n minio
```

### Step 3: Verify Services

```bash
# Check all services
kubectl get services -n minio

# Expected output:
# NAME            TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
# minio           ClusterIP   10.43.xxx.x   <none>        9000/TCP         5m
# minio-console   NodePort    10.43.xxx.x   <none>        9001:30901/TCP   5m
# minio-hl        ClusterIP   None          <none>        9000/TCP         5m
```

### Step 4: Verify Ingress

```bash
# Check ingress status
kubectl get ingress -n minio

# Expected output:
# NAME    CLASS   HOSTS                    ADDRESS   PORTS   AGE
# minio   nginx   minio.askcollections.com   x.x.x.x   80,443  5m
```

## SSL Testing

### Test External SSL

```bash
# Test external API access
curl -I https://minio.askcollections.com

# Expected output:
# HTTP/2 200
# Server: nginx
# Content-Type: application/xml
```

### Test Internal SSL

```bash
# Test internal service SSL
kubectl exec -it minio-0 -n minio -- curl -I https://minio-hl.minio.svc.cluster.local:9000/minio/health/live

# Expected output:
# HTTP/2 200
# Content-Type: application/json
```

### Test Console Access

```bash
# Get cluster node IP
kubectl get nodes -o wide

# Test console via NodePort (replace with actual node IP)
curl -k -I https://<node-ip>:30901

# Expected output:
# HTTP/2 200
# Content-Type: text/html
```

## MinIO Client Testing

### Install MinIO Client

```bash
# Download mc client
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

### Test External Access

```bash
# Configure external access
mc alias set external https://minio.askcollections.com minioadmin minioadmin

# Test bucket operations
mc ls external
mc mb external/test-bucket
mc cp /etc/hosts external/test-bucket/
mc ls external/test-bucket
mc rm external/test-bucket/hosts
mc rb external/test-bucket
```

### Test Internal Access

```bash
# Configure internal access (with SSL verification disabled)
mc alias set internal https://minio.minio.svc.cluster.local:9000 minioadmin minioadmin --insecure

# Test bucket operations
mc ls internal
mc mb internal/test-bucket
mc cp /etc/hosts internal/test-bucket/
mc ls internal/test-bucket
mc rm internal/test-bucket/hosts
mc rb internal/test-bucket
```

## Monitoring and Health Checks

### Pod Health

```bash
# Check pod readiness
kubectl get pods -n minio -o wide

# Check pod logs
kubectl logs minio-0 -n minio

# Check pod events
kubectl describe pod minio-0 -n minio
```

### Service Health

```bash
# Check service endpoints
kubectl get endpoints -n minio

# Test service connectivity
kubectl run test-pod --image=curlimages/curl --rm -it -- curl -I https://minio.minio.svc.cluster.local:9000/minio/health/live
```

### Certificate Health

```bash
# Check certificate status
kubectl get certificate -n minio

# Check certificate expiration
kubectl get secret minio-internal-tls -n minio -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting

**Symptoms**: Pods stuck in Pending or CrashLoopBackOff

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod minio-0 -n minio

# Check storage class
kubectl get pvc -n minio
kubectl describe pvc minio-minio-0 -n minio
```

**Solutions**:
- Verify NFS storage class is available
- Check NFS server connectivity
- Verify resource limits

#### 2. SSL Certificate Issues

**Symptoms**: Certificate not ready or SSL connection failures

**Diagnosis**:
```bash
# Check certificate status
kubectl describe certificate minio-internal-tls -n minio

# Check cert-manager logs
kubectl logs -l app=cert-manager -n cert-manager
```

**Solutions**:
- Verify cert-manager is running
- Check certificate issuer status
- Force certificate renewal if needed

#### 3. Network Connectivity Issues

**Symptoms**: Services not accessible or connection timeouts

**Diagnosis**:
```bash
# Check service endpoints
kubectl get endpoints -n minio

# Check ingress status
kubectl describe ingress minio -n minio

# Test network connectivity
kubectl run test-pod --image=curlimages/curl --rm -it -- curl -I https://minio.minio.svc.cluster.local:9000/minio/health/live
```

**Solutions**:
- Verify service selectors
- Check ingress configuration
- Verify DNS resolution

#### 4. ArgoCD Sync Issues

**Symptoms**: Application shows OutOfSync status

**Diagnosis**:
```bash
# Check ArgoCD application status
kubectl describe application minio -n argocd

# Check ArgoCD logs
kubectl logs -l app.kubernetes.io/name=argocd-application-controller -n argocd
```

**Solutions**:
- Verify Git repository access
- Check manifest syntax
- Force sync if needed

### Debug Commands

```bash
# Comprehensive health check
kubectl get all,certificate,issuer,ingress -n minio

# Check all events
kubectl get events -n minio --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n minio

# Check storage usage
kubectl exec -it minio-0 -n minio -- df -h

# Check MinIO cluster status
kubectl exec -it minio-0 -n minio -- mc admin info local
```

## Scaling and Maintenance

### Horizontal Scaling

```bash
# Scale to 6 replicas
kubectl scale statefulset minio --replicas=6 -n minio

# Monitor scaling
kubectl get pods -n minio -w
```

### Storage Scaling

```bash
# Update PVC size (requires StatefulSet recreation)
# Edit applications/minio/base/statefulset.yaml
# Change storage size from 500Gi to desired size
# Commit and push to trigger ArgoCD sync
```

### Updates

```bash
# Update MinIO image
# Edit applications/minio/base/statefulset.yaml
# Change image tag to desired version
# Commit and push to trigger ArgoCD sync
```

## Backup and Recovery

### Data Backup

```bash
# Backup MinIO data using mc client
mc mirror external/ /backup/minio-data/

# Backup configuration
kubectl get secret,configmap -n minio -o yaml > minio-config-backup.yaml
```

### Disaster Recovery

```bash
# Restore from backup
mc mirror /backup/minio-data/ external/

# Restore configuration
kubectl apply -f minio-config-backup.yaml
```

## Security Considerations

### Production Hardening

1. **Change Default Credentials**:
   ```bash
   # Update secret with production credentials
   kubectl patch secret minio-creds-secret -n minio --type='merge' -p='{"data":{"accesskey":"<base64-encoded-access-key>","secretkey":"<base64-encoded-secret-key>"}}'
   ```

2. **Network Policies**: Implement network policies for additional security
3. **RBAC**: Ensure proper RBAC configuration
4. **Audit Logging**: Enable audit logging for compliance

### Monitoring

1. **Metrics**: Enable Prometheus metrics
2. **Alerts**: Configure alerts for critical issues
3. **Logging**: Centralize logs for analysis 