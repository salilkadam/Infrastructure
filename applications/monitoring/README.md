# Monitoring Stack Setup

This directory contains a comprehensive monitoring stack for your Kubernetes infrastructure, including Prometheus, Grafana, and Node Exporter.

## Architecture

- **Prometheus**: Time-series database for metrics collection and alerting
- **Grafana**: Visualization and dashboard platform
- **Node Exporter**: Kubernetes node metrics collection
- **ArgoCD**: GitOps deployment and continuous synchronization

## Components

### Prometheus
- **Metrics Collection**: Scrapes metrics from all services
- **Alerting**: Comprehensive alert rules for infrastructure health
- **Storage**: Persistent storage with 30-day retention
- **Service Discovery**: Automatic discovery of Kubernetes resources

### Grafana
- **Dashboards**: Pre-configured dashboards for all services
- **Data Sources**: Prometheus integration
- **Visualization**: Real-time monitoring and alerting
- **Authentication**: Admin/admin123 (change in production)

### Node Exporter
- **Node Metrics**: CPU, memory, disk, network metrics
- **DaemonSet**: Runs on all Kubernetes nodes
- **Host Metrics**: System-level performance data

## Monitored Services

### Infrastructure
- **Kubernetes Nodes**: CPU, memory, disk usage
- **Kubernetes Pods**: Status, resource usage, restarts
- **Kubernetes API Server**: Performance and health

### Applications
- **Milvus**: Vector database metrics and health
- **PostgreSQL**: Database connections, transactions, performance
- **MinIO**: Storage usage, request rates, errors
- **etcd**: Cluster health, backend usage
- **Pulsar**: Message queue metrics
- **ArgoCD**: Application sync status and health
- **Adminer**: Web interface health

## Access Information

### External URLs
- **Prometheus**: https://prometheus.askcollections.com
- **Grafana**: https://grafana.askcollections.com

### Internal Services
- **Prometheus**: `prometheus.monitoring.svc.cluster.local:9090`
- **Grafana**: `grafana.monitoring.svc.cluster.local:3000`
- **Node Exporter**: `node-exporter.monitoring.svc.cluster.local:9100`

### Grafana Credentials
- **Username**: admin
- **Password**: admin123

## Dashboards

### Infrastructure Overview
- Node CPU and memory usage
- Pod status and counts
- System resource utilization
- Cluster health overview

### Milvus Monitoring
- Pod status and health
- Memory and CPU usage
- Query performance metrics
- Vector database operations

### PostgreSQL Monitoring
- Database connections
- Transaction rates
- Query performance
- Replication status

### MinIO Monitoring
- Bucket usage statistics
- Request rates and errors
- Storage utilization
- Performance metrics

## Alert Rules

### Infrastructure Alerts
- **NodeHighCPUUsage**: CPU usage > 80%
- **NodeHighMemoryUsage**: Memory usage > 85%
- **NodeHighDiskUsage**: Disk usage > 85%
- **PodRestartingFrequently**: Pod restarts > 5 in 15 minutes

### Application Alerts
- **MilvusHighMemoryUsage**: Memory usage > 80%
- **MilvusHighCPUUsage**: CPU usage > 80%
- **MilvusPodDown**: Pod not responding
- **PostgreSQLHighConnections**: Connections > 80
- **PostgreSQLReplicationLag**: Replication lag > 30 seconds
- **MinIOHighUsage**: Storage usage > 85%
- **EtcdHighUsage**: Backend usage > 80%

### ArgoCD Alerts
- **ArgoCDApplicationOutOfSync**: Application sync issues
- **ArgoCDApplicationHealthDegraded**: Application health problems

## Deployment

### Prerequisites
- Kubernetes cluster with ArgoCD installed
- NGINX Ingress Controller
- cert-manager for SSL certificates
- NFS storage class for persistent volumes

### Installation

1. **Apply ArgoCD Application**:
   ```bash
   kubectl apply -f applications/monitoring/argocd-application.yaml
   ```

2. **Monitor Deployment**:
   ```bash
   kubectl get application monitoring -n argocd
   kubectl get pods -n monitoring
   ```

3. **Verify Services**:
   ```bash
   kubectl get svc -n monitoring
   kubectl get ingress -n monitoring
   ```

## Configuration

### Prometheus Configuration
- **Scrape Interval**: 15s (global), 10s-60s (per job)
- **Retention**: 30 days
- **Storage**: 10Gi persistent volume
- **Alert Rules**: Comprehensive monitoring rules

### Grafana Configuration
- **Dashboards**: Auto-provisioned from ConfigMaps
- **Data Sources**: Prometheus integration
- **Storage**: 5Gi persistent volume
- **Plugins**: Pie chart, world map panels

### Node Exporter Configuration
- **Metrics**: System, CPU, memory, disk, network
- **Port**: 9100
- **Host Access**: Required for system metrics
- **Resources**: Minimal resource usage

## Monitoring Best Practices

### Resource Management
- Monitor resource usage and set appropriate limits
- Use persistent storage for data retention
- Implement proper backup strategies

### Security
- Change default passwords in production
- Use RBAC for access control
- Implement network policies
- Secure ingress with TLS

### Performance
- Optimize scrape intervals based on needs
- Use efficient queries and aggregations
- Monitor Prometheus performance
- Implement proper retention policies

## Troubleshooting

### Common Issues

1. **Prometheus Not Scraping**:
   ```bash
   kubectl logs prometheus-xxx -n monitoring
   kubectl get endpoints -n monitoring
   ```

2. **Grafana Not Loading**:
   ```bash
   kubectl logs grafana-xxx -n monitoring
   kubectl get configmap grafana-datasources -n monitoring -o yaml
   ```

3. **Node Exporter Issues**:
   ```bash
   kubectl logs node-exporter-xxx -n monitoring
   kubectl get daemonset node-exporter -n monitoring
   ```

4. **Ingress Problems**:
   ```bash
   kubectl get ingress monitoring-ingress -n monitoring
   kubectl describe ingress monitoring-ingress -n monitoring
   ```

### Debug Commands
```bash
# Check Prometheus targets
curl -s http://prometheus.monitoring.svc.cluster.local:9090/api/v1/targets

# Check Grafana health
curl -s http://grafana.monitoring.svc.cluster.local:3000/api/health

# Check Node Exporter metrics
curl -s http://node-exporter.monitoring.svc.cluster.local:9100/metrics

# Check ArgoCD sync status
kubectl get application monitoring -n argocd -o yaml
```

## Scaling

### Horizontal Scaling
- Prometheus: Can be scaled with federation
- Grafana: Multiple replicas for high availability
- Node Exporter: Automatically scales with nodes

### Vertical Scaling
- Adjust resource limits based on usage
- Increase storage for longer retention
- Optimize scrape intervals

## Maintenance

### Updates
- Regular image updates for security
- Dashboard and rule updates
- Configuration optimizations

### Backups
- Grafana dashboards and configurations
- Prometheus rules and configurations
- Alert manager configurations

## Support

For issues and questions:
1. Check ArgoCD application status
2. Review pod logs and events
3. Verify network connectivity
4. Check resource availability
5. Validate configuration files 