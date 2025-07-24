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