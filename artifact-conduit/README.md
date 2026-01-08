# Artifact Conduit (ARC) OCM Component

This directory contains the OCM (Open Component Model) packaging for [Artifact Conduit (ARC)](https://github.com/opendefensecloud/artifact-conduit), an open-source system that acts as a gateway for procuring various artifact types and transferring them across security zones while ensuring policy compliance through automated scanning and validation.

## Architecture

ARC consists of three main components:

1. **API Server**: Extension API server providing custom resources for artifact management
2. **Controller Manager**: Reconciles Order and ArtifactWorkflow resources to orchestrate artifact transfers
3. **etcd**: Dedicated storage backend for the API server

## Component Structure

```
artifact-conduit/
├── bootstrap.yaml                    # KRO bootstrap configuration
├── component-constructor.yaml        # OCM component descriptor
├── rgd-template.yaml                 # ResourceGraphDefinition for KRO
└── configs/
    ├── minimal/                      # Minimal configuration profile
    │   └── values.yaml
    └── production/                   # Production HA configuration profile
        └── values.yaml
```

## Prerequisites

### Required
- **Kubernetes**: 1.28 or later
- **Helm**: 3.8 or later
- **cert-manager**: For TLS certificate management
- **Argo Workflows**: For artifact processing workflows

### Optional 
- **KRO (Kubernetes Resource Orchestrator)**: For RGD-based bootstrapping
- **OCM K8s Toolkit**: For OCM-based deployment
- **FluxCD**: For GitOps-style deployments
- **Prometheus Operator**: For metrics collection (production)

## Deployment via KRO Bootstrap (Recommended for OCM)

This approach uses the ResourceGraphDefinition pattern for self-contained deployment with automatic image localization.

1. **Install prerequisites**:
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Install KRO
kubectl apply -f https://github.com/kro-run/kro/releases/latest/download/kro.yaml

# Install OCM K8s Toolkit
kubectl apply -f https://github.com/open-component-model/ocm-k8s-toolkit/releases/latest/download/install.yaml

# Install Argo Workflows
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml
```

2. **Apply bootstrap configuration**:
```bash
# Edit bootstrap.yaml to set your registry URL
kubectl apply -f bootstrap.yaml
```

3. **Verify deployment**:
```bash
# Check RGD is created
kubectl get rgd

# Check custom CRD exists
kubectl get crd artifactconduitbootstraps.kro.run

# Check bootstrap instance status
kubectl get artifactconduitbootstrap -A

# Check ARC components
kubectl get pods -n arc-system
```

### OCM Transfer to Air-Gapped Environment

For air-gapped or restricted environments:

1. **Create OCM component archive**:
```bash
ocm add componentversion --create --file component-constructor.yaml .
ocm transfer componentarchive ./github.com/ocm/artifact-conduit \
  oci://your-registry.com/ocm-components \
  --copy-resources
```

2. **In air-gapped environment**, apply bootstrap with internal registry:
```bash
# Edit bootstrap.yaml to point to internal registry
sed -i 's|ghcr.io/your-org|your-internal-registry.com|g' bootstrap.yaml
kubectl apply -f bootstrap.yaml
```

## Configuration Profiles

All Helm values from the upstream chart can be overridden. See the ARC documentation or the charts `values.yaml` for details.

Two profiles exist to make getting started easier: Minimal and Production.

### Minimal Profile

Suitable for:
- Development environments
- Testing and evaluation
- Resource-constrained environments
- Non-HA scenarios

**Specifications**:
- Single replica for each component
- Minimal resource requests (50m CPU, 64Mi memory per component)
- 1Gi etcd storage
- Metrics disabled
- Self-signed certificates

**Resource Requirements**:
- Total CPU: ~150m (requests), ~500m (limits)
- Total Memory: ~160Mi (requests), ~320Mi (limits)
- Storage: 1Gi

### Production Profile

Suitable for:
- Production environments
- Mission-critical workloads
- High availability requirements
- Enterprise deployments

**Specifications**:
- 3 replicas for each component with pod anti-affinity
- Higher resource allocation (250m-1000m CPU, 256Mi-512Mi memory)
- 20Gi etcd storage with fast SSD recommended
- Metrics and Prometheus integration enabled
- Leader election enabled for controller
- Long-lived certificates (1 year duration)

**Resource Requirements**:
- Total CPU: ~700m (requests), ~3000m (limits)
- Total Memory: ~640Mi (requests), ~1280Mi (limits)
- Storage: 20Gi (fast SSD recommended)

## Monitoring and Observability

### Metrics (Production Profile)

When metrics are enabled, ARC exposes Prometheus-compatible metrics:

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n arc-system

# Query metrics directly
kubectl port-forward -n arc-system svc/arc-controller-metrics 8443:8443
curl -k https://localhost:8443/metrics
```
