# Deployment Guide

## Quick Start

### 1. Repository Setup
```bash
# Navigate to your infrastructure directory
cd /data/separate/master/yaml/newsetup/Infrastructure

# Repository is already initialized and committed
git remote add origin https://github.com/salilkadam/infrastructure-k8s.git
git branch -M main
git push -u origin main
```

### 2. Update Configuration

Before deploying, update the following:

#### Update Repository URL
Edit `applications/minio/argocd-app.yaml` and update the `repoURL`:
```yaml
spec:
  source:
    repoURL: https://github.com/salilkadam/infrastructure-k8s  # Update this
```

#### Update Hostnames
The domain names have been configured to use `askcollections.com`:
- `applications/minio/overlays/dev/kustomization.yaml`
- `applications/minio/overlays/prod/kustomization.yaml`

Update these files if you need to use a different domain.

### 3. Deploy to ArgoCD

```bash
# Apply the MinIO ArgoCD application
kubectl apply -f applications/minio/argocd-app.yaml

# Or deploy manually for testing
kubectl apply -k applications/minio/overlays/dev
```

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -n minio

# Check services
kubectl get svc -n minio

# Check ingress
kubectl get ingress -n minio

# Check persistent volumes
kubectl get pvc -n minio
```

### 5. Access MinIO

Once deployed, you can access MinIO at:
- **API**: `https://minio-dev.askcollections.com` (SSL enabled)
- **Console**: `http://NODE_IP:30001` (Internal NodePort access only)

Replace `NODE_IP` with your K3s node IP address.

Default credentials:
- Username: `admin`
- Password: `password`

## Production Deployment

For production, ensure you:
1. Update credentials in the secret
2. Switch to `letsencrypt-prod` cluster issuer (API SSL only)
3. Update resource limits as needed
4. Configure monitoring and backup strategies
5. Consider VPN or bastion host for console access
6. Review NodePort security (console is accessible on all nodes)

## Troubleshooting

### Common Issues
1. **Storage Class**: Ensure `nfs-client` is available
2. **SSL**: Verify `letsencrypt-staging` cluster issuer
3. **DNS**: Ensure your domain points to the cluster
4. **Firewall**: Check if ports 80/443 are accessible

### Useful Commands
```bash
# Check storage class
kubectl get storageclass

# Check cluster issuer
kubectl get clusterissuer

# Check certificates (API only)
kubectl get certificates -A

# View ArgoCD applications
kubectl get applications -n argocd

# Check console NodePort service
kubectl get svc minio-console-service -n minio

# Get node IPs for console access
kubectl get nodes -o wide
``` 