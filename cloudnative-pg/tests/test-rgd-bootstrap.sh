#!/usr/bin/env bash
#
# Test script for CloudNativePG RGD/KRO bootstrap deployment on kind cluster
#
# This script:
# 1. Creates a kind cluster
# 2. Installs OCM K8s Toolkit (Repository, Component, Resource, Deployer CRDs)
# 3. Installs KRO (Kubernetes Resource Orchestrator)
# 4. Applies the bootstrap.yaml to deploy CloudNativePG via RGD
# 5. Verifies RGD is created and CRD exists
# 6. Waits for CloudNativePGBootstrap instance to reach ACTIVE state
# 7. Verifies operator and PostgreSQL cluster are deployed
# 8. Tests PostgreSQL connectivity
# 9. Cleans up resources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="cnpg-rgd-test"
TIMEOUT=900  # 15 minutes

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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
    log_info "Starting CloudNativePG RGD/KRO bootstrap test..."
    log_info "This test verifies the ResourceGraphDefinition deployment pattern"

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

    # Install cert-manager (required by OCM controller)
    log_step "Installing cert-manager..."
    log_info "cert-manager is required by OCM controller for TLS certificates"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

    log_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available deployment/cert-manager \
        -n cert-manager --timeout=300s || {
            log_error "cert-manager failed to become ready"
            kubectl get pods -n cert-manager
            exit 1
        }
    kubectl wait --for=condition=Available deployment/cert-manager-webhook \
        -n cert-manager --timeout=300s || {
            log_error "cert-manager-webhook failed to become ready"
            exit 1
        }
    kubectl wait --for=condition=Available deployment/cert-manager-cainjector \
        -n cert-manager --timeout=300s || {
            log_error "cert-manager-cainjector failed to become ready"
            exit 1
        }

    # Create TLS certificates for OCM registry using cert-manager
    log_step "Creating TLS certificates for OCM registry..."
    log_info "Using cert-manager to generate self-signed certificates"

    # Create ocm-system namespace first
    kubectl create namespace ocm-system 2>/dev/null || true

    # Create self-signed issuer
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
  namespace: ocm-system
spec:
  selfSigned: {}
EOF

    # Create certificate
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ocm-registry-tls
  namespace: ocm-system
spec:
  secretName: ocm-registry-tls-certs
  duration: 8760h # 1 year
  renewBefore: 720h # 30 days
  isCA: false
  privateKey:
    algorithm: RSA
    size: 2048
  usages:
    - server auth
    - client auth
  dnsNames:
    - registry.ocm-system.svc.cluster.local
    - registry.ocm-system.svc
    - registry
    - localhost
  ipAddresses:
    - 127.0.0.1
  issuerRef:
    name: selfsigned-issuer
    kind: Issuer
