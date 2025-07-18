# PostgreSQL Metadata System for Milvus

This directory contains the PostgreSQL cluster configuration for storing application-level metadata for the Milvus vector database system.

## Architecture Overview

### 🏗️ **System Design**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Milvus Core   │    │   PostgreSQL    │    │   Application   │
│                 │    │   Metadata      │    │   Layer         │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • etcd          │    │ • Collections   │    │ • User Mgmt     │
│ • MinIO         │    │ • Permissions   │    │ • Audit Logs    │
│ • Pulsar        │    │ • Performance   │    │ • Analytics     │
│ • Vector Data   │    │ • Query Logs    │    │ • Monitoring    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 📊 **Data Storage Strategy**

- **etcd**: Milvus internal metadata (collections, indexes, segments)
- **PostgreSQL**: Application-level metadata (users, permissions, audit trails, performance metrics)
- **MinIO**: Vector data and object storage
- **Pulsar**: Message queuing for data ingestion

## 🗄️ Database Schema

### Core Tables

#### Users & Authentication
- `users` - User accounts and authentication
- `permissions` - Access control for collections

#### Collection Management
- `collections` - Collection metadata and configuration
- `collection_partitions` - Partition information
- `index_management` - Index building status and progress

#### Monitoring & Analytics
- `audit_logs` - User actions and system events
- `performance_metrics` - Operation performance data
- `query_logs` - Detailed query execution logs
- `ingestion_logs` - Data ingestion tracking

#### System Configuration
- `system_config` - Application configuration settings

### Views
- `collection_stats` - Aggregated collection statistics

## 🚀 Quick Start

### 1. Deploy PostgreSQL Cluster

```bash
# The cluster is managed by ArgoCD
kubectl get applications -n argocd postgresql
```

### 2. Initialize Database Schema

The schema is automatically initialized by the `postgresql-init` job:

```bash
kubectl get jobs -n postgres
kubectl logs job/postgresql-init -n postgres
```

### 3. Access PostgreSQL

#### Via kubectl
```bash
# Connect to PostgreSQL
kubectl exec -it pg-0 -n postgres -- psql -U milvus_user -d milvus_metadata

# Test connection
kubectl exec -it pg-0 -n postgres -- pg_isready -U milvus_user -d milvus_metadata
```

#### Via Web Admin (Adminer)
```bash
# Port forward to access Adminer
kubectl port-forward svc/pgadmin 8080:80 -n postgres

# Access at http://localhost:8080
# Server: postgresql.postgres.svc.cluster.local
# Username: milvus_user
# Password: milvus_password
# Database: milvus_metadata
```

### 4. Use Python Client

```python
from metadata_client import MilvusMetadataClient

# Initialize client
client = MilvusMetadataClient()

# Create a collection record
collection = client.create_collection(
    collection_name="my_vectors",
    dimension=768,
    metric_type="COSINE",
    description="My vector collection",
    created_by="user-uuid"
)

# Log a vector search
client.log_query(
    user_id="user-uuid",
    collection_id=collection['id'],
    query_type="vector_search",
    duration_ms=150,
    success=True,
    top_k=10,
    result_count=10
)

# Get performance stats
stats = client.get_performance_stats(collection_id=collection['id'])
print(stats)
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_HOST` | `postgresql.postgres.svc.cluster.local` | PostgreSQL host |
| `POSTGRES_PORT` | `5432` | PostgreSQL port |
| `POSTGRES_DB` | `milvus_metadata` | Database name |
| `POSTGRES_USER` | `milvus_user` | Username |
| `POSTGRES_PASSWORD` | `milvus_password` | Password |

### System Configuration

Default system configuration is automatically inserted:

```sql
-- View system configuration
SELECT * FROM system_config;

-- Key configurations:
-- milvus_api_endpoint: milvus-proxy.milvus.svc.cluster.local:19530
-- max_query_timeout: 300
-- default_top_k: 10
-- enable_audit_logging: true
-- enable_performance_monitoring: true
-- data_retention_days: 90
```

## 📈 Monitoring & Analytics

### Performance Metrics

Track operation performance:

```python
# Log performance metric
client.log_performance_metric(
    collection_id="collection-uuid",
    operation_type="search",
    duration_ms=150,
    success=True,
    metadata={"top_k": 10, "result_count": 10}
)

# Get performance statistics
stats = client.get_performance_stats(days=7)
```

### Audit Logging

Track user actions:

```python
# Log audit event
client.log_audit_event(
    user_id="user-uuid",
    action="create_collection",
    resource_type="collection",
    resource_id="collection-uuid",
    details={"collection_name": "my_vectors"}
)

# Get audit logs
logs = client.get_audit_logs(user_id="user-uuid", limit=50)
```

### Collection Statistics

View aggregated collection data:

```python
# Get collection statistics
stats = client.get_collection_stats()

# Example output:
# {
#   "collection_name": "my_vectors",
#   "dimension": 768,
#   "partition_count": 3,
#   "user_count": 5,
#   "avg_query_duration": 145.2,
#   "total_queries": 1250,
#   "successful_queries": 1240
# }
```

