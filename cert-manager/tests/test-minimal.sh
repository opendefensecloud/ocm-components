#!/usr/bin/env bash
set -euo pipefail

# cert-manager Minimal Deployment Test
# This script tests cert-manager deployment on a local kind cluster
# It verifies: Helm install, CRD creation, pod readiness, and certificate issuance

CLUSTER_NAME="${KIND_CLUSTER_NAME:-cert-manager-test}"
NAMESPACE="cert-manager"
TIMEOUT="300s"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

cleanup() {
    log_info "Cleaning up kind cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null || true
}

# Parse flags
SKIP_CLEANUP=false
for arg in "$@"; do
    case $arg in
        --skip-cleanup) SKIP_CLEANUP=true ;;
    esac
done

if [ "$SKIP_CLEANUP" = false ]; then
    trap cleanup EXIT
fi

# Check prerequisites
for cmd in kind kubectl helm; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "'$cmd' is required but not found in PATH"
        exit 1
    fi
done

log_info "=== cert-manager Minimal Deployment Test ==="

# Step 1: Create kind cluster
log_info "Creating kind cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_warn "Cluster '${CLUSTER_NAME}' already exists, deleting..."
    kind delete cluster --name "${CLUSTER_NAME}"
fi
kind create cluster --name "${CLUSTER_NAME}" --wait 60s

# Step 2: Add Helm repo and install cert-manager
log_info "Adding jetstack Helm repository..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update jetstack

log_info "Installing cert-manager with minimal values..."
helm install cert-manager jetstack/cert-manager \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values "${COMPONENT_DIR}/values-minimal.yaml" \
    --wait \
    --timeout "${TIMEOUT}"

# Step 3: Verify CRDs are installed
log_info "Verifying CRDs..."
EXPECTED_CRDS=(
    "certificates.cert-manager.io"
    "certificaterequests.cert-manager.io"
    "clusterissuers.cert-manager.io"
    "issuers.cert-manager.io"
    "orders.acme.cert-manager.io"
    "challenges.acme.cert-manager.io"
)

for crd in "${EXPECTED_CRDS[@]}"; do
    if kubectl get crd "$crd" &>/dev/null; then
        log_info "  CRD found: $crd"
    else
        log_error "  CRD missing: $crd"
        exit 1
    fi
done

# Step 4: Verify pods are running
log_info "Waiting for all cert-manager pods to be ready..."
kubectl wait --for=condition=Ready pods --all \
    -n "${NAMESPACE}" \
    --timeout="${TIMEOUT}"

log_info "Pod status:"
kubectl get pods -n "${NAMESPACE}" -o wide

