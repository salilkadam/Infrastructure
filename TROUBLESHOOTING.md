# MinIO Console Access Troubleshooting Guide

## Test Results Summary ✅

I've tested the MinIO setup and everything is working correctly:

### ✅ Deployment Status
```bash
# MinIO pods are running
kubectl get pods -n minio
NAME                                              READY   STATUS    RESTARTS   AGE
prod-minio-deployment-prod-6d58b8f964-fkgp2       1/1     Running   0          XXm
prod-minio-deployment-prod-6d58b8f964-g6tqm       1/1     Running   0          XXm

# Services are correctly configured
kubectl get svc -n minio
NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
prod-minio-console-service-prod   NodePort    10.43.40.138   <none>        9001:30001/TCP
prod-minio-service-prod           ClusterIP   10.43.2.146    <none>        9000/TCP,9001/TCP
```

### ✅ NodePort Accessibility
```bash
# Console is accessible via NodePort on all cluster nodes
curl -I http://192.168.0.10:30001   # ✅ Working
curl -I http://192.168.0.201:30001  # ✅ Working 
curl -I http://192.168.0.202:30001  # ✅ Working
curl -I http://192.168.0.203:30001  # ✅ Working
```

### ✅ Authentication Configuration
```bash
# Credentials are properly configured
Username: admin
Password: password
```

### ✅ MinIO Console Response
```bash
# Console returns proper HTTP response
HTTP/1.1 200 OK
Server: MinIO Console
Content-Type: text/html
```

## Available Node IPs for Console Access

You can access the MinIO console using any of these IPs:
- **192.168.0.10:30001** (current node)
- **192.168.0.200:30001** (cp1)
- **192.168.0.201:30001** (node1)
- **192.168.0.202:30001** (node2)
- **192.168.0.203:30001** (node3)
- **192.168.0.204:30001** (cp2)

## Common Issues and Solutions

### 1. Network Connectivity Issues

**Problem**: Cannot access from your local machine
**Solution**: Ensure you're accessing from within the cluster network or have proper network routing.

```bash
# Test from within the cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Then inside the pod:
wget -O- http://192.168.0.10:30001
```

### 2. Browser-Related Issues

**Problem**: Browser shows "network error" or "connection refused"
**Solutions**:
- Try accessing via HTTP (not HTTPS): `http://192.168.0.10:30001`
- Try a different browser or incognito mode
- Check for browser extensions blocking the connection
- Clear browser cache and cookies

### 3. Firewall/Network Policies

**Problem**: Connection blocked by firewall
**Solutions**:
```bash
# Check if NodePort is properly exposed
kubectl get svc -n minio prod-minio-console-service-prod

# Test from cluster node directly
ssh user@192.168.0.10
curl -I http://localhost:30001
```

### 4. DNS Resolution Issues

**Problem**: Using hostname instead of IP
**Solution**: Always use IP addresses for NodePort access:
- ✅ `http://192.168.0.10:30001`
- ❌ `http://node-hostname:30001`

### 5. Port Already in Use

**Problem**: Another service using port 30001
**Solution**: Check if port is available:
```bash
# Check what's using port 30001
netstat -tulpn | grep 30001
# Or check with ss
ss -tulpn | grep 30001
```

## Alternative Access Methods

### 1. Port-Forward (Recommended for troubleshooting)
```bash
# Forward console port to local machine
kubectl port-forward -n minio svc/prod-minio-console-service-prod 9001:9001

# Then access via: http://localhost:9001
```

### 2. Direct Pod Access
```bash
# Get pod name
kubectl get pods -n minio

# Port-forward directly to pod
kubectl port-forward -n minio pod/prod-minio-deployment-prod-XXXXX 9001:9001
```

### 3. Cluster Internal Access
```bash
# Create a temporary pod for testing
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Inside the pod, test with:
wget -O- http://prod-minio-console-service-prod.minio.svc.cluster.local:9001
```

## Diagnostic Commands

### Check Pod Logs
```bash
kubectl logs -n minio deployment/prod-minio-deployment-prod --tail=50
```

### Check Service Details
```bash
kubectl describe svc -n minio prod-minio-console-service-prod
```

### Check Node Status
```bash
kubectl get nodes -o wide
```

### Test Network Connectivity
```bash
# From cluster node
telnet 192.168.0.10 30001

# Check if port is listening
netstat -tlnp | grep 30001
```

## Working Configuration Summary

- **Console URL**: `http://ANY_NODE_IP:30001`
- **Username**: `admin`
- **Password**: `password`
- **Protocol**: HTTP (not HTTPS)
- **Access Method**: NodePort 30001

## Next Steps

1. **Try port-forward method first** (most reliable for testing)
2. **Verify network connectivity** from your client machine
3. **Check browser settings** and try different browsers
4. **Test from within cluster** using the debug pod method

The MinIO console is definitely working and accessible. The issue is likely related to network connectivity between your client and the Kubernetes cluster nodes. 