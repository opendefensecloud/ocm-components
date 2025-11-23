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

## Suggested Components

See [suggested-components.md](suggested-components.md) for a list of additional components that are candidates for inclusion in this monorepo based on common dependencies and use cases.

High Priority:

- CloudNativePG (PostgreSQL operator)
- cert-manager (TLS certificate management)
- External Secrets Operator
- Prometheus Operator
- Traefik Ingress Controller

## Repository Structure

```text
ocm-monorepo/
├── keycloak/                   # Keycloak component
│   ├── operator/              # Operator manifests and CRDs
│   ├── configs/               # Configuration examples
│   │   ├── minimal/          # Dev/test configuration
│   │   └── production/       # Production HA configuration
│   ├── tests/                # Test scripts
│   ├── component-constructor.yaml  # OCM component descriptor
│   └── README.md             # Component documentation
├── .github/
│   └── workflows/            # CI/CD pipelines for releases
├── suggested-components.md   # List of suggested components
├── CLAUDE.md                 # Development guidelines
└── README.md                 # This file
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

Each component includes test scripts for validation:

```bash
cd keycloak/tests
./test-minimal.sh
```

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