# Step 5: Verify deployments
log_info "Checking deployments..."
for deploy in cert-manager cert-manager-webhook cert-manager-cainjector; do
    READY=$(kubectl get deployment "$deploy" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$READY" -ge 1 ]; then
        log_info "  Deployment $deploy: $READY replica(s) ready"
    else
        log_error "  Deployment $deploy: not ready"
        kubectl describe deployment "$deploy" -n "${NAMESPACE}"
        exit 1
    fi
done

# Step 6: Create a self-signed ClusterIssuer
log_info "Creating self-signed ClusterIssuer..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

# Wait for the issuer to be ready
log_info "Waiting for ClusterIssuer to be ready..."
for i in $(seq 1 30); do
    READY=$(kubectl get clusterissuer selfsigned-issuer -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [ "$READY" = "True" ]; then
        log_info "  ClusterIssuer is ready"
        break
    fi
    if [ "$i" -eq 30 ]; then
        log_error "  ClusterIssuer not ready after 30 seconds"
        kubectl describe clusterissuer selfsigned-issuer
        exit 1
    fi
    sleep 1
done

# Step 7: Issue a test certificate
log_info "Creating test namespace and certificate..."
kubectl create namespace cert-test

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: cert-test
spec:
  secretName: test-cert-tls
  duration: 2160h  # 90 days
  renewBefore: 360h  # 15 days
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: test.example.com
  dnsNames:
    - test.example.com
    - www.test.example.com
EOF

log_info "Waiting for certificate to be issued..."
for i in $(seq 1 60); do
    READY=$(kubectl get certificate test-cert -n cert-test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [ "$READY" = "True" ]; then
        log_info "  Certificate issued successfully!"
        break
    fi
    if [ "$i" -eq 60 ]; then
        log_error "  Certificate not issued after 60 seconds"
        kubectl describe certificate test-cert -n cert-test
        kubectl describe certificaterequest -n cert-test
        exit 1
    fi
    sleep 1
done

# Step 8: Verify the TLS secret was created
log_info "Verifying TLS secret..."
if kubectl get secret test-cert-tls -n cert-test &>/dev/null; then
    TLS_CRT=$(kubectl get secret test-cert-tls -n cert-test -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject 2>/dev/null || echo "unable to parse")
    log_info "  TLS secret exists, subject: $TLS_CRT"
else
    log_error "  TLS secret 'test-cert-tls' not found"
    exit 1
fi

# Step 9: Test CA issuer chain (create a CA and issue from it)
log_info "Testing CA issuer chain..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca-cert
  namespace: cert-test
spec:
  isCA: true
  secretName: ca-cert-tls
  commonName: Test CA
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ca-issuer
  namespace: cert-test
spec:
  ca:
    secretName: ca-cert-tls
EOF

# Wait for CA cert and issuer
for i in $(seq 1 60); do
    CA_READY=$(kubectl get certificate ca-cert -n cert-test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [ "$CA_READY" = "True" ]; then
        break
    fi
    if [ "$i" -eq 60 ]; then
        log_error "  CA certificate not ready after 60 seconds"
        exit 1
    fi
    sleep 1
done

for i in $(seq 1 30); do
    ISSUER_READY=$(kubectl get issuer ca-issuer -n cert-test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [ "$ISSUER_READY" = "True" ]; then
        log_info "  CA Issuer is ready"
        break
    fi
    if [ "$i" -eq 30 ]; then
        log_error "  CA Issuer not ready after 30 seconds"
        exit 1
    fi
    sleep 1
done

# Issue a certificate from the CA issuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca-signed-cert
  namespace: cert-test
spec:
  secretName: ca-signed-cert-tls
  issuerRef:
    name: ca-issuer
    kind: Issuer
  commonName: app.test.example.com
  dnsNames:
    - app.test.example.com
EOF

for i in $(seq 1 60); do
    SIGNED_READY=$(kubectl get certificate ca-signed-cert -n cert-test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [ "$SIGNED_READY" = "True" ]; then
        log_info "  CA-signed certificate issued successfully!"
        break
    fi
    if [ "$i" -eq 60 ]; then
        log_error "  CA-signed certificate not issued after 60 seconds"
        kubectl describe certificate ca-signed-cert -n cert-test
        exit 1
    fi
    sleep 1
done

# Summary
echo ""
log_info "=== Test Summary ==="
log_info "CRDs:              $(kubectl get crd | grep -c cert-manager) cert-manager CRDs installed"
log_info "Pods:              $(kubectl get pods -n ${NAMESPACE} --no-headers | grep -c Running) running"
log_info "ClusterIssuers:    $(kubectl get clusterissuer --no-headers 2>/dev/null | wc -l) configured"
log_info "Issuers:           $(kubectl get issuer -A --no-headers 2>/dev/null | wc -l) configured"
log_info "Certificates:      $(kubectl get certificate -A --no-headers 2>/dev/null | wc -l) issued"
log_info "TLS Secrets:       $(kubectl get secrets -n cert-test --field-selector type=kubernetes.io/tls --no-headers 2>/dev/null | wc -l) created"
echo ""
log_info "=== All minimal tests passed! ==="
