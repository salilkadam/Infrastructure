# Feature: Dockerized Dev Environment for k3s

## Goal
Create a self-sufficient Docker image for the dev-environment, containing all required services (PostgreSQL, Redis, MinIO, OpenCV, Node.js, Python, etc.), to be deployed on a k3s cluster. The image will be built and pushed to Docker Hub via GitHub Actions, and deployed using ArgoCD.

## Implementation Plan
1. **Dockerfile**: Build a Docker image with all services and tools, referencing existing setup scripts.
2. **GitHub Actions**: Automate Docker image build and push to Docker Hub on changes.
3. **Kubernetes Deployment**: Update deployment.yaml to use the new image.
4. **Testing**: Deploy to k3s, verify health, iterate until stable.
5. **Documentation**: Update docs and scripts as needed.

## Implementation Tracker
| Phase | Description | Status |
|-------|-------------|--------|
| 1     | Dockerfile creation | Pending |
| 2     | GitHub Actions workflow | Pending |
| 3     | Deployment YAML update | Pending |
| 4     | k3s deployment & test | Pending |
| 5     | Documentation update | Pending | 