# CloudNativePG OCM Component

This directory contains the OCM (Open Component Model) component for CloudNativePG, a comprehensive platform for managing PostgreSQL databases within Kubernetes environments.

## Overview

**CloudNativePG** is a Kubernetes operator that covers the full lifecycle of a highly available PostgreSQL database cluster with a primary/standby architecture, using native streaming replication.

- **Version**: 1.27.1
- **Operator**: Official CloudNativePG Operator
- **License**: Apache 2.0
- **CNCF Status**: Sandbox Project
- **Operator Maturity**: Level V - Auto Pilot
- **GitHub Stars**: 7.4k+
- **Homepage**: https://cloudnative-pg.io

## Directory Structure

```
cloudnative-pg/
├── operator/                    # CloudNativePG operator manifests
│   ├── cnpg-operator.yml       # Operator deployment
│   ├── values.yaml             # Operator Helm chart values
│   └── cluster-values.yaml     # Cluster Helm chart values
├── configs/
│   ├── minimal/                 # Minimal configuration
│   │   └── cluster.yaml        # Single instance for dev/test
│   └── production/              # Production configuration
│       └── cluster.yaml        # HA with 3 replicas, backups, monitoring
├── examples/                    # Usage examples
├── tests/                       # Test scripts
├── docs/
│   └── HELM_CHART_CONFIG.md    # Complete Helm chart configuration guide
├── component-constructor.yaml   # OCM component descriptor
└── README.md                    # This file
```

## Quick Start

### Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Storage class available

### Installation

1. **Install the CloudNativePG Operator:**

   ```bash
   kubectl apply --server-side -f operator/cnpg-operator.yml
   ```

2. **Deploy PostgreSQL Cluster (Minimal):**

   ```bash
   kubectl apply -f configs/minimal/cluster.yaml
   ```

   Or for production:

   ```bash
   kubectl apply -f configs/production/cluster.yaml
   ```

3. **Get connection credentials:**

   ```bash
   # Username
   kubectl get secret app-user-secret -n postgres -o jsonpath='{.data.username}' | base64 -d

   # Password
   kubectl get secret app-user-secret -n postgres -o jsonpath='{.data.password}' | base64 -d
   ```

4. **Connect to PostgreSQL:**

   ```bash
   # Port forward for local access
   kubectl port-forward -n postgres svc/postgres-minimal-rw 5432:5432

   # Connect
   psql postgresql://app:changeme@localhost:5432/app
   ```

## Configurations

### Minimal Configuration

**File**: [`configs/minimal/cluster.yaml`](configs/minimal/cluster.yaml)

**Features**:
- Single PostgreSQL instance
- 1GB storage
- PostgreSQL 17 (latest)
- Minimal resource allocation (256Mi RAM, 100m CPU)
- No backups
- No monitoring
- Development/testing only

**Use Cases**:
- Local development
- CI/CD testing
- Proof of concept
- Non-critical environments

**Quick Deploy**:
```bash
kubectl apply -f configs/minimal/cluster.yaml
```

### Production Configuration

**File**: [`configs/production/cluster.yaml`](configs/production/cluster.yaml)

**Features**:
- 3 PostgreSQL instances (HA)
- 100GB data storage + 20GB WAL storage
- PostgreSQL 17 with production tuning
- Synchronous replication (1-2 replicas)
- Automated S3 backups with 30-day retention
- Daily scheduled backups
- Prometheus monitoring with custom queries
- PgBouncer connection pooling
- Pod anti-affinity across zones
- Network policies for security
- PodDisruptionBudget (min 2 available)
- Resource limits: 4-8GB RAM, 2-4 CPU per pod

**Prerequisites**:
1. Fast storage class (SSD recommended)
2. S3-compatible object storage for backups
3. Prometheus Operator for monitoring (optional)
4. External Secrets Operator for credentials (recommended)

**Configuration Steps**:

1. Create S3 credentials secret:
   ```bash
   kubectl create secret generic s3-backup-creds \
     -n postgres-production \
     --from-literal=ACCESS_KEY_ID='your-access-key' \
     --from-literal=SECRET_ACCESS_KEY='your-secret-key' \
     --from-literal=REGION='us-east-1'
   ```

