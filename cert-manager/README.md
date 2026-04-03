# cert-manager OCM Component

Automated TLS certificate management for Kubernetes.

## Overview

[cert-manager](https://cert-manager.io/) is a CNCF graduated project that adds certificates and certificate issuers as resource types in Kubernetes clusters and simplifies the process of obtaining, renewing, and using those certificates.

- **Version**: v1.20.1
- **License**: Apache 2.0
- **CNCF Status**: Graduated
- **Helm Chart**: jetstack/cert-manager v1.20.1

## Component Resources

| Resource | Type | Description |
|----------|------|-------------|
| `cert-manager-chart` | Helm Chart | Official cert-manager Helm chart |
| `cert-manager-controller-image` | OCI Image | Main controller |
| `cert-manager-webhook-image` | OCI Image | Admission webhook |
| `cert-manager-cainjector-image` | OCI Image | CA bundle injector |
| `cert-manager-acmesolver-image` | OCI Image | ACME challenge solver |
| `cert-manager-startupapicheck-image` | OCI Image | Startup readiness check |
| `cert-manager-rgd` | YAML | ResourceGraphDefinition for KRO |
| `cert-manager-minimal-config` | YAML | Minimal Helm values |
| `cert-manager-production-config` | YAML | Production Helm values |

## Quick Start

### Direct Helm Installation

```bash
# Add Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install with minimal config (dev/test)
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --values values-minimal.yaml

# Install with production config (HA)
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --values values-production.yaml
```

### OCM Bootstrap (KRO)

```bash
# Apply bootstrap resources (requires OCM K8s Toolkit and KRO)
kubectl apply -f bootstrap.yaml

# This creates the CertManagerBootstrap CRD
# The minimal instance is included in bootstrap.yaml
```

## Configuration Profiles

### Minimal (Development/Testing)

- Single replica for controller, webhook, and cainjector
- Minimal resource requests (50m CPU, 128Mi memory for controller)
- CRDs installed via Helm
- Monitoring disabled
- Suitable for local development and CI

### Production (High Availability)

- **Controller**: 2 replicas with PDB
- **Webhook**: 3 replicas with PDB (critical path for admission)
- **CA Injector**: 2 replicas with PDB
- Topology spread constraints across zones
- Pod anti-affinity across nodes
- Security hardening (non-root, read-only filesystem, dropped capabilities, seccomp)
- Prometheus ServiceMonitor enabled
- Increased concurrent challenge limit (60)

## Issuer Types

cert-manager supports multiple certificate authority backends:

| Issuer Type | Use Case |
|-------------|----------|
| **SelfSigned** | Development, testing, internal CAs |
| **CA** | Internal PKI with your own CA certificate |
| **ACME (Let's Encrypt)** | Public-facing services with free certificates |
| **Vault** | HashiCorp Vault PKI backend |
| **Venafi** | Enterprise certificate management |

### Example: Self-Signed Issuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

### Example: Let's Encrypt (ACME) Issuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v2.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx
```

### Example: CA Issuer (Internal PKI)

```yaml
# First create a root CA certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: root-ca
  namespace: cert-manager
spec:
  isCA: true
  secretName: root-ca-tls
  commonName: My Root CA
  duration: 87600h  # 10 years
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: internal-ca-issuer
spec:
  ca:
    secretName: root-ca-tls
```

### Example: Issuing a Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: my-app
spec:
  secretName: my-app-tls-secret
  duration: 2160h    # 90 days
  renewBefore: 360h  # 15 days before expiry
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: app.example.com
  dnsNames:
    - app.example.com
    - www.app.example.com
```

## Integration with Other Components

### Keycloak

The Keycloak production configuration references cert-manager for TLS:

```yaml
# In Keycloak Ingress
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```

### Ingress Controllers

cert-manager integrates with any ingress controller via annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - example.com
      secretName: example-com-tls
```

## Key Helm Values

| Parameter | Default (Minimal) | Default (Production) | Description |
|-----------|-------------------|---------------------|-------------|
| `replicaCount` | 1 | 2 | Controller replicas |
| `webhook.replicaCount` | 1 | 3 | Webhook replicas |
| `cainjector.replicaCount` | 1 | 2 | CA Injector replicas |
| `crds.enabled` | true | true | Install CRDs via Helm |
| `prometheus.enabled` | false | true | Enable Prometheus metrics |
| `podDisruptionBudget.enabled` | false | true | Enable PDB |
| `resources.requests.cpu` | 50m | 100m | Controller CPU request |
| `resources.requests.memory` | 128Mi | 256Mi | Controller memory request |
| `global.logLevel` | 2 | 2 | Log verbosity (0-6) |
| `maxConcurrentChallenges` | 60 | 60 | Max parallel ACME challenges |

## CRDs

cert-manager installs the following Custom Resource Definitions:

- `certificates.cert-manager.io` - Certificate resources
- `certificaterequests.cert-manager.io` - Certificate signing requests
- `issuers.cert-manager.io` - Namespace-scoped certificate authorities
- `clusterissuers.cert-manager.io` - Cluster-scoped certificate authorities
- `orders.acme.cert-manager.io` - ACME order tracking
- `challenges.acme.cert-manager.io` - ACME challenge tracking

## Testing

```bash
# Run minimal deployment test
cd tests
./test-minimal.sh

# Run production deployment test (multi-node kind cluster)
./test-production.sh

# Keep cluster after test for debugging
./test-minimal.sh --skip-cleanup
```

## Building the OCM Component

```bash
cd cert-manager
ocm add componentversions --create --file ../cert-manager-component.ctf component-constructor.yaml
```

## Air-Gapped Deployment

```bash
# Transfer to OCI registry
ocm transfer ctf --copy-resources cert-manager-component.ctf oci://your-registry/ocm-components

# In air-gapped environment
ocm transfer oci://your-registry/ocm-components ctf cert-manager-airgapped.ctf
```

The RGD template automatically handles image localization when components are transferred between registries.

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Helm Chart Values](https://artifacthub.io/packages/helm/cert-manager/cert-manager)
- [ACME Configuration](https://cert-manager.io/docs/configuration/acme/)
- [Issuer Types](https://cert-manager.io/docs/configuration/)
- [Securing Ingress Resources](https://cert-manager.io/docs/usage/ingress/)
