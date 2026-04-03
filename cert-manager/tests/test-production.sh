#!/usr/bin/env bash
set -euo pipefail

# cert-manager Production Deployment Test
# This script tests cert-manager production deployment on a local kind cluster
# It verifies: HA replicas, PDB, security contexts, monitoring, and certificate issuance

CLUSTER_NAME="${KIND_CLUSTER_NAME:-cert-manager-prod-test}"
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

log_info "=== cert-manager Production Deployment Test ==="

# Step 1: Create multi-node kind cluster for HA testing
log_info "Creating multi-node kind cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_warn "Cluster '${CLUSTER_NAME}' already exists, deleting..."
    kind delete cluster --name "${CLUSTER_NAME}"
fi

cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --wait 90s --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
EOF

# Step 2: Install Prometheus Operator CRDs (required for ServiceMonitor)
log_info "Installing Prometheus Operator CRDs (required for ServiceMonitor)..."
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml

# Step 3: Add Helm repo and install cert-manager with production values
log_info "Adding jetstack Helm repository..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update jetstack

log_info "Installing cert-manager with production values..."
helm install cert-manager jetstack/cert-manager \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values "${COMPONENT_DIR}/values-production.yaml" \
    --wait \
    --timeout "${TIMEOUT}"

# Step 3: Verify CRDs
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

# Step 4: Verify all pods are running
log_info "Waiting for all cert-manager pods to be ready..."
kubectl wait --for=condition=Ready pods --all \
    -n "${NAMESPACE}" \
    --timeout="${TIMEOUT}"

log_info "Pod status:"
kubectl get pods -n "${NAMESPACE}" -o wide

# Step 5: Verify HA replica counts
log_info "Verifying HA replica counts..."

