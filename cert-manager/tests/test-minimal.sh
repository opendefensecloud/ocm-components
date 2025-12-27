#!/usr/bin/env bash
#
# Test script for minimal cert-manager deployment on kind cluster
#
# This script:
# 1. Creates a kind cluster
# 2. Installs cert-manager using the Helm chart
# 3. Waits for all components to be ready
# 4. Creates a self-signed issuer and test certificate
# 5. Verifies certificate is issued successfully
# 6. Cleans up resources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="cert-manager-test"
NAMESPACE="cert-manager"
TEST_NAMESPACE="cert-test"
TIMEOUT=600  # 10 minutes

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"

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

cleanup() {
    log_info "Cleaning up resources..."
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
}

# Trap errors and cleanup
trap cleanup EXIT

# Main test flow
main() {
    log_info "Starting cert-manager minimal configuration test..."

    # Check prerequisites
    log_info "Checking prerequisites..."
    command -v kind >/dev/null 2>&1 || { log_error "kind is not installed. Please install kind first."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is not installed. Please install kubectl first."; exit 1; }
    command -v helm >/dev/null 2>&1 || { log_error "helm is not installed. Please install helm first."; exit 1; }

    # Check if Helm chart exists
    if [ ! -f "$COMPONENT_DIR/cert-manager-v1.19.2.tgz" ]; then
        log_error "Helm chart not found at $COMPONENT_DIR/cert-manager-v1.19.2.tgz"
        exit 1
    fi

    # Create kind cluster
    log_info "Creating kind cluster: $CLUSTER_NAME"
    kind create cluster --name "$CLUSTER_NAME" --wait 120s

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s

    log_info "Note: Container images will be pulled by kind (this may take several minutes on first run)"

    # Create namespace
    log_info "Creating cert-manager namespace..."
    kubectl create namespace "$NAMESPACE"

    # Install cert-manager using Helm
    log_info "Installing cert-manager using Helm chart..."
    helm install cert-manager "$COMPONENT_DIR/cert-manager-v1.19.2.tgz" \
        --namespace "$NAMESPACE" \
        --set crds.enabled=true \
        --set crds.keep=true \
        --set replicaCount=1 \
        --set webhook.replicaCount=1 \
        --set cainjector.replicaCount=1 \
        --set resources.requests.cpu=10m \
        --set resources.requests.memory=32Mi \
        --set resources.limits.cpu=100m \
        --set resources.limits.memory=128Mi \
        --wait \
        --timeout 10m

    # Wait for all deployments to be ready
    log_info "Waiting for cert-manager deployments to be ready..."

    kubectl wait --for=condition=Available deployment/cert-manager \
        -n "$NAMESPACE" --timeout=300s || {
        log_error "cert-manager controller failed to become ready"
        kubectl describe deployment cert-manager -n "$NAMESPACE"
        kubectl get pods -n "$NAMESPACE"
        kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=cert-manager --tail=100 2>&1 || true
        exit 1
    }

    kubectl wait --for=condition=Available deployment/cert-manager-webhook \
        -n "$NAMESPACE" --timeout=300s || {
        log_error "cert-manager webhook failed to become ready"
        kubectl describe deployment cert-manager-webhook -n "$NAMESPACE"
        exit 1
    }

    kubectl wait --for=condition=Available deployment/cert-manager-cainjector \
        -n "$NAMESPACE" --timeout=300s || {
        log_error "cert-manager cainjector failed to become ready"
        kubectl describe deployment cert-manager-cainjector -n "$NAMESPACE"
        exit 1
    }

    log_info "All cert-manager components are ready!"

    # Create test namespace
    log_info "Creating test namespace..."
    kubectl create namespace "$TEST_NAMESPACE"

    # Create self-signed ClusterIssuer
    log_info "Creating self-signed ClusterIssuer..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

    # Wait for ClusterIssuer to be ready
    log_info "Waiting for ClusterIssuer to be ready..."
    sleep 5

    issuer_ready=$(kubectl get clusterissuer selfsigned-issuer -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$issuer_ready" != "True" ]; then
        log_warn "ClusterIssuer not immediately ready, waiting..."
        sleep 10
    fi

    # Create a self-signed CA certificate
    log_info "Creating self-signed CA certificate..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-ca
  namespace: $NAMESPACE
spec:
  isCA: true
  commonName: selfsigned-ca
  secretName: selfsigned-ca-secret
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
    group: cert-manager.io
EOF

    # Wait for CA certificate to be ready
    log_info "Waiting for CA certificate to be issued..."
    timeout_counter=0
    while [ $timeout_counter -lt 120 ]; do
        cert_ready=$(kubectl get certificate selfsigned-ca -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
        if [ "$cert_ready" == "True" ]; then
            log_info "CA certificate is ready!"
            break
        fi
        log_info "Waiting for CA certificate... (${timeout_counter}s)"
        sleep 5
        timeout_counter=$((timeout_counter + 5))
    done

    if [ "$cert_ready" != "True" ]; then
        log_error "CA certificate failed to become ready"
        kubectl describe certificate selfsigned-ca -n "$NAMESPACE"
        exit 1
    fi

    # Create CA ClusterIssuer
    log_info "Creating CA ClusterIssuer..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-ca-issuer
spec:
  ca:
    secretName: selfsigned-ca-secret
EOF

    # Wait for CA issuer to be ready
    sleep 5

    # Create a test certificate
    log_info "Creating test certificate..."
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: $TEST_NAMESPACE
spec:
  secretName: test-certificate-tls
  duration: 2160h
  renewBefore: 360h
  subject:
    organizations:
      - test-org
  commonName: test.example.local
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
    - server auth
    - client auth
  dnsNames:
    - test.example.local
    - www.test.example.local
  issuerRef:
    name: selfsigned-ca-issuer
    kind: ClusterIssuer
    group: cert-manager.io
EOF

    # Wait for test certificate to be ready
    log_info "Waiting for test certificate to be issued..."
    timeout_counter=0
    while [ $timeout_counter -lt 120 ]; do
        cert_ready=$(kubectl get certificate test-certificate -n "$TEST_NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
        if [ "$cert_ready" == "True" ]; then
            log_info "Test certificate is ready!"
            break
        fi
        log_info "Waiting for test certificate... (${timeout_counter}s)"
        sleep 5
        timeout_counter=$((timeout_counter + 5))
    done

    if [ "$cert_ready" != "True" ]; then
        log_error "Test certificate failed to become ready"
        kubectl describe certificate test-certificate -n "$TEST_NAMESPACE"
        kubectl get certificaterequest -n "$TEST_NAMESPACE"
        exit 1
    fi

    # Verify the certificate secret was created
    log_info "Verifying certificate secret..."
    if kubectl get secret test-certificate-tls -n "$TEST_NAMESPACE" >/dev/null 2>&1; then
        log_info "Certificate secret exists!"

        # Check if the secret contains the expected keys
        tls_crt=$(kubectl get secret test-certificate-tls -n "$TEST_NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d | head -1)
        if echo "$tls_crt" | grep -q "BEGIN CERTIFICATE"; then
            log_info "Certificate data is valid!"
        else
            log_error "Certificate data is invalid"
            exit 1
        fi
    else
        log_error "Certificate secret not found"
        exit 1
    fi

    # Print summary
    log_info "========================================="
    log_info "Test Summary"
    log_info "========================================="
    log_info "✓ Kind cluster created successfully"
    log_info "✓ cert-manager installed via Helm"
    log_info "✓ cert-manager controller is ready"
    log_info "✓ cert-manager webhook is ready"
    log_info "✓ cert-manager cainjector is ready"
    log_info "✓ Self-signed ClusterIssuer created"
    log_info "✓ CA certificate issued"
    log_info "✓ CA ClusterIssuer created"
    log_info "✓ Test certificate issued successfully"
    log_info "✓ Certificate secret created with valid data"
    log_info "========================================="
    log_info ""
    log_info "cert-manager components:"
    kubectl get pods -n "$NAMESPACE"
    log_info ""
    log_info "ClusterIssuers:"
    kubectl get clusterissuers
    log_info ""
    log_info "Certificates:"
    kubectl get certificates -A
    log_info ""
    log_info "To keep the cluster running, press Ctrl+C now."
    log_info "Otherwise, the cluster will be deleted in 10 seconds..."

    sleep 10
}

main "$@"
