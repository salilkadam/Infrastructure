# Redis Cluster Application

This directory contains a production-ready Redis cluster deployment with high availability, monitoring, and scalability features managed by ArgoCD.

## Architecture

### Components

- **Redis StatefulSet**: 3-5 replicas with Redis Sentinel for high availability
- **Redis Sentinel**: Automatic failover and monitoring
- **Redis Exporter**: Prometheus metrics collection
- **Services**: 
  - `redis`: Headless service for pod-to-pod communication
  - `redis-external`: NodePort service for external access
- **Persistent Storage**: NFS-based storage with 20-50Gi per pod
- **Monitoring**: Prometheus metrics via Redis Exporter

### High Availability Features

- **Redis Sentinel**: Automatic failover detection and promotion
- **Pod Anti-Affinity**: Ensures Redis pods are distributed across nodes
- **Health Checks**: Liveness, readiness, and startup probes
- **Persistent Storage**: Data survives pod restarts and node failures
- **Resource Management**: CPU and memory limits with requests

## Quick Start

### 1. Deploy the Redis Cluster

```bash
# Deploy via ArgoCD (default - 3 replicas)
kubectl apply -f applications/redis/argocd-application.yaml

# Or deploy directly with kustomize
kubectl apply -k applications/redis/base/
```

### 2. Monitor Deployment

```bash
# Check ArgoCD application status
kubectl get application redis -n argocd

# Monitor Redis pods
kubectl get pods -n redis

# Check Redis services
kubectl get services -n redis
```

### 3. Verify Redis Cluster

```bash
# Test Redis connection
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 ping

# Check Redis info
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 info replication

# Check Sentinel status
kubectl exec -it redis-0 -n redis -- redis-cli -p 26379 sentinel masters
```

## Access Information

### Internal Access (within cluster)

- **Redis**: `redis-0.redis.redis.svc.cluster.local:6379`
- **Sentinel**: `redis-0.redis.redis.svc.cluster.local:26379`
- **Password**: `redis_password_2024`

### External Access

- **Redis**: NodePort 30379 on any cluster node
- **Sentinel**: NodePort 30380 on any cluster node
- **Example**: `redis://<cluster-node-ip>:30379`

### Connection Examples

#### Python
```python
import redis

# Internal connection
r = redis.Redis(
    host='redis-0.redis.redis.svc.cluster.local',
    port=6379,
    password='redis_password_2024',
    decode_responses=True
)

# External connection
r = redis.Redis(
    host='<cluster-node-ip>',
    port=30379,
    password='redis_password_2024',
    decode_responses=True
)

# Test connection
print(r.ping())
```

#### Node.js
```javascript
const redis = require('redis');

// Internal connection
const client = redis.createClient({
  host: 'redis-0.redis.redis.svc.cluster.local',
  port: 6379,
  password: 'redis_password_2024'
});

// External connection
const client = redis.createClient({
  host: '<cluster-node-ip>',
  port: 30379,
  password: 'redis_password_2024'
});

client.on('connect', () => {
  console.log('Connected to Redis');
});
```

#### Redis CLI
```bash
# Internal access
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024

# External access
redis-cli -h <cluster-node-ip> -p 30379 -a redis_password_2024
```

## Environment Configurations

### Development (1 replica)
```bash
kubectl apply -k applications/redis/overlays/dev/
```
- **Replicas**: 1
- **Memory**: 256Mi-512Mi
- **CPU**: 100m-500m
- **Storage**: 10Gi

### Production (5 replicas)
```bash
kubectl apply -f applications/redis/argocd-application-prod.yaml
```
- **Replicas**: 5
- **Memory**: 1Gi-4Gi
- **CPU**: 500m-2000m
- **Storage**: 50Gi

## Scaling

### Horizontal Scaling

```bash
# Scale Redis StatefulSet
kubectl scale statefulset redis -n redis --replicas=5

# Scale Redis Exporter
kubectl scale deployment redis-exporter -n redis --replicas=2
```

### Vertical Scaling

Update the StatefulSet resource limits:
```bash
kubectl patch statefulset redis -n redis -p '{"spec":{"template":{"spec":{"containers":[{"name":"redis","resources":{"requests":{"memory":"2Gi","cpu":"1000m"},"limits":{"memory":"8Gi","cpu":"4000m"}}}]}}}}'
```

