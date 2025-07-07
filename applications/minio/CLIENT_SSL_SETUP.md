# MinIO Client SSL Setup Guide

## Understanding the SSL Error

The error you're seeing:
```
SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)'))
```

This happens because:
1. MinIO is using self-signed certificates for internal communication
2. Your client doesn't trust the self-signed Certificate Authority (CA)
3. The client cannot verify the certificate chain

## Why Let's Encrypt Won't Work

❌ **Let's Encrypt CANNOT issue certificates for:**
- Internal IP addresses (`192.168.0.200`)
- Internal cluster DNS names (`*.svc.cluster.local`)
- Non-public domains

✅ **Let's Encrypt ONLY works for:**
- Public domain names with HTTP-01 or DNS-01 validation
- Services accessible from the public internet

## Solutions for Internal SSL Communication

### Solution 1: Use CA Certificate for Verification (Recommended)

#### Step 1: Extract the CA Certificate
```bash
# Get the CA certificate from the cluster
kubectl get secret minio-internal-ca -n minio -o jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt

# Verify the certificate
openssl x509 -in minio-ca.crt -text -noout
```

#### Step 2: Configure Client with CA Certificate

**Python (boto3/minio-py):**
```python
from minio import Minio
import ssl

# Create SSL context with CA certificate
ssl_context = ssl.create_default_context()
ssl_context.load_verify_locations('minio-ca.crt')

# Create MinIO client with CA certificate
client = Minio(
    '192.168.0.200:30001',
    access_key='admin',
    secret_key='password',
    secure=True,
    http_client=urllib3.PoolManager(
        cert_reqs='CERT_REQUIRED',
        ca_certs='minio-ca.crt'
    )
)
```

**Python (requests):**
```python
import requests

response = requests.get(
    'https://192.168.0.200:30001/test-bucket-crud',
    verify='minio-ca.crt'  # Use CA certificate for verification
)
```

**curl:**
```bash
curl --cacert minio-ca.crt https://192.168.0.200:30001/test-bucket-crud
```

**mc (MinIO Client):**
```bash
# Configure with CA certificate
mc alias set local https://192.168.0.200:30001 admin password --api s3v4 --path off

# Add CA certificate to system or use --insecure flag
mc --insecure ls local/
```

### Solution 2: Disable SSL Verification (Not Recommended for Production)

**Python (boto3/minio-py):**
```python
from minio import Minio
import urllib3

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Create client with SSL verification disabled
client = Minio(
    '192.168.0.200:30001',
    access_key='admin',
    secret_key='password',
    secure=True,
    http_client=urllib3.PoolManager(
        cert_reqs='CERT_NONE'
    )
)
```

**Python (requests):**
```python
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

response = requests.get(
    'https://192.168.0.200:30001/test-bucket-crud',
    verify=False  # Disable SSL verification
)
```

**curl:**
```bash
curl -k https://192.168.0.200:30001/test-bucket-crud
```

### Solution 3: Use Internal Cluster Communication (Recommended)

Instead of using NodePort, use internal cluster communication:

**From within the cluster:**
```bash
# Use internal service name (no external IP needed)
curl --cacert minio-ca.crt https://prod-minio-service-prod.minio.svc.cluster.local:9000/
```

**Python from within cluster:**
```python
from minio import Minio

client = Minio(
    'prod-minio-service-prod.minio.svc.cluster.local:9000',
    access_key='admin',
    secret_key='password',
    secure=True,
    http_client=urllib3.PoolManager(
        ca_certs='minio-ca.crt'
    )
)
```

## Setting Up CA Certificate in Container Images

### Option 1: Add to System CA Store
```dockerfile
# In your Dockerfile
COPY minio-ca.crt /usr/local/share/ca-certificates/minio-ca.crt
RUN update-ca-certificates
```

### Option 2: Environment Variable
```yaml
# In your pod spec
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: your-app
    env:
    - name: REQUESTS_CA_BUNDLE
      value: /etc/ssl/certs/minio-ca.crt
    volumeMounts:
    - name: minio-ca
      mountPath: /etc/ssl/certs/minio-ca.crt
      subPath: ca.crt
  volumes:
  - name: minio-ca
    secret:
      secretName: minio-internal-ca
```

### Option 3: ConfigMap with CA Certificate
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minio-ca-config
  namespace: minio
data:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    # Your CA certificate content here
    -----END CERTIFICATE-----
```

## Automated CA Certificate Distribution

### Script to Extract and Distribute CA Certificate
```bash
#!/bin/bash
# Extract CA certificate and make it available to clients

NAMESPACE="minio"
CA_SECRET="minio-internal-ca"
OUTPUT_DIR="/etc/ssl/certs"

# Extract CA certificate
kubectl get secret $CA_SECRET -n $NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 -d > $OUTPUT_DIR/minio-ca.crt

# Update CA certificates (Ubuntu/Debian)
if command -v update-ca-certificates &> /dev/null; then
    cp $OUTPUT_DIR/minio-ca.crt /usr/local/share/ca-certificates/
    update-ca-certificates
fi

# Update CA certificates (CentOS/RHEL)
if command -v update-ca-trust &> /dev/null; then
    cp $OUTPUT_DIR/minio-ca.crt /etc/pki/ca-trust/source/anchors/
    update-ca-trust
fi

echo "CA certificate installed successfully"
```

## Testing SSL Connection

### Test with curl
```bash
# Extract CA certificate
kubectl get secret minio-internal-ca -n minio -o jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt

# Test connection
curl --cacert minio-ca.crt -I https://192.168.0.200:30001/minio/health/live
```

### Test with Python
```python
import requests
import subprocess
import base64

# Get CA certificate from cluster
ca_cert = subprocess.check_output([
    'kubectl', 'get', 'secret', 'minio-internal-ca', '-n', 'minio', 
    '-o', 'jsonpath={.data.ca\.crt}'
])
ca_cert_decoded = base64.b64decode(ca_cert)

# Write to file
with open('minio-ca.crt', 'wb') as f:
    f.write(ca_cert_decoded)

# Test connection
response = requests.get(
    'https://192.168.0.200:30001/minio/health/live',
    verify='minio-ca.crt'
)
print(f"Status: {response.status_code}")
```

## Best Practices

1. **✅ Use CA Certificate**: Always use the CA certificate for SSL verification
2. **✅ Internal Communication**: Use internal cluster DNS names when possible
3. **✅ Secure Storage**: Store CA certificates securely in ConfigMaps/Secrets
4. **❌ Avoid --insecure**: Don't disable SSL verification in production
5. **❌ Don't Use Let's Encrypt**: For internal communication, stick with self-signed CA

## Summary

The SSL error is **normal behavior** when using self-signed certificates. The solution is to:

1. **Extract the CA certificate** from the `minio-internal-ca` secret
2. **Configure your client** to use the CA certificate for verification
3. **Use internal cluster communication** when possible

This approach provides **proper SSL security** while maintaining the ability to verify certificate authenticity. 