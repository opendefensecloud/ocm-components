# Solution Arsenal Discovery (SolAr Discovery) OCM Component

This directory contains the OCM (Open Component Model) packaging for [SolAr Discovery](https://github.com/opendefensecloud/solution-arsenal), a standalone OCI registry scanner that discovers OCM packages and populates the Solution Arsenal catalog.

## Component structure

```
solution-arsenal-discovery/
├── component-constructor.yaml  # OCM component descriptor
├── minimal-values.yaml         # Helm values: single-instance dev/test profile
├── production-values.yaml      # Helm values: HA production profile
```

## Prerequisites

### Required
- **Kubernetes**
- **Helm**


## Quick start

### 1. Build the CTF archive

Run from the `solution-arsenal-discovery/` directory of this repo:

```bash
ocm add componentversion --version 0.1.0 --create --file ./ctf component-constructor.yaml
```

### 2. Transfer to a registry

```bash
# Public registry (replace with your org)
ocm transfer ctf --copy-local-resources ./ctf ghcr.io/your-org

# Local registry for testing
ocm transfer ctf --copy-local-resources ./ctf localhost:5001
```

The `--copy-local-resources` flag rewrites the image references inside the component to point to the target registry. The RGD picks up these rewritten references at runtime so images are pulled from the correct location.

## Resources

- [Solution Arsenal repository](https://github.com/opendefensecloud/solution-arsenal)
- [SolAr documentation](https://solar.opendefense.cloud)
- [OCM specification](https://ocm.software)