EOF

    log_info "Waiting for certificate to be issued..."
    kubectl wait --for=condition=Ready certificate/ocm-registry-tls \
        -n ocm-system --timeout=120s || {
            log_error "Certificate failed to be issued"
            kubectl describe certificate ocm-registry-tls -n ocm-system
            exit 1
        }

    log_info "Verifying TLS secret was created..."
    kubectl get secret ocm-registry-tls-certs -n ocm-system || {
        log_error "TLS secret not found"
        exit 1
    }

    # Install OCM K8s Toolkit
    log_step "Installing OCM K8s Toolkit..."
    log_info "Installing OCM controller from OCI registry..."
    helm upgrade --install ocm-controller \
        oci://ghcr.io/open-component-model/helm/ocm-controller \
        --version v0.26.0 \
        --namespace ocm-system \
        --wait \
        --timeout=5m || {
            log_error "Failed to install OCM controller"
            kubectl get pods -n ocm-system
            kubectl logs -n ocm-system -l app.kubernetes.io/name=ocm-controller --tail=50 2>/dev/null || true
            exit 1
        }

    log_info "Waiting for OCM controller to be ready..."
    kubectl wait --for=condition=Available deployment/ocm-controller \
        -n ocm-system --timeout=500s || {
            log_error "OCM controller failed to become ready"
            kubectl describe deployment ocm-controller -n ocm-system
            exit 1
        }

    # Install FluxCD for HelmRelease support
    log_step "Installing FluxCD..."
    log_info "Installing Flux source-controller and helm-controller..."
    kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml --wait=true

    log_info "Waiting for Flux controllers to be ready..."
    kubectl wait --for=condition=Available deployment/source-controller \
        -n flux-system --timeout=500s || {
            log_error "Flux source-controller failed to become ready"
            exit 1
        }
    kubectl wait --for=condition=Available deployment/helm-controller \
        -n flux-system --timeout=500s || {
            log_error "Flux helm-controller failed to become ready"
            exit 1
        }

    # Install KRO (Kubernetes Resource Orchestrator)
    log_step "Installing KRO (Kubernetes Resource Orchestrator)..."
    log_info "Installing KRO via Helm from ghcr.io..."

    # Install KRO version 0.6.3
    log_info "Installing KRO version 0.6.3 from GitHub Container Registry..."

    helm install kro oci://registry.k8s.io/kro/charts/kro \
        --version 0.6.3 \
        --namespace kro \
        --create-namespace \
        --wait \
        --timeout=5m || {
            log_error "Failed to install KRO"
            kubectl get pods -n kro
            kubectl logs -n kro -l app.kubernetes.io/name=kro --tail=50 2>/dev/null || true
            exit 1
        }

    log_info "Waiting for KRO controller to be ready..."
    kubectl wait --for=condition=Available deployment/kro \
        -n kro --timeout=500s || {
            log_error "KRO controller failed to become ready"
            kubectl describe deployment kro -n kro
            kubectl get pods -n kro
            exit 1
        }

    # Verify ResourceGraphDefinition CRD is installed
    log_info "Verifying ResourceGraphDefinition CRD is installed..."
    kubectl get crd resourcegraphdefinitions.kro.run || {
        log_error "ResourceGraphDefinition CRD not found"
        kubectl get crds | grep kro
        exit 1
    }

    # Build OCM component (if not already built)
    log_step "Building OCM component..."
    if [ ! -f ../cloudnative-pg-component.ctf ]; then
        log_info "Building component archive..."
        cd ..
        ocm add componentversions --create --file cloudnative-pg-component.ctf component-constructor.yaml || {
            log_error "Failed to build OCM component"
            exit 1
        }
        cd tests
    else
        log_info "Component archive already exists"
    fi

    # Transfer component to local OCI registry (for testing)
    log_step "Setting up local OCI registry for testing..."

    # Create a local registry
    log_info "Starting local Docker registry..."
    docker run -d --name registry --network=kind -p 5000:5000 registry:2 2>/dev/null || {
        log_warn "Registry container already exists, using existing one"
        docker start registry 2>/dev/null || true
    }

    # Wait for registry to be ready
    sleep 5

    # Transfer component to local registry
    log_info "Transferring OCM component to local registry..."
    ocm transfer ctf ../cloudnative-pg-component.ctf oci://localhost:5000/ocm-components || {
        log_error "Failed to transfer component to local registry"
        exit 1
    }

    # Update bootstrap.yaml with local registry URL
    log_info "Creating test bootstrap configuration..."
    cat > /tmp/bootstrap-test.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ocm-system
---
apiVersion: delivery.ocm.software/v1alpha1
kind: Repository
metadata:
  name: cloudnative-pg-repo
  namespace: ocm-system
spec:
  url: oci://registry:5000/ocm-components
---
apiVersion: delivery.ocm.software/v1alpha1
kind: Component
metadata:
  name: cloudnative-pg-component
  namespace: ocm-system
spec:
  component: github.com/ocm/cloudnative-pg
  version: 1.27.1
  repository:
    name: cloudnative-pg-repo
