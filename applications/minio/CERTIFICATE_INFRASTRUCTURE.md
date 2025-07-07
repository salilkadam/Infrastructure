# MinIO Certificate Infrastructure

## Overview
This document describes the complete certificate infrastructure for MinIO SSL/TLS setup, designed to work from a clean deployment.

## Certificate Chain Architecture

```
Self-Signed ClusterIssuer
    ↓
Internal CA Certificate
    ↓
CA Issuer
    ↓
MinIO TLS Certificate
```

## Components

### 1. Self-Signed ClusterIssuer (`cert-clusterissuer-selfsigned.yaml`)
- **Purpose**: Creates self-signed certificates
- **Resource**: ClusterIssuer
- **Name**: `minio-selfsigned-clusterissuer`
- **Scope**: Cluster-wide

### 2. Internal CA Certificate (`cert-internal-ca.yaml`)
- **Purpose**: Creates a Certificate Authority for MinIO
- **Resource**: Certificate
- **Name**: `minio-internal-ca`
- **Secret**: `minio-internal-ca`
- **Validity**: 10 years
- **Signed by**: `minio-selfsigned-clusterissuer`

### 3. CA Issuer (`cert-ca-issuer.yaml`)
- **Purpose**: Issues certificates using the internal CA
- **Resource**: Issuer
- **Name**: `minio-internal-ca-issuer`
- **Scope**: Namespace-scoped (minio)
- **Uses**: `minio-internal-ca` secret

### 4. MinIO TLS Certificate (`cert-minio-tls.yaml`)
- **Purpose**: Provides TLS certificates for MinIO server
- **Resource**: Certificate
- **Name**: `minio-internal-tls`
- **Secret**: `minio-internal-tls`
- **Validity**: 90 days (auto-renewed)
- **Signed by**: `minio-internal-ca-issuer`

## Subject Alternative Names (SANs)

The MinIO TLS certificate includes the following SANs:

### DNS Names:
- `minio-hl.minio.svc.cluster.local` (headless service)
- `minio.minio.svc.cluster.local` (service)
- `minio-service.minio.svc.cluster.local` (base service)
- `prod-minio-service-prod.minio.svc.cluster.local` (prod service)
- `minio` (short name)
- `localhost` (local access)
- `*.minio.svc.cluster.local` (wildcard for all services)

### IP Addresses:
- `127.0.0.1` (localhost IPv4)
- `::1` (localhost IPv6)

## Certificate Usage

The MinIO TLS certificate is configured for:
- **Digital Signature**: For authentication
- **Key Encipherment**: For key exchange
- **Server Auth**: For server authentication
- **Client Auth**: For client authentication

## Prerequisites

### 1. cert-manager Installation
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

### 2. Deployment Order
The certificates have dependencies and must be deployed in order:
1. `cert-clusterissuer-selfsigned.yaml` (ClusterIssuer)
2. `cert-internal-ca.yaml` (CA Certificate)
3. `cert-ca-issuer.yaml` (CA Issuer)
4. `cert-minio-tls.yaml` (MinIO TLS Certificate)

## Deployment Commands

### Option 1: Using Kustomize (Recommended)
```bash
# Apply entire MinIO configuration (includes certificates)
kubectl apply -k applications/minio/overlays/prod/

# Verify certificates
kubectl get certificate -n minio
kubectl get issuer -n minio
kubectl get clusterissuer | grep minio
```

### Option 2: Manual Certificate Deployment
```bash
# Step 1: Create self-signed ClusterIssuer
kubectl apply -f applications/minio/base/cert-clusterissuer-selfsigned.yaml

# Step 2: Create CA certificate (wait for ClusterIssuer)
kubectl apply -f applications/minio/base/cert-internal-ca.yaml

# Step 3: Create CA issuer (wait for CA certificate)
kubectl apply -f applications/minio/base/cert-ca-issuer.yaml

# Step 4: Create MinIO TLS certificate (wait for CA issuer)
kubectl apply -f applications/minio/base/cert-minio-tls.yaml
```

## Verification

### Check Certificate Status
```bash
# Check all certificates
kubectl get certificate -n minio

# Check certificate details
kubectl describe certificate minio-internal-ca -n minio
kubectl describe certificate minio-internal-tls -n minio

# Check issuers
kubectl get issuer -n minio
kubectl get clusterissuer | grep minio
```

### Check Generated Secrets
```bash
# Check CA secret
kubectl get secret minio-internal-ca -n minio -o yaml

# Check TLS secret
kubectl get secret minio-internal-tls -n minio -o yaml

# Verify certificate content
kubectl get secret minio-internal-tls -n minio -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

## Troubleshooting

### Common Issues

1. **Certificate Not Ready**
   ```bash
   # Check certificate status
   kubectl describe certificate minio-internal-ca -n minio
   kubectl describe certificate minio-internal-tls -n minio
   
   # Check cert-manager logs
   kubectl logs -l app=cert-manager -n cert-manager
   ```

2. **Issuer Not Ready**
   ```bash
   # Check issuer status
   kubectl describe issuer minio-internal-ca-issuer -n minio
   kubectl describe clusterissuer minio-selfsigned-clusterissuer
   ```

3. **Secret Not Created**
   ```bash
   # Check if secret exists
   kubectl get secrets -n minio | grep minio-internal
   
   # Check certificate events
   kubectl get events -n minio --field-selector involvedObject.kind=Certificate
   ```

### Manual Certificate Renewal
```bash
# Force certificate renewal
kubectl patch certificate minio-internal-tls -n minio --type='json' -p='[{"op": "remove", "path": "/spec/renewBefore"}]'
kubectl patch certificate minio-internal-tls -n minio --type='json' -p='[{"op": "add", "path": "/spec/renewBefore", "value": "1h"}]'
```

## Security Considerations

1. **CA Certificate Security**: The CA certificate is critical - protect the secret
2. **Certificate Rotation**: Certificates auto-renew but monitor expiration
3. **Access Control**: Ensure proper RBAC for certificate resources
4. **Network Security**: Use network policies to restrict access to certificate endpoints

## Clean Deployment Requirements

For a completely clean deployment, ensure:
- ✅ cert-manager is installed and running
- ✅ No existing certificates with the same names
- ✅ No existing secrets with the same names
- ✅ MinIO namespace exists
- ✅ Proper RBAC permissions for cert-manager

This infrastructure provides a complete, self-contained certificate solution for MinIO SSL/TLS without external dependencies. 