## 🔐 Security & Permissions

### User Management

```python
# Create user
user = client.create_user(
    username="john_doe",
    email="john@example.com",
    password_hash="hashed_password",
    role="user"
)

# Grant permissions
client.grant_permission(
    user_id=user['id'],
    collection_id="collection-uuid",
    permission_type="read"
)

# Check permissions
has_permission = client.check_permission(
    user_id="user-uuid",
    collection_id="collection-uuid",
    permission_type="write"
)
```

### Permission Types

- `read` - Can query the collection
- `write` - Can insert/update data
- `admin` - Full control over collection

## 🛠️ Development

### Local Development

1. **Install Dependencies**
   ```bash
   cd applications/postgresql/client
   pip install -r requirements.txt
   ```

2. **Set Environment Variables**
   ```bash
   export POSTGRES_HOST=localhost
   export POSTGRES_PORT=5432
   export POSTGRES_DB=milvus_metadata
   export POSTGRES_USER=milvus_user
   export POSTGRES_PASSWORD=milvus_password
   ```

3. **Run Tests**
   ```python
   python metadata_client.py
   ```

### Database Migrations

To add new tables or modify schema:

1. Update `init-schema.sql`
2. Delete the existing init job: `kubectl delete job postgresql-init -n postgres`
3. The job will be recreated and run automatically

## 📊 Scaling

### Horizontal Scaling

The PostgreSQL cluster can be scaled by updating the overlay configurations:

```bash
# Development (1 replica)
kubectl apply -k applications/postgresql/overlays/dev

# Staging (2 replicas)
kubectl apply -k applications/postgresql/overlays/staging

# Production (3 replicas)
kubectl apply -k applications/postgresql/overlays/prod
```

### Performance Optimization

1. **Connection Pooling**: The Python client uses connection pooling
2. **Indexes**: Automatic indexes on frequently queried columns
3. **Partitioning**: Large tables can be partitioned by timestamp
4. **Archiving**: Old audit logs can be archived based on retention policy

## 🔍 Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check if PostgreSQL is running
   kubectl get pods -n postgres
   
   # Check logs
   kubectl logs pg-0 -n postgres
   ```

2. **Schema Not Initialized**
   ```bash
   # Check init job status
   kubectl get jobs -n postgres
   kubectl logs job/postgresql-init -n postgres
   ```

3. **Permission Denied**
   ```bash
   # Verify user permissions
   kubectl exec -it pg-0 -n postgres -- psql -U milvus_user -d milvus_metadata -c "\du"
   ```

### Useful Queries

```sql
-- Check table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check slow queries
SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;

-- Check recent audit logs
SELECT action, resource_type, timestamp FROM audit_logs ORDER BY timestamp DESC LIMIT 20;
```

## 📚 API Reference

### MilvusMetadataClient

#### User Management
- `create_user(username, email, password_hash, role)`
- `get_user(user_id=None, username=None)`
- `update_user_last_login(user_id)`

#### Collection Management
- `create_collection(name, dimension, metric_type, description, created_by, metadata)`
- `get_collection(collection_id=None, collection_name=None)`
- `list_collections(status)`
- `update_collection(collection_id, **kwargs)`

#### Permissions
- `grant_permission(user_id, collection_id, permission_type, granted_by)`
- `check_permission(user_id, collection_id, permission_type)`
- `revoke_permission(user_id, collection_id, permission_type)`

#### Monitoring
- `log_audit_event(user_id, action, resource_type, resource_id, details, ip_address, user_agent)`
- `log_performance_metric(collection_id, operation_type, duration_ms, success, operation_id, error_message, metadata)`
- `log_query(user_id, collection_id, query_type, duration_ms, success, top_k, query_vector_dimension, search_params, result_count, error_message)`

#### Configuration
- `get_config(config_key)`
- `set_config(config_key, config_value, config_type, description)`

#### Analytics
- `get_audit_logs(user_id, action, resource_type, limit)`
- `get_performance_stats(collection_id, days)`
- `get_collection_stats()`

## 🤝 Integration with Milvus

### Example Integration

```python
from pymilvus import connections, Collection
from metadata_client import MilvusMetadataClient, log_vector_search

# Connect to Milvus
connections.connect("default", host="milvus-proxy.milvus.svc.cluster.local", port="19530")

# Initialize metadata client
metadata_client = MilvusMetadataClient()

# Get collection from Milvus
collection = Collection("my_vectors")

# Perform search
start_time = time.time()
results = collection.search(
    data=query_vectors,
    anns_field="vector",
    param={"metric_type": "COSINE", "params": {"nprobe": 10}},
    limit=10
)
duration_ms = int((time.time() - start_time) * 1000)

# Log the search
log_vector_search(
    client=metadata_client,
    user_id="user-uuid",
    collection_id="collection-uuid",
    query_vector_dimension=768,
    top_k=10,
    duration_ms=duration_ms,
    success=True,
    result_count=len(results[0])
)
```

This setup provides a robust, scalable metadata management system for Milvus applications with comprehensive monitoring, auditing, and analytics capabilities. 