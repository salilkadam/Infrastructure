# CloudNativePG PostgreSQL Setup

This directory contains the CloudNativePG PostgreSQL setup with Adminer web interface, configured for CI/CD management through ArgoCD.

## Architecture

- **CloudNativePG Operator**: Manages PostgreSQL clusters in Kubernetes
- **PostgreSQL Cluster**: High-availability database with automatic failover
- **Adminer**: Web-based database administration interface
- **ArgoCD**: GitOps deployment and continuous synchronization

## Components

### Base Configuration (`base/`)
- `operator.yaml`: CloudNativePG operator installation
- `cluster.yaml`: PostgreSQL cluster definition
- `adminer.yaml`: Adminer web interface deployment
- `ingress.yaml`: External access configuration
- `secret.yaml`: Database credentials
- `namespace.yaml`: Kubernetes namespace

### Environment Overlays
- `overlays/dev/`: Development environment (1 instance, minimal resources)
- `overlays/staging/`: Staging environment (2 instances, moderate resources)
- `overlays/prod/`: Production environment (3 instances, production resources)

## Features

### PostgreSQL Cluster
- **High Availability**: Automatic failover and replication
- **Backup & Recovery**: Continuous archiving and point-in-time recovery
- **Monitoring**: Prometheus metrics and health checks
- **Security**: TLS encryption and RBAC
- **Scaling**: Horizontal and vertical scaling capabilities

### Adminer Interface
- **Web-based**: Accessible via browser
- **Multi-database**: Supports PostgreSQL, MySQL, SQLite, etc.
- **Secure**: HTTPS with Let's Encrypt certificates
- **Responsive**: Modern UI with dark theme

### CI/CD Integration
- **GitOps**: Declarative infrastructure as code
- **Automated Sync**: Continuous deployment from Git
- **Environment Promotion**: Dev → Staging → Production
- **Rollback**: Automatic rollback on failures

## Access Information

### Development Environment
- **Adminer URL**: https://pg.askcollections.com
- **Database Host**: `pg-rw.postgres.svc.cluster.local`
- **Port**: 5432
- **Username**: postgres
- **Password**: postgres_password

### Connection Details
- **Read-Write**: `pg-rw.postgres.svc.cluster.local:5432`
- **Read-Only**: `pg-ro.postgres.svc.cluster.local:5432`
- **Replica**: `pg-r.postgres.svc.cluster.local:5432`

## Deployment

### Prerequisites
- Kubernetes cluster with ArgoCD installed
- NGINX Ingress Controller
- cert-manager for SSL certificates
- NFS storage class for persistent volumes

### Installation

1. **Apply ArgoCD Applications**:
   ```bash
   # Development
   kubectl apply -f applications/cloudnative-pg/argocd-application.yaml
   
   # Staging (optional)
   kubectl apply -f applications/cloudnative-pg/argocd-application-staging.yaml
   
   # Production (optional)
   kubectl apply -f applications/cloudnative-pg/argocd-application-prod.yaml
   ```

2. **Monitor Deployment**:
   ```bash
   kubectl get application -n argocd | grep cloudnative-pg
   ```

3. **Check Cluster Status**:
   ```bash
   kubectl get cluster -n postgres
   kubectl get pods -n postgres
   ```

## Environment Configurations

### Development
- **Instances**: 1
- **CPU**: 100m-500m
- **Memory**: 256Mi-512Mi
- **Storage**: 10Gi

### Staging
- **Instances**: 2
- **CPU**: 250m-1000m
- **Memory**: 512Mi-1Gi
- **Storage**: 20Gi

### Production
- **Instances**: 3
- **CPU**: 500m-2000m
- **Memory**: 1Gi-2Gi
- **Storage**: 50Gi
- **Connections**: 200 max
- **Adminer Replicas**: 2

## Monitoring

### Health Checks
```bash
# Cluster health
kubectl get cluster pg -n postgres -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# Pod status
kubectl get pods -n postgres

# Service status
kubectl get svc -n postgres
```

### Logs
```bash
# PostgreSQL logs
kubectl logs pg-1 -n postgres

# Adminer logs
kubectl logs -l app.kubernetes.io/component=admin -n postgres

# Operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
```

## Backup & Recovery

### Automatic Backups
- Continuous archiving enabled
- WAL files stored in MinIO
- Point-in-time recovery available

### Manual Backup
```bash
# Create backup
kubectl exec -it pg-1 -n postgres -- pg_basebackup -D /tmp/backup -Ft -z -P

# List backups
kubectl get backup -n postgres
```

## Troubleshooting

### Common Issues

1. **Pod Pending**: Check resource availability and storage
2. **Sync Failures**: Verify ArgoCD application configuration
3. **Connection Issues**: Check service endpoints and network policies
4. **Certificate Errors**: Verify cert-manager and ingress configuration

### Debug Commands
```bash
# Check ArgoCD sync status
kubectl get application cloudnative-pg -n argocd -o yaml

# Verify CRDs
kubectl get crd | grep postgresql

# Check operator status
kubectl get pods -n cnpg-system

# Test database connectivity
kubectl exec -it pg-1 -n postgres -- psql -U postgres -c "SELECT version();"
```

## Security

### Network Security
- TLS encryption for all connections
- Network policies (if configured)
- Ingress with SSL termination

### Access Control
- RBAC for Kubernetes resources
- Database user management
- Secret management for credentials

### Compliance
- Audit logging enabled
- Resource quotas and limits
- Security context configurations

## Maintenance

### Updates
- Operator updates through ArgoCD
- PostgreSQL version upgrades
- Adminer image updates

### Scaling
- Horizontal scaling: Increase instances
- Vertical scaling: Adjust resource limits
- Storage scaling: Increase PVC size

## Support

For issues and questions:
1. Check ArgoCD application status
2. Review pod logs and events
3. Verify network connectivity
4. Check resource availability 