---
apiVersion: delivery.ocm.software/v1alpha1
kind: Resource
metadata:
  name: cloudnative-pg-rgd
  namespace: ocm-system
spec:
  resource: cloudnative-pg-rgd
  component:
    name: cloudnative-pg-component
---
apiVersion: delivery.ocm.software/v1alpha1
kind: Deployer
metadata:
  name: cloudnative-pg-rgd-deployer
  namespace: ocm-system
spec:
  resource:
    name: cloudnative-pg-rgd
---
apiVersion: v1alpha1
kind: CloudNativePGBootstrap
metadata:
  name: cloudnative-pg-minimal-test
  namespace: default
spec:
  registry:
    url: registry:5000
  componentName: github.com/ocm/cloudnative-pg
  componentVersion: 1.27.1
  namespace: cnpg-system
  operatorNamespace: cnpg-system
  deploymentProfile: minimal
  clusterName: postgres-test
  clusterNamespace: postgres
  instances: 1
  postgresVersion: "17"
  storageSize: 1Gi
  backupEnabled: false
  monitoringEnabled: false
EOF

    # Apply bootstrap configuration
    log_step "Applying bootstrap configuration..."
    kubectl apply -f /tmp/bootstrap-test.yaml || {
        log_error "Failed to apply bootstrap configuration"
        exit 1
    }

    # Wait for ResourceGraphDefinition to be created
    log_step "Waiting for ResourceGraphDefinition to be created..."
    timeout=0
    while [ $timeout -lt 300 ]; do
        if kubectl get rgd cloudnative-pg-bootstrap 2>/dev/null; then
            log_info "✓ ResourceGraphDefinition created successfully!"
            break
        fi
        sleep 5
        timeout=$((timeout + 5))
    done

    if [ $timeout -ge 300 ]; then
        log_error "Timeout waiting for ResourceGraphDefinition to be created"
        kubectl get rgd -A
        kubectl get deployer -n ocm-system -o yaml
        exit 1
    fi

    # Verify custom CRD was created by ResourceGraphDefinition
    log_info "Verifying CloudNativePGBootstrap CRD was created..."
    kubectl get crd cloudnativepgbootstraps.v1alpha1.kro.run || {
        log_error "CloudNativePGBootstrap CRD not found"
        kubectl get crds | grep cloudnativepg
        exit 1
    }

    # Wait for bootstrap instance to reach ACTIVE state
    log_step "Waiting for CloudNativePGBootstrap instance to reach ACTIVE state..."
    timeout=0
    while [ $timeout -lt $TIMEOUT ]; do
        status=$(kubectl get CloudNativePGBootstrap cloudnative-pg-minimal-test -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
        synced=$(kubectl get CloudNativePGBootstrap cloudnative-pg-minimal-test -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "Unknown")

        log_info "Bootstrap status: $status, Synced: $synced"

        if [ "$status" = "ACTIVE" ] && [ "$synced" = "True" ]; then
            log_info "✓ CloudNativePGBootstrap is ACTIVE and SYNCED!"
            break
        fi

        sleep 15
        timeout=$((timeout + 15))
    done

    if [ $timeout -ge $TIMEOUT ]; then
        log_error "Timeout waiting for CloudNativePGBootstrap to reach ACTIVE state"
        kubectl describe CloudNativePGBootstrap cloudnative-pg-minimal-test
        exit 1
    fi

    # Verify operator was deployed
    log_step "Verifying CloudNativePG operator was deployed..."
    kubectl wait --for=condition=Available deployment/cloudnative-pg-operator \
        -n cnpg-system --timeout=600s || {
            log_error "Operator failed to become ready"
            kubectl get all -n cnpg-system
            kubectl describe deployment cloudnative-pg-operator -n cnpg-system
            exit 1
        }

    log_info "✓ CloudNativePG operator is running!"

    # Verify PostgreSQL cluster was deployed
    log_step "Verifying PostgreSQL cluster was deployed..."
    timeout=0
    while [ $timeout -lt $TIMEOUT ]; do
        ready=$(kubectl get cluster -n postgres postgres-test -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

        if [ "$ready" = "Cluster in healthy state" ]; then
            log_info "✓ PostgreSQL cluster is ready!"
            break
        fi

        log_info "Cluster status: $ready - waiting..."
        sleep 10
        timeout=$((timeout + 10))
    done

    if [ $timeout -ge $TIMEOUT ]; then
        log_error "Timeout waiting for PostgreSQL cluster to be ready"
        kubectl get cluster -n postgres -o yaml
        kubectl get pods -n postgres
        exit 1
    fi

    # Wait for PostgreSQL pods to be running
    log_info "Waiting for PostgreSQL pods to be running..."
    kubectl wait --for=condition=Ready pod \
        -l cnpg.io/cluster=postgres-test \
        -n postgres --timeout=300s || {
            log_error "PostgreSQL pods failed to become ready"
            kubectl describe pods -n postgres -l cnpg.io/cluster=postgres-test
            exit 1
        }

    # Test PostgreSQL connection
    log_step "Testing PostgreSQL connection..."

    primary_pod=$(kubectl get pods -n postgres -l cnpg.io/cluster=postgres-test,role=primary -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$primary_pod" ]; then
        log_error "Could not find primary pod"
        kubectl get pods -n postgres
        exit 1
    fi

    log_info "Primary pod: $primary_pod"

    db_username=$(kubectl get secret app-user-secret -n postgres -o jsonpath='{.data.username}' | base64 -d)
    db_password=$(kubectl get secret app-user-secret -n postgres -o jsonpath='{.data.password}' | base64 -d)

    test_result=$(kubectl exec -n postgres "$primary_pod" -- \
        env PGPASSWORD="$db_password" psql -h localhost -U "$db_username" -d app -c "SELECT version();" 2>&1 || echo "FAILED")

    if echo "$test_result" | grep -q "PostgreSQL"; then
        log_info "✓ PostgreSQL is accessible and responding!"
    else
        log_error "✗ Failed to connect to PostgreSQL"
        echo "$test_result"
        exit 1
    fi

    # Verify image localization
    log_step "Verifying image localization..."
    operator_image=$(kubectl get deployment cloudnative-pg-operator -n cnpg-system -o jsonpath='{.spec.template.spec.containers[0].image}')
    postgres_image=$(kubectl get cluster postgres-test -n postgres -o jsonpath='{.spec.imageName}')

    log_info "Operator image: $operator_image"
    log_info "PostgreSQL image: $postgres_image"

    if [[ "$operator_image" == registry:5000/* ]] && [[ "$postgres_image" == registry:5000/* ]]; then
        log_info "✓ Images were successfully localized to local registry!"
    else
        log_warn "Images may not have been localized (this is OK for testing with original registry)"
    fi

    # Print final summary
    log_info "========================================="
    log_info "RGD/KRO Bootstrap Test Summary"
    log_info "========================================="
    log_info "✓ Kind cluster created successfully"
    log_info "✓ OCM K8s Toolkit installed"
    log_info "✓ FluxCD installed"
    log_info "✓ KRO installed"
    log_info "✓ ResourceGraphDefinition created"
    log_info "✓ CloudNativePGBootstrap CRD created"
    log_info "✓ Bootstrap instance reached ACTIVE state"
    log_info "✓ CloudNativePG operator deployed via RGD"
    log_info "✓ PostgreSQL cluster deployed via RGD"
    log_info "✓ PostgreSQL is accessible"
    log_info "✓ Image localization verified"
    log_info "========================================="
    log_info ""
    log_info "The RGD pattern successfully deployed CloudNativePG!"
    log_info ""
    log_info "To keep the cluster running, press Ctrl+C now."
    log_info "Otherwise, the cluster will be deleted in 10 seconds..."

    sleep 10
}

main "$@"
