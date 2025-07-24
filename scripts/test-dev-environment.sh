#!/bin/bash

set -e

echo "=== Testing Enhanced Dev Environment ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check if pod is ready
check_pod_ready() {
    local namespace=$1
    local pod_label=$2
    local max_attempts=30
    local attempt=1
    
    print_status "INFO" "Waiting for dev-environment pod to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl get pods -n $namespace -l $pod_label --no-headers | grep -q "Running"; then
            print_status "SUCCESS" "Dev environment pod is ready"
            return 0
        fi
        print_status "WARNING" "Attempt $attempt/$max_attempts: Pod not ready yet..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    print_status "ERROR" "Pod failed to become ready"
    return 1
}

# Function to test service connectivity
test_service() {
    local service_name=$1
    local port=$2
    local max_attempts=10
    local attempt=1
    
    print_status "INFO" "Testing $service_name connectivity on port $port..."
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl exec -n dev-environment dev-environment-7dc84786d7-hj6pr -- netstat -tuln | grep -q ":$port "; then
            print_status "SUCCESS" "$service_name is running on port $port"
            return 0
        fi
        print_status "WARNING" "Attempt $attempt/$max_attempts: $service_name not ready on port $port..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_status "ERROR" "$service_name failed to start on port $port"
    return 1
}

