# cert-manager Helm Chart Configuration Guide

This document provides a comprehensive guide to configuring the cert-manager Helm chart for different deployment scenarios.

## Overview

cert-manager is a native Kubernetes certificate management controller. It can help with issuing certificates from a variety of sources, such as Let's Encrypt, HashiCorp Vault, Venafi, a simple signing key pair, or self-signed.

**Version**: 1.19.2
**Chart Repository**: `oci://quay.io/jetstack/charts/cert-manager`
**Documentation**: https://cert-manager.io/docs/

## Quick Start

### Minimal Installation

```bash
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

### Production Installation

```bash
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.2 \
  --namespace cert-manager \
  --create-namespace \
  -f production-values.yaml
```

## Global Configuration

### CRD Installation

| Parameter | Description | Default |
|-----------|-------------|---------|
| `crds.enabled` | Install CRDs as part of Helm installation | `false` |
| `crds.keep` | Keep CRDs when Helm release is uninstalled | `true` |

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imagePullSecrets` | List of image pull secrets | `[]` |
| `global.nodeSelector` | Global node selector | `{}` |
| `global.commonLabels` | Labels to apply to all resources | `{}` |
| `global.priorityClassName` | Priority class for all pods | `""` |
| `global.logLevel` | Verbosity of cert-manager (0-6) | `2` |

### RBAC

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.rbac.create` | Create ClusterRoles and ClusterRoleBindings | `true` |
| `global.rbac.aggregateClusterRoles` | Aggregate ClusterRoles to default user-facing roles | `true` |

### Leader Election

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.leaderElection.namespace` | Namespace for leader election lease | `kube-system` |
| `global.leaderElection.leaseDuration` | Leader lease duration | `60s` |
| `global.leaderElection.renewDeadline` | Leader renewal deadline | `40s` |
| `global.leaderElection.retryPeriod` | Retry period for leadership | `15s` |

## Controller Configuration

### Replicas and High Availability

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of controller replicas | `1` |
| `podDisruptionBudget.enabled` | Enable PodDisruptionBudget | `false` |
| `podDisruptionBudget.minAvailable` | Minimum available pods | - |
| `podDisruptionBudget.maxUnavailable` | Maximum unavailable pods | - |

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Controller image repository | `quay.io/jetstack/cert-manager-controller` |
| `image.tag` | Controller image tag | Chart appVersion |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.requests.cpu` | CPU request | - |
| `resources.requests.memory` | Memory request | - |
| `resources.limits.cpu` | CPU limit | - |
| `resources.limits.memory` | Memory limit | - |

### Feature Gates

| Parameter | Description | Default |
|-----------|-------------|---------|
| `featureGates` | Comma-separated list of feature gates | `""` |
| `maxConcurrentChallenges` | Maximum concurrent ACME challenges | `60` |

### Pod Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `affinity` | Pod affinity rules | `{}` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Pod tolerations | `[]` |
| `topologySpreadConstraints` | Topology spread constraints | `[]` |

### Security Context

| Parameter | Description | Default |
|-----------|-------------|---------|
| `securityContext.runAsNonRoot` | Run as non-root | `true` |
| `securityContext.seccompProfile.type` | Seccomp profile | `RuntimeDefault` |
| `containerSecurityContext.allowPrivilegeEscalation` | Allow privilege escalation | `false` |
| `containerSecurityContext.capabilities.drop` | Drop capabilities | `["ALL"]` |
| `containerSecurityContext.readOnlyRootFilesystem` | Read-only root filesystem | `true` |

## Webhook Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `webhook.replicaCount` | Number of webhook replicas | `1` |
| `webhook.timeoutSeconds` | Webhook timeout | `30` |
| `webhook.image.repository` | Webhook image repository | `quay.io/jetstack/cert-manager-webhook` |
| `webhook.resources` | Webhook resource limits | `{}` |
| `webhook.affinity` | Webhook pod affinity | `{}` |
| `webhook.nodeSelector` | Webhook node selector | `{}` |
| `webhook.tolerations` | Webhook tolerations | `[]` |

### Webhook Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `webhook.serviceType` | Service type | `ClusterIP` |
| `webhook.securePort` | HTTPS port | `10250` |
| `webhook.hostNetwork` | Use host network | `false` |

## CA Injector Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cainjector.enabled` | Enable CA injector | `true` |
| `cainjector.replicaCount` | Number of CA injector replicas | `1` |
| `cainjector.image.repository` | CA injector image repository | `quay.io/jetstack/cert-manager-cainjector` |
| `cainjector.resources` | CA injector resource limits | `{}` |
| `cainjector.affinity` | CA injector pod affinity | `{}` |
| `cainjector.nodeSelector` | CA injector node selector | `{}` |
| `cainjector.tolerations` | CA injector tolerations | `[]` |

