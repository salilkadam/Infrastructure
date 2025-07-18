# PostgreSQL Cluster with pgAdmin

This directory contains the Kubernetes manifests for deploying a PostgreSQL cluster with pgAdmin using ArgoCD GitOps.

## Architecture

- **PostgreSQL**: Scalable PostgreSQL 15 cluster with persistent storage
- **pgAdmin**: Web-based PostgreSQL administration tool
- **ArgoCD**: GitOps deployment management
- **NFS Storage**: Persistent storage using NFS client provisioner
- **Scaling**: Horizontal scaling support with environment-specific replica counts

## Components

### Base Configuration (`base/`)
- `namespace.yaml`: PostgreSQL namespace
- `configmap.yaml`: PostgreSQL configuration and environment variables
- `statefulset.yaml`: PostgreSQL StatefulSet with persistent storage
- `pgadmin.yaml`: pgAdmin deployment and service
- `services.yaml`: PostgreSQL services (ClusterIP and Headless)
- `kustomization.yaml`: Base kustomization configuration

### Environment Overlays
- `overlays/dev/`: Development environment with minimal resources (1 replica)
- `overlays/staging/`: Staging environment with moderate resources (2 replicas)
- `overlays/prod/`: Production environment with high resources (3 replicas)

## Resource Allocation

### Development
- PostgreSQL: 100m CPU, 256Mi memory (requests) / 200m CPU, 512Mi memory (limits) - 1 replica
- pgAdmin: 25m CPU, 64Mi memory (requests) / 50m CPU, 128Mi memory (limits) - 1 replica

### Staging
- PostgreSQL: 250m CPU, 512Mi memory (requests) / 500m CPU, 1Gi memory (limits) - 2 replicas
- pgAdmin: 100m CPU, 128Mi memory (requests) / 200m CPU, 256Mi memory (limits) - 2 replicas

### Production
- PostgreSQL: 500m CPU, 1Gi memory (requests) / 1000m CPU, 2Gi memory (limits) - 3 replicas
- pgAdmin: 200m CPU, 256Mi memory (requests) / 400m CPU, 512Mi memory (limits) - 2 replicas

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
- **Internal**: `postgresql.postgres.svc.cluster.local:5432`
- **External**: Use port-forward or ingress

### pgAdmin
- **Internal**: `pgadmin.postgres.svc.cluster.local:80`
- **External**: Use port-forward or ingress

### Port Forwarding
```bash
# PostgreSQL
kubectl port-forward svc/postgresql 5432:5432 -n postgres

# pgAdmin
kubectl port-forward svc/pgadmin 8080:80 -n postgres
```

## Monitoring

### Health Checks
- PostgreSQL: `pg_isready` liveness and readiness probes
- pgAdmin: HTTP health checks on `/misc/ping`

### Logs
```bash
# PostgreSQL logs
kubectl logs -f pg-0 -n postgres

# pgAdmin logs
kubectl logs -f deployment/pgadmin -n postgres
```

### Resource Usage
```bash
kubectl top pods -n postgresql
```

## Backup and Recovery

### Manual Backup
```bash
kubectl exec -it pg-0 -n postgres -- pg_dump -U milvus_user milvus_metadata > backup.sql
```

### Manual Restore
```bash
kubectl exec -i pg-0 -n postgres -- psql -U milvus_user milvus_metadata < backup.sql
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
kubectl get pods -n postgres

# Check services
kubectl get svc -n postgres

# Check persistent volumes
kubectl get pvc -n postgres

# Check events
kubectl get events -n postgres --sort-by='.lastTimestamp'
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
- Environment-specific scaling:
  - Development: 1 replica (minimal resources)
  - Staging: 2 replicas (moderate resources)
  - Production: 3 replicas (high availability)

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