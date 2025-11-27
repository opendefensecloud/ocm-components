# Artifact Conduit (ARC) OCM Component

This directory contains the OCM (Open Component Model) packaging for [Artifact Conduit (ARC)](https://github.com/opendefensecloud/artifact-conduit), an open-source system that acts as a gateway for procuring various artifact types and transferring them across security zones while ensuring policy compliance through automated scanning and validation.

## Overview

**Artifact Conduit (ARC)** solves the problem of securely moving external resources (container images, Helm charts, packages) into restricted environments without direct internet access. It provides:

- **Artifact Procurement**: Pull artifacts from diverse sources including OCI registries, Helm repositories, S3-compatible storage, and HTTP endpoints
- **Security Validation**: Malware scanning, CVE analysis, license verification, and signature validation
- **Policy Enforcement**: Ensures only compliant artifacts cross security boundaries
- **Declarative Management**: Kubernetes-native configuration approach
- **Auditability**: Attestation and traceability of operations

## Architecture

ARC consists of three main components:

1. **API Server**: Extension API server providing custom resources for artifact management
2. **Controller Manager**: Reconciles Order and ArtifactWorkflow resources to orchestrate artifact transfers
3. **etcd**: Dedicated storage backend for the API server

## Component Structure

```
artifact-conduit/
├── arc-0.1.0.tgz                    # Packaged Helm chart
├── bootstrap.yaml                    # KRO bootstrap configuration
├── component-constructor.yaml        # OCM component descriptor
├── rgd-template.yaml                 # ResourceGraphDefinition for KRO
├── charts/
│   └── arc/                          # Unpacked Helm chart
├── configs/
│   ├── minimal/                      # Minimal configuration profile
│   │   └── values.yaml
│   └── production/                   # Production HA configuration profile
│       └── values.yaml
├── docs/                             # Documentation
├── examples/                         # Usage examples
├── operator/                         # Operator manifests (if needed)
└── tests/                            # Test scripts
    ├── test-minimal.sh               # Test minimal deployment
    └── test-rgd-bootstrap.sh         # Test RGD-based deployment
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

## Deployment Options

### Option 1: Direct Helm Installation (Simplest)

#### Minimal Configuration
```bash
helm install artifact-conduit ./arc-0.1.0.tgz \
  --namespace arc-system \
  --create-namespace \
  --values configs/minimal/values.yaml
```

#### Production Configuration
```bash
helm install artifact-conduit ./arc-0.1.0.tgz \
  --namespace arc-system \
  --create-namespace \
  --values configs/production/values.yaml
```

### Option 2: KRO Bootstrap (Recommended for OCM)

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

### Option 3: OCM Transfer to Air-Gapped Environment

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

## Configuration Options

All Helm values from the upstream chart can be overridden. Key configuration areas:

### API Server
- Replica count and resources
- Service type and ports
- Security contexts and probes
- Node affinity and tolerations

### Controller Manager
- Replica count and leader election
- Metrics and monitoring
- Health probe settings
- Custom command-line arguments

### etcd
- Replica count for HA
- Persistent storage size and class
- Resource limits
- Backup configuration (via additional manifests)

### cert-manager Integration
- Issuer type (self-signed, CA, ACME/Let's Encrypt)
- Certificate duration and renewal
- Custom certificate settings

See [docs/HELM_CHART_CONFIG.md](docs/HELM_CHART_CONFIG.md) for complete configuration reference.

## Usage Examples

### Creating an Artifact Order

Once ARC is deployed, you can create artifact orders using custom resources:

```yaml
apiVersion: arc.opendefense.cloud/v1alpha1
kind: Order
metadata:
  name: pull-nginx-image
  namespace: arc-system
spec:
  source:
    type: oci
    url: docker.io/library/nginx:latest
  destination:
    registry: your-internal-registry.com
    repository: nginx
    tag: latest
  policies:
    - type: cve-scan
      severity: high
    - type: license-check
      allowList: ["Apache-2.0", "MIT"]
```

### Configuring Artifact Workflows

Define workflows for complex artifact processing:

```yaml
apiVersion: arc.opendefense.cloud/v1alpha1
kind: ArtifactWorkflow
metadata:
  name: secure-image-transfer
  namespace: arc-system
spec:
  steps:
    - name: fetch
      type: pull
    - name: scan
      type: security-scan
    - name: sign
      type: signature
    - name: transfer
      type: push
  policies:
    enforce: true
```

See [examples/](examples/) directory for more usage examples.

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

### Health Checks

```bash
# Check API Server health
kubectl get apiservice v1alpha1.arc.opendefense.cloud

# Check Controller Manager
kubectl logs -n arc-system -l app.kubernetes.io/component=controller-manager

# Check etcd health
kubectl exec -n arc-system etcd-0 -- etcdctl endpoint health
```

## Testing

### Run Minimal Configuration Test
```bash
cd tests
./test-minimal.sh
```

### Run RGD Bootstrap Test
```bash
cd tests
./test-rgd-bootstrap.sh
```

Tests create a temporary kind cluster, deploy ARC, verify functionality, and clean up.

## Upgrading

### Helm Upgrade
```bash
helm upgrade artifact-conduit ./arc-0.1.0.tgz \
  --namespace arc-system \
  --values configs/production/values.yaml
```

### OCM Component Update
```bash
# Transfer newer version
ocm transfer component github.com/ocm/artifact-conduit:0.2.0 \
  oci://your-registry.com/ocm-components

# Update bootstrap.yaml with new version
# Re-apply bootstrap.yaml
```

## Troubleshooting

### API Server Not Ready
```bash
kubectl describe deployment -n arc-system arc-apiserver
kubectl logs -n arc-system -l app.kubernetes.io/component=apiserver
```

### Controller Manager Issues
```bash
kubectl logs -n arc-system -l app.kubernetes.io/component=controller-manager
kubectl describe pod -n arc-system -l app.kubernetes.io/component=controller-manager
```

### etcd Connection Problems
```bash
kubectl logs -n arc-system -l app.kubernetes.io/component=etcd
kubectl exec -n arc-system etcd-0 -- etcdctl member list
```

### Certificate Issues
```bash
kubectl get certificate -n arc-system
kubectl describe certificate -n arc-system
kubectl logs -n cert-manager -l app=cert-manager
```

## Security Considerations

### Network Policies
Consider implementing NetworkPolicies to restrict traffic:
- API Server: Only accessible from Kubernetes API aggregation layer
- Controller Manager: Internal communication only
- etcd: Only accessible from API Server

### RBAC
The component creates necessary RBAC resources automatically. Review and customize:
```bash
kubectl get clusterrole | grep arc
kubectl get clusterrolebinding | grep arc
```

### Image Security
- All images are pulled from official repositories
- Images can be scanned and signed before deployment
- Use private registry with image pull secrets for air-gapped environments

### Data Encryption
- etcd data is not encrypted by default
- Consider enabling etcd encryption at rest in production
- TLS enabled for all API communication via cert-manager

## Dependencies

### Argo Workflows Requirement

ARC requires Argo Workflows for executing artifact processing pipelines. The workflow engine orchestrates:
- Fetching artifacts from various sources
- Running security scans and validations
- Applying policies and transformations
- Publishing artifacts to destinations

**Installation**:
```bash
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml
```

**Note**: Argo Workflows is not packaged as a dependency to avoid duplication if it's already deployed in your cluster.

## Project Status

**Maturity**: Early-stage / Pre-release
- Version: 0.1.0 (no stable releases yet)
- Active development with 356+ commits
- 8 contributors, 20 open issues
- Not recommended for production without thorough testing

**License**: Apache-2.0

## Contributing

Artifact Conduit is an open-source project. To contribute:

1. Visit the [upstream repository](https://github.com/opendefensecloud/artifact-conduit)
2. Review the contribution guidelines
3. Submit issues or pull requests

## References

- [Artifact Conduit GitHub](https://github.com/opendefensecloud/artifact-conduit)
- [Artifact Conduit Documentation](https://arc.opendefense.cloud)
- [Open Component Model](https://ocm.software/)
- [KRO (Kubernetes Resource Orchestrator)](https://kro.run/)
- [Argo Workflows](https://argoproj.github.io/workflows/)
- [cert-manager](https://cert-manager.io/)

## Support

For issues specific to this OCM packaging, please file an issue in the monorepo.
For issues with Artifact Conduit itself, please file an issue in the [upstream repository](https://github.com/opendefensecloud/artifact-conduit/issues).