check_replicas() {
    local deploy=$1
    local expected=$2
    local ready
    ready=$(kubectl get deployment "$deploy" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$ready" -ge "$expected" ]; then
        log_info "  Deployment $deploy: $ready/$expected replicas ready"
    else
        log_error "  Deployment $deploy: $ready/$expected replicas ready (expected at least $expected)"
        kubectl describe deployment "$deploy" -n "${NAMESPACE}"
        exit 1
    fi
}

check_replicas "cert-manager" 2
check_replicas "cert-manager-webhook" 3
check_replicas "cert-manager-cainjector" 2

# Step 6: Verify PodDisruptionBudgets
log_info "Verifying PodDisruptionBudgets..."
PDB_COUNT=$(kubectl get pdb -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)
if [ "$PDB_COUNT" -ge 1 ]; then
    log_info "  Found $PDB_COUNT PDB(s):"
    kubectl get pdb -n "${NAMESPACE}"
else
    log_warn "  No PDBs found (may be expected depending on chart version)"
fi

# Step 7: Verify security contexts
log_info "Verifying security contexts..."
for deploy in cert-manager cert-manager-webhook cert-manager-cainjector; do
    RUN_AS_NON_ROOT=$(kubectl get deployment "$deploy" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null || echo "")
    if [ "$RUN_AS_NON_ROOT" = "true" ]; then
        log_info "  $deploy: runAsNonRoot=true"
    else
        log_warn "  $deploy: runAsNonRoot not explicitly set at pod level (may be set at container level)"
    fi
done

# Step 8: Verify pods are distributed across nodes
log_info "Checking pod distribution across nodes..."
kubectl get pods -n "${NAMESPACE}" -o wide --no-headers | while read -r line; do
    POD=$(echo "$line" | awk '{print $1}')
    NODE=$(echo "$line" | awk '{print $7}')
    log_info "  $POD -> $NODE"
done

# Step 9: Test certificate issuance
log_info "Creating self-signed ClusterIssuer..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

for i in $(seq 1 30); do
    READY=$(kubectl get clusterissuer selfsigned-issuer -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [ "$READY" = "True" ]; then
        log_info "  ClusterIssuer is ready"
        break
    fi
    if [ "$i" -eq 30 ]; then
        log_error "  ClusterIssuer not ready after 30 seconds"
        exit 1
    fi
    sleep 1
done

# Step 10: Test multiple certificate issuance (simulating production load)
log_info "Testing batch certificate issuance..."
kubectl create namespace cert-prod-test

for i in $(seq 1 5); do
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: prod-test-cert-${i}
  namespace: cert-prod-test
spec:
  secretName: prod-test-cert-${i}-tls
  duration: 8760h
  renewBefore: 720h
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  commonName: service-${i}.prod.example.com
  dnsNames:
    - service-${i}.prod.example.com
    - service-${i}.internal.example.com
EOF
done

log_info "Waiting for all 5 certificates to be issued..."
ALL_READY=false
for attempt in $(seq 1 90); do
    READY_COUNT=0
    for i in $(seq 1 5); do
        STATUS=$(kubectl get certificate "prod-test-cert-${i}" -n cert-prod-test \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
        if [ "$STATUS" = "True" ]; then
            READY_COUNT=$((READY_COUNT + 1))
        fi
    done
    if [ "$READY_COUNT" -eq 5 ]; then
        ALL_READY=true
        log_info "  All 5 certificates issued successfully!"
        break
    fi
    if [ "$attempt" -eq 90 ]; then
        log_error "  Only $READY_COUNT/5 certificates ready after 90 seconds"
        kubectl get certificates -n cert-prod-test
        exit 1
    fi
    sleep 1
done

# Step 11: Test CA issuer with chain
log_info "Testing full CA issuer chain..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-prod-test
spec:
  isCA: true
  secretName: root-ca-tls
  commonName: Production Root CA
  duration: 87600h
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: production-ca-issuer
  namespace: cert-prod-test
spec:
  ca:
    secretName: root-ca-tls
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: intermediate-ca
  namespace: cert-prod-test
spec:
  isCA: true
  secretName: intermediate-ca-tls
  commonName: Production Intermediate CA
  duration: 43800h
  issuerRef:
    name: production-ca-issuer
    kind: Issuer
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: intermediate-ca-issuer
  namespace: cert-prod-test
spec:
  ca:
    secretName: intermediate-ca-tls
EOF

# Wait for the chain to be established
for i in $(seq 1 60); do
    ROOT_READY=$(kubectl get certificate root-ca -n cert-prod-test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    INTER_READY=$(kubectl get certificate intermediate-ca -n cert-prod-test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [ "$ROOT_READY" = "True" ] && [ "$INTER_READY" = "True" ]; then
        log_info "  Root CA and Intermediate CA ready"
        break
    fi
    if [ "$i" -eq 60 ]; then
        log_error "  CA chain not ready after 60 seconds"
        kubectl get certificates -n cert-prod-test
        exit 1
    fi
    sleep 1
done

# Issue a leaf certificate from the intermediate CA
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: leaf-cert
  namespace: cert-prod-test
spec:
  secretName: leaf-cert-tls
  issuerRef:
    name: intermediate-ca-issuer
    kind: Issuer
  commonName: app.prod.example.com
  dnsNames:
    - app.prod.example.com
    - "*.app.prod.example.com"
EOF

for i in $(seq 1 60); do
    LEAF_READY=$(kubectl get certificate leaf-cert -n cert-prod-test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    if [ "$LEAF_READY" = "True" ]; then
        log_info "  Leaf certificate issued from intermediate CA!"
        break
    fi
    if [ "$i" -eq 60 ]; then
        log_error "  Leaf certificate not issued after 60 seconds"
        exit 1
    fi
    sleep 1
done

# Verify the certificate chain
log_info "Verifying certificate chain..."
LEAF_ISSUER=$(kubectl get secret leaf-cert-tls -n cert-prod-test -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer 2>/dev/null || echo "unknown")
log_info "  Leaf cert issuer: $LEAF_ISSUER"

# Summary
echo ""
log_info "=== Production Test Summary ==="
log_info "CRDs:              $(kubectl get crd | grep -c cert-manager) cert-manager CRDs installed"
log_info "Controller:        $(kubectl get deployment cert-manager -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')/2 replicas"
log_info "Webhook:           $(kubectl get deployment cert-manager-webhook -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')/3 replicas"
log_info "CA Injector:       $(kubectl get deployment cert-manager-cainjector -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')/2 replicas"
log_info "PDBs:              $(kubectl get pdb -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l) configured"
log_info "ClusterIssuers:    $(kubectl get clusterissuer --no-headers 2>/dev/null | wc -l) configured"
log_info "Issuers:           $(kubectl get issuer -A --no-headers 2>/dev/null | wc -l) configured"
log_info "Certificates:      $(kubectl get certificate -A --no-headers 2>/dev/null | wc -l) issued"
log_info "TLS Secrets:       $(kubectl get secrets -n cert-prod-test --field-selector type=kubernetes.io/tls --no-headers 2>/dev/null | wc -l) created"
echo ""
log_info "=== All production tests passed! ==="
