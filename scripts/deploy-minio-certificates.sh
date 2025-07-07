#!/bin/bash

# MinIO Certificate Infrastructure Deployment Script
# This script deploys the complete certificate infrastructure for MinIO SSL/TLS
# It handles dependencies and ensures proper order of deployment

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MINIO_BASE_DIR="${PROJECT_ROOT}/applications/minio/base"
NAMESPACE="minio"
TIMEOUT=300  # 5 minutes timeout for each resource

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Check if cert-manager is installed
check_cert_manager() {
    log_info "Checking cert-manager installation..."
    
    if ! kubectl get ns cert-manager &>/dev/null; then
        log_error "cert-manager namespace not found"
        log_info "Installing cert-manager..."
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
        
        log_info "Waiting for cert-manager to be ready..."
        kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
        kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=300s
        kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=300s
        
        log_success "cert-manager installed and ready"
    else
        log_success "cert-manager is already installed"
    fi
}

# Wait for resource to be ready
wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace_arg=""
    
    if [ "$3" != "cluster" ]; then
        namespace_arg="-n $NAMESPACE"
    fi
    
    log_info "Waiting for $resource_type/$resource_name to be ready..."
    
    local timeout_counter=0
    while [ $timeout_counter -lt $TIMEOUT ]; do
        if kubectl get $resource_type $resource_name $namespace_arg &>/dev/null; then
            # Check if resource has ready condition
            if kubectl get $resource_type $resource_name $namespace_arg -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
                log_success "$resource_type/$resource_name is ready"
                return 0
            fi
        fi
        
        sleep 5
        timeout_counter=$((timeout_counter + 5))
        if [ $((timeout_counter % 30)) -eq 0 ]; then
            log_info "Still waiting for $resource_type/$resource_name... (${timeout_counter}s elapsed)"
        fi
    done
    
    log_error "Timeout waiting for $resource_type/$resource_name to be ready"
    return 1
}

# Deploy ClusterIssuer
deploy_clusterissuer() {
    log_info "Deploying self-signed ClusterIssuer..."
    
    kubectl apply -f "${MINIO_BASE_DIR}/cert-clusterissuer-selfsigned.yaml"
    wait_for_resource "clusterissuer" "minio-selfsigned-clusterissuer" "cluster"
    
    log_success "ClusterIssuer deployed successfully"
}

# Deploy CA Certificate
deploy_ca_certificate() {
    log_info "Deploying internal CA certificate..."
    
    kubectl apply -f "${MINIO_BASE_DIR}/cert-internal-ca.yaml"
    wait_for_resource "certificate" "minio-internal-ca"
    
    log_success "CA Certificate deployed successfully"
}

# Deploy CA Issuer
deploy_ca_issuer() {
    log_info "Deploying CA Issuer..."
    
    kubectl apply -f "${MINIO_BASE_DIR}/cert-ca-issuer.yaml"
    wait_for_resource "issuer" "minio-internal-ca-issuer"
    
    log_success "CA Issuer deployed successfully"
}

# Deploy MinIO TLS Certificate
deploy_minio_tls() {
    log_info "Deploying MinIO TLS certificate..."
    
    kubectl apply -f "${MINIO_BASE_DIR}/cert-minio-tls.yaml"
    wait_for_resource "certificate" "minio-internal-tls"
    
    log_success "MinIO TLS Certificate deployed successfully"
}

# Verify all certificates
verify_certificates() {
    log_info "Verifying certificate deployment..."
    
    # Check ClusterIssuer
    if ! kubectl get clusterissuer minio-selfsigned-clusterissuer &>/dev/null; then
        log_error "ClusterIssuer not found"
        return 1
    fi
    
    # Check CA Certificate
    if ! kubectl get certificate minio-internal-ca -n $NAMESPACE &>/dev/null; then
        log_error "CA Certificate not found"
        return 1
    fi
    
    # Check CA Issuer
    if ! kubectl get issuer minio-internal-ca-issuer -n $NAMESPACE &>/dev/null; then
        log_error "CA Issuer not found"
        return 1
    fi
    
    # Check MinIO TLS Certificate
    if ! kubectl get certificate minio-internal-tls -n $NAMESPACE &>/dev/null; then
        log_error "MinIO TLS Certificate not found"
        return 1
    fi
    
    # Check secrets
    if ! kubectl get secret minio-internal-ca -n $NAMESPACE &>/dev/null; then
        log_error "CA secret not found"
        return 1
    fi
    
    if ! kubectl get secret minio-internal-tls -n $NAMESPACE &>/dev/null; then
        log_error "TLS secret not found"
        return 1
    fi
    
    log_success "All certificates verified successfully"
    
    # Show certificate information
    log_info "Certificate Status:"
    echo "===================="
    kubectl get certificate -n $NAMESPACE
    echo ""
    kubectl get issuer -n $NAMESPACE
    echo ""
    kubectl get clusterissuer | grep minio
}

# Clean up certificates (optional)
cleanup_certificates() {
    log_warning "Cleaning up existing certificates..."
    
    kubectl delete certificate minio-internal-tls -n $NAMESPACE --ignore-not-found=true
    kubectl delete certificate minio-internal-ca -n $NAMESPACE --ignore-not-found=true
    kubectl delete issuer minio-internal-ca-issuer -n $NAMESPACE --ignore-not-found=true
    kubectl delete clusterissuer minio-selfsigned-clusterissuer --ignore-not-found=true
    
    kubectl delete secret minio-internal-tls -n $NAMESPACE --ignore-not-found=true
    kubectl delete secret minio-internal-ca -n $NAMESPACE --ignore-not-found=true
    
    log_success "Cleanup completed"
}

# Main deployment function
main() {
    local action="${1:-deploy}"
    
    log_info "Starting MinIO Certificate Infrastructure Deployment"
    log_info "Project Root: $PROJECT_ROOT"
    log_info "MinIO Base Directory: $MINIO_BASE_DIR"
    log_info "Target Namespace: $NAMESPACE"
    echo ""
    
    case $action in
        "deploy")
            check_kubectl
            check_cert_manager
            
            # Ensure namespace exists
            kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
            
            # Deploy certificates in order
            deploy_clusterissuer
            deploy_ca_certificate
            deploy_ca_issuer
            deploy_minio_tls
            
            # Verify deployment
            verify_certificates
            
            log_success "MinIO Certificate Infrastructure deployed successfully!"
            ;;
        "cleanup")
            check_kubectl
            cleanup_certificates
            ;;
        "verify")
            check_kubectl
            verify_certificates
            ;;
        *)
            echo "Usage: $0 {deploy|cleanup|verify}"
            echo ""
            echo "  deploy  - Deploy certificate infrastructure (default)"
            echo "  cleanup - Remove all certificates and secrets"
            echo "  verify  - Verify certificate deployment"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 