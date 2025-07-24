# Implementation Plan: Dockerized Dev Environment

## Phases

### Phase 1: Dockerfile Creation
- Build a Dockerfile that installs and configures PostgreSQL, Redis, MinIO, Node.js, Python, OpenCV, and all required dependencies.
- Reference and adapt logic from setup-local-services.sh.
- Add healthcheck scripts for each service.
- Add test scripts for service validation.
- **Unit Test**: Docker build completes, all binaries present.

### Phase 2: GitHub Actions Workflow
- Create a workflow to build and push the Docker image to Docker Hub on Dockerfile or code changes.
- Use GitHub Secrets for Docker Hub credentials.
- **Unit Test**: Workflow runs and pushes image to Docker Hub.

### Phase 3: Kubernetes Deployment Update
- Update dev-environment deployment.yaml to use the new image.
- Remove redundant setup steps from manifest.
- **Integration Test**: Pod starts and all services are reachable.

### Phase 4: k3s Deployment & Iteration
- Deploy to k3s cluster using ArgoCD.
- Validate all services (PostgreSQL, Redis, MinIO, OpenCV) are healthy.
- Iterate on Dockerfile and deployment until stable.
- **Integration Test**: Run /workspace/test-local-services.py and .js in the pod.

### Phase 5: Documentation & Scripts
- Update documentation for usage, troubleshooting, and test commands.
- Update or add scripts as needed.
- **Unit/Integration Test**: Docs and scripts match deployed environment. 