# Function to test Redis functionality
test_redis_functionality() {
    print_status "INFO" "Testing Redis functionality..."
    
    local result=$(kubectl exec -n dev-environment dev-environment-7dc84786d7-hj6pr -- python3 -c "
import redis
try:
    r = redis.Redis(host='localhost', port=6379, password='Th1515T0p53cr3t', decode_responses=True)
    r.set('test_key', 'test_value')
    value = r.get('test_key')
    r.delete('test_key')
    print('SUCCESS: Redis test passed')
except Exception as e:
    print(f'ERROR: Redis test failed - {e}')
")
    
    if echo "$result" | grep -q "SUCCESS"; then
        print_status "SUCCESS" "Redis functionality test passed"
        return 0
    else
        print_status "ERROR" "Redis functionality test failed"
        return 1
    fi
}

# Function to test MinIO functionality
test_minio_functionality() {
    print_status "INFO" "Testing MinIO functionality..."
    
    local result=$(kubectl exec -n dev-environment dev-environment-7dc84786d7-hj6pr -- python3 -c "
from minio import Minio
try:
    client = Minio('localhost:9000', access_key='minioadmin', secret_key='minioadmin', secure=False)
    buckets = list(client.list_buckets())
    print(f'SUCCESS: MinIO test passed - Found {len(buckets)} buckets')
except Exception as e:
    print(f'ERROR: MinIO test failed - {e}')
")
    
    if echo "$result" | grep -q "SUCCESS"; then
        print_status "SUCCESS" "MinIO functionality test passed"
        return 0
    else
        print_status "ERROR" "MinIO functionality test failed"
        return 1
    fi
}

# Function to test PostgreSQL functionality
test_postgresql_functionality() {
    print_status "INFO" "Testing PostgreSQL functionality..."
    
    local result=$(kubectl exec -n dev-environment dev-environment-7dc84786d7-hj6pr -- python3 -c "
import psycopg2
try:
    conn = psycopg2.connect(
        host='localhost',
        port=5432,
        database='assetdb',
        user='postgres',
        password='Th1515T0p53cr3t'
    )
    cursor = conn.cursor()
    cursor.execute('SELECT version();')
    version = cursor.fetchone()
    cursor.execute('SELECT COUNT(*) FROM assets;')
    count = cursor.fetchone()
    cursor.close()
    conn.close()
    print(f'SUCCESS: PostgreSQL test passed - {version[0]}, {count[0]} assets')
except Exception as e:
    print(f'ERROR: PostgreSQL test failed - {e}')
")
    
    if echo "$result" | grep -q "SUCCESS"; then
        print_status "SUCCESS" "PostgreSQL functionality test passed"
        return 0
    else
        print_status "ERROR" "PostgreSQL functionality test failed"
        return 1
    fi
}

# Function to test OpenCV functionality
test_opencv_functionality() {
    print_status "INFO" "Testing OpenCV functionality..."
    
    local result=$(kubectl exec -n dev-environment dev-environment-7dc84786d7-hj6pr -- python3 -c "
import cv2
import numpy as np
try:
    img = np.zeros((100, 100, 3), dtype=np.uint8)
    img[:] = (255, 0, 0)  # Blue color
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    print(f'SUCCESS: OpenCV test passed - Image shape {img.shape}, Gray shape {gray.shape}')
except Exception as e:
    print(f'ERROR: OpenCV test failed - {e}')
")
    
    if echo "$result" | grep -q "SUCCESS"; then
        print_status "SUCCESS" "OpenCV functionality test passed"
        return 0
    else
        print_status "ERROR" "OpenCV functionality test failed"
        return 1
    fi
}

# Function to test production services connectivity
test_production_services() {
    print_status "INFO" "Testing production services connectivity..."
    
    # Test production PostgreSQL
    local pg_result=$(kubectl exec -n dev-environment dev-environment-7dc84786d7-hj6pr -- python3 -c "
import os
try:
    import psycopg2
    conn = psycopg2.connect(
        host=os.getenv('POSTGRES_HOST'),
        port=os.getenv('POSTGRES_PORT'),
        database=os.getenv('POSTGRES_DB'),
        user=os.getenv('POSTGRES_USER'),
        password=os.getenv('POSTGRES_PASSWORD')
    )
    conn.close()
    print('SUCCESS: Production PostgreSQL connection test passed')
except Exception as e:
    print(f'ERROR: Production PostgreSQL connection test failed - {e}')
")
    
    if echo "$pg_result" | grep -q "SUCCESS"; then
        print_status "SUCCESS" "Production PostgreSQL connectivity test passed"
    else
        print_status "WARNING" "Production PostgreSQL connectivity test failed (this is expected if production services are not running)"
    fi
    
    # Test production Redis
    local redis_result=$(kubectl exec -n dev-environment dev-environment-7dc84786d7-hj6pr -- python3 -c "
import os
import redis
try:
    r = redis.Redis(
        host=os.getenv('REDIS_HOST'),
        port=int(os.getenv('REDIS_PORT')),
        password=os.getenv('REDIS_PASSWORD'),
        decode_responses=True
    )
    r.ping()
    print('SUCCESS: Production Redis connection test passed')
except Exception as e:
    print(f'ERROR: Production Redis connection test failed - {e}')
")
    
    if echo "$redis_result" | grep -q "SUCCESS"; then
        print_status "SUCCESS" "Production Redis connectivity test passed"
    else
        print_status "WARNING" "Production Redis connectivity test failed (this is expected if production services are not running)"
    fi
    
    # Test production MinIO
    local minio_result=$(kubectl exec -n dev-environment dev-environment-7dc84786d7-hj6pr -- python3 -c "
import os
from minio import Minio
try:
    client = Minio(
        os.getenv('MINIO_ENDPOINT'),
        access_key=os.getenv('MINIO_ACCESS_KEY'),
        secret_key=os.getenv('MINIO_SECRET_KEY'),
        secure=False
    )
    buckets = list(client.list_buckets())
    print('SUCCESS: Production MinIO connection test passed')
except Exception as e:
    print(f'ERROR: Production MinIO connection test failed - {e}')
")
    
    if echo "$minio_result" | grep -q "SUCCESS"; then
        print_status "SUCCESS" "Production MinIO connectivity test passed"
    else
        print_status "WARNING" "Production MinIO connectivity test failed (this is expected if production services are not running)"
    fi
}

# Main test function
main() {
    print_status "INFO" "Starting comprehensive dev environment test..."
    
    # Check if dev-environment pod is ready
    if ! check_pod_ready "dev-environment" "app.kubernetes.io/name=dev-environment"; then
        exit 1
    fi
    
    # Get pod name
    local pod_name=$(kubectl get pods -n dev-environment -l app.kubernetes.io/name=dev-environment --no-headers | awk '{print $1}')
    print_status "INFO" "Testing pod: $pod_name"
    
    # Test local services
    local tests_passed=0
    local total_tests=0
    
    # Test Redis
    total_tests=$((total_tests + 1))
    if test_service "Redis" 6379 && test_redis_functionality; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test MinIO
    total_tests=$((total_tests + 1))
    if test_service "MinIO" 9000 && test_minio_functionality; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test MinIO Console
    total_tests=$((total_tests + 1))
    if test_service "MinIO Console" 9001; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test PostgreSQL
    total_tests=$((total_tests + 1))
    if test_service "PostgreSQL" 5432 && test_postgresql_functionality; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test OpenCV
    total_tests=$((total_tests + 1))
    if test_opencv_functionality; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test production services (optional)
    test_production_services
    
    # Print summary
    echo ""
    print_status "INFO" "=== Test Summary ==="
    print_status "INFO" "Local Services: $tests_passed/$total_tests tests passed"
    
    if [ $tests_passed -eq $total_tests ]; then
        print_status "SUCCESS" "🎉 All local development services are working correctly!"
        print_status "INFO" "Local services available:"
        print_status "INFO" "  - Redis: localhost:6379 (password: Th1515T0p53cr3t)"
        print_status "INFO" "  - MinIO: localhost:9000 (API)"
        print_status "INFO" "  - MinIO Console: localhost:9001 (Web UI)"
        print_status "INFO" "  - PostgreSQL: localhost:5432 (database: assetdb)"
        print_status "INFO" "  - OpenCV: Fully functional with all required libraries"
        echo ""
        print_status "INFO" "You can now develop and test your applications locally!"
        exit 0
    else
        print_status "ERROR" "⚠️  Some local services failed. Check the logs above."
        exit 1
    fi
}

# Run main function
main 