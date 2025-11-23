# CloudNativePG Helm Chart Configuration

This document explains how to use the CloudNativePG Helm charts with custom configurations, exposing all available parameters beyond the provided minimal and production configs.

## Helm Charts

CloudNativePG provides two Helm charts:

1. **Operator Chart** (`cloudnative-pg`) - Installs the CloudNativePG operator
2. **Cluster Chart** (`cluster`) - Deploys PostgreSQL database clusters

## Using Helm Charts Directly

### Add the Helm Repository

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
```

### Install Operator with Custom Values

```bash
# Create custom values file
cat > my-operator-values.yaml <<EOF
replicaCount: 2  # HA operator deployment

config:
  clusterWide: true
  maxConcurrentReconciles: 20

resources:
  limits:
    cpu: 500m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

monitoring:
  podMonitorEnabled: true
  grafanaDashboard:
    create: true
EOF

# Install with custom values
helm install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace \
  --values my-operator-values.yaml
```

### Deploy PostgreSQL Cluster with Custom Values

```bash
# Create custom cluster values
cat > my-cluster-values.yaml <<EOF
mode: standalone  # or 'replica' for read replicas

cluster:
  instances: 3
  primaryUpdateStrategy: unsupervised

  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      work_mem: "8MB"

  storage:
    size: 50Gi
    storageClass: fast-ssd

  monitoring:
    enabled: true
    podMonitorEnabled: true

  backup:
    enabled: true
    retentionPolicy: "30d"
    schedule: "0 2 * * *"
    destinationPath: s3://my-bucket/backups
    s3Credentials:
      accessKeyId:
        name: aws-creds
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: aws-creds
        key: SECRET_ACCESS_KEY
EOF

# Deploy cluster
helm install my-postgres cnpg/cluster \
  --namespace postgres \
  --create-namespace \
  --values my-cluster-values.yaml
```

## All Available Operator Chart Parameters

See [`operator/values.yaml`](../operator/values.yaml) for the complete list. Key parameters include:

### Deployment Configuration
- `replicaCount` - Number of operator replicas (default: 1)
- `image.repository` - Operator image repository
- `image.tag` - Operator version override
- `updateStrategy` - Deployment update strategy

### Operator Behavior
- `config.clusterWide` - Watch all namespaces (true) or single namespace (false)
- `config.maxConcurrentReconciles` - Max concurrent reconciliations (default: 10)
- `config.data` - Operator configuration options:
  - `INHERITED_ANNOTATIONS` - Annotations to inherit in managed resources
  - `INHERITED_LABELS` - Labels to inherit
  - `WATCH_NAMESPACE` - Specific namespaces to watch
  - `LOG_LEVEL` - Logging verbosity

### Webhook Configuration
- `webhook.port` - Webhook server port (default: 9443)
- `webhook.mutating.failurePolicy` - Mutating webhook failure policy
- `webhook.validating.failurePolicy` - Validating webhook failure policy

### Resource Management
- `resources.limits` - Resource limits for operator pod
- `resources.requests` - Resource requests for operator pod

### Monitoring
- `monitoring.podMonitorEnabled` - Create PodMonitor for Prometheus
- `monitoring.grafanaDashboard.create` - Create Grafana dashboard ConfigMap

### Security
- `securityContext` - Pod security context
- `containerSecurityContext` - Container security context
- `podSecurityContext` - Pod-level security settings

## All Available Cluster Chart Parameters

See [`operator/cluster-values.yaml`](../operator/cluster-values.yaml) for the complete list. Key parameters include:

### Cluster Mode
- `mode` - Deployment mode:
  - `standalone` - Independent cluster
  - `replica` - Read replica of another cluster
  - `recovery` - Point-in-time recovery

### Instance Configuration
- `cluster.instances` - Number of PostgreSQL instances (1-N)
- `cluster.imageName` - PostgreSQL image (supports PG 15, 16, 17)
- `cluster.primaryUpdateStrategy` - How to handle primary updates:
  - `supervised` - Wait for manual approval
  - `unsupervised` - Automatic switchover

### PostgreSQL Settings
- `cluster.postgresql.parameters` - PostgreSQL configuration parameters:
  - `max_connections`
  - `shared_buffers`
  - `effective_cache_size`
  - `work_mem`
  - `maintenance_work_mem`
  - Any valid PostgreSQL parameter

### Storage Configuration
- `cluster.storage.size` - PVC size (default: 1Gi)
- `cluster.storage.storageClass` - StorageClass name
- `cluster.storage.pvcTemplate` - Full PVC template for advanced config
- `cluster.walStorage` - Separate storage for WAL files

### High Availability
- `cluster.minSyncReplicas` - Minimum synchronous replicas
- `cluster.maxSyncReplicas` - Maximum synchronous replicas
- `cluster.enableSuperuserAccess` - Enable superuser access (false recommended)

### Backup Configuration
- `cluster.backup.enabled` - Enable automated backups
- `cluster.backup.barmanObjectStore` - Object storage configuration:
  - `destinationPath` - S3/Azure/GCS path
  - `serverName` - Backup identifier
  - `wal.compression` - WAL compression method
  - `wal.encryption` - WAL encryption
  - `data.compression` - Data backup compression
  - `retentionPolicy` - Backup retention (e.g., "30d")
- `cluster.backup.volumeSnapshot` - Volume snapshot backups

### Monitoring
- `cluster.monitoring.enabled` - Enable monitoring
- `cluster.monitoring.podMonitorEnabled` - Create PodMonitor
- `cluster.monitoring.customQueriesConfigMap` - Custom Prometheus queries

### Connection Pooling
- `cluster.enablePgBouncer` - Enable PgBouncer for connection pooling
- `cluster.pgbouncer.poolMode` - Pooling mode (session/transaction/statement)
- `cluster.pgbouncer.parameters` - PgBouncer configuration

### Bootstrap Methods
- `cluster.bootstrap.initdb` - Initialize new cluster
- `cluster.bootstrap.recovery` - Recover from backup
- `cluster.bootstrap.pg_basebackup` - Clone from existing cluster

## Example: Custom Production Configuration

```yaml
# custom-production-cluster.yaml
mode: standalone

