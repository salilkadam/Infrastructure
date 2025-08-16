### GPU on Kubernetes — Summary of Actions

**Driver and toolkit:**
- Installed/verified NVIDIA driver 575.64.03 (nvidia-smi)
- Installed NVIDIA Container Toolkit 1.17.8 (nvidia-ctk)

**Container runtime:**
- containerd 1.7.27 with CDI enabled (enable_cdi=true, cdi_spec_dirs)
- runc 1.2.5

**Kubernetes:**
- k3s v1.33.3+k3s1 on node gpu-server
- Labeled node: nvidia.com/gpu.present=true

**NVIDIA device plugin:**
- Applied DaemonSet (v0.17.3) captured in manifests/nvidia-device-plugin.yaml
- Removed legacy DaemonSets in kube-system

**CDI:**
- Generated nvidia CDI spec at /etc/cdi/nvidia.yaml (kind: nvidia.com/gpu)

**Validation:**
- Launched basic and CDI-annotated nvidia-smi test pods
- Observed initial ContainerCreating due to image pull; mitigated by pre-pulling or waiting

**Artifacts saved:**
- configs/cdi/nvidia.yaml
- configs/containerd/config.toml
- manifests/nvidia-device-plugin.yaml
- manifests/nvidia-smi-basic.yaml
- manifests/nvidia-smi-cdi.yaml
- scripts/*
