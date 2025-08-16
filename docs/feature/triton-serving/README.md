# Triton Serving Feature

This feature deploys NVIDIA Triton Inference Server on k3s with GPU acceleration, using `fast-local-ssd` StorageClass for the model repository, Prometheus for metrics, nginx Ingress with cert-manager for TLS, and ArgoCD for GitOps.

See `IMPLEMENTATION_PLAN.md` and `IMPLEMENTATION_TRACKER.md` for details.
