# ArgoCD Application - Triton

Apply `argocd-app.yaml` to register the Triton app in ArgoCD. Sync to deploy.

Paths:
- Source: `applications/triton/base`
- Destination namespace: `triton`

Requires:
- GPU node labels `nvidia.com/gpu.present=true`
- RuntimeClass `nvidia-experimental`
- StorageClass `fast-local-ssd`
