# PostgreSQL Cluster with pgAdmin

This directory contains the Kubernetes manifests for deploying a PostgreSQL cluster with pgAdmin using ArgoCD GitOps.

## Architecture

- **PostgreSQL**: Single-node PostgreSQL 15 cluster with persistent storage
- **pgAdmin**: Web-based PostgreSQL administration tool
- **ArgoCD**: GitOps deployment management
- **NFS Storage**: Persistent storage using NFS client provisioner

## Components

### Base Configuration (`base/`)
- `namespace.yaml`: PostgreSQL namespace
- `configmap.yaml`: PostgreSQL configuration and environment variables
- `statefulset.yaml`: PostgreSQL StatefulSet with persistent storage
- `pgadmin.yaml`: pgAdmin deployment and service
- `services.yaml`: PostgreSQL services (ClusterIP and Headless)
- `kustomization.yaml`: Base kustomization configuration

### Environment Overlays
- `overlays/dev/`: Development environment with minimal resources
- `overlays/staging/`: Staging environment with moderate resources
- `overlays/prod/`: Production environment with high resources

## Resource Allocation

### Development
- PostgreSQL: 125m CPU, 256Mi memory (requests) / 250m CPU, 512Mi memory (limits)
- pgAdmin: 50m CPU, 64Mi memory (requests) / 100m CPU, 128Mi memory (limits)

### Staging
- PostgreSQL: 250m CPU, 512Mi memory (requests) / 500m CPU, 1Gi memory (limits)
- pgAdmin: 100m CPU, 128Mi memory (requests) / 200m CPU, 256Mi memory (limits)

### Production
- PostgreSQL: 500m CPU, 1Gi memory (requests) / 1000m CPU, 2Gi memory (limits)
- pgAdmin: 200m CPU, 256Mi memory (requests) / 400m CPU, 512Mi memory (limits)

## Configuration

### PostgreSQL Settings
- **Database**: `milvus_metadata`
- **User**: `milvus_user`
- **Password**: `milvus_password`
- **Port**: 5432
- **Storage**: 20Gi NFS persistent volume

### pgAdmin Settings
- **Email**: `admin@milvus.local`
- **Password**: `admin123`
- **Port**: 80
- **Server Mode**: Enabled

## Deployment

### Using ArgoCD
1. Apply the ArgoCD application:
   ```bash
   kubectl apply -f applications/postgresql/argocd-application.yaml
   ```

2. Monitor deployment:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n postgresql
   ```

### Manual Deployment
1. Deploy to development environment:
   ```bash
   kubectl apply -k applications/postgresql/overlays/dev
   ```

2. Deploy to staging environment:
   ```bash
   kubectl apply -k applications/postgresql/overlays/staging
   ```

3. Deploy to production environment:
   ```bash
   kubectl apply -k applications/postgresql/overlays/prod
   ```

## Access

### PostgreSQL
- **Internal**: `postgresql.postgresql.svc.cluster.local:5432`
- **External**: Use port-forward or ingress

### pgAdmin
- **Internal**: `pgadmin.postgresql.svc.cluster.local:80`
- **External**: Use port-forward or ingress

### Port Forwarding
```bash
# PostgreSQL
kubectl port-forward svc/postgresql 5432:5432 -n postgresql

# pgAdmin
kubectl port-forward svc/pgadmin 8080:80 -n postgresql
```

## Monitoring

### Health Checks
- PostgreSQL: `pg_isready` liveness and readiness probes
- pgAdmin: HTTP health checks on `/misc/ping`

### Logs
```bash
# PostgreSQL logs
kubectl logs -f postgresql-0 -n postgresql

# pgAdmin logs
kubectl logs -f deployment/pgadmin -n postgresql
```

### Resource Usage
```bash
kubectl top pods -n postgresql
```

## Backup and Recovery

### Manual Backup
```bash
kubectl exec -it postgresql-0 -n postgresql -- pg_dump -U milvus_user milvus_metadata > backup.sql
```

### Manual Restore
```bash
kubectl exec -i postgresql-0 -n postgresql -- psql -U milvus_user milvus_metadata < backup.sql
```

## Troubleshooting

### Common Issues

1. **Pod Stuck in Pending**
   - Check node resources and affinity rules
   - Verify NFS storage class availability

2. **PostgreSQL Connection Issues**
   - Verify service endpoints
   - Check PostgreSQL logs for authentication errors

3. **pgAdmin Access Issues**
   - Verify pgAdmin pod is running
   - Check service configuration

### Debug Commands
```bash
# Check pod status
kubectl get pods -n postgresql

# Check services
kubectl get svc -n postgresql

# Check persistent volumes
kubectl get pvc -n postgresql

# Check events
kubectl get events -n postgresql --sort-by='.lastTimestamp'
```

## Security Considerations

- Default passwords should be changed in production
- Consider using Kubernetes secrets for sensitive data
- Enable SSL/TLS for PostgreSQL connections
- Restrict network access using network policies
- Regular security updates for PostgreSQL and pgAdmin images

## Scaling

### Horizontal Scaling
- PostgreSQL StatefulSet can be scaled to multiple replicas for read replicas
- pgAdmin can be scaled for high availability

### Vertical Scaling
- Adjust resource requests and limits in overlay configurations
- Monitor resource usage and adjust accordingly

## Integration with Milvus

This PostgreSQL cluster is configured to store Milvus metadata:
- Collection metadata
- Index metadata
- Partition information
- User and role management

The database name `milvus_metadata` and credentials are configured to work with Milvus out of the box. 