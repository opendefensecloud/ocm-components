#!/usr/bin/env bash
set -euo pipefail

# Argo Workflows Minimal Deployment Test
# Deploys argo-workflows on a local kind cluster and verifies:
# CRD creation, pod readiness, and successful workflow execution.

CLUSTER_NAME="${KIND_CLUSTER_NAME:-argo-workflows-test}"
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

log_info "=== Argo Workflows Minimal Deployment Test ==="

# Step 1: Create kind cluster
log_info "Creating kind cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_warn "Cluster '${CLUSTER_NAME}' already exists, deleting..."
    kind delete cluster --name "${CLUSTER_NAME}"
fi
kind create cluster --name "${CLUSTER_NAME}" --wait 60s

# Step 2: Install Argo Workflows via Helm
log_info "Adding argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo

log_info "Installing argo-workflows with minimal values..."
helm install argo-workflows argo/argo-workflows \
    --version 1.0.14 \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values "${COMPONENT_DIR}/minimal-values.yaml" \
    --wait \
    --timeout "${TIMEOUT}"

# Step 3: Verify CRDs
log_info "Verifying CRDs..."
EXPECTED_CRDS=(
    "workflows.argoproj.io"
    "workflowtemplates.argoproj.io"
    "clusterworkflowtemplates.argoproj.io"
    "cronworkflows.argoproj.io"
    "workflowartifactgctasks.argoproj.io"
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
log_info "Waiting for all argo-workflows pods to be ready..."
kubectl wait --for=condition=Ready pods --all \
    -n "${NAMESPACE}" \
    --timeout="${TIMEOUT}"

log_info "Pod status:"
kubectl get pods -n "${NAMESPACE}" -o wide

# Step 5: Verify deployments
log_info "Checking deployments..."
for deploy in argo-workflows-workflow-controller argo-workflows-server; do
    READY=$(kubectl get deployment "$deploy" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "${READY:-0}" -ge 1 ]; then
        log_info "  Deployment $deploy: $READY replica(s) ready"
    else
        log_error "  Deployment $deploy: not ready"
        kubectl describe deployment "$deploy" -n "${NAMESPACE}"
        exit 1
    fi
done

# Step 6: Submit a hello-world workflow
log_info "Submitting hello-world workflow..."
kubectl apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: hello-world
  namespace: argo
spec:
  serviceAccountName: argo-workflow
  entrypoint: hello
  templates:
    - name: hello
      container:
        image: busybox:1.36
        command: [sh, -c]
        args: ["echo 'Hello from Argo Workflows!'"]
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
EOF

# Step 7: Wait for workflow to succeed
log_info "Waiting for workflow to complete..."
for i in $(seq 1 120); do
    PHASE=$(kubectl get workflow hello-world -n argo -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    case "$PHASE" in
        Succeeded)
            log_info "  Workflow completed successfully (phase: $PHASE)"
            break
            ;;
        Failed|Error)
            log_error "  Workflow failed (phase: $PHASE)"
            kubectl describe workflow hello-world -n argo
            kubectl get pods -n argo -l workflows.argoproj.io/workflow=hello-world -o wide
            exit 1
            ;;
    esac
    if [ "$i" -eq 120 ]; then
        log_error "  Workflow did not complete within 120 seconds (phase: ${PHASE:-unknown})"
        kubectl describe workflow hello-world -n argo
        exit 1
    fi
    sleep 1
done

# Step 8: Verify workflow pod logs
log_info "Checking workflow pod logs..."
WORKFLOW_POD=$(kubectl get pods -n argo -l workflows.argoproj.io/workflow=hello-world -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$WORKFLOW_POD" ]; then
    LOGS=$(kubectl logs "$WORKFLOW_POD" -n argo -c main 2>/dev/null || echo "")
    if echo "$LOGS" | grep -q "Hello from Argo Workflows"; then
        log_info "  Workflow logs verified: output found"
    else
        log_warn "  Could not verify workflow output in logs (pod may have been cleaned up)"
    fi
fi

# Summary
echo ""
log_info "=== Test Summary ==="
log_info "CRDs:       ${#EXPECTED_CRDS[@]} argo-workflows CRDs installed"
log_info "Pods:       $(kubectl get pods -n ${NAMESPACE} --no-headers | grep -c Running) running"
log_info "Workflows:  $(kubectl get workflows -n argo --no-headers 2>/dev/null | wc -l | tr -d ' ') completed"
echo ""
log_info "=== All minimal tests passed! ==="