2. Update S3 backup path in the manifest:
   ```yaml
   backup:
     barmanObjectStore:
       destinationPath: s3://your-bucket-name/postgres-ha
   ```

3. Update storage class names:
   ```yaml
   storage:
     storageClass: fast-ssd  # Your storage class
   ```

4. Deploy:
   ```bash
   kubectl apply -f configs/production/cluster.yaml
   ```

## Advanced Configuration

### Using Helm Charts

CloudNativePG provides official Helm charts for both the operator and clusters. See [`docs/HELM_CHART_CONFIG.md`](docs/HELM_CHART_CONFIG.md) for complete documentation on:

- All available operator parameters
- All available cluster parameters
- Custom configuration examples
- Hybrid OCM + Helm approach

**Example - Custom Helm deployment**:

```bash
# Add Helm repository
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

# Install operator with custom values
helm install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace \
  --set replicaCount=2 \
  --set monitoring.podMonitorEnabled=true

# Deploy cluster with custom values
helm install my-db cnpg/cluster \
  --namespace my-app \
  --values configs/production/cluster.yaml \
  --set cluster.instances=5 \
  --set cluster.storage.size=500Gi
```

## OCM Component

This PostgreSQL installation is packaged as an OCM component.

### Building the Component

```bash
# From the cloudnative-pg directory
ocm add componentversions --create --file ../cloudnative-pg-component.ctf component-constructor.yaml
```

### Transferring to Air-Gapped Environments

```bash
# Create Common Transport Archive
ocm transfer ctf cloudnative-pg-component.ctf oci://your-registry/ocm-components

# In air-gapped environment
ocm transfer oci://your-registry/ocm-components ctf cloudnative-pg-airgapped.ctf
```

## Included Resources

This OCM component includes:

1. **CloudNativePG Operator** (v1.27.1)
   - Operator deployment manifests
   - CRDs for Cluster, Backup, ScheduledBackup, Pooler
   - RBAC configuration

2. **Helm Chart Values**
   - Complete operator chart values
   - Complete cluster chart values
   - Documentation for all parameters

3. **Container Images**
   - `ghcr.io/cloudnative-pg/cloudnative-pg:1.27.1` (operator)
   - `ghcr.io/cloudnative-pg/postgresql:17` (PostgreSQL 17)
   - `ghcr.io/cloudnative-pg/postgresql:16` (PostgreSQL 16)
   - `ghcr.io/cloudnative-pg/postgresql:15` (PostgreSQL 15)

4. **Configurations**
   - Minimal (dev/test) configuration
   - Production HA configuration

5. **Documentation**
   - Complete Helm chart configuration guide
   - Architecture and best practices

## Features

### High Availability
- Primary/standby architecture with streaming replication
- Automatic failover and switchover
- Synchronous replication support (zero data loss)
- Pod anti-affinity for fault tolerance
- PodDisruptionBudget for controlled maintenance

### Backup & Recovery
- Continuous backup to S3/Azure/GCS object stores
- Point-In-Time Recovery (PITR)
- Volume snapshot backups
- Automated scheduled backups
- Configurable retention policies

### Monitoring
- Prometheus metrics exporter
- Custom SQL queries support
- Grafana dashboard integration
- JSON-formatted logs
- PodMonitor for automatic discovery

### Connection Pooling
- Integrated PgBouncer support
- Transaction/session/statement pooling modes
- Configurable pool sizes

### Security
- TLS encryption for connections
- Certificate management
- Network policies
- Pod security contexts
- Secret management integration

## Common Operations

### Scaling

```bash
# Scale to 5 replicas
kubectl patch cluster postgres-ha -n postgres-production \
  --type merge \
  --patch '{"spec":{"instances":5}}'
```

### Manual Backup

```bash
# Create immediate backup
kubectl create -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: manual-backup-$(date +%Y%m%d-%H%M%S)
  namespace: postgres-production
spec:
  cluster:
    name: postgres-ha
EOF
```

### Point-in-Time Recovery

See production config for recovery bootstrap configuration example.

### Switchover

```bash
# Promote a standby to primary
kubectl cnpg promote postgres-ha -n postgres-production <pod-name>
```

## Monitoring

### Prometheus Metrics

CloudNativePG exposes metrics at `/metrics` on port 9187:

- `cnpg_pg_replication_lag` - Replication lag in seconds
- `cnpg_pg_database_size_bytes` - Database size
- `cnpg_backends_total` - Active connections
- `cnpg_pg_stat_archiver` - WAL archiving stats
- Plus standard PostgreSQL metrics

### Custom Queries

Production config includes custom Prometheus queries for:
- Replication lag monitoring
- Database size tracking
- Slow query detection

## Troubleshooting

### Check Operator Status

```bash
kubectl get pods -n cnpg-system
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
```

### Check Cluster Status

```bash
kubectl get cluster -n postgres
kubectl describe cluster postgres-minimal -n postgres
```

### View Cluster Pods

```bash
kubectl get pods -n postgres -l cnpg.io/cluster=postgres-minimal
```

### Check Logs

```bash
# Primary pod logs
kubectl logs -n postgres postgres-minimal-1

# Follow logs
kubectl logs -n postgres postgres-minimal-1 -f
```

### Common Issues

**Operator not starting**:
- Check RBAC permissions
- Verify webhook configuration
- Check for port 9443 conflicts (GKE)

**Cluster pods not starting**:
- Check storage class availability
- Verify PVC creation
- Check resource quotas

**Backup failures**:
- Verify S3 credentials
- Check network connectivity to S3
- Review barman logs in pod

**Replication lag**:
- Check network connectivity between pods
- Verify storage performance
- Review PostgreSQL logs for issues

## PostgreSQL Version Support

CloudNativePG supports multiple PostgreSQL versions:

- **PostgreSQL 17** (recommended for new deployments)
- **PostgreSQL 16**
- **PostgreSQL 15**

Specify version in cluster spec:
```yaml
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:17
```

## Performance Tuning

See production configuration for recommended PostgreSQL parameters:

- `shared_buffers`: 2GB (25% of available RAM)
- `effective_cache_size`: 6GB (75% of available RAM)
- `work_mem`: 16MB per operation
- `maintenance_work_mem`: 512MB
- `max_wal_size`: 4GB
- `checkpoint_completion_target`: 0.9

Adjust based on your workload and available resources.

## Dependencies

### Required
- Storage class with dynamic provisioning

### Recommended for Production
- S3-compatible object storage (AWS S3, MinIO, etc.)
- Prometheus Operator for monitoring
- External Secrets Operator for credential management
- cert-manager for TLS certificates

See [`../suggested-components.md`](../suggested-components.md) for details.

## Testing

See [`tests/`](tests/) directory for test scripts.

### Local Testing with kind

```bash
# Create kind cluster
kind create cluster --name cnpg-test

# Run tests
cd tests
./test-minimal.sh
```

## Upgrading

### Operator Upgrade

```bash
# Download new operator manifest
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.28/releases/cnpg-1.28.0.yaml
```

### PostgreSQL Version Upgrade

Update the `imageName` in your cluster spec:

```yaml
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:17
```

The operator will perform a rolling upgrade automatically.

## References

- [CloudNativePG Official Documentation](https://cloudnative-pg.io/documentation/)
- [CloudNativePG GitHub](https://github.com/cloudnative-pg/cloudnative-pg)
- [CloudNativePG Helm Charts](https://github.com/cloudnative-pg/charts)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [OCM Documentation](https://ocm.software/docs/)

## Support

- **CloudNativePG Issues**: https://github.com/cloudnative-pg/cloudnative-pg/issues
- **Slack**: #cloudnativepg on Kubernetes Slack
- **OCM Issues**: https://github.com/open-component-model/ocm/issues

## License

This OCM component packaging is provided under the same Apache 2.0 license as CloudNativePG.

CloudNativePG is a registered trademark of the Cloud Native Computing Foundation.
