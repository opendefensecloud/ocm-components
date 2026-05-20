# Flux OCM Component

This directory contains the OCM (Open Component Model) packaging for [Flux](http://github.com/fluxcd/flux2)

## Component structure

```
flux/
├── component-constructor.yaml  # OCM component descriptor
├── values.yaml.tpl  # values.yaml template for ocm-kit
```

## Quick start

### 1. Build the CTF archive

Run from the `flux/` directory of this repo:

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