## ACME Solver Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `acmesolver.image.repository` | ACME solver image repository | `quay.io/jetstack/cert-manager-acmesolver` |

## Startup API Check

| Parameter | Description | Default |
|-----------|-------------|---------|
| `startupapicheck.enabled` | Enable startup API check | `true` |
| `startupapicheck.image.repository` | Startup API check image | `quay.io/jetstack/cert-manager-startupapicheck` |
| `startupapicheck.resources` | Resource limits | `{}` |
| `startupapicheck.timeout` | Timeout for API check | `1m` |

## Prometheus Monitoring

| Parameter | Description | Default |
|-----------|-------------|---------|
| `prometheus.enabled` | Enable Prometheus metrics | `true` |
| `prometheus.servicemonitor.enabled` | Create ServiceMonitor | `false` |
| `prometheus.servicemonitor.prometheusInstance` | Prometheus instance selector | `default` |
| `prometheus.servicemonitor.interval` | Scrape interval | `60s` |
| `prometheus.servicemonitor.scrapeTimeout` | Scrape timeout | `30s` |
| `prometheus.servicemonitor.labels` | ServiceMonitor labels | `{}` |

## Example Configurations

### Minimal Development Configuration

```yaml
crds:
  enabled: true
  keep: true

replicaCount: 1

resources:
  requests:
    cpu: 10m
    memory: 32Mi
  limits:
    cpu: 100m
    memory: 128Mi

webhook:
  replicaCount: 1

cainjector:
  replicaCount: 1

prometheus:
  enabled: false

podDisruptionBudget:
  enabled: false
```

### Production HA Configuration

```yaml
crds:
  enabled: true
  keep: true

replicaCount: 2

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - cert-manager
          topologyKey: topology.kubernetes.io/zone

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: cert-manager

webhook:
  replicaCount: 2
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 500m
      memory: 256Mi

cainjector:
  replicaCount: 2
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 500m
      memory: 256Mi

prometheus:
  enabled: true
  servicemonitor:
    enabled: true
    interval: 60s
    labels:
      release: prometheus

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

## ClusterIssuer Examples

### Self-Signed Issuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

### Let's Encrypt with HTTP-01

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-production-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

### Let's Encrypt with DNS-01 (CloudFlare)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns01-cloudflare
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-dns01-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```

### CA Issuer with Internal CA

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: internal-ca-issuer
spec:
  ca:
    secretName: internal-ca-secret
```

## Certificate Examples

### Basic Certificate

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
  subject:
    organizations:
      - Example Org
  commonName: example.com
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
    - server auth
    - client auth
  dnsNames:
    - example.com
    - www.example.com
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
    group: cert-manager.io
```

### Wildcard Certificate (requires DNS-01)

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-cert
  namespace: default
spec:
  secretName: wildcard-cert-tls
  duration: 2160h
  renewBefore: 360h
  commonName: "*.example.com"
  dnsNames:
    - "*.example.com"
    - example.com
  issuerRef:
    name: letsencrypt-dns01-cloudflare
    kind: ClusterIssuer
```

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

### Check ClusterIssuer Status

```bash
kubectl get clusterissuers
kubectl describe clusterissuer <name>
```

### Check Challenges

```bash
kubectl get challenges -A
kubectl describe challenge <name> -n <namespace>
```

## Resources

- [Official Documentation](https://cert-manager.io/docs/)
- [GitHub Repository](https://github.com/cert-manager/cert-manager)
- [Helm Chart Values](https://github.com/cert-manager/cert-manager/blob/master/deploy/charts/cert-manager/values.yaml)
- [ArtifactHub](https://artifacthub.io/packages/helm/cert-manager/cert-manager)
