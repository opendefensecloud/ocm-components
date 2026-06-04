#!/usr/bin/env bash
set -euo pipefail

# Argo Workflows Production Deployment Test
# Deploys argo-workflows on a multi-node kind cluster and verifies:
# HA replicas, PodDisruptionBudgets, pod distribution, and DAG workflow execution.

CLUSTER_NAME="${KIND_CLUSTER_NAME:-argo-workflows-prod-test}"
NAMESPACE="argo"
TIMEOUT="300s"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"

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

SKIP_CLEANUP=false
for arg in "$@"; do
    case $arg in
        --skip-cleanup) SKIP_CLEANUP=true ;;
    esac
done

if [ "$SKIP_CLEANUP" = false ]; then
    trap cleanup EXIT
fi

for cmd in kind kubectl helm; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "'$cmd' is required but not found in PATH"
        exit 1
    fi
done

log_info "=== Argo Workflows Production Deployment Test ==="

# Step 1: Create multi-node kind cluster
log_info "Creating multi-node kind cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_warn "Cluster '${CLUSTER_NAME}' already exists, deleting..."
    kind delete cluster --name "${CLUSTER_NAME}"
fi

cat <<'EOF' | kind create cluster --name "${CLUSTER_NAME}" --config=- --wait 60s
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
EOF

# Step 2: Install Argo Workflows with production values
log_info "Adding argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo

log_info "Installing argo-workflows with production values..."
helm install argo-workflows argo/argo-workflows \
    --version 1.0.14 \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values "${COMPONENT_DIR}/production-values.yaml" \
    --wait \
    --timeout "${TIMEOUT}"

# Step 3: Verify pods are ready
log_info "Waiting for all argo-workflows pods to be ready..."
kubectl wait --for=condition=Ready pods --all \
    -n "${NAMESPACE}" \
    --timeout="${TIMEOUT}"

log_info "Pod status:"
kubectl get pods -n "${NAMESPACE}" -o wide

# Step 4: Verify HA replica counts
log_info "Verifying HA replica counts..."
CONTROLLER_READY=$(kubectl get deployment argo-workflows-workflow-controller -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
SERVER_READY=$(kubectl get deployment argo-workflows-server -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

if [ "${CONTROLLER_READY:-0}" -ge 2 ]; then
    log_info "  workflow-controller: $CONTROLLER_READY replicas ready (>= 2 required)"
else
    log_error "  workflow-controller: only $CONTROLLER_READY replica(s) ready, expected >= 2"
    exit 1
fi

if [ "${SERVER_READY:-0}" -ge 2 ]; then
    log_info "  argo-server: $SERVER_READY replicas ready (>= 2 required)"
else
    log_error "  argo-server: only $SERVER_READY replica(s) ready, expected >= 2"
    exit 1
fi

# Step 5: Verify PodDisruptionBudgets exist
log_info "Verifying PodDisruptionBudgets..."
for pdb in $(kubectl get pdb -n "${NAMESPACE}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    log_info "  PDB found: $pdb"
done

PDB_COUNT=$(kubectl get pdb -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$PDB_COUNT" -ge 1 ]; then
    log_info "  $PDB_COUNT PodDisruptionBudget(s) configured"
else
    log_error "  No PodDisruptionBudgets found — production profile requires pdb.enabled: true"
    exit 1
fi

# Step 6: Verify pod spread across nodes
log_info "Checking pod distribution across nodes..."
CONTROLLER_NODES=$(kubectl get pods -n "${NAMESPACE}" -l app=workflow-controller \
    -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null | tr ' ' '\n' | sort -u | wc -l | tr -d ' ')
log_info "  Controller pods spread across $CONTROLLER_NODES unique node(s)"
if [ "${CONTROLLER_NODES:-0}" -lt 2 ]; then
    log_error "  Controller pods are only on $CONTROLLER_NODES node(s), expected >= 2 for HA"
    exit 1
fi

# Step 7: Submit a DAG workflow with parallel steps
log_info "Submitting DAG workflow with parallel steps..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: dag-parallel-test
  namespace: ${NAMESPACE}
spec:
  serviceAccountName: argo-workflow
  entrypoint: dag-pipeline
  templates:
    - name: dag-pipeline
      dag:
        tasks:
          - name: step-a
            template: echo-step
            arguments:
              parameters:
                - name: message
                  value: "Step A"
          - name: step-b
            template: echo-step
            arguments:
              parameters:
                - name: message
                  value: "Step B"
          - name: step-c
            template: echo-step
            dependencies:
              - step-a
              - step-b
            arguments:
              parameters:
                - name: message
                  value: "Step C (depends on A and B)"

    - name: echo-step
      inputs:
        parameters:
          - name: message
      container:
        image: busybox:1.36
        command: [sh, -c]
        args: ["echo '{{ inputs.parameters.message }}'"]
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
EOF

# Step 8: Wait for DAG workflow to succeed
log_info "Waiting for DAG workflow to complete..."
for i in $(seq 1 180); do
    PHASE=$(kubectl get workflow dag-parallel-test -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    case "$PHASE" in
        Succeeded)
            log_info "  DAG workflow completed successfully (phase: $PHASE)"
            break
            ;;
        Failed|Error)
            log_error "  DAG workflow failed (phase: $PHASE)"
            kubectl describe workflow dag-parallel-test -n "${NAMESPACE}"
            kubectl get pods -n "${NAMESPACE}" -l workflows.argoproj.io/workflow=dag-parallel-test -o wide
            exit 1
            ;;
    esac
    if [ "$i" -eq 180 ]; then
        log_error "  DAG workflow did not complete within 180 seconds (phase: ${PHASE:-unknown})"
        kubectl describe workflow dag-parallel-test -n "${NAMESPACE}"
        exit 1
    fi
    sleep 1
done

# Step 9: Verify DAG nodes all succeeded
log_info "Verifying all DAG nodes succeeded..."
FAILED_NODES=$(kubectl get workflow dag-parallel-test -n "${NAMESPACE}" \
    -o jsonpath='{.status.nodes[?(@.phase!="Succeeded")].displayName}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' || true)
if [ -z "$FAILED_NODES" ]; then
    log_info "  All DAG nodes succeeded"
else
    log_error "  Some DAG nodes did not succeed: $FAILED_NODES"
    exit 1
fi

# Summary
echo ""
log_info "=== Test Summary ==="
log_info "Controller replicas:  $CONTROLLER_READY ready"
log_info "Server replicas:      $SERVER_READY ready"
log_info "PodDisruptionBudgets: $PDB_COUNT configured"
log_info "Node spread:          Controller pods on $CONTROLLER_NODES node(s)"
log_info "DAG workflow:         Succeeded (3 steps: A, B, C)"
echo ""
log_info "=== All production tests passed! ==="
