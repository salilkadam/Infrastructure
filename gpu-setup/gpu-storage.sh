#!/bin/bash
########################################################################################
# First, let's extend your current root filesystem
sudo lvextend -L +300G /dev/ubuntu-vg-1/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg-1/ubuntu-lv

# Create critical data volumes on your primary system (NVMe)
sudo lvcreate -L 800G -n ai-models-lv ubuntu-vg-1
sudo lvcreate -L 1T -n critical-data-lv ubuntu-vg-1
sudo lvcreate -L 500G -n home-extend-lv ubuntu-vg-1

# Format the new volumes
sudo mkfs.ext4 /dev/ubuntu-vg-1/ai-models-lv
sudo mkfs.ext4 /dev/ubuntu-vg-1/critical-data-lv  
sudo mkfs.ext4 /dev/ubuntu-vg-1/home-extend-lv

########################################################################################

# Create backup volumes on your SATA drive
sudo lvcreate -L 800G -n backup-lv ubuntu-vg
sudo lvcreate -L 500G -n mirror-lv ubuntu-vg
sudo lvcreate -L 300G -n config-backup-lv ubuntu-vg

# Format backup volumes
sudo mkfs.ext4 /dev/ubuntu-vg/backup-lv
sudo mkfs.ext4 /dev/ubuntu-vg/mirror-lv
sudo mkfs.ext4 /dev/ubuntu-vg/config-backup-lv

# Create new VG for disposable workloads on the fastest drive
sudo pvcreate /dev/nvme0n1
sudo vgcreate docker-vg /dev/nvme0n1

# Create volumes for different workload types
sudo lvcreate -L 1.5T -n docker-lv docker-vg        # Docker images/containers
sudo lvcreate -L 1T -n k8s-storage-lv docker-vg     # Kubernetes persistent volumes  
sudo lvcreate -L 800G -n temp-work-lv docker-vg     # Temporary ML workspaces
sudo lvcreate -l 100%FREE -n bulk-cache-lv docker-vg # Remaining for cache/temp

# Format disposable volumes
sudo mkfs.ext4 /dev/docker-vg/docker-lv
sudo mkfs.ext4 /dev/docker-vg/k8s-storage-lv
sudo mkfs.ext4 /dev/docker-vg/temp-work-lv
sudo mkfs.ext4 /dev/docker-vg/bulk-cache-lv
########################################################################################
# Create mount points for critical storage
sudo mkdir -p /opt/ai-models
sudo mkdir -p /var/lib/critical-data
sudo mkdir -p /home-extend

# Create mount points for backup storage  
sudo mkdir -p /mnt/backup
sudo mkdir -p /mnt/mirror
sudo mkdir -p /mnt/config-backup

# Create mount points for disposable storage
sudo mkdir -p /var/lib/docker-storage
sudo mkdir -p /var/lib/k8s-storage
sudo mkdir -p /tmp/ml-workspace
sudo mkdir -p /var/cache/bulk

# Backup current fstab
sudo cp /etc/fstab /etc/fstab.backup

# Add critical storage mounts
echo "# Critical Storage (Primary NVMe)" | sudo tee -a /etc/fstab
echo "/dev/ubuntu-vg-1/ai-models-lv /opt/ai-models ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
echo "/dev/ubuntu-vg-1/critical-data-lv /var/lib/critical-data ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
echo "/dev/ubuntu-vg-1/home-extend-lv /home-extend ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Add backup storage mounts
echo "# Backup Storage (SATA)" | sudo tee -a /etc/fstab
echo "/dev/ubuntu-vg/backup-lv /mnt/backup ext4 defaults 0 2" | sudo tee -a /etc/fstab
echo "/dev/ubuntu-vg/mirror-lv /mnt/mirror ext4 defaults 0 2" | sudo tee -a /etc/fstab
echo "/dev/ubuntu-vg/config-backup-lv /mnt/config-backup ext4 defaults 0 2" | sudo tee -a /etc/fstab

# Add disposable storage mounts  
echo "# Disposable Storage (Secondary NVMe)" | sudo tee -a /etc/fstab
echo "/dev/docker-vg/docker-lv /var/lib/docker-storage ext4 defaults,noatime,discard 0 2" | sudo tee -a /etc/fstab
echo "/dev/docker-vg/k8s-storage-lv /var/lib/k8s-storage ext4 defaults,noatime,discard 0 2" | sudo tee -a /etc/fstab
echo "/dev/docker-vg/temp-work-lv /tmp/ml-workspace ext4 defaults,noatime,discard 0 2" | sudo tee -a /etc/fstab
echo "/dev/docker-vg/bulk-cache-lv /var/cache/bulk ext4 defaults,noatime,discard 0 2" | sudo tee -a /etc/fstab

