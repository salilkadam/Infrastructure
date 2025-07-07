#!/bin/bash

echo "=== MinIO Console Access Test ==="
echo "Testing MinIO console accessibility..."
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

# Get cluster nodes
echo "✅ Available cluster nodes:"
kubectl get nodes -o wide | grep -E "NAME|Ready" | head -10

# Test console accessibility from different nodes
echo
echo "Testing console accessibility..."
NODES=(192.168.0.10 192.168.0.200 192.168.0.201 192.168.0.202 192.168.0.203 192.168.0.204)
SUCCESS_COUNT=0

for NODE in "${NODES[@]}"; do
    echo -n "Testing $NODE:$NODEPORT ... "
    if curl -s -I "http://$NODE:$NODEPORT" | grep -q "200 OK"; then
        echo "✅ Working"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "❌ Failed"
    fi
done

echo
echo "=== Test Results ==="
echo "Accessible nodes: $SUCCESS_COUNT/${#NODES[@]}"

if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo "✅ MinIO console is accessible!"
    echo
    echo "📝 Access Information:"
    echo "   URLs: http://[NODE_IP]:$NODEPORT"
    echo "   Username: admin"
    echo "   Password: password"
    echo
    echo "🔧 If you still can't access from your browser:"
    echo "   1. Try port-forward: kubectl port-forward -n minio svc/prod-minio-console-service-prod 9001:9001"
    echo "   2. Then access: http://localhost:9001"
    echo "   3. Check network connectivity between your machine and cluster nodes"
    echo "   4. Try different browsers or incognito mode"
else
    echo "❌ MinIO console is not accessible from any node"
    echo "Check the troubleshooting guide: cat TROUBLESHOOTING.md"
fi

echo
echo "=== Additional Information ==="
echo "🔍 Check pod logs: kubectl logs -n minio deployment/prod-minio-deployment-prod"
echo "🔍 Check service details: kubectl describe svc -n minio prod-minio-console-service-prod"
echo "🔍 Full troubleshooting guide: cat TROUBLESHOOTING.md" 