# OCM Monorepo

A monorepo for packaging cloud-native applications as OCM (Open Component Model) components.

## Overview

This repository packages various cloud-native applications as OCM components, including operators, Helm charts, container images, and extensive configuration options. Each directory represents a single cloud-native application packaged for deployment in Kubernetes environments.

### Component Architecture

Components can reference each other to fulfill dependencies rather than duplicating resources. For example, the Keycloak component can reference the CloudNativePG component for its database requirements instead of bundling a database solution directly.

## Available Components

### Keycloak (v26.4.5)

Identity and Access Management

- **Status**: ✅ Ready
- **Operator**: Official Keycloak Operator (Quarkus-based)
- **License**: Apache 2.0
- **Configurations**:
  - Minimal (dev/test with ephemeral PostgreSQL)
  - Production (HA with 3 replicas, external database)
- **Documentation**: [keycloak/README.md](keycloak/README.md)
- **Dependencies**: PostgreSQL (CloudNativePG recommended for production)

Quick Start:

```bash
# Install operator
kubectl apply -f keycloak/operator/keycloaks-crd.yml
kubectl apply -f keycloak/operator/keycloakrealmimports-crd.yml
kubectl apply -f keycloak/operator/operator.yml

# Deploy minimal config
kubectl apply -f keycloak/configs/minimal/keycloak.yml
```

### CloudNativePG (v1.27.1)

PostgreSQL Operator for Kubernetes

- **Status**: ✅ Ready
- **Operator**: Official CloudNativePG Operator
- **License**: Apache 2.0
- **CNCF**: Sandbox Project
- **Configurations**:
  - Minimal (single instance for dev/test)
  - Production (HA with 3 replicas, backups, monitoring)
- **Documentation**: [cloudnative-pg/README.md](cloudnative-pg/README.md)
- **Features**: Streaming replication, automated backups, PITR, PgBouncer pooling

Quick Start:

```bash
# Install operator via Helm
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system --create-namespace --wait

# Deploy minimal cluster
kubectl apply -f cloudnative-pg/cluster-minimal.yaml
```

### Artifact Conduit (ARC) (v0.1.0)

Kubernetes-native Artifact Gateway for Secure Cross-Zone Transfers

- **Status**: ⚠️ Early Stage (Pre-release)
- **License**: Apache 2.0
- **Configurations**:
  - Minimal (single instance for dev/test)
  - Production (HA with 3 replicas, metrics enabled)
- **Documentation**: [artifact-conduit/README.md](artifact-conduit/README.md)
- **Dependencies**: cert-manager (required), Argo Workflows (required)
- **Features**: Multi-source artifact procurement (OCI, Helm, S3, HTTP), security validation (CVE scanning, malware detection, license checks), policy enforcement, audit trails

Quick Start:

```bash
# Install prerequisites
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml

# Install with Helm
helm install artifact-conduit artifact-conduit/arc-0.1.0.tgz \
  --namespace arc-system \
  --create-namespace \
  --values artifact-conduit/minimal-values.yaml
```

**Note**: Artifact Conduit is an early-stage project (356+ commits, 8 contributors) not yet recommended for production without thorough testing. It provides a declarative way to transfer artifacts across security boundaries with automated scanning and policy compliance.

## Suggested Components

The following are candidates for inclusion in this monorepo based on common dependencies and use cases:

- cert-manager (TLS certificate management)
- External Secrets Operator
- Prometheus Operator
- Traefik Ingress Controller

## Repository Structure

```text
ocm-components/
├── artifact-conduit/          # Artifact Conduit (ARC) component
│   ├── bootstrap.yaml         # KRO bootstrap configuration
│   ├── component-constructor.yaml
│   ├── rgd-template.yaml      # ResourceGraphDefinition for KRO
│   ├── minimal-values.yaml
│   └── production-values.yaml
├── cloudnative-pg/            # CloudNativePG component
│   ├── bootstrap.yaml
│   ├── component-constructor.yaml
│   ├── rgd-template.yaml
│   ├── cluster-minimal.yaml
│   └── cluster-production.yaml
├── keycloak/                  # Keycloak component
│   ├── operator/              # Operator manifests and CRDs
│   ├── configs/               # Configuration examples
│   │   ├── minimal/
│   │   └── production/
│   ├── component-constructor.yaml
│   └── README.md
├── .github/
│   └── workflows/             # CI/CD pipelines for releases
├── CLAUDE.md                  # Development guidelines
└── README.md                  # This file
```

## Working with OCM Components

### Building a Component

Each component can be built into a Common Transport Format (CTF) archive:

```bash
cd keycloak
ocm add componentversions --create --file ../keycloak-component.ctf component-constructor.yaml
```

### Transferring to Air-Gapped Environments

```bash
# Transfer to OCI registry
ocm transfer ctf keycloak-component.ctf oci://your-registry/ocm-components

# In air-gapped environment, pull from registry
ocm transfer oci://your-registry/ocm-components ctf keycloak-airgapped.ctf
```

### Creating Offline Packages

Each component has a GitHub Actions workflow that creates offline packages for air-gapped deployments. These are available in the Releases section.

## Development Guidelines

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines including:

- How to add new components
- Required configurations (minimal and production)
- Testing requirements
- Documentation standards
- Release pipeline requirements

## Contributing

When adding a new component:

1. Research official Helm charts and operators
2. Create component directory structure
3. Package operator manifests and CRDs
4. Create minimal and production configurations
5. Write comprehensive documentation
6. Create tests for deployment on kind cluster
7. Set up GitHub release pipeline
8. Update this README and suggested-components.md

## Requirements

- Kubernetes 1.24+
- kubectl
- OCM CLI (for building components)
- kind (for local testing)

## Testing

Tests are designed to run on local kind clusters and verify:

- Operator installation
- Component deployment
- Health checks
- Basic functionality

## Releases

Components are released independently using semantic versioning:

- **Component releases**: `<component-name>-v<version>` (e.g., `keycloak-v26.4.5`)
- Each release includes an offline package (tar.gz) with all manifests and images
- Checksums are provided for verification

## License

Individual components retain their original licenses (typically Apache 2.0). See each component's README for specific license information.

## Resources

- [Open Component Model Documentation](https://ocm.software/docs/)
- [OCM CLI Reference](https://ocm.software/docs/cli-reference/)
- [OCM Specification](https://github.com/open-component-model/ocm-spec)
