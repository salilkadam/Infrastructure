#!/bin/bash

# MinIO CA Certificate Extraction and SSL Testing Script
# This script extracts the MinIO CA certificate and tests SSL connections

set -e

# Configuration
NAMESPACE="minio"
CA_SECRET="minio-internal-ca"
OUTPUT_FILE="minio-ca.crt"
MINIO_ENDPOINTS=(
    "192.168.0.200:30001"
    "192.168.0.201:30001"
    "192.168.0.202:30001"
    "192.168.0.203:30001"
    "192.168.0.204:30001"
    "192.168.0.10:30001"
    "prod-minio-service-prod.minio.svc.cluster.local:9000"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Extract CA certificate from cluster
extract_ca_certificate() {
    log_info "Extracting CA certificate from cluster..."
    
    # Check if secret exists
    if ! kubectl get secret $CA_SECRET -n $NAMESPACE &>/dev/null; then
        log_error "Secret $CA_SECRET not found in namespace $NAMESPACE"
        log_info "Make sure MinIO certificates are deployed first"
        exit 1
    fi
    
    # Extract CA certificate
    kubectl get secret $CA_SECRET -n $NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 -d > $OUTPUT_FILE
    
    if [ -f "$OUTPUT_FILE" ]; then
        log_success "CA certificate extracted to $OUTPUT_FILE"
        
        # Show certificate info
        log_info "Certificate details:"
        openssl x509 -in $OUTPUT_FILE -text -noout | grep -A 2 "Subject:"
        openssl x509 -in $OUTPUT_FILE -text -noout | grep -A 2 "Validity"
        openssl x509 -in $OUTPUT_FILE -text -noout | grep -A 10 "Subject Alternative Name"
    else
        log_error "Failed to extract CA certificate"
        exit 1
    fi
}

# Test SSL connection with CA certificate
test_ssl_connection() {
    local endpoint=$1
    
    log_info "Testing SSL connection to $endpoint..."
    
    # Test with curl using CA certificate
    if curl --cacert $OUTPUT_FILE -k -I -s --max-time 10 https://$endpoint/minio/health/live > /dev/null 2>&1; then
        log_success "✅ SSL connection successful to $endpoint"
        return 0
    else
        log_error "❌ SSL connection failed to $endpoint"
        return 1
    fi
}

# Test SSL connection without CA certificate (should fail)
test_ssl_connection_no_ca() {
    local endpoint=$1
    
    log_info "Testing SSL connection to $endpoint (without CA certificate)..."
    
    # Test with curl without CA certificate (should fail)
    if curl -I -s --max-time 10 https://$endpoint/minio/health/live > /dev/null 2>&1; then
        log_warning "⚠️  SSL connection succeeded without CA certificate to $endpoint"
        return 0
    else
        log_info "❌ SSL connection failed without CA certificate to $endpoint (expected)"
        return 1
    fi
}

# Test all endpoints
test_all_endpoints() {
    log_info "Testing SSL connections to all MinIO endpoints..."
    
    local success_count=0
    local total_count=${#MINIO_ENDPOINTS[@]}
    
    for endpoint in "${MINIO_ENDPOINTS[@]}"; do
        if test_ssl_connection "$endpoint"; then
            ((success_count++))
        fi
    done
    
    echo ""
    log_info "SSL Test Results:"
    echo "=================="
    echo "Successful connections: $success_count/$total_count"
    
    if [ $success_count -eq $total_count ]; then
        log_success "All SSL connections successful!"
    else
        log_warning "Some SSL connections failed. Check network connectivity."
    fi
}

# Generate client configuration examples
generate_client_examples() {
    log_info "Generating client configuration examples..."
    
    cat > minio-client-examples.md << 'EOF'
# MinIO Client Configuration Examples

## Python (requests)
```python
import requests

# Use CA certificate for verification
response = requests.get(
    'https://192.168.0.200:30001/minio/health/live',
    verify='minio-ca.crt'
)
print(f"Status: {response.status_code}")
```

## Python (minio-py)
```python
from minio import Minio
import urllib3

# Create client with CA certificate
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

## curl
```bash
# Test with CA certificate
curl --cacert minio-ca.crt https://192.168.0.200:30001/minio/health/live

# Test without verification (insecure)
curl -k https://192.168.0.200:30001/minio/health/live
```

## mc (MinIO Client)
```bash
# Configure alias
mc alias set local https://192.168.0.200:30001 admin password

# Use with --insecure flag
mc --insecure ls local/
```
EOF

    log_success "Client examples generated in minio-client-examples.md"
}

# Install CA certificate system-wide (optional)
install_ca_certificate() {
    log_info "Installing CA certificate system-wide..."
    
    if [ "$EUID" -ne 0 ]; then
        log_error "Root privileges required to install CA certificate system-wide"
        log_info "Run with sudo or manually copy the certificate"
        return 1
    fi
    
    # Ubuntu/Debian
    if command -v update-ca-certificates &> /dev/null; then
        cp $OUTPUT_FILE /usr/local/share/ca-certificates/minio-ca.crt
        update-ca-certificates
        log_success "CA certificate installed system-wide (Ubuntu/Debian)"
    fi
    
    # CentOS/RHEL
    if command -v update-ca-trust &> /dev/null; then
        cp $OUTPUT_FILE /etc/pki/ca-trust/source/anchors/minio-ca.crt
        update-ca-trust
        log_success "CA certificate installed system-wide (CentOS/RHEL)"
    fi
}

# Main function
main() {
    local action="${1:-extract}"
    
    case $action in
        "extract")
            log_info "Starting CA certificate extraction..."
            check_kubectl
            extract_ca_certificate
            log_success "CA certificate extraction completed!"
            ;;
        "test")
            log_info "Starting SSL connection tests..."
            check_kubectl
            
            if [ ! -f "$OUTPUT_FILE" ]; then
                log_warning "CA certificate file not found, extracting first..."
                extract_ca_certificate
            fi
            
            test_all_endpoints
            ;;
        "examples")
            generate_client_examples
            ;;
        "install")
            if [ ! -f "$OUTPUT_FILE" ]; then
                log_warning "CA certificate file not found, extracting first..."
                extract_ca_certificate
            fi
            install_ca_certificate
            ;;
        "all")
            check_kubectl
            extract_ca_certificate
            test_all_endpoints
            generate_client_examples
            
            log_info "Summary:"
            echo "============"
            echo "✅ CA certificate: $OUTPUT_FILE"
            echo "✅ Client examples: minio-client-examples.md"
            echo "✅ SSL tests completed"
            ;;
        *)
            echo "Usage: $0 {extract|test|examples|install|all}"
            echo ""
            echo "  extract   - Extract CA certificate from cluster (default)"
            echo "  test      - Test SSL connections to all endpoints"
            echo "  examples  - Generate client configuration examples"
            echo "  install   - Install CA certificate system-wide (requires root)"
            echo "  all       - Run extract, test, and examples"
            echo ""
            echo "Examples:"
            echo "  $0 extract                    # Extract CA certificate"
            echo "  $0 test                       # Test SSL connections"
            echo "  $0 all                        # Full process"
            echo "  sudo $0 install               # Install system-wide"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 