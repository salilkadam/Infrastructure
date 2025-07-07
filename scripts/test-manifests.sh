#!/bin/bash
set -e

echo "🔍 Testing MinIO manifest validation locally..."
echo "================================================="

# Test base manifests
echo "📋 Testing base manifests..."
if [ -f "applications/minio/base/kustomization.yaml" ]; then
    echo "Building base manifests..."
    if kustomize build applications/minio/base > /tmp/base-manifests.yaml 2>/tmp/base-warnings.txt; then
        # Check for deprecation warnings
        if grep -q "deprecated" /tmp/base-warnings.txt; then
            echo "⚠️  Deprecation warnings found:"
            cat /tmp/base-warnings.txt
            echo "Please fix deprecated configurations"
            exit 1
        fi
        
        # Validate YAML syntax
        python3 -c "
import yaml
import sys
try:
    docs = list(yaml.safe_load_all(open('/tmp/base-manifests.yaml')))
    resource_count = len([d for d in docs if d is not None])
    print(f'📊 Generated {resource_count} Kubernetes resources')
    # Basic validation - check for required fields
    for doc in docs:
        if doc and 'apiVersion' in doc and 'kind' in doc:
            continue
        elif doc is None:
            continue
        else:
            print(f'❌ Invalid resource: missing apiVersion or kind')
            sys.exit(1)
    print('✅ All resources have required fields')
except Exception as e:
    print(f'❌ YAML validation failed: {e}')
    sys.exit(1)
        " || exit 1
        echo "✅ Base manifests validation passed"
    else
        echo "❌ Failed to build base manifests"
        cat /tmp/base-warnings.txt
        exit 1
    fi
else
    echo "❌ Base kustomization.yaml not found"
    exit 1
fi

# Test overlay manifests
echo "📋 Testing overlay manifests..."
if [ -f "applications/minio/overlays/prod/kustomization.yaml" ]; then
    echo "Building prod overlay manifests..."
    if kustomize build applications/minio/overlays/prod > /tmp/overlay-manifests.yaml 2>/tmp/overlay-warnings.txt; then
        # Check for deprecation warnings
        if grep -q "deprecated" /tmp/overlay-warnings.txt; then
            echo "⚠️  Deprecation warnings found:"
            cat /tmp/overlay-warnings.txt
            echo "Please fix deprecated configurations"
            exit 1
        fi
        
        # Validate YAML syntax
        python3 -c "
import yaml
import sys
try:
    docs = list(yaml.safe_load_all(open('/tmp/overlay-manifests.yaml')))
    resource_count = len([d for d in docs if d is not None])
    print(f'📊 Generated {resource_count} Kubernetes resources')
    # Basic validation - check for required fields
    for doc in docs:
        if doc and 'apiVersion' in doc and 'kind' in doc:
            continue
        elif doc is None:
            continue
        else:
            print(f'❌ Invalid resource: missing apiVersion or kind')
            sys.exit(1)
    print('✅ All resources have required fields')
except Exception as e:
    print(f'❌ YAML validation failed: {e}')
    sys.exit(1)
        " || exit 1
        echo "✅ Overlay manifests validation passed"
    else
        echo "❌ Failed to build overlay manifests"
        cat /tmp/overlay-warnings.txt
        exit 1
    fi
else
    echo "❌ Prod overlay kustomization.yaml not found"
    exit 1
fi

# Test ArgoCD application
echo "📋 Testing ArgoCD application..."
if [ -f "applications/minio/argocd-app.yaml" ]; then
    python3 -c "
import yaml
import sys
try:
    docs = list(yaml.safe_load_all(open('applications/minio/argocd-app.yaml')))
    print(f'📊 ArgoCD application YAML contains {len(docs)} documents')
    print('✅ ArgoCD application validation passed')
except Exception as e:
    print(f'❌ ArgoCD application validation failed: {e}')
    sys.exit(1)
    " || exit 1
else
    echo "❌ ArgoCD application manifest not found"
    exit 1
fi

echo "================================================="
echo "🎉 All manifest validations passed successfully!"
echo "The GitHub Actions workflow should now work correctly." 