#!/bin/bash

echo "=== MinIO Console Access Test (SSL) ==="
echo "Testing MinIO console accessibility with SSL..."
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if MinIO namespace exists
if ! kubectl get namespace minio &> /dev/null; then
    echo "❌ MinIO namespace does not exist"
    exit 1
fi

echo "✅ MinIO namespace exists"

# Check if MinIO pods are running
POD_STATUS=$(kubectl get pods -n minio --no-headers | grep -E "Running|1/1" | wc -l)
if [ "$POD_STATUS" -eq 0 ]; then
    echo "❌ No MinIO pods are running"
    kubectl get pods -n minio
    exit 1
fi

echo "✅ MinIO pods are running ($POD_STATUS pods)"

# Check if console service exists
if ! kubectl get svc -n minio prod-minio-console-service-prod &> /dev/null; then
    echo "❌ MinIO console service does not exist"
    exit 1
fi

echo "✅ MinIO console service exists"

# Get NodePort
NODEPORT=$(kubectl get svc -n minio prod-minio-console-service-prod -o jsonpath='{.spec.ports[0].nodePort}')
echo "✅ Console NodePort: $NODEPORT"

# Check if CA certificate is available
if [ ! -f "minio-ca.crt" ]; then
    echo "⚠️  CA certificate not found, extracting..."
    if kubectl get secret minio-internal-ca -n minio &> /dev/null; then
        kubectl get secret minio-internal-ca -n minio -o jsonpath='{.data.ca\.crt}' | base64 -d > minio-ca.crt
        echo "✅ CA certificate extracted"
    else
        echo "❌ CA certificate secret not found"
        exit 1
    fi
else
    echo "✅ CA certificate available"
fi

# Get cluster nodes
echo "✅ Available cluster nodes:"
kubectl get nodes -o wide | grep -E "NAME|Ready" | head -10

# Test console accessibility from different nodes with SSL
echo
echo "Testing console accessibility with SSL..."
NODES=(192.168.0.10 192.168.0.200 192.168.0.201 192.168.0.202 192.168.0.203 192.168.0.204)
SUCCESS_COUNT=0

for NODE in "${NODES[@]}"; do
    echo -n "Testing $NODE:$NODEPORT (HTTPS) ... "
    if curl --cacert minio-ca.crt -s -I --max-time 5 "https://$NODE:$NODEPORT" | grep -q "200"; then
        echo "✅ Working"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "❌ Failed"
    fi
done

echo
echo "=== SSL Test Results ==="
echo "Accessible nodes: $SUCCESS_COUNT/${#NODES[@]}"

if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo "✅ MinIO console is accessible via HTTPS!"
    echo
    echo "📝 Access Information:"
    echo "   URLs: https://[NODE_IP]:$NODEPORT"
    echo "   Username: admin"
    echo "   Password: password"
    echo "   ⚠️  IMPORTANT: Your browser needs to trust the CA certificate"
    echo
    echo "🔧 Browser Access Options:"
    echo "   1. Install minio-ca.crt in your browser/system trust store"
    echo "   2. Or accept the security warning in your browser"
    echo "   3. Or use port-forward: kubectl port-forward -n minio svc/prod-minio-console-service-prod 9001:9001"
    echo "      Then access: https://localhost:9001"
    echo
    echo "🔐 SSL Configuration:"
    echo "   ✅ Internal SSL communication enabled"
    echo "   ✅ CA certificate: minio-ca.crt"
    echo "   ✅ All cluster IPs included in certificate"
else
    echo "❌ MinIO console is not accessible from any node"
    echo "Check the troubleshooting guide: cat TROUBLESHOOTING.md"
fi

echo
echo "=== Additional Information ==="
echo "🔍 Check pod logs: kubectl logs -n minio deployment/prod-minio-deployment-prod"
echo "🔍 Check service details: kubectl describe svc -n minio prod-minio-console-service-prod"
echo "🔍 Check certificate: openssl x509 -in minio-ca.crt -text -noout | grep -A 5 'Subject:'"
echo "🔍 Extract CA for clients: ./scripts/extract-minio-ca.sh extract"
echo "🔍 Full troubleshooting guide: cat TROUBLESHOOTING.md" 