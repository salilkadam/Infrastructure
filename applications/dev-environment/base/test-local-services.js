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