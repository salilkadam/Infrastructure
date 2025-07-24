#!/bin/bash

set -e

echo "Setting up local development services..."

# Create scripts directory
mkdir -p /workspace/scripts

# Function to check if a service is running
check_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    echo "Checking if $service_name is running on port $port..."
    while [ $attempt -le $max_attempts ]; do
        if netstat -tuln | grep -q ":$port "; then
            echo "$service_name is running on port $port"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: $service_name not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "ERROR: $service_name failed to start on port $port"
    return 1
}

# Setup PostgreSQL
setup_postgresql() {
    echo "Setting up local PostgreSQL..."
    
    # Initialize PostgreSQL data directory
    if [ ! -d "/var/lib/postgresql/data" ]; then
        mkdir -p /var/lib/postgresql/data
        chown postgres:postgres /var/lib/postgresql/data
        su - postgres -c "initdb -D /var/lib/postgresql/data"
    fi
    
    # Configure PostgreSQL
    cat > /etc/postgresql/postgresql.conf << EOF
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_parallel_maintenance_workers = 4
EOF

    # Configure pg_hba.conf for local access
    cat > /etc/postgresql/pg_hba.conf << EOF
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

    # Start PostgreSQL
    su - postgres -c "pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/logfile start"
    
    # Wait for PostgreSQL to be ready
    sleep 5
    
    # Create assetdb database and set password
    su - postgres -c "psql -c \"ALTER USER postgres PASSWORD '$LOCAL_POSTGRES_PASSWORD';\""
    su - postgres -c "createdb -O postgres assetdb"
    
    # Create sample table and data
    su - postgres -c "psql -d assetdb -c \"
    CREATE TABLE IF NOT EXISTS assets (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    INSERT INTO assets (name, description) VALUES 
        ('Sample Asset 1', 'This is a sample asset for testing'),
        ('Sample Asset 2', 'Another sample asset for testing')
    ON CONFLICT DO NOTHING;
    \""
    
    echo "PostgreSQL setup complete!"
}

# Setup Redis
setup_redis() {
    echo "Setting up local Redis..."
    
    # Configure Redis
    cat > /etc/redis/redis.conf << EOF
bind 127.0.0.1
port 6379
requirepass $LOCAL_REDIS_PASSWORD
maxmemory 256mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
EOF

    # Start Redis
    redis-server /etc/redis/redis.conf --daemonize yes
    
    echo "Redis setup complete!"
}

# Setup MinIO
setup_minio() {
    echo "Setting up local MinIO..."
    
    # Create MinIO directories
    mkdir -p /workspace/minio/data
    mkdir -p /workspace/minio/config
    
    # Download MinIO binary if not exists
    if [ ! -f "/usr/local/bin/minio" ]; then
        wget -O /usr/local/bin/minio https://dl.min.io/server/minio/release/linux-amd64/minio
        chmod +x /usr/local/bin/minio
    fi
    
    # Create MinIO configuration
    cat > /workspace/minio/config/config.json << EOF
{
    "version": "1",
    "credential": {
        "accessKey": "$LOCAL_MINIO_ACCESS_KEY",
        "secretKey": "$LOCAL_MINIO_SECRET_KEY"
    },
    "region": "us-east-1",
    "browser": "on",
    "logger": {
        "console": {
            "enabled": true,
            "level": "info"
        }
    }
}
EOF

    # Start MinIO server
    /usr/local/bin/minio server /workspace/minio/data --console-address ":9001" --address ":9000" &
    
    # Wait for MinIO to start
    sleep 5
    
    # Create default bucket
    /usr/local/bin/mc alias set myminio http://localhost:9000 $LOCAL_MINIO_ACCESS_KEY $LOCAL_MINIO_SECRET_KEY
    /usr/local/bin/mc mb myminio/default --ignore-existing
    
    echo "MinIO setup complete!"
}

# Setup test scripts
setup_test_scripts() {
    echo "Creating test scripts..."
    
    # Python test script
    cat > /workspace/test-local-services.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import psycopg2
import redis
from minio import Minio
import cv2
import numpy as np

def test_postgresql():
    print("Testing PostgreSQL connection...")
    try:
        conn = psycopg2.connect(
            host=os.getenv('LOCAL_POSTGRES_HOST'),
            port=os.getenv('LOCAL_POSTGRES_PORT'),
            database=os.getenv('LOCAL_POSTGRES_DB'),
            user=os.getenv('LOCAL_POSTGRES_USER'),
            password=os.getenv('LOCAL_POSTGRES_PASSWORD')
        )
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        print(f"✅ PostgreSQL connected: {version[0]}")
        
        cursor.execute("SELECT * FROM assets LIMIT 2;")
        assets = cursor.fetchall()
        print(f"✅ Assets table has {len(assets)} records")
        
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"❌ PostgreSQL test failed: {e}")
        return False

def test_redis():
    print("Testing Redis connection...")
    try:
        r = redis.Redis(
            host=os.getenv('LOCAL_REDIS_HOST'),
            port=int(os.getenv('LOCAL_REDIS_PORT')),
            password=os.getenv('LOCAL_REDIS_PASSWORD'),
            decode_responses=True
        )
        r.set('test_key', 'test_value')
        value = r.get('test_key')
        print(f"✅ Redis connected: test_key = {value}")
        r.delete('test_key')
        return True
    except Exception as e:
        print(f"❌ Redis test failed: {e}")
        return False

def test_minio():
    print("Testing MinIO connection...")
    try:
        client = Minio(
            os.getenv('LOCAL_MINIO_ENDPOINT'),
            access_key=os.getenv('LOCAL_MINIO_ACCESS_KEY'),
            secret_key=os.getenv('LOCAL_MINIO_SECRET_KEY'),
            secure=False
        )
        buckets = list(client.list_buckets())
        print(f"✅ MinIO connected: Found {len(buckets)} buckets")
        return True
    except Exception as e:
        print(f"❌ MinIO test failed: {e}")
        return False

def test_opencv():
    print("Testing OpenCV...")
    try:
        # Create a simple test image
        img = np.zeros((100, 100, 3), dtype=np.uint8)
        img[:] = (255, 0, 0)  # Blue color
        
        # Test basic OpenCV operations
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        
        print(f"✅ OpenCV working: Image shape {img.shape}, Gray shape {gray.shape}")
        return True
    except Exception as e:
        print(f"❌ OpenCV test failed: {e}")
        return False

def main():
    print("=== Local Development Environment Test ===")
    
    tests = [
        test_postgresql,
        test_redis,
        test_minio,
        test_opencv
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print(f"=== Test Results: {passed}/{total} tests passed ===")
    
    if passed == total:
        print("🎉 All services are working correctly!")
        return 0
    else:
        print("⚠️  Some services failed. Check the logs above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOF

    # Node.js test script
    cat > /workspace/test-local-services.js << 'EOF'
#!/usr/bin/env node

const { Client } = require('pg');
const redis = require('redis');
const Minio = require('minio');

async function testPostgreSQL() {
    console.log("Testing PostgreSQL connection...");
    try {
        const client = new Client({
            host: process.env.LOCAL_POSTGRES_HOST,
            port: process.env.LOCAL_POSTGRES_PORT,
            database: process.env.LOCAL_POSTGRES_DB,
            user: process.env.LOCAL_POSTGRES_USER,
            password: process.env.LOCAL_POSTGRES_PASSWORD,
        });
        
        await client.connect();
        const result = await client.query('SELECT version()');
        console.log(`✅ PostgreSQL connected: ${result.rows[0].version}`);
        
        const assets = await client.query('SELECT * FROM assets LIMIT 2');
        console.log(`✅ Assets table has ${assets.rows.length} records`);
        
        await client.end();
        return true;
    } catch (error) {
        console.log(`❌ PostgreSQL test failed: ${error.message}`);
        return false;
    }
}

async function testRedis() {
    console.log("Testing Redis connection...");
    try {
        const client = redis.createClient({
            host: process.env.LOCAL_REDIS_HOST,
            port: process.env.LOCAL_REDIS_PORT,
            password: process.env.LOCAL_REDIS_PASSWORD
        });
        
        await client.connect();
        await client.set('test_key', 'test_value');
        const value = await client.get('test_key');
        console.log(`✅ Redis connected: test_key = ${value}`);
        await client.del('test_key');
        await client.disconnect();
        return true;
    } catch (error) {
        console.log(`❌ Redis test failed: ${error.message}`);
        return false;
    }
}

async function testMinIO() {
    console.log("Testing MinIO connection...");
    try {
        const minioClient = new Minio.Client({
            endPoint: process.env.LOCAL_MINIO_ENDPOINT.split(':')[0],
            port: parseInt(process.env.LOCAL_MINIO_ENDPOINT.split(':')[1]),
            useSSL: false,
            accessKey: process.env.LOCAL_MINIO_ACCESS_KEY,
            secretKey: process.env.LOCAL_MINIO_SECRET_KEY
        });
        
        const buckets = await minioClient.listBuckets();
        console.log(`✅ MinIO connected: Found ${buckets.length} buckets`);
        return true;
    } catch (error) {
        console.log(`❌ MinIO test failed: ${error.message}`);
        return false;
    }
}

async function main() {
    console.log("=== Local Development Environment Test (Node.js) ===");
    
    const tests = [
        testPostgreSQL,
        testRedis,
        testMinIO
    ];
    
    let passed = 0;
    const total = tests.length;
    
    for (const test of tests) {
        if (await test()) {
            passed++;
        }
        console.log();
    }
    
    console.log(`=== Test Results: ${passed}/${total} tests passed ===`);
    
    if (passed === total) {
        console.log("🎉 All services are working correctly!");
        process.exit(0);
    } else {
        console.log("⚠️  Some services failed. Check the logs above.");
        process.exit(1);
    }
}

main().catch(console.error);
EOF

    # Make scripts executable
    chmod +x /workspace/test-local-services.py
    chmod +x /workspace/test-local-services.js
    
    # Install Node.js dependencies
    cat > /workspace/package.json << 'EOF'
{
  "name": "dev-environment-tests",
  "version": "1.0.0",
  "description": "Test scripts for local development environment",
  "main": "test-local-services.js",
  "scripts": {
    "test": "node test-local-services.js"
  },
  "dependencies": {
    "pg": "^8.11.0",
    "redis": "^4.6.0",
    "minio": "^7.1.0"
  }
}
EOF

    cd /workspace && npm install
    
    echo "Test scripts created!"
}

# Main setup function
main() {
    echo "Starting local development environment setup..."
    
    # Setup services
    setup_postgresql
    setup_redis
    setup_minio
    setup_test_scripts
    
    # Wait for all services to be ready
    echo "Waiting for services to be ready..."
    check_service "PostgreSQL" 5432
    check_service "Redis" 6379
    check_service "MinIO" 9000
    check_service "MinIO Console" 9001
    
    echo ""
    echo "=== Local Development Environment Setup Complete ==="
    echo "Services available at:"
    echo "  PostgreSQL: localhost:5432 (assetdb database)"
    echo "  Redis: localhost:6379 (with password)"
    echo "  MinIO: localhost:9000 (API)"
    echo "  MinIO Console: localhost:9001 (Web UI)"
    echo ""
    echo "Environment variables:"
    echo "  LOCAL_POSTGRES_* - for local PostgreSQL"
    echo "  LOCAL_REDIS_* - for local Redis"
    echo "  LOCAL_MINIO_* - for local MinIO"
    echo ""
    echo "Test scripts:"
    echo "  Python: python3 /workspace/test-local-services.py"
    echo "  Node.js: node /workspace/test-local-services.js"
    echo ""
    echo "Production services are still available via:"
    echo "  POSTGRES_* - for production PostgreSQL"
    echo "  REDIS_* - for production Redis"
    echo "  MINIO_* - for production MinIO"
}

# Run main function
main 