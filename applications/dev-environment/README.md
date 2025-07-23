# Development Environment

This directory contains a Kubernetes-based development environment with Python and Node.js support, including clients for PostgreSQL, Redis, and MinIO.

## Features

- **Python 3.11** with development tools
- **Node.js 20** with npm and yarn
- **PostgreSQL client** (psycopg2-binary)
- **Redis client** (redis)
- **MinIO client** (minio, boto3)
- **Development tools**: git, vim, nano, curl, wget
- **Persistent workspace** (10Gi storage)
- **SSH key support** for git access

## Quick Start

### 1. Deploy the Environment

```bash
# Apply the ArgoCD application
kubectl apply -f applications/dev-environment/argocd-application.yaml

# Or apply directly with kustomize
kubectl apply -k applications/dev-environment/base/
```

### 2. Access the Development Environment

#### Option A: Shell Access
```bash
# Get the pod name
kubectl get pods -n dev-environment

# Shell into the container
kubectl exec -it <pod-name> -n dev-environment -- /bin/bash
```

#### Option B: Port Forward
```bash
# Forward Node.js port
kubectl port-forward svc/dev-environment -n dev-environment 3000:3000

# Forward Python port
kubectl port-forward svc/dev-environment -n dev-environment 8000:8000
```

#### Option C: Web Access
Access via: https://dev.askcollections.com

## Environment Variables

The container comes with pre-configured environment variables for connecting to your infrastructure services:

### PostgreSQL
- `POSTGRES_HOST`: pg-rw.postgres.svc.cluster.local
- `POSTGRES_PORT`: 5432
- `POSTGRES_DB`: postgres
- `POSTGRES_USER`: postgres
- `POSTGRES_PASSWORD`: postgres_password

### Redis
- `REDIS_HOST`: redis.redis.svc.cluster.local
- `REDIS_PORT`: 6379

### MinIO
- `MINIO_ENDPOINT`: minio.minio.svc.cluster.local:9000
- `MINIO_ACCESS_KEY`: minioadmin
- `MINIO_SECRET_KEY`: minioadmin
- `MINIO_BUCKET`: default

## Usage Examples

### Python Development

```python
# PostgreSQL connection
import psycopg2
import os

conn = psycopg2.connect(
    host=os.getenv('POSTGRES_HOST'),
    port=os.getenv('POSTGRES_PORT'),
    database=os.getenv('POSTGRES_DB'),
    user=os.getenv('POSTGRES_USER'),
    password=os.getenv('POSTGRES_PASSWORD')
)

# Redis connection
import redis
r = redis.Redis(
    host=os.getenv('REDIS_HOST'),
    port=int(os.getenv('REDIS_PORT'))
)

# MinIO connection
from minio import Minio
client = Minio(
    os.getenv('MINIO_ENDPOINT'),
    access_key=os.getenv('MINIO_ACCESS_KEY'),
    secret_key=os.getenv('MINIO_SECRET_KEY'),
    secure=False
)
```

### Node.js Development

```javascript
// PostgreSQL connection
const { Client } = require('pg');
const client = new Client({
  host: process.env.POSTGRES_HOST,
  port: process.env.POSTGRES_PORT,
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

// Redis connection
const redis = require('redis');
const client = redis.createClient({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT
});

// MinIO connection
const Minio = require('minio');
const minioClient = new Minio.Client({
  endPoint: process.env.MINIO_ENDPOINT.split(':')[0],
  port: parseInt(process.env.MINIO_ENDPOINT.split(':')[1]),
  useSSL: false,
  accessKey: process.env.MINIO_ACCESS_KEY,
  secretKey: process.env.MINIO_SECRET_KEY
});
```

## Workspace

Your development workspace is mounted at `/workspace` and persists across pod restarts. This is where you should store your code and projects.

## SSH Keys

To use SSH keys for git access:

1. Add your SSH keys to the `secret.yaml` file:
   ```yaml
   stringData:
     id_rsa: |
       -----BEGIN OPENSSH PRIVATE KEY-----
       Your private key content here
       -----END OPENSSH PRIVATE KEY-----
     id_rsa.pub: |
       ssh-rsa Your public key content here
   ```

2. Apply the updated secret:
   ```bash
   kubectl apply -f applications/dev-environment/base/secret.yaml
   ```

3. Restart the deployment:
   ```bash
   kubectl rollout restart deployment/dev-environment -n dev-environment
   ```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n dev-environment
kubectl describe pod <pod-name> -n dev-environment
```

### Check Logs
```bash
kubectl logs <pod-name> -n dev-environment
```

### Check Services
```bash
kubectl get svc -n dev-environment
```

### Check PVC
```bash
kubectl get pvc -n dev-environment
```

## Customization

### Adding More Tools

To add additional development tools, modify the `deployment.yaml` file and update the command in the container spec.

### Changing Base Image

You can change the base image from `python:3.11-slim` to any other image that supports your development needs.

### Resource Limits

Adjust the resource requests and limits in `deployment.yaml` based on your needs.

## Security Notes

- The container runs as root for development convenience
- SSH keys are mounted as read-only
- Environment variables contain sensitive information
- Consider using Kubernetes secrets for production use 