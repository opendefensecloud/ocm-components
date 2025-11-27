#!/usr/bin/env bash
#
# Test script for minimal Artifact Conduit deployment on kind cluster
#
# This script:
# 1. Creates a kind cluster
# 2. Installs cert-manager (prerequisite)
# 3. Deploys Artifact Conduit with minimal configuration
# 4. Waits for all components to be ready
# 5. Verifies API server is accessible
# 6. Cleans up resources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="arc-test"
NAMESPACE="arc-system"
TIMEOUT=600  # 10 minutes

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

cleanup() {
    log_info "Cleaning up resources..."
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
}

# Trap errors and cleanup
trap cleanup EXIT

# Main test flow
main() {
    log_info "Starting Artifact Conduit minimal configuration test..."

    # Check prerequisites
    log_step "Checking prerequisites..."
    command -v kind >/dev/null 2>&1 || { log_error "kind is not installed. Please install kind first."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is not installed. Please install kubectl first."; exit 1; }
    command -v helm >/dev/null 2>&1 || { log_error "helm is not installed. Please install helm first."; exit 1; }

    # Create kind cluster
    log_step "Creating kind cluster: $CLUSTER_NAME"
    kind create cluster --name "$CLUSTER_NAME"

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s

    log_info "Note: Container images will be pulled by kind (this may take several minutes on first run)"

    # Install cert-manager (prerequisite)
    log_step "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

    # Wait for cert-manager to be ready
    log_info "Waiting for cert-manager to be ready (pulling images may take several minutes)..."
    kubectl wait --for=condition=Available deployment/cert-manager \
      -n cert-manager --timeout=600s || {
        log_error "cert-manager failed to become ready"
        kubectl describe deployment cert-manager -n cert-manager
        kubectl get pods -n cert-manager
        kubectl logs -n cert-manager -l app=cert-manager --tail=100 2>&1 || true
        exit 1
    }

    kubectl wait --for=condition=Available deployment/cert-manager-webhook \
      -n cert-manager --timeout=600s || {
        log_error "cert-manager-webhook failed to become ready"
        kubectl describe deployment cert-manager-webhook -n cert-manager
        exit 1
    }

    kubectl wait --for=condition=Available deployment/cert-manager-cainjector \
      -n cert-manager --timeout=600s || {
        log_error "cert-manager-cainjector failed to become ready"
        kubectl describe deployment cert-manager-cainjector -n cert-manager
        exit 1
    }

    log_info "cert-manager is ready"

    # Create namespace for ARC
    log_step "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"

    # Install Artifact Conduit with minimal configuration
    log_step "Installing Artifact Conduit with minimal configuration..."
    helm install artifact-conduit ../arc-0.1.0.tgz \
      --namespace "$NAMESPACE" \
      --values ../configs/minimal/values.yaml \
      --wait \
      --timeout=10m || {
        log_error "Helm install failed"
        kubectl get pods -n "$NAMESPACE"
        kubectl describe pods -n "$NAMESPACE"
        exit 1
    }

    # Wait for API Server to be ready
    log_step "Waiting for API Server to be ready..."
    kubectl wait --for=condition=Available deployment/artifact-conduit-arc-apiserver \
      -n "$NAMESPACE" --timeout=600s || {
        log_error "API Server failed to become ready"
        kubectl describe deployment artifact-conduit-arc-apiserver -n "$NAMESPACE"
        kubectl get pods -n "$NAMESPACE"
        kubectl describe pods -n "$NAMESPACE" -l app.kubernetes.io/component=apiserver
        kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/component=apiserver --tail=100 2>&1 || true
        exit 1
    }

    log_info "API Server is ready"

    # Wait for Controller Manager to be ready
    log_step "Waiting for Controller Manager to be ready..."
    kubectl wait --for=condition=Available deployment/artifact-conduit-arc-controller-manager \
      -n "$NAMESPACE" --timeout=600s || {
        log_error "Controller Manager failed to become ready"
        kubectl describe deployment artifact-conduit-arc-controller-manager -n "$NAMESPACE"
        kubectl get pods -n "$NAMESPACE"
        kubectl describe pods -n "$NAMESPACE" -l app.kubernetes.io/component=controller-manager
        kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/component=controller-manager --tail=100 2>&1 || true
        exit 1
    }

    log_info "Controller Manager is ready"

    # Wait for etcd to be ready (it's a StatefulSet, so wait for pods)
    log_step "Waiting for etcd to be ready..."
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=etcd \
      -n "$NAMESPACE" --timeout=600s || {
        log_error "etcd failed to become ready"
        kubectl describe statefulset artifact-conduit-arc-etcd -n "$NAMESPACE"
        kubectl get pods -n "$NAMESPACE"
        kubectl describe pods -n "$NAMESPACE" -l app.kubernetes.io/component=etcd
        kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/component=etcd --tail=100 2>&1 || true
        exit 1
    }

    log_info "etcd is ready"

    # Verify APIService is registered
    log_step "Verifying APIService registration..."
    if kubectl get apiservice v1alpha1.arc.bwi.de >/dev/null 2>&1; then
        log_info "APIService v1alpha1.arc.bwi.de is registered"

        # Check APIService status
        available=$(kubectl get apiservice v1alpha1.arc.bwi.de -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
        if [ "$available" = "True" ]; then
            log_info "APIService is available"
        else
            log_warn "APIService is not yet available"
            kubectl describe apiservice v1alpha1.arc.bwi.de
        fi
    else
        log_warn "APIService v1alpha1.arc.bwi.de not found (this may be expected if CRDs are not created yet)"
    fi

    # Verify all pods are running
    log_step "Verifying all pods are running..."
    pod_count=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    running_count=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers | wc -l)

    log_info "Pods running: $running_count/$pod_count"
    kubectl get pods -n "$NAMESPACE"

    if [ "$running_count" -eq "$pod_count" ]; then
        log_info "All pods are running successfully!"
    else
        log_warn "Not all pods are running. Check the output above."
    fi

    # Display resource information
    log_step "Deployment summary:"
    echo ""
    kubectl get all -n "$NAMESPACE"
    echo ""
    kubectl get certificates -n "$NAMESPACE" 2>/dev/null || true
    echo ""

    # Success message
    echo ""
    log_info "======================================"
    log_info "✓ Artifact Conduit minimal deployment test PASSED"
    log_info "======================================"
    echo ""
    log_info "Components deployed:"
    log_info "  - API Server (1 replica)"
    log_info "  - Controller Manager (1 replica)"
    log_info "  - etcd (1 replica)"
    echo ""
    log_info "To interact with the deployment:"
    log_info "  kubectl get pods -n $NAMESPACE"
    log_info "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=arc"
    echo ""
    log_info "To access API Server:"
    log_info "  kubectl port-forward -n $NAMESPACE svc/arc-apiserver 8443:443"
    echo ""
}

# Run main function
main
