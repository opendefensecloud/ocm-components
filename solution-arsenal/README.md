# Solution Arsenal (SolAr) OCM Component

This directory contains the OCM (Open Component Model) packaging for [Solution Arsenal (SolAr)](https://github.com/opendefensecloud/solution-arsenal), an application catalog and fleet rollout manager.

## Component structure

```
solution-arsenal/
├── bootstrap.yaml              # OCM K8s Toolkit bootstrap + example CR instances
├── component-constructor.yaml  # OCM component descriptor
├── minimal-values.yaml         # Helm values: single-instance dev/test profile
├── production-values.yaml      # Helm values: HA production profile
└── rgd-template.yaml           # KRO ResourceGraphDefinition
```



## Prerequisites

### Required
- **Kubernetes**
- **Helm**
- **cert-manager**

### Optional 
- **KRO (Kubernetes Resource Orchestrator)**: For RGD-based bootstrapping
- **OCM K8s Toolkit**: For OCM-based deployment
- **FluxCD**: For GitOps-style deployments

## Quick start

### 1. Build the CTF archive

Run from the `solution-arsenal/` directory of this repo:

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

### 3. Edit bootstrap.yaml

Open `bootstrap.yaml` and set the registry URL in the `Repository` resource:

```yaml
spec:
  url: oci://ghcr.io/your-org
```

If the registry is private, uncomment the `Secret` block and the `secretRef` fields throughout the file.

### 4. Apply the bootstrap

```bash
kubectl apply -f bootstrap.yaml
```

This creates the OCM K8s Toolkit resources that fetch the RGD and the `SolutionArsenalBootstrap` CR that triggers the actual deployment.

### 5. Verify

```bash
# RGD created by the deployer
kubectl get rgd solution-arsenal-bootstrap

# CRD registered by KRO
kubectl get crd solutionarsenalbootstraps.kro.run

# Bootstrap instance status
kubectl get solutionarsenalbootstrap -A

# Application pods
kubectl get pods -n solar-system
```


## Resources

- [Solution Arsenal repository](https://github.com/opendefensecloud/solution-arsenal)
- [SolAr documentation](https://solar.opendefense.cloud)
- [OCM specification](https://ocm.software)
- [KRO documentation](https://kro.run)