# Mount everything
sudo mount -a
########################################################################################

# Create backup script
sudo mkdir -p /usr/local/bin
cat << 'EOF' | sudo tee /usr/local/bin/backup-critical.sh
#!/bin/bash
LOG_FILE="/var/log/backup-critical.log"

echo "$(date): Starting critical data backup" >> $LOG_FILE

# Backup AI models
rsync -av --delete /opt/ai-models/ /mnt/backup/ai-models/ >> $LOG_FILE 2>&1

# Backup critical data
rsync -av --delete /var/lib/critical-data/ /mnt/backup/critical-data/ >> $LOG_FILE 2>&1

# Backup home directories
rsync -av --delete /home/ /mnt/backup/home/ >> $LOG_FILE 2>&1

# Backup system configs
rsync -av --delete /etc/ /mnt/config-backup/etc/ >> $LOG_FILE 2>&1

# Mirror important directories for quick failover
rsync -av --delete /opt/ai-models/ /mnt/mirror/ai-models/ >> $LOG_FILE 2>&1

echo "$(date): Backup completed" >> $LOG_FILE
EOF

sudo chmod +x /usr/local/bin/backup-critical.sh

# Add to crontab for automated backups
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-critical.sh") | sudo crontab -

########################################################################################

# Setup DOcker
# Update package index
sudo apt update

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to docker group
sudo usermod -aG docker $USER
# Stop Docker to configure it
sudo systemctl stop docker

# Ensure the Docker daemon config we created earlier is in place
sudo mkdir -p /etc/docker
cat << EOF | sudo tee /etc/docker/daemon.json
{
  "data-root": "/var/lib/docker-storage",
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "default-shm-size": "1G",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
EOF

# Start and enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Verify Docker is using the correct storage location
docker info | grep "Docker Root Dir"



# Replace these variables with your actual values:
export K3S_SERVER_URL="https://192.168.0.200:6443"
export K3S_NODE_TOKEN="<TOKEN_FROM_MASTER>"

# Install k3s agent
curl -sfL https://get.k3s.io | K3S_URL=$K3S_SERVER_URL K3S_TOKEN=$K3S_NODE_TOKEN sh -s - agent

# The above command is equivalent to:
# curl -sfL https://get.k3s.io | K3S_URL=https://your-master-ip:6443 K3S_TOKEN=your-token sh -s - agent
# Create k3s agent config
sudo mkdir -p /etc/rancher/k3s
cat << EOF | sudo tee /etc/rancher/k3s/agent.yaml
node-name: $(hostname)
data-dir: /var/lib/k3s-storage
kubelet-arg:
  - "root-dir=/var/lib/k3s-storage/kubelet"
  - "volume-plugin-dir=/var/lib/k3s-storage/kubelet-plugins"
EOF

# Restart k3s agent to apply config
sudo systemctl restart k3s-agent



# Create storage classes that can use this node's storage
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-local-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ai-models-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# Get your node name first
NODE_NAME=$(hostname)

# Create PVs for your storage (run from master)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ai-models-pv
spec:
  capacity:
    storage: 700Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ai-models-storage
  local:
    path: /opt/ai-models
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE_NAME
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: fast-storage-pv
spec:
  capacity:
    storage: 900Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: fast-local-ssd
  local:
    path: /var/lib/k8s-storage
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE_NAME
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: temp-workspace-pv
spec:
  capacity:
    storage: 700Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Delete
  storageClassName: fast-local-ssd
  local:
    path: /tmp/ml-workspace
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE_NAME
EOF

# From the master, label this node for AI workloads
kubectl label node $NODE_NAME node-type=ai-compute
kubectl label node $NODE_NAME storage-type=nvme-ssd
kubectl label node $NODE_NAME workload=ml-training

# Add taints if you want to dedicate this node only for AI workloads
# kubectl taint node $NODE_NAME dedicated=ai:NoSchedule

# Check all storage
echo "=== Storage Overview ==="
df -h

echo -e "\n=== LVM Status ==="
sudo vgs
sudo lvs

echo -e "\n=== Mount Points ==="
mount | grep -E "(ubuntu-vg|docker-vg)"

echo -e "\n=== Available Space Summary ==="
echo "Critical Storage (Primary): $(df -h /opt/ai-models | tail -1 | awk '{print $4}') available"
echo "Backup Storage: $(df -h /mnt/backup | tail -1 | awk '{print $4}') available"  
echo "Docker Storage: $(df -h /var/lib/docker-storage | tail -1 | awk '{print $4}') available"
echo "K8s Storage: $(df -h /var/lib/k8s-storage | tail -1 | awk '{print $4}') available"

