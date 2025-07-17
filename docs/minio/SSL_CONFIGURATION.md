# MinIO SSL Configuration

## Overview

This deployment uses a two-tier SSL certificate infrastructure:
- **Internal Communication**: Self-signed certificates for pod-to-pod communication
- **External Communication**: Let's Encrypt certificates for external API access

## Certificate Infrastructure

### Certificate Chain

```
Self-Signed ClusterIssuer (minio-selfsigned-clusterissuer)
    ↓
Internal CA Certificate (minio-internal-ca)
    ↓
CA Issuer (minio-internal-ca-issuer)
    ↓
MinIO TLS Certificate (minio-internal-tls)
```

### Components

1. **Self-Signed ClusterIssuer** (`cert-clusterissuer-selfsigned.yaml`)
   - Creates self-signed certificates
   - Cluster-wide resource

2. **Internal CA Certificate** (`cert-internal-ca.yaml`)
   - Certificate Authority for internal communication
   - 10-year validity
   - Signed by self-signed ClusterIssuer

3. **CA Issuer** (`cert-ca-issuer.yaml`)
   - Issues certificates using the internal CA
   - Namespace-scoped

4. **MinIO TLS Certificate** (`cert-minio-tls.yaml`)
   - TLS certificates for MinIO server
   - 90-day validity with auto-renewal
   - Includes all necessary SANs

### Subject Alternative Names (SANs)

The MinIO TLS certificate includes:

**DNS Names:**
- `minio-hl.minio.svc.cluster.local` (headless service)
- `minio.minio.svc.cluster.local` (API service)
- `minio-console.minio.svc.cluster.local` (console service)
- `minio-0.minio-hl.minio.svc.cluster.local` (pod 0)
- `minio-1.minio-hl.minio.svc.cluster.local` (pod 1)
- `minio-2.minio-hl.minio.svc.cluster.local` (pod 2)
- `minio-3.minio-hl.minio.svc.cluster.local` (pod 3)
- `minio` (short name)
- `localhost` (local access)

**IP Addresses:**
- `127.0.0.1` (localhost IPv4)
- `::1` (localhost IPv6)

## SSL Connection Methods

### 1. External API Access (Recommended)

**URL**: https://minio.askcollections.com

```python
from minio import Minio

client = Minio(
    "minio.askcollections.com",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=True  # Uses Let's Encrypt certificate
)
```

### 2. Internal Cluster Access

**Service**: `minio.minio.svc.cluster.local:9000`

```python
from minio import Minio

client = Minio(
    "minio.minio.svc.cluster.local:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=True
)
```

### 3. Direct Pod Access

**Pod**: `minio-0.minio-hl.minio.svc.cluster.local:9000`

```python
from minio import Minio

client = Minio(
    "minio-0.minio-hl.minio.svc.cluster.local:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=True
)
```

### 4. Console Access

**NodePort**: `https://<cluster-node-ip>:30901`

```bash
# Access console via NodePort
curl -k https://<cluster-node-ip>:30901
```

## Working with Internal SSL Certificates

### Extracting CA Certificate

```bash
# Extract the CA certificate
kubectl get secret minio-internal-ca -n minio -o jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt

# Verify the certificate
openssl x509 -in minio-ca.crt -text -noout
```

### Using CA Certificate for Verification

**Python with CA Certificate:**
```python
from minio import Minio
import urllib3

client = Minio(
    "minio.minio.svc.cluster.local:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=True,
    http_client=urllib3.PoolManager(
        cert_reqs='CERT_REQUIRED',
        ca_certs='minio-ca.crt'
    )
)
```

**curl with CA Certificate:**
```bash
curl --cacert minio-ca.crt https://minio.minio.svc.cluster.local:9000/minio/health/live
```

**MinIO Client (mc):**
```bash
# Configure with CA certificate
mc alias set internal https://minio.minio.svc.cluster.local:9000 minioadmin minioadmin --api s3v4

# Use with CA certificate
mc --insecure ls internal/
```

### Disabling SSL Verification (Not Recommended)

**Python:**
```python
from minio import Minio
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

client = Minio(
    "minio.minio.svc.cluster.local:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=True,
    http_client=urllib3.PoolManager(
        cert_reqs='CERT_NONE'
    )
)
```

**curl:**
```bash
curl -k https://minio.minio.svc.cluster.local:9000/minio/health/live
```

## SSL Testing

### Test External SSL
```bash
# Test external API
curl -I https://minio.askcollections.com

# Test with verbose output
curl -v https://minio.askcollections.com
```

### Test Internal SSL
```bash
# Test internal service
kubectl exec -it minio-0 -n minio -- curl -I https://minio-hl.minio.svc.cluster.local:9000/minio/health/live

# Test from another pod
kubectl run test-pod --image=curlimages/curl --rm -it -- curl -I https://minio.minio.svc.cluster.local:9000/minio/health/live
```

### Test Console SSL
```bash
# Test console via NodePort
curl -k -I https://<cluster-node-ip>:30901
```

## Certificate Management

### Check Certificate Status
```bash
# Check all certificates
kubectl get certificate -n minio

# Check certificate details
kubectl describe certificate minio-internal-tls -n minio

# Check certificate expiration
kubectl get secret minio-internal-tls -n minio -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

### Manual Certificate Renewal
```bash
# Force certificate renewal
kubectl patch certificate minio-internal-tls -n minio --type='json' -p='[{"op": "remove", "path": "/spec/renewBefore"}]'
kubectl patch certificate minio-internal-tls -n minio --type='json' -p='[{"op": "add", "path": "/spec/renewBefore", "value": "1h"}]'
```

### Certificate Troubleshooting
```bash
# Check cert-manager logs
kubectl logs -l app=cert-manager -n cert-manager

# Check certificate events
kubectl get events -n minio --field-selector involvedObject.kind=Certificate

# Check issuer status
kubectl describe issuer minio-internal-ca-issuer -n minio
```

## Security Best Practices

1. **Use External Access**: Prefer external API access with Let's Encrypt certificates
2. **CA Certificate**: Use CA certificate for internal communication verification
3. **Certificate Rotation**: Monitor certificate expiration and renewal
4. **Network Policies**: Implement network policies for additional security
5. **Credential Management**: Change default credentials for production

## Troubleshooting SSL Issues

### Common SSL Errors

1. **Certificate Verify Failed**:
   - Use CA certificate for verification
   - Or disable SSL verification (not recommended for production)

2. **Hostname Mismatch**:
   - Ensure using correct service names
   - Check SANs in certificate

3. **Certificate Expired**:
   - Check certificate status
   - Force renewal if needed

### Debug Commands

```bash
# Check certificate details
kubectl get secret minio-internal-tls -n minio -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text

# Test SSL connection with verbose output
openssl s_client -connect minio.minio.svc.cluster.local:9000 -servername minio.minio.svc.cluster.local

# Check certificate chain
kubectl get secret minio-internal-tls -n minio -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer -subject
``` 