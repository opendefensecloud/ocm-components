# Helm Chart Configuration Reference

This document provides a complete reference for all configurable values in the Artifact Conduit Helm chart.

## Table of Contents

- [Global Configuration](#global-configuration)
- [API Server Configuration](#api-server-configuration)
- [Controller Manager Configuration](#controller-manager-configuration)
- [etcd Configuration](#etcd-configuration)
- [cert-manager Integration](#cert-manager-integration)
- [RBAC Configuration](#rbac-configuration)
- [Examples](#examples)

## Global Configuration

Global settings that can be shared with subcharts.

```yaml
global:
  # Global image pull secrets for all components
  imagePullSecrets: []
  # - name: myregistrykey

  # Global storage class for persistent volumes
  storageClass: ""  # Empty uses cluster default
```

## API Server Configuration

The API Server provides the extension API for Artifact Conduit custom resources.

### Basic Settings

```yaml
apiserver:
  # Enable or disable API Server deployment
  enabled: true

  # Number of replicas (set to 3+ for HA)
  replicaCount: 1

  # Override name for API Server resources
  nameOverride: ""
  fullnameOverride: ""
```

### Image Configuration

```yaml
apiserver:
  image:
    # Container image repository
    repository: ghcr.io/opendefensecloud/arc-apiserver

    # Image tag (defaults to chart appVersion if empty)
    tag: ""

    # Image pull policy
    pullPolicy: IfNotPresent

  # Image pull secrets (overrides global)
  imagePullSecrets: []
```

### Service Configuration

```yaml
apiserver:
  service:
    # Service type (ClusterIP, NodePort, LoadBalancer)
    type: ClusterIP

    # External service port
    port: 443

    # Container target port
    targetPort: 8443

    # Service annotations
    annotations: {}
    # cloud.google.com/load-balancer-type: "Internal"
```

### Command and Arguments

```yaml
apiserver:
  # Container command
  command: ["/arc-apiserver"]

  # Command-line arguments
  args:
    # etcd server URLs (auto-configured if empty)
    etcdServers: ""

    # HTTPS port
    securePort: 8443

    # Audit log path ("-" for stdout)
    auditLogPath: "-"

    # Enable priority and fairness
    enablePriorityAndFairness: false

    # Audit log rotation settings
    auditLogMaxAge: 0
    auditLogMaxBackup: 0

  # Additional command-line arguments
  extraArgs: {}
  # feature-gates: "SomeFeature=true"

  # Additional environment variables
  extraEnv: []
  # - name: LOG_LEVEL
  #   value: "debug"
```

### Resources

```yaml
apiserver:
  resources:
    limits:
      cpu: 500m
      memory: 128Mi
    requests:
      cpu: 10m
      memory: 64Mi
```

### Security Contexts

```yaml
apiserver:
  # Pod security context
  podSecurityContext:
    runAsNonRoot: true

  # Container security context
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
```

### Health Probes

```yaml
apiserver:
  livenessProbe:
    httpGet:
      path: /healthz
      port: 8443
      scheme: HTTPS
    initialDelaySeconds: 20
    periodSeconds: 20

  readinessProbe:
    httpGet:
      path: /readyz
      port: 8443
      scheme: HTTPS
    initialDelaySeconds: 5
    periodSeconds: 10
```

### Pod Placement

```yaml
apiserver:
  # Node selector
  nodeSelector: {}
  # kubernetes.io/arch: amd64

  # Tolerations
  tolerations: []
  # - key: "dedicated"
  #   operator: "Equal"
  #   value: "arc"
  #   effect: "NoSchedule"

  # Affinity rules (recommended for HA)
  affinity: {}
  # podAntiAffinity:
  #   preferredDuringSchedulingIgnoredDuringExecution:
  #     - weight: 100
  #       podAffinityTerm:
  #         labelSelector:
  #           matchExpressions:
  #             - key: app.kubernetes.io/component
  #               operator: In
  #               values:
  #                 - apiserver
  #         topologyKey: kubernetes.io/hostname
```

### Pod Metadata

```yaml
apiserver:
  # Pod annotations
  podAnnotations: {}
  # prometheus.io/scrape: "true"

  # Pod labels
  podLabels: {}
  # environment: production
```

### Service Account

```yaml
apiserver:
  serviceAccount:
    # Create service account
    create: true

    # Service account annotations
    annotations: {}
    # eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME

    # Service account name (auto-generated if empty)
    name: ""
```

### APIService Configuration

```yaml
apiserver:
  apiservice:
    # Group priority minimum
    groupPriorityMinimum: 2000

    # Version priority
    versionPriority: 100
```

## Controller Manager Configuration

The Controller Manager reconciles Artifact Conduit custom resources.

### Basic Settings

```yaml
controller:
  enabled: true
  replicaCount: 1
  nameOverride: ""
  fullnameOverride: ""
```

### Image Configuration

```yaml
controller:
  image:
    repository: ghcr.io/opendefensecloud/arc-controller-manager
    tag: ""
    pullPolicy: IfNotPresent
  imagePullSecrets: []
```

### Command and Arguments

```yaml
controller:
  command: ["/arc-controller-manager"]

  args:
    # Health probe address
    healthProbeBindAddress: ":8081"

    # Metrics address (set to "0" to disable)
    metricsBindAddress: "0"

    # Serve metrics securely via HTTPS
    metricsSecure: true

    # Enable HTTP/2
    enableHTTP2: false

    # Enable leader election (required for HA with multiple replicas)
    leaderElect: false

    # Pprof address (empty to disable)
    pprofBindAddress: ""

  extraArgs: {}
  extraEnv: []
```

### Metrics Configuration

```yaml
controller:
  metrics:
    # Enable metrics service
    enabled: false

    service:
      type: ClusterIP
      port: 8443
      annotations: {}

    # cert-manager integration for secure metrics
    certManager:
      enabled: false
      certPath: /tmp/k8s-metrics-server/metrics-certs
      certName: tls.crt
      certKey: tls.key

    # ServiceMonitor for Prometheus Operator
    serviceMonitor:
      enabled: false
      interval: 30s
      scrapeTimeout: 10s
      additionalLabels: {}
      # release: prometheus
```

### Resources

```yaml
controller:
  resources:
    limits:
      cpu: 100m
      memory: 30Mi
    requests:
      cpu: 100m
      memory: 20Mi
```

### Security Contexts

```yaml
controller:
  podSecurityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault

  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
```

### Health Probes

```yaml
controller:
  livenessProbe:
    httpGet:
      path: /healthz
      port: 8081
    initialDelaySeconds: 15
    periodSeconds: 20

  readinessProbe:
    httpGet:
      path: /readyz
      port: 8081
    initialDelaySeconds: 5
    periodSeconds: 10
```

### Pod Placement and Metadata

```yaml
controller:
  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  podLabels: {}
```

### Service Account

```yaml
controller:
  serviceAccount:
    create: true
    annotations: {}
    name: ""
```

## etcd Configuration

etcd is the dedicated storage backend for the API Server.

### Basic Settings

```yaml
etcd:
  enabled: true
  replicaCount: 1  # Set to 3+ for HA
```

### Image Configuration

```yaml
etcd:
  image:
    repository: quay.io/coreos/etcd
    tag: v3.6.6
    pullPolicy: IfNotPresent
  imagePullSecrets: []
```

### Command Arguments

```yaml
etcd:
  args:
    listenClientUrls: "http://[::]:2379"
    advertiseClientUrls: "http://localhost:2379"
    dataDir: "/etcd-data-dir/default.etcd"

  extraArgs: {}
  # initial-cluster-state: "new"
  # initial-cluster: "etcd-0=http://etcd-0:2380,etcd-1=http://etcd-1:2380"

  extraEnv: []
```

### Service Configuration

```yaml
etcd:
  service:
    type: ClusterIP
    port: 2379
    annotations: {}
```

### Persistence

```yaml
etcd:
  persistence:
    # Enable persistent storage
    enabled: true

    # Storage class (empty uses cluster default)
    storageClass: ""

    # Access mode
    accessMode: ReadWriteOnce

    # Storage size
    size: 1Gi

    # PVC annotations
    annotations: {}
```

### Resources

```yaml
etcd:
  resources:
    limits:
      cpu: 500m
      memory: 128Mi
    requests:
      cpu: 10m
      memory: 64Mi
```

### Security Contexts

```yaml
etcd:
  podSecurityContext:
    seccompProfile:
      type: RuntimeDefault

  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
```

### Health Probes

```yaml
etcd:
  livenessProbe:
    httpGet:
      path: /health
      port: 2379
    initialDelaySeconds: 15
    periodSeconds: 20

  readinessProbe:
    httpGet:
      path: /health
      port: 2379
    initialDelaySeconds: 5
    periodSeconds: 10
```

### Pod Placement and Metadata

```yaml
etcd:
  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  podLabels: {}
```

## cert-manager Integration

Automatic TLS certificate management via cert-manager.

```yaml
certManager:
  # Enable cert-manager integration
  enabled: true

  issuer:
    # Create Issuer resource
    create: true

    # Issuer kind (Issuer or ClusterIssuer)
    kind: Issuer

    # Issuer name (auto-generated if empty)
    name: ""

    # Use self-signed certificates (simplest)
    selfSigned: true

    # CA issuer (for internal CA)
    ca:
      enabled: false
      secretName: "ca-key-pair"

    # ACME/Let's Encrypt issuer (for public certificates)
    acme:
      enabled: false
      server: "https://acme-v02.api.letsencrypt.org/directory"
      email: "admin@example.com"
      privateKeySecretRef: "letsencrypt-production"

  certificate:
    # Certificate validity duration
    duration: 2160h  # 90 days

    # Renew before expiry
    renewBefore: 720h  # 30 days
```

## RBAC Configuration

Role-Based Access Control settings.

```yaml
rbac:
  # Create RBAC resources
  create: true

  # Additional ClusterRole rules for controller
  additionalControllerRules: []
  # - apiGroups: [""]
  #   resources: ["configmaps"]
  #   verbs: ["get", "list", "watch"]

  # Additional ClusterRole rules for apiserver
  additionalAPIServerRules: []
  # - apiGroups: [""]
  #   resources: ["secrets"]
  #   verbs: ["get", "list"]
```

## Examples

### Minimal Development Setup

```yaml
apiserver:
  replicaCount: 1
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi

controller:
  replicaCount: 1
  args:
    leaderElect: false
    metricsBindAddress: "0"
  metrics:
    enabled: false

etcd:
  replicaCount: 1
  persistence:
    size: 1Gi

certManager:
  enabled: true
  issuer:
    selfSigned: true
```

### Production HA Setup

```yaml
apiserver:
  replicaCount: 3
  resources:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values:
                    - apiserver
            topologyKey: kubernetes.io/hostname

controller:
  replicaCount: 3
  args:
    leaderElect: true
    metricsBindAddress: ":8443"
    metricsSecure: true
  metrics:
    enabled: true
    certManager:
      enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: prometheus
  resources:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 200m
      memory: 128Mi
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values:
                    - controller-manager
            topologyKey: kubernetes.io/hostname

etcd:
  replicaCount: 3
  persistence:
    size: 20Gi
    storageClass: "fast-ssd"
  resources:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values:
                    - etcd
            topologyKey: kubernetes.io/hostname

certManager:
  enabled: true
  issuer:
    kind: ClusterIssuer
    ca:
      enabled: true
      secretName: "internal-ca"
  certificate:
    duration: 8760h  # 1 year
    renewBefore: 2160h  # 90 days
```

### Private Registry Setup

```yaml
global:
  imagePullSecrets:
    - name: my-registry-secret

apiserver:
  image:
    repository: my-registry.com/arc/apiserver
    tag: "v0.1.0"

controller:
  image:
    repository: my-registry.com/arc/controller-manager
    tag: "v0.1.0"

etcd:
  image:
    repository: my-registry.com/coreos/etcd
    tag: "v3.6.6"
```

### Node Affinity for Dedicated Nodes

```yaml
apiserver:
  nodeSelector:
    workload: arc
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "arc"
      effect: "NoSchedule"

controller:
  nodeSelector:
    workload: arc
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "arc"
      effect: "NoSchedule"

etcd:
  nodeSelector:
    workload: arc
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "arc"
      effect: "NoSchedule"
```

## Reference

- [Artifact Conduit Documentation](https://arc.opendefense.cloud)
- [Helm Values File](../charts/arc/values.yaml)
- [Minimal Configuration](../configs/minimal/values.yaml)
- [Production Configuration](../configs/production/values.yaml)