## Monitoring

### Prometheus Metrics

The Redis Exporter provides comprehensive metrics:
- **Redis Metrics**: Memory usage, commands, connections, keyspace
- **Sentinel Metrics**: Master/replica status, failover events
- **Performance Metrics**: Latency, throughput, hit rates

### Access Metrics

```bash
# Get metrics from Redis Exporter
kubectl port-forward svc/redis-exporter -n redis 9121:9121

# View metrics
curl http://localhost:9121/metrics
```

### Grafana Dashboards

Import the Redis dashboard in Grafana:
- **Redis Overview**: General Redis metrics
- **Redis Sentinel**: Sentinel-specific metrics
- **Redis Performance**: Performance and latency metrics

## Backup and Recovery

### Manual Backup

```bash
# Create backup
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 BGSAVE

# Copy backup file
kubectl cp redis/redis-0:/data/dump.rdb ./redis-backup.rdb
```

### Restore from Backup

```bash
# Copy backup to pod
kubectl cp ./redis-backup.rdb redis/redis-0:/data/dump.rdb

# Restart Redis to load backup
kubectl delete pod redis-0 -n redis
```

## Troubleshooting

### Common Issues

#### 1. Redis Pod Not Starting
```bash
# Check pod logs
kubectl logs redis-0 -n redis -c redis

# Check pod events
kubectl describe pod redis-0 -n redis
```

#### 2. Sentinel Issues
```bash
# Check Sentinel logs
kubectl logs redis-0 -n redis -c sentinel

# Check Sentinel status
kubectl exec -it redis-0 -n redis -- redis-cli -p 26379 sentinel masters
```

#### 3. Connection Issues
```bash
# Test internal connectivity
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 ping

# Check service endpoints
kubectl get endpoints -n redis
```

#### 4. Memory Issues
```bash
# Check Redis memory usage
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 info memory

# Check pod resource usage
kubectl top pod redis-0 -n redis
```

### Performance Tuning

#### Memory Optimization
```bash
# Update maxmemory policy
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 CONFIG SET maxmemory-policy allkeys-lru

# Check memory usage
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 info memory
```

#### Persistence Tuning
```bash
# Update AOF settings
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 CONFIG SET appendfsync everysec

# Check persistence status
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 info persistence
```

## Security

### Authentication
- **Password**: Required for all Redis connections
- **Sentinel**: Uses same password for authentication
- **Network**: Internal cluster communication only

### Network Security
- **Internal**: Pod-to-pod communication via headless service
- **External**: NodePort access for external applications
- **Monitoring**: Prometheus metrics endpoint

### Data Security
- **Encryption**: Data at rest (depends on storage class)
- **Backup**: Regular backups recommended
- **Access Control**: Kubernetes RBAC for pod access

## Maintenance

### Updates
```bash
# Update Redis image
kubectl set image statefulset/redis redis=redis:7.2-alpine -n redis

# Update Redis Exporter
kubectl set image deployment/redis-exporter redis-exporter=oliver006/redis_exporter:v1.55.0 -n redis
```

### Health Checks
```bash
# Check cluster health
kubectl get pods -n redis

# Check Redis replication
kubectl exec -it redis-0 -n redis -- redis-cli -a redis_password_2024 info replication

# Check Sentinel status
kubectl exec -it redis-0 -n redis -- redis-cli -p 26379 sentinel masters
```

## Configuration Reference

### Redis Configuration
- **Port**: 6379
- **Sentinel Port**: 26379
- **Max Memory**: 2GB (configurable)
- **Memory Policy**: allkeys-lru
- **Persistence**: AOF enabled
- **Replication**: Master-replica with Sentinel

### Resource Requirements
- **CPU Requests**: 250m-1000m
- **CPU Limits**: 1000m-4000m
- **Memory Requests**: 512Mi-2Gi
- **Memory Limits**: 2Gi-8Gi
- **Storage**: 20Gi-50Gi per pod

### Network Ports
- **Redis**: 6379 (internal), 30379 (external)
- **Sentinel**: 26379 (internal), 30380 (external)
- **Exporter**: 9121 (metrics) 