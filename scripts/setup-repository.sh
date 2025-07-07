#!/bin/bash

# Setup script for configuring the GitHub repository and CI/CD pipeline
# This script helps configure the remote repository and provides setup instructions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check git status
check_git_status() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not a git repository. Please run 'git init' first."
        exit 1
    fi
}

# Function to configure remote repository
configure_remote() {
    local repo_url="$1"
    
    print_header "Configuring Remote Repository"
    
    # Check if remote exists
    if git remote get-url origin >/dev/null 2>&1; then
        print_info "Remote 'origin' already exists: $(git remote get-url origin)"
        read -p "Do you want to update it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git remote set-url origin "$repo_url"
            print_status "Remote repository updated: $repo_url"
        else
            print_info "Keeping existing remote configuration"
        fi
    else
        git remote add origin "$repo_url"
        print_status "Remote repository configured: $repo_url"
    fi
}

# Function to generate kubeconfig secret
generate_kubeconfig_secret() {
    print_header "Generating Kubeconfig Secret"
    
    if [ ! -f ~/.kube/config ]; then
        print_error "Kubeconfig file not found at ~/.kube/config"
        return 1
    fi
    
    local kubeconfig_base64=$(cat ~/.kube/config | base64 -w 0)
    
    echo "Add this secret to your GitHub repository:"
    echo "Settings → Secrets and variables → Actions → New repository secret"
    echo
    echo "Secret Name: KUBE_CONFIG"
    echo "Secret Value:"
    echo "$kubeconfig_base64"
    echo
    print_warning "Keep this secret secure and don't share it publicly!"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check required tools
    if ! command_exists git; then
        missing_tools+=("git")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists gh; then
        print_warning "GitHub CLI (gh) not found. Install it for easier workflow management."
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    print_status "All required tools are available"
    
    # Check Kubernetes connectivity
    if kubectl cluster-info >/dev/null 2>&1; then
        print_status "Kubernetes cluster is accessible"
        kubectl get nodes --no-headers | wc -l | xargs -I {} echo "Found {} nodes in cluster"
    else
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check cert-manager
    if kubectl get namespace cert-manager >/dev/null 2>&1; then
        print_status "cert-manager is installed"
    else
        print_warning "cert-manager not found. It will be installed automatically during deployment."
    fi
}

# Function to show next steps
show_next_steps() {
    print_header "Next Steps"
    
    echo "1. Create GitHub Repository:"
    echo "   - Go to https://github.com/new"
    echo "   - Repository name: k3s-minio-infrastructure (or your preference)"
    echo "   - Make it private for security"
    echo "   - Don't initialize with README (we already have files)"
    echo
    
    echo "2. Configure Repository Secrets:"
    echo "   - Run this script with 'secrets' option to generate KUBE_CONFIG"
    echo "   - Add the secret to GitHub repository settings"
    echo
    
    echo "3. Update Remote URL:"
    echo "   - Replace YOUR_USERNAME with your GitHub username"
    echo "   - Run: git remote set-url origin https://github.com/YOUR_USERNAME/k3s-minio-infrastructure.git"
    echo
    
    echo "4. Push Code:"
    echo "   git push -u origin master"
    echo
    
    echo "5. Configure Environment Protection (Optional):"
    echo "   - Go to repository Settings → Environments"
    echo "   - Create 'prod' environment with protection rules"
    echo
    
    echo "6. Test Deployment:"
    echo "   - Manual trigger: gh workflow run deploy-minio.yml -f environment=prod"
    echo "   - Check status: gh run list"
    echo
    
    print_status "Setup complete! Follow the steps above to finish configuration."
}

# Function to test repository setup
test_repository_setup() {
    print_header "Testing Repository Setup"
    
    # Check if we can connect to the remote
    if git ls-remote origin >/dev/null 2>&1; then
        print_status "Successfully connected to remote repository"
        
        # Check if we can push
        if git push --dry-run origin master >/dev/null 2>&1; then
            print_status "Ready to push to remote repository"
        else
            print_error "Cannot push to remote repository. Check permissions."
        fi
    else
        print_error "Cannot connect to remote repository. Check URL and permissions."
    fi
    
    # Check workflow files
    if [ -f ".github/workflows/deploy-minio.yml" ] && [ -f ".github/workflows/certificate-monitoring.yml" ]; then
        print_status "GitHub Actions workflow files are present"
    else
        print_error "GitHub Actions workflow files are missing"
    fi
}

# Function to push changes
push_changes() {
    print_header "Pushing Changes to Remote Repository"
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "You have uncommitted changes. Commit them first."
        return 1
    fi
    
    # Check if remote is configured
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_error "Remote repository not configured. Use 'configure-remote' option first."
        return 1
    fi
    
    # Push changes
    if git push -u origin master; then
        print_status "Changes successfully pushed to remote repository"
        print_info "GitHub Actions workflows will now be available in your repository"
    else
        print_error "Failed to push changes. Check repository permissions."
        return 1
    fi
}

# Main function
main() {
    echo -e "${BLUE}=== GitHub Repository Setup Script ===${NC}\n"
    
    # Check git status
    check_git_status
    
    case "${1:-help}" in
        "prerequisites")
            check_prerequisites
            ;;
        "configure-remote")
            if [ -z "$2" ]; then
                print_error "Usage: $0 configure-remote <repository-url>"
                echo "Example: $0 configure-remote https://github.com/username/k3s-minio-infrastructure.git"
                exit 1
            fi
            configure_remote "$2"
            ;;
        "secrets")
            generate_kubeconfig_secret
            ;;
        "test")
            test_repository_setup
            ;;
        "push")
            push_changes
            ;;
        "all")
            check_prerequisites
            show_next_steps
            ;;
        "help"|*)
            echo "Usage: $0 [OPTION]"
            echo
            echo "Options:"
            echo "  prerequisites      - Check system prerequisites"
            echo "  configure-remote <url> - Configure remote repository"
            echo "  secrets           - Generate kubeconfig secret for GitHub"
            echo "  test              - Test repository setup"
            echo "  push              - Push changes to remote repository"
            echo "  all               - Run prerequisites check and show next steps"
            echo "  help              - Show this help message"
            echo
            echo "Examples:"
            echo "  $0 prerequisites"
            echo "  $0 configure-remote https://github.com/username/k3s-minio-infrastructure.git"
            echo "  $0 secrets"
            echo "  $0 push"
            echo
            ;;
    esac
}

# Run main function with all arguments
main "$@" 