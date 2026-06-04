# Argo Workflows OCM Component

Argo Workflows v4.0.5 packaged as an OCM component. Argo Workflows is a CNCF graduated project providing a Kubernetes-native workflow engine for orchestrating parallel jobs, ML pipelines, data processing, and CI/CD.

## OCM Resources

| Resource | Type | Description |
|---|---|---|
| `argo-workflows-chart` | helmChart | Official Argo Workflows Helm chart v1.0.14 |
| `argo-workflows-controller-image` | ociImage | Workflow controller (`quay.io/argoproj/workflow-controller:v4.0.5`) |
| `argo-workflows-server-image` | ociImage | Argo server/UI (`quay.io/argoproj/argocli:v4.0.5`) |
| `argo-workflows-executor-image` | ociImage | Workflow executor (`quay.io/argoproj/argoexec:v4.0.5`) |
| `argo-workflows-minimal-config` | yaml | Minimal Helm values (dev/test) |
| `argo-workflows-production-config` | yaml | Production Helm values (HA) |

## Quick Start

### Build OCM Component

```bash
cd argo-workflows
ocm add componentversion --version 4.0.5 --create --file ./ctf component-constructor.yaml
```

### Install via Helm (Minimal)

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo-workflows argo/argo-workflows \
  --version 1.0.14 \
  --namespace argo \
  --create-namespace \
  --values minimal-values.yaml
```

### Install via Helm (Production)

```bash
helm install argo-workflows argo/argo-workflows \
  --version 1.0.14 \
  --namespace argo \
  --create-namespace \
  --values production-values.yaml
```

## Configuration Profiles

### Minimal (dev/test)

| Parameter | Value |
|---|---|
| Controller replicas | 1 |
| Server replicas | 1 |
| Auth mode | `server` (no token required) |
| Workflow archive | disabled |
| Prometheus monitoring | disabled |
| Controller CPU request | 50m |
| Controller memory request | 128Mi |

### Production (HA)

| Parameter | Value |
|---|---|
| Controller replicas | 2 |
| Server replicas | 2 |
| Auth mode | `client` (Kubernetes RBAC) |
| Max concurrent workflows | 50 |
| Prometheus monitoring | enabled |
| PodDisruptionBudgets | enabled (minAvailable: 1) |
| Pod anti-affinity | preferred (hostname) |
| TopologySpreadConstraints | zone-aware |
| Controller CPU request | 100m |
| Controller memory request | 256Mi |

#### SSO/OIDC Authentication

The production profile defaults to `client` auth (Kubernetes service account tokens). To enable SSO, set in your values override:

```yaml
server:
  authModes:
    - sso
  sso:
    issuer: https://your-oidc-provider
    clientId:
      name: argo-workflows-sso
      key: client-id
    clientSecret:
      name: argo-workflows-sso
      key: client-secret
    redirectUrl: https://argo-workflows.example.com/oauth2/callback
```

## Architecture

Argo Workflows consists of three main components:

- **Workflow Controller**: Watches Workflow CRs and schedules pods
- **Argo Server**: REST API + web UI + CLI proxy
- **Executor (argoexec)**: Sidecar injected into each workflow step pod; manages step lifecycle and artifact collection

## Testing

```bash
# Minimal deployment on a local kind cluster
bash tests/test-minimal.sh

# Production HA deployment on a multi-node kind cluster
bash tests/test-production.sh

# Keep the cluster after tests for inspection
bash tests/test-minimal.sh --skip-cleanup
```

## Dependency Note

Argo Workflows is a core dependency of the `artifact-conduit` component. When deploying artifact-conduit, ensure argo-workflows is installed in the same cluster first.
