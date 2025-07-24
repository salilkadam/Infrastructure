# Development Environment

This directory contains a Kubernetes-based development environment with Python and Node.js support, including local instances of PostgreSQL, Redis, and MinIO for development and testing.

## Features

- **Python 3.11** with development tools and Poetry
- **Node.js 20** with npm and yarn
- **OpenCV Support** with all required libraries (libgl1-mesa-glx, libglib2.0-0, libsm6, libxext6, libxrender-dev, libgomp1)
- **Local PostgreSQL** instance with `assetdb` database
- **Local Redis** instance with authentication
- **Local MinIO** instance with web console
- **Production service clients** (PostgreSQL, Redis, MinIO)
- **Development tools**: git, vim, nano, curl, wget
- **Persistent workspace** (10Gi storage)
- **SSH key support** for git access

## Quick Start

### 1. Deploy the Environment

```bash
# Apply the development environment
kubectl apply -k applications/dev-environment/

# Wait for the pod to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=dev-environment -n dev-environment --timeout=300s
```

### 2. Access the Environment

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -n dev-environment -l app.kubernetes.io/name=dev-environment --no-headers | awk '{print $1}')

# Access the container
kubectl exec -it $POD_NAME -n dev-environment -- bash
```

### 3. Test the Setup

```bash
# Run the comprehensive test script
python3 /workspace/test-local-services.py
```

## Local Services

### Local PostgreSQL

- **Host**: localhost
- **Port**: 5432
- **Database**: assetdb
- **User**: postgres
- **Password**: Th1515T0p53cr3t

```bash
# Connect to PostgreSQL
psql -h localhost -p 5432 -U postgres -d assetdb

# Python example
import psycopg2
conn = psycopg2.connect(
    host='localhost',
    port=5432,
    database='assetdb',
    user='postgres',
    password='Th1515T0p53cr3t'
)
```

### Local Redis

- **Host**: localhost
- **Port**: 6379
- **Password**: Th1515T0p53cr3t

```bash
# Connect to Redis
redis-cli -h localhost -p 6379 -a Th1515T0p53cr3t

# Python example
import redis
r = redis.Redis(host='localhost', port=6379, password='Th1515T0p53cr3t', decode_responses=True)
```

### Local MinIO

- **API Host**: localhost
- **API Port**: 9000
- **Console Port**: 9001
- **Access Key**: minioadmin
- **Secret Key**: minioadmin
- **Default Bucket**: default

```bash
# Web Console
# Access via: http://localhost:9001
# Login: minioadmin / minioadmin

# Command line
mc alias set myminio http://localhost:9000 minioadmin minioadmin
mc ls myminio

# Python example
from minio import Minio
client = Minio('localhost:9000', access_key='minioadmin', secret_key='minioadmin', secure=False)
```

### OpenCV Support

```python
import cv2
import numpy as np

# Test basic functionality
img = np.zeros((100, 100, 3), dtype=np.uint8)
img[:] = (255, 0, 0)  # Blue color
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
blur = cv2.GaussianBlur(gray, (5, 5), 0)
```

## Connection Information

### Local Development Services

| Service | Host | Port | Credentials |
|---------|------|------|-------------|
| PostgreSQL | localhost | 5432 | postgres/Th1515T0p53cr3t |
| Redis | localhost | 6379 | -/Th1515T0p53cr3t |
| MinIO API | localhost | 9000 | minioadmin/minioadmin |
| MinIO Console | localhost | 9001 | minioadmin/minioadmin |

### Production Services

The environment also provides access to production services via environment variables:

- `POSTGRES_*` - Production PostgreSQL
- `REDIS_*` - Production Redis  
- `MINIO_*` - Production MinIO

## Port Forwarding

To access services from your local machine:

```bash
# Redis
kubectl port-forward svc/dev-environment -n dev-environment 6379:6379

# MinIO API
kubectl port-forward svc/dev-environment -n dev-environment 9000:9000

# MinIO Console
kubectl port-forward svc/dev-environment -n dev-environment 9001:9001

# PostgreSQL
kubectl port-forward svc/dev-environment -n dev-environment 5432:5432
```

## Development Workflow

1. **Start Development**: Access the container and start coding
2. **Use Local Services**: Connect to local PostgreSQL, Redis, and MinIO for development
3. **Test Locally**: Use the provided test scripts to verify functionality
4. **Deploy to Production**: Use production service environment variables for production testing

## Testing

### Automated Testing

```bash
# Run comprehensive test suite
./scripts/test-dev-environment.sh
```

### Manual Testing

```bash
# Test individual services
python3 /workspace/test-local-services.py

# Test Redis
redis-cli -h localhost -p 6379 -a Th1515T0p53cr3t ping

# Test MinIO
mc alias set myminio http://localhost:9000 minioadmin minioadmin
mc ls myminio

# Test PostgreSQL
psql -h localhost -p 5432 -U postgres -d assetdb -c "SELECT version();"

# Test OpenCV
python3 -c "import cv2; print(cv2.__version__)"
```

## Environment Variables

### Local Services

- `LOCAL_POSTGRES_*` - Local PostgreSQL configuration
- `LOCAL_REDIS_*` - Local Redis configuration  
- `LOCAL_MINIO_*` - Local MinIO configuration

### Production Services

- `POSTGRES_*` - Production PostgreSQL configuration
- `REDIS_*` - Production Redis configuration
- `MINIO_*` - Production MinIO configuration

## Troubleshooting

### Service Not Starting

```bash
# Check service status
netstat -tuln | grep -E ':(6379|5432|9000|9001) '

# Check logs
kubectl logs -n dev-environment <pod-name>
```

### Connection Issues

```bash
# Test connectivity
telnet localhost 6379  # Redis
telnet localhost 5432  # PostgreSQL
telnet localhost 9000  # MinIO API
telnet localhost 9001  # MinIO Console
```

### Reset Environment

```bash
# Delete and recreate the pod
kubectl delete pod -l app.kubernetes.io/name=dev-environment -n dev-environment
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=dev-environment -n dev-environment
```

## Architecture

The development environment runs as a single container with:

- **System Services**: PostgreSQL, Redis, MinIO running as local processes
- **Development Tools**: Python, Node.js, Git, editors
- **Libraries**: OpenCV, database drivers, and other development dependencies
- **Storage**: Persistent volume for workspace data
- **Networking**: Services bound to localhost for security

This setup provides a complete, isolated development environment that can be easily deployed and destroyed as needed. 