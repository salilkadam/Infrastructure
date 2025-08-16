### Kubernetes GPU Setup (Server Repro Guide)

**Environment (captured):**
- NVIDIA driver: 575.64.03
- NVIDIA Container Toolkit (nvidia-ctk): 1.17.8
- containerd: 1.7.27
- runc: 1.2.5
- Kubernetes (k3s): v1.33.3+k3s1
- Node: gpu-server

**Key steps done:**
- Enabled CDI in containerd (configs/containerd/config.toml shows enable_cdi=true and cdi_spec_dirs)
- Generated/installed CDI spec at /etc/cdi/nvidia.yaml (configs/cdi/nvidia.yaml, kind nvidia.com/gpu)
- Deployed NVIDIA device plugin (manifests/nvidia-device-plugin.yaml)
- Ensured node label nvidia.com/gpu.present=true
- Removed legacy kube-system device plugin DaemonSets
- Validated with nvidia-smi pods (basic and CDI)

**Recreate:**
1) Configure containerd for CDI and restart containerd+kubelet
2) Generate CDI spec: scripts/generate_cdi_spec.sh /etc/cdi/nvidia.yaml
3) Deploy device plugin: scripts/setup_device_plugin.sh
4) (Optional) Pre-pull images: scripts/prepull_images.sh
5) Test GPU: scripts/test_gpu.sh basic|cdi

**Included:** manifests/, configs/, scripts/
