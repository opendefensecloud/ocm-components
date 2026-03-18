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
├── cluster-minimal.yaml          # Minimal cluster configuration (dev/test)
├── cluster-production.yaml       # Production cluster configuration (HA)
├── bootstrap.yaml                # KRO bootstrap configuration
├── component-constructor.yaml    # OCM component descriptor
├── rgd-template.yaml             # ResourceGraphDefinition for KRO
└── README.md                     # This file
```

## Quick Start

There are three ways to deploy CloudNativePG, depending on your needs:

1. **RGD/KRO Bootstrap (Recommended)** - Self-contained deployment with automatic image localization
2. **Helm Charts** - Standard Helm-based deployment
3. **Direct Manifests** - Manual Kubernetes manifest deployment

### Method 1: RGD/KRO Bootstrap Deployment (Recommended)

This method uses ResourceGraphDefinitions (RGD) with KRO for a fully automated, self-contained deployment that includes automatic image localization when transferring between registries.

#### Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- OCM K8s Toolkit installed
- KRO (Kubernetes Resource Orchestrator) installed
- FluxCD installed (for HelmRelease support)
- Storage class available

#### Installation

1. **Install prerequisites:**

   ```bash
   # Install cert-manager (required by OCM controller)
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
   kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s
   kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=300s
   kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=300s

   # Install OCM K8s Toolkit
   helm upgrade --install ocm-controller \
     oci://ghcr.io/open-component-model/helm/ocm-controller \
     --version v0.26.0 \
     --namespace ocm-system --create-namespace --wait

   # Install FluxCD
   kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml

   # Install KRO (Kubernetes Resource Orchestrator)
   KRO_VERSION=$(curl -s "https://api.github.com/repos/kro-run/kro/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | tr -d 'v')
   helm install kro oci://public.ecr.aws/kro/kro \
     --namespace kro --create-namespace \
     --version="${KRO_VERSION}" --wait
   ```

2. **Build and transfer OCM component:**

   ```bash
   # Build component archive
   cd cloudnative-pg
   ocm add componentversions --create --file cloudnative-pg-component.ctf component-constructor.yaml

   # Transfer to your OCI registry
   ocm transfer ctf cloudnative-pg-component.ctf oci://your-registry/ocm-components
   ```

3. **Update bootstrap.yaml with your registry URL:**

   ```bash
   # Edit bootstrap.yaml
   vim bootstrap.yaml

   # Update the Repository spec.url to point to your registry:
   spec:
     url: oci://your-registry/ocm-components
   ```

4. **Apply bootstrap configuration:**

   ```bash
   kubectl apply -f bootstrap.yaml
   ```

5. **Verify deployment:**

   ```bash
   # Check RGD was created
   kubectl get rgd

   # Check CloudNativePGBootstrap CRD exists
   kubectl get crd cloudnativepgbootstraps.v1alpha1.kro.run

   # Check bootstrap instance status
   kubectl get CloudNativePGBootstrap cloudnative-pg-minimal

   # Wait for ACTIVE state
   kubectl wait --for=condition=Synced CloudNativePGBootstrap/cloudnative-pg-minimal --timeout=10m

   # Verify operator is running
   kubectl get pods -n cnpg-system

   # Verify PostgreSQL cluster
   kubectl get cluster -n postgres
   kubectl get pods -n postgres
   ```

6. **Get connection credentials:**

   ```bash
   # Username
   kubectl get secret app-user-secret -n postgres -o jsonpath='{.data.username}' | base64 -d

   # Password
   kubectl get secret app-user-secret -n postgres -o jsonpath='{.data.password}' | base64 -d
   ```

7. **Connect to PostgreSQL:**

   ```bash
   # Port forward for local access
   kubectl port-forward -n postgres svc/postgres-minimal-rw 5432:5432

   # Connect
   psql postgresql://app:<password>@localhost:5432/app
   ```

#### Customizing the Bootstrap Deployment

The [bootstrap.yaml](bootstrap.yaml) includes examples for both minimal and production configurations. You can customize the deployment by modifying the `CloudNativePGBootstrap` resource:

```yaml
apiVersion: v1alpha1
kind: CloudNativePGBootstrap
metadata:
  name: my-postgres
  namespace: default
spec:
  # Deployment profile: "minimal" or "production"
  deploymentProfile: production

  # Cluster configuration
  clusterName: my-postgres-cluster
  clusterNamespace: my-app
  instances: 3  # Number of PostgreSQL instances
  postgresVersion: "17"
  storageSize: 100Gi
  storageClass: fast-ssd

  # Enable backups (production)
  backupEnabled: true
  backupDestination: s3://my-bucket/postgres-backup
  backupSecretName: s3-backup-creds

  # Enable monitoring
  monitoringEnabled: true
```

See the [RGD Template](rgd-template.yaml) for all available configuration options.

### Method 2: Helm Chart Deployment

For standard Helm-based deployments without RGD/KRO:

#### Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Helm 3.x installed
- Storage class available

#### Installation

1. **Add CloudNativePG Helm repository:**

   ```bash
   helm repo add cnpg https://cloudnative-pg.github.io/charts
   helm repo update
   ```

2. **Install the operator:**

   ```bash
   helm upgrade --install cnpg cnpg/cloudnative-pg \
     --namespace cnpg-system \
     --create-namespace \
     --wait
   ```

3. **Deploy PostgreSQL cluster:**

   ```bash
   # Minimal configuration
   helm install my-db cnpg/cluster \
     --namespace my-app \
     --create-namespace \
     --set cluster.instances=1 \
     --set cluster.storage.size=1Gi

   # Or production configuration
   helm install my-db cnpg/cluster \
     --namespace my-app \
     --create-namespace \
     --set cluster.instances=3 \
     --set cluster.storage.size=100Gi \
     --set cluster.storage.storageClass=fast-ssd
   ```

### Method 3: Direct Manifest Deployment

For manual deployment using Kubernetes manifests:

#### Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Storage class available

#### Installation

1. **Install the CloudNativePG Operator:**

   ```bash
   # Install the operator using the official Helm chart
   helm repo add cnpg https://cloudnative-pg.github.io/charts
   helm upgrade --install cnpg cnpg/cloudnative-pg \
     --namespace cnpg-system --create-namespace --wait
   ```

2. **Deploy PostgreSQL Cluster (Minimal):**

   ```bash
   kubectl apply -f cluster-minimal.yaml
   ```

   Or for production:

   ```bash
   kubectl apply -f cluster-production.yaml
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

**File**: [`cluster-minimal.yaml`](cluster-minimal.yaml)

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
kubectl apply -f cluster-minimal.yaml
```

### Production Configuration

**File**: [`cluster-production.yaml`](cluster-production.yaml)

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
   kubectl apply -f cluster-production.yaml
   ```

## Advanced Configuration

### Using Helm Charts

CloudNativePG provides official Helm charts for both the operator and clusters. See the [upstream documentation](https://cloudnative-pg.io/documentation/) for complete parameter references.

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
  --values cluster-production.yaml \
  --set cluster.instances=5 \
  --set cluster.storage.size=500Gi
```

## ResourceGraphDefinition (RGD) and KRO

This component includes a ResourceGraphDefinition (RGD) that enables bootstrapping with KRO (Kubernetes Resource Orchestrator). The RGD pattern provides several key benefits:

### Benefits of RGD Deployment

1. **Self-contained Deployment**: All deployment logic is packaged with the OCM component
2. **Automatic Image Localization**: When transferring components between registries, image references are automatically updated
3. **Simplified Operations**: Users only need to apply `bootstrap.yaml` - no manual configuration required
4. **Reproducible Deployments**: Deployment configuration is versioned with the component
5. **Declarative Configuration**: Single YAML file controls the entire deployment

### How RGD Works

The RGD deployment follows a layered architecture:

1. **OCM Layer**: Component resources (Helm charts, container images, RGD template) are stored in OCM registry
2. **Bootstrap Layer**: OCM K8s Toolkit resources (Repository, Component, Resource, Deployer) fetch the RGD from OCM
3. **RGD Execution**: KRO processes the RGD and creates a custom CRD (`CloudNativePGBootstrap`)
4. **Deployment Layer**: FluxCD resources (OCIRepository, HelmRelease) deploy the actual application

### Image Localization

The RGD implements two-step localization:

1. **OCM Transfer**: Use `ocm transfer --copy-resources` flag to transfer components between registries
2. **Runtime Injection**: RGD uses OCM K8s Toolkit Resource objects to extract updated image references and inject them into Helm values

This ensures that when you transfer the component from `registry-a.com` to `registry-b.com`, all image references automatically update without manual intervention.

### Testing the RGD Deployment

To verify the RGD deployment:

1. Create a kind cluster with OCM K8s Toolkit, FluxCD, and KRO installed
2. Build and transfer the OCM component to a local registry
3. Apply the `bootstrap.yaml` to deploy CloudNativePG via RGD bootstrap
4. Verify all resources are created correctly
5. Test PostgreSQL connectivity
6. Validate image localization

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

See the project root README for details on suggested components.

## Testing

### Local Testing with kind

```bash
# Create kind cluster
kind create cluster --name cnpg-test

# Install operator
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system --create-namespace --wait

# Deploy minimal cluster
kubectl apply -f cluster-minimal.yaml

# Verify
kubectl wait --for=condition=Ready cluster/pg-minimal --timeout=300s
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