cluster:
  name: production-postgres
  instances: 5

  postgresql:
    parameters:
      max_connections: "500"
      shared_buffers: "4GB"
      effective_cache_size: "12GB"
      work_mem: "16MB"
      maintenance_work_mem: "512MB"
      wal_buffers: "16MB"
      checkpoint_completion_target: "0.9"
      max_wal_size: "4GB"
      min_wal_size: "1GB"

  storage:
    size: 200Gi
    storageClass: fast-ssd

  walStorage:
    size: 20Gi
    storageClass: fast-ssd

  minSyncReplicas: 2
  maxSyncReplicas: 3

  backup:
    enabled: true
    barmanObjectStore:
      destinationPath: s3://prod-backups/postgres
      s3Credentials:
        accessKeyId:
          name: s3-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: s3-creds
          key: SECRET_ACCESS_KEY
      wal:
        compression: gzip
        maxParallel: 8
      data:
        compression: gzip
        jobs: 4
      retentionPolicy: "90d"
    volumeSnapshot:
      enabled: true
      className: csi-snapclass
    schedule: "0 2 * * *"

  monitoring:
    enabled: true
    podMonitorEnabled: true
    customQueriesConfigMap:
      - name: custom-queries
        key: queries.yaml

  enablePgBouncer: true
  pgbouncer:
    poolMode: transaction
    parameters:
      max_client_conn: "1000"
      default_pool_size: "25"

  resources:
    requests:
      memory: "8Gi"
      cpu: "2"
    limits:
      memory: "16Gi"
      cpu: "4"

  nodeMaintenanceWindow:
    inProgress: false
    reusePVC: true

  affinity:
    topologyKey: topology.kubernetes.io/zone
    podAntiAffinityType: required
```

Deploy this custom configuration:

```bash
helm install prod-postgres cnpg/cluster \
  --namespace production \
  --create-namespace \
  --values custom-production-cluster.yaml
```

## Hybrid Approach: OCM + Custom Helm Values

You can combine the OCM component's provided configs with custom Helm values:

```bash
# Install operator from OCM component
kubectl apply -f operator/cnpg-operator.yml

# Deploy cluster using Helm with custom values
helm install my-db cnpg/cluster \
  --namespace my-app \
  --values configs/production/cluster.yaml \
  --set cluster.instances=7 \
  --set cluster.storage.size=500Gi
```

## References

- [CloudNativePG Operator Chart](https://github.com/cloudnative-pg/charts/tree/main/charts/cloudnative-pg)
- [CloudNativePG Cluster Chart](https://github.com/cloudnative-pg/charts/tree/main/charts/cluster)
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [Operator Configuration Options](https://cloudnative-pg.io/documentation/current/operator_conf/)
- [Cluster Spec Reference](https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-ClusterSpec)
