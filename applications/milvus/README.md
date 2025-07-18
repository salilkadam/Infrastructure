# Milvus Application

This directory contains the Kubernetes manifests for deploying Milvus, a vector database, using ArgoCD.

## Architecture

Milvus is deployed as a distributed system with the following components:

- **Proxy**: Entry point for client connections (2 replicas)
- **Root Coordinator**: Manages metadata and cluster topology (1 replica)
- **Data Coordinator**: Manages data lifecycle (1 replica)
- **Index Coordinator**: Manages index operations (1 replica)
- **Query Coordinator**: Manages query operations (1 replica)
- **Data Node**: Stores and manages data (2 replicas)
- **Index Node**: Builds and manages indexes (2 replicas)
- **Query Node**: Executes queries (2 replicas)

## Dependencies

This Milvus deployment depends on:
- **MinIO**: For object storage (S3-compatible)
- **etcd**: For metadata storage

## Configuration

### MinIO Integration
- Uses MinIO credentials stored in `milvus-minio-credentials` secret
- Connects to MinIO API service at `minio-api.minio.svc.cluster.local:9000`
- Uses SSL for secure communication
- Stores data in `milvus` bucket

### etcd Integration
- Uses etcd credentials stored in `milvus-etcd-credentials` secret
- Connects to etcd service at `etcd.etcd.svc.cluster.local:2379`
- Uses HTTP (non-SSL) for internal communication

## Services

- **milvus-headless**: Internal service for component communication
- **milvus-proxy**: External NodePort service for client access
  - gRPC: Port 30930
  - HTTP: Port 30921

## Deployment

The application is deployed using ArgoCD with automated sync enabled.

## Access

Once deployed, Milvus can be accessed via:
- gRPC: `node-ip:30930`
- HTTP: `node-ip:30921`

## Resources

Each component has resource limits and requests configured for optimal performance. 