# cert-manager OCM Component

This directory contains the OCM (Open Component Model) packaging for [cert-manager](https://cert-manager.io/), the native Kubernetes certificate management controller.

## Overview

cert-manager is a CNCF graduated project that adds certificates and certificate issuers as resource types in Kubernetes clusters, simplifying the process of obtaining, renewing, and using TLS certificates.

**Version**: 1.19.2
**License**: Apache 2.0
**CNCF Status**: Graduated

## Features

- Automated TLS certificate management
- Let's Encrypt integration (HTTP-01 and DNS-01 challenges)
- Self-signed certificates for internal use
- CA-based certificate issuance
- Vault, Venafi, and other issuer support
- Automatic certificate renewal
- Gateway API integration
- Prometheus monitoring

## Component Structure

```
cert-manager/
├── component-constructor.yaml    # OCM component descriptor
├── cert-manager-v1.19.2.tgz      # Official Helm chart
├── rgd-template.yaml             # ResourceGraphDefinition for KRO
├── bootstrap.yaml                # Bootstrap configuration for OCM deployment
├── operator/
│   ├── cert-manager-manifest.yaml  # Generated Kubernetes manifests
│   └── values.yaml                 # Full Helm chart values reference
├── configs/
│   ├── minimal/
│   │   └── cert-manager.yaml     # Minimal configuration for dev/test
│   └── production/
│       └── cert-manager.yaml     # Production HA configuration
├── docs/
│   └── HELM_CHART_CONFIG.md      # Comprehensive configuration guide
└── tests/
    ├── test-minimal.sh           # Minimal deployment test
    └── test-rgd-bootstrap.sh     # Full RGD bootstrap test
```

## Quick Start

### Prerequisites

- Kubernetes 1.24+
- Helm 3.8+ (for Helm installation)
- kubectl configured to access your cluster

### Installation using Helm

```bash
# Create namespace
kubectl create namespace cert-manager

# Install cert-manager
helm install cert-manager ./cert-manager-v1.19.2.tgz \
    --namespace cert-manager \
    --set crds.enabled=true \
    --set crds.keep=true

# Wait for components to be ready
kubectl wait --for=condition=Available deployment/cert-manager \
    -n cert-manager --timeout=300s
kubectl wait --for=condition=Available deployment/cert-manager-webhook \
    -n cert-manager --timeout=300s
kubectl wait --for=condition=Available deployment/cert-manager-cainjector \
    -n cert-manager --timeout=300s
```

### Installation using Manifests

```bash
kubectl apply --server-side -f operator/cert-manager-manifest.yaml
```

## Configuration Profiles

### Minimal Configuration

The minimal configuration is designed for development, testing, and non-production environments:

- Single replica for each component
- Minimal resource allocation
- Self-signed ClusterIssuer included
- No monitoring enabled
- Pod disruption budget disabled

```bash
# Apply minimal configuration after installing cert-manager
kubectl apply -f configs/minimal/cert-manager.yaml
```

### Production Configuration

The production configuration provides a highly available setup:

- Multiple replicas (2 per component)
- Pod anti-affinity for zone distribution
- Pod disruption budgets enabled
- Prometheus monitoring enabled
- Production-grade resource limits
- Let's Encrypt staging and production issuers

```bash
# Apply production configuration
kubectl apply -f configs/production/cert-manager.yaml
```

## Creating Certificates

### Self-Signed Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
  namespace: default
spec:
  secretName: example-cert-tls
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days
  commonName: example.local
  dnsNames:
    - example.local
    - www.example.local
  issuerRef:
    name: selfsigned-ca-issuer
    kind: ClusterIssuer
```

### Let's Encrypt Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: production-cert
  namespace: default
spec:
  secretName: production-cert-tls
  duration: 2160h
  renewBefore: 720h
  commonName: app.example.com
  dnsNames:
    - app.example.com
    - www.app.example.com
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
```

## ClusterIssuers

The component provides several pre-configured ClusterIssuers:

| Issuer Name | Type | Use Case |
|-------------|------|----------|
| `selfsigned-issuer` | Self-Signed | Creating CA certificates |
| `selfsigned-ca-issuer` | CA | Internal certificates |
| `letsencrypt-staging` | ACME | Testing Let's Encrypt |
| `letsencrypt-production` | ACME | Production certificates |

## OCM Deployment with KRO

### Bootstrap Deployment

The component includes a ResourceGraphDefinition (RGD) for deployment via KRO:

```bash
# Apply bootstrap configuration
kubectl apply -f bootstrap.yaml
```

This creates:
- OCM Repository pointing to your registry
- OCM Component reference
- RGD for cert-manager deployment
- CertManagerBootstrap custom resource

### CertManagerBootstrap Custom Resource

```yaml
apiVersion: v1alpha1
kind: CertManagerBootstrap
metadata:
  name: cert-manager-production
  namespace: default
spec:
  registry:
    url: ghcr.io
  componentName: github.com/ocm/cert-manager
  componentVersion: 1.19.2
  namespace: cert-manager
  deploymentProfile: production
  controllerReplicas: 2
  webhookReplicas: 2
  cainjectorReplicas: 2
  monitoringEnabled: true
  createSelfSignedIssuer: true
  createLetsEncryptIssuers: true
  letsEncryptEmail: admin@example.com
  ingressClass: nginx
```

## Container Images

| Image | Purpose |
|-------|---------|
| `quay.io/jetstack/cert-manager-controller:v1.19.2` | Main controller |
| `quay.io/jetstack/cert-manager-webhook:v1.19.2` | Validation webhook |
| `quay.io/jetstack/cert-manager-cainjector:v1.19.2` | CA injection |
| `quay.io/jetstack/cert-manager-acmesolver:v1.19.2` | ACME challenges |
| `quay.io/jetstack/cert-manager-startupapicheck:v1.19.2` | Startup checks |

## Testing

### Run Minimal Test

```bash
cd tests
./test-minimal.sh
```

This test:
1. Creates a kind cluster
2. Installs cert-manager
3. Creates self-signed issuers
4. Issues a test certificate
5. Verifies certificate is valid

### Run RGD Bootstrap Test

```bash
cd tests
./test-rgd-bootstrap.sh
```

This test:
1. Creates a kind cluster with local registry
2. Installs FluxCD, KRO, and OCM toolkit
3. Builds and pushes the OCM component
4. Deploys cert-manager via RGD
5. Verifies certificate issuance

## Troubleshooting

### Check cert-manager Status

```bash
kubectl get pods -n cert-manager
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

### Check Certificate Status

```bash
kubectl get certificates -A
kubectl describe certificate <name> -n <namespace>
```

### Check Challenges

```bash
kubectl get challenges -A
kubectl describe challenge <name> -n <namespace>
```

### Common Issues

1. **Webhook timeout**: Ensure webhook is ready before creating certificates
2. **DNS resolution**: For HTTP-01 challenges, domain must resolve to your ingress
3. **Rate limits**: Use Let's Encrypt staging for testing to avoid rate limits
4. **RBAC issues**: Check if cert-manager has necessary permissions

## Resources

- [Official Documentation](https://cert-manager.io/docs/)
- [GitHub Repository](https://github.com/cert-manager/cert-manager)
- [Helm Chart](https://artifacthub.io/packages/helm/cert-manager/cert-manager)
- [CNCF Project Page](https://www.cncf.io/projects/cert-manager/)
- [Slack Channel](https://kubernetes.slack.com/channels/cert-manager)

## License

cert-manager is licensed under the Apache License 2.0. This OCM component packaging follows the same license.
