#!/usr/bin/env bash
#
# Test script for minimal CloudNativePG deployment on kind cluster
#
# This script:
# 1. Creates a kind cluster
# 2. Installs the CloudNativePG operator
# 3. Deploys minimal PostgreSQL cluster
# 4. Waits for cluster to be ready
# 5. Verifies PostgreSQL is accessible
# 6. Cleans up resources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="cnpg-test"
NAMESPACE="postgres"
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

cleanup() {
    log_info "Cleaning up resources..."
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
}

# Trap errors and cleanup
trap cleanup EXIT

# Main test flow
main() {
    log_info "Starting CloudNativePG minimal configuration test..."

    # Check prerequisites
    log_info "Checking prerequisites..."
    command -v kind >/dev/null 2>&1 || { log_error "kind is not installed. Please install kind first."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is not installed. Please install kubectl first."; exit 1; }

    # Create kind cluster
    log_info "Creating kind cluster: $CLUSTER_NAME"
    kind create cluster --name "$CLUSTER_NAME"

    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s

    log_info "Note: Container images will be pulled by kind (this may take several minutes on first run)"

    # Install CloudNativePG operator
    log_info "Installing CloudNativePG operator..."
    kubectl apply --server-side -f ../operator/cnpg-operator.yml

    # Wait for operator to be ready (may take a while to pull image)
    log_info "Waiting for operator to be ready (pulling images may take several minutes)..."
    kubectl wait --for=condition=Available deployment/cnpg-controller-manager \
      -n cnpg-system --timeout=600s || {
        log_error "Operator failed to become ready"
        kubectl describe deployment cnpg-controller-manager -n cnpg-system
        kubectl get pods -n cnpg-system
        kubectl describe pods -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
        kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --tail=100 2>&1 || true
        exit 1
    }

    # Deploy minimal PostgreSQL cluster
    log_info "Deploying minimal PostgreSQL cluster..."
    kubectl apply -f ../configs/minimal/cluster.yaml

    # Wait for cluster to be ready
    log_info "Waiting for PostgreSQL cluster to be ready (this may take several minutes)..."

    timeout=0
    while [ $timeout -lt $TIMEOUT ]; do
        # Check if cluster is ready
        ready=$(kubectl get cluster -n "$NAMESPACE" postgres-minimal -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

        if [ "$ready" = "Cluster in healthy state" ]; then
            log_info "PostgreSQL cluster is ready!"
            break
        fi

        log_info "Cluster status: $ready - waiting..."
        sleep 10
        timeout=$((timeout + 10))
    done

    if [ $timeout -ge $TIMEOUT ]; then
        log_error "Timeout waiting for PostgreSQL cluster to be ready"
        kubectl get cluster -n "$NAMESPACE" -o yaml
        kubectl get pods -n "$NAMESPACE"
        kubectl logs -n "$NAMESPACE" -l cnpg.io/cluster=postgres-minimal --tail=100
        exit 1
    fi

    # Wait for pods to be running
    log_info "Waiting for PostgreSQL pods to be running..."
    kubectl wait --for=condition=Ready pod \
      -l cnpg.io/cluster=postgres-minimal \
      -n "$NAMESPACE" --timeout=180s || {
        log_error "PostgreSQL pods failed to become ready"
        kubectl describe pods -n "$NAMESPACE" -l cnpg.io/cluster=postgres-minimal
        exit 1
    }

    # Get connection credentials
    log_info "Retrieving database credentials..."
    db_username=$(kubectl get secret app-user-secret -n "$NAMESPACE" -o jsonpath='{.data.username}' | base64 -d)
    db_password=$(kubectl get secret app-user-secret -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)

    log_info "Database credentials:"
    log_info "  Username: $db_username"
    log_info "  Password: $db_password"
    log_info "  Database: app"

    # Test PostgreSQL connection
    log_info "Testing PostgreSQL connection..."

    # Get primary pod name
    primary_pod=$(kubectl get pods -n "$NAMESPACE" -l cnpg.io/cluster=postgres-minimal,role=primary -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$primary_pod" ]; then
        log_error "Could not find primary pod"
        kubectl get pods -n "$NAMESPACE" -l cnpg.io/cluster=postgres-minimal
        exit 1
    fi

    log_info "Primary pod: $primary_pod"

    # Test database connection
    log_info "Executing test query..."
    test_result=$(kubectl exec -n "$NAMESPACE" "$primary_pod" -- \
      psql -U "$db_username" -d app -c "SELECT version();" 2>&1 || echo "FAILED")

    if echo "$test_result" | grep -q "PostgreSQL"; then
        log_info "✓ PostgreSQL is accessible and responding!"
        echo "$test_result" | grep "PostgreSQL"
    else
        log_error "✗ Failed to connect to PostgreSQL"
        echo "$test_result"
        exit 1
    fi

    # Test write operation
    log_info "Testing write operations..."
    kubectl exec -n "$NAMESPACE" "$primary_pod" -- \
      psql -U "$db_username" -d app -c \
      "CREATE TABLE IF NOT EXISTS test_table (id serial PRIMARY KEY, data text);" >/dev/null

    kubectl exec -n "$NAMESPACE" "$primary_pod" -- \
      psql -U "$db_username" -d app -c \
      "INSERT INTO test_table (data) VALUES ('test data');" >/dev/null

    row_count=$(kubectl exec -n "$NAMESPACE" "$primary_pod" -- \
      psql -U "$db_username" -d app -t -c \
      "SELECT COUNT(*) FROM test_table;" | tr -d ' ')

    if [ "$row_count" -ge 1 ]; then
        log_info "✓ Write operations successful!"
    else
        log_error "✗ Write operations failed"
        exit 1
    fi

    # Print summary
    log_info "========================================="
    log_info "Test Summary"
    log_info "========================================="
    log_info "✓ Kind cluster created successfully"
    log_info "✓ CloudNativePG operator installed"
    log_info "✓ PostgreSQL cluster deployed and running"
    log_info "✓ PostgreSQL is accessible"
    log_info "✓ Read/write operations successful"
    log_info "========================================="
    log_info ""
    log_info "Connection details:"
    log_info "  Service: postgres-minimal-rw.$NAMESPACE.svc.cluster.local:5432"
    log_info "  Database: app"
    log_info "  Username: $db_username"
    log_info "  Password: $db_password"
    log_info ""
    log_info "To connect from your local machine:"
    log_info "  kubectl port-forward -n $NAMESPACE svc/postgres-minimal-rw 5432:5432"
    log_info "  psql postgresql://$db_username:$db_password@localhost:5432/app"
    log_info ""
    log_info "To keep the cluster running, press Ctrl+C now."
    log_info "Otherwise, the cluster will be deleted in 10 seconds..."

    sleep 10
}

main "$@"
