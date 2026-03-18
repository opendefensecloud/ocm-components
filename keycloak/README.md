# Keycloak OCM Component

This directory contains the OCM (Open Component Model) component for Keycloak, an open-source identity and access management solution.

## Overview

**Keycloak** provides authentication, authorization, and user management capabilities for modern applications and services. This component packages the official Keycloak Operator and provides both minimal and production-grade configurations.

- **Version**: 26.4.5
- **Operator**: Official Keycloak Operator (Quarkus-based)
- **License**: Apache 2.0
- **Homepage**: https://www.keycloak.org

## Directory Structure

```
keycloak/
├── operator/                    # Official Keycloak operator manifests
│   ├── keycloaks-crd.yml       # Keycloak CRD
│   ├── keycloakrealmimports-crd.yml  # Realm import CRD
│   └── operator.yml             # Operator deployment
├── configs/
│   ├── minimal/                 # Minimal configuration
│   │   └── keycloak.yml        # Dev/test setup with ephemeral DB
│   └── production/              # Production configuration
│       └── keycloak.yml        # HA setup with external DB
├── docs/                        # Configuration documentation
│   ├── CR_CONFIGURATION.md     # Complete CR parameter reference (1,604 parameters)
│   ├── QUICK_REFERENCE.md      # Quick lookup tables
│   ├── PARAMETER_TREE.txt      # Visual parameter hierarchy
│   └── ARCHITECTURE.md         # Architecture overview
├── component-constructor.yaml   # OCM component descriptor
└── README.md                    # This file
```

## Quick Start

### Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- For production: External PostgreSQL database

### Installation

1. **Install the Keycloak Operator:**

   ```bash
   kubectl apply -f operator/keycloaks-crd.yml
   kubectl apply -f operator/keycloakrealmimports-crd.yml
   kubectl apply -f operator/operator.yml
   ```

2. **Deploy Keycloak (Minimal):**

   ```bash
   kubectl apply -f configs/minimal/keycloak.yml
   ```

   Or for production:

   ```bash
   kubectl apply -f configs/production/keycloak.yml
   ```

3. **Get admin credentials:**

   ```bash
   kubectl get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.username}' | base64 -d
   kubectl get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d
   ```

4. **Access Keycloak:**

   Forward the port for local access:
   ```bash
   kubectl port-forward -n keycloak svc/keycloak-service 8443:8443
   ```

   Then visit: https://localhost:8443

## Configurations

### Minimal Configuration

**File**: [`configs/minimal/keycloak.yml`](configs/minimal/keycloak.yml)

**Features**:
- Single Keycloak instance
- Ephemeral PostgreSQL (data lost on restart)
- Self-signed TLS certificate
- Minimal resource allocation (500m CPU, 512Mi RAM)
- Development/testing only

**Use Cases**:
- Local development
- Testing and CI/CD
- Proof of concept
- Non-production environments

**Quick Deploy**:
```bash
kubectl apply -f configs/minimal/keycloak.yml
```

### Production Configuration

**File**: [`configs/production/keycloak.yml`](configs/production/keycloak.yml)

**Features**:
- 3 Keycloak replicas for high availability
- External PostgreSQL database (HA recommended)
- TLS with cert-manager integration
- Pod anti-affinity and topology spread
- Resource limits: 2-6 CPU, 1250-2250Mi RAM per pod
- Horizontal Pod Autoscaler (3-10 replicas)
- Pod Disruption Budget
- Metrics and monitoring
- Distributed caching with Infinispan
- Load shedding (max 1000 queued requests)
- Network policies for security

**Prerequisites**:
1. External PostgreSQL database (e.g., CloudNativePG, AWS RDS)
2. cert-manager for TLS certificates
3. Ingress controller (NGINX recommended)
4. Prometheus Operator for metrics (optional)

**Configuration Steps**:

1. Update database connection in the manifest:
   ```yaml
   db:
     host: your-postgres-host.example.com
   ```

2. Update hostnames:
   ```yaml
   hostname:
     hostname: keycloak.example.com
     admin: admin.keycloak.example.com
   ```

3. Configure database credentials (use external secrets in production):
   ```bash
   kubectl create secret generic keycloak-db-secret \
     -n keycloak \
     --from-literal=username=keycloak \
     --from-literal=password='your-secure-password' \
     --from-literal=database=keycloak
   ```

4. Deploy:
   ```bash
   kubectl apply -f configs/production/keycloak.yml
   ```

## Advanced Configuration

The Keycloak Operator provides extensive configuration options through the Keycloak Custom Resource (CR). We provide comprehensive documentation of all available parameters to meet enterprise requirements.

### Configuration Documentation

See [`docs/CR_CONFIGURATION.md`](docs/CR_CONFIGURATION.md) for complete documentation of all 1,604 configuration parameters available in the Keycloak CR, including:

- **Instance Configuration**: Replicas, image, image pull secrets, startup optimization
- **Database Configuration**: Vendor, host, connection pooling, credentials management
- **HTTP/HTTPS Configuration**: Ports, TLS certificates, service annotations
- **Hostname Configuration**: Public hostname, admin URL, backchannel settings
- **Ingress Configuration**: Kubernetes Ingress integration
- **Feature Flags**: Enable/disable Keycloak features
- **Bootstrap Admin**: Initial admin user configuration
- **Cache Configuration**: Infinispan distributed cache settings
- **Environment Variables**: Custom environment variables and options
- **Health Probes**: Liveness, readiness, and startup probe configuration
- **Resource Management**: CPU and memory requests/limits
- **Pod Scheduling**: Affinity, tolerations, topology spread, priority
- **Observability**: Prometheus ServiceMonitor, OpenTelemetry tracing
- **Transactions**: XA datasource configuration
- **TLS Truststores**: Custom certificate trust configuration
- **Network Policy**: Ingress traffic control
- **Import Jobs**: Realm import configuration
- **Update Strategy**: Rolling update configuration
- **Advanced**: Unsupported pod template customization

### Quick Reference

For a concise lookup table of commonly used parameters, see [`docs/QUICK_REFERENCE.md`](docs/QUICK_REFERENCE.md).

### Parameter Tree

For a visual tree structure of all parameters and their relationships, see [`docs/PARAMETER_TREE.txt`](docs/PARAMETER_TREE.txt).

### Example: Custom Configuration

Here's an example of using advanced configuration options:

```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak-custom
  namespace: keycloak
spec:
  instances: 3

  # Custom image
  image: quay.io/keycloak/keycloak:26.4.5
  imagePullSecrets:
    - name: registry-credentials

  # Database with connection pooling
  db:
    vendor: postgres
    host: postgres-ha-rw.postgres.svc
    port: 5432
    database: keycloak
    poolMinSize: 10
    poolMaxSize: 100
    poolInitialSize: 20
    usernameSecret:
      name: keycloak-db-secret
      key: username
    passwordSecret:
      name: keycloak-db-secret
      key: password

  # TLS configuration
  http:
    tlsSecret: keycloak-tls-secret
    httpPort: 8080
    httpsPort: 8443

  # Hostname configuration
  hostname:
    hostname: keycloak.example.com
    admin: admin-keycloak.example.com
    strict: true
    strictBackchannel: true

  # Enable specific features
  features:
    enabled:
      - docker
      - token-exchange
      - admin-fine-grained-authz
    disabled:
      - impersonation

  # Resource limits
  resources:
    requests:
      cpu: "2"
      memory: "2Gi"
    limits:
      cpu: "4"
      memory: "4Gi"

  # OpenTelemetry tracing
  additionalOptions:
    - name: tracing-enabled
      value: "true"
    - name: tracing-endpoint
      value: "http://jaeger-collector:4317"
    - name: tracing-protocol
      value: "grpc"
    - name: tracing-sampler-type
      value: "traceidratio"
    - name: tracing-sampler-ratio
      value: "1.0"

  # Ingress configuration
  ingress:
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    ingressClassName: nginx
```

For more examples and detailed parameter descriptions, see the configuration documentation.

## OCM Component

This Keycloak installation is packaged as an OCM component.

### Building the Component

```bash
# From the keycloak directory
ocm add componentversions --create --file keycloak-component.ctf component-constructor.yaml
```

### Transferring to Air-Gapped Environments

```bash
# Create Common Transport Archive
ocm transfer ctf keycloak-component.ctf oci://your-registry/ocm-components

# In air-gapped environment
ocm transfer oci://your-registry/ocm-components ctf keycloak-airgapped.ctf
```

## Included Resources

This OCM component includes:

1. **Keycloak Operator CRDs** (v26.4.5)
   - Keycloak Custom Resource Definition
   - KeycloakRealmImport Custom Resource Definition

2. **Keycloak Operator** (v26.4.5)
   - Deployment, RBAC, ServiceAccount
   - ClusterRoles and RoleBindings

3. **Container Images**
   - `quay.io/keycloak/keycloak-operator:26.4.5`
   - `quay.io/keycloak/keycloak:26.4.5`

4. **Configurations**
   - Minimal (dev/test) configuration
   - Production HA configuration

## Dependencies

The following components are recommended for production deployments:

### Required
- **PostgreSQL Database**: CloudNativePG operator (suggested component)
  - For HA, use external database or CloudNativePG cluster

### Recommended for Production
- **cert-manager**: Automated TLS certificate management
- **NGINX Ingress Controller**: HTTP/HTTPS ingress
- **External Secrets Operator**: Secure secret management
- **Prometheus Operator**: Monitoring and metrics

See the project root README for details on suggested components.

## Monitoring

### Metrics Endpoint

Keycloak exposes Prometheus metrics at `/metrics` when enabled:

```yaml
spec:
  metrics:
    enabled: true
```

### ServiceMonitor

Production configuration includes a ServiceMonitor for automatic Prometheus scraping:

```bash
kubectl get servicemonitor -n keycloak
```

### Key Metrics
- `keycloak_logins_total`: Total number of login attempts
- `keycloak_registrations_total`: User registrations
- `jvm_memory_used_bytes`: JVM memory usage
- `http_server_requests_seconds`: HTTP request duration

## Security

### Production Security Checklist

- [ ] Change default admin credentials immediately
- [ ] Enable MFA for admin accounts
- [ ] Use external secrets management (External Secrets Operator)
- [ ] Configure proper TLS certificates (cert-manager)
- [ ] Enable Network Policies
- [ ] Use security contexts (runAsNonRoot, drop ALL capabilities)
- [ ] Regular security updates
- [ ] Configure rate limiting on ingress
- [ ] Enable audit logging
- [ ] Review and disable unused features

### Security Context

Both configurations use hardened security contexts:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

## Troubleshooting

### Check Operator Status

```bash
kubectl get pods -n keycloak -l app=keycloak-operator
kubectl logs -n keycloak -l app=keycloak-operator
```

### Check Keycloak Status

```bash
kubectl get keycloak -n keycloak
kubectl describe keycloak -n keycloak keycloak
```

### View Keycloak Logs

```bash
kubectl logs -n keycloak -l app=keycloak-app
```

### Common Issues

**Pods not starting**:
- Check database connectivity
- Verify secrets are created
- Review resource limits

**Cannot access Keycloak**:
- Verify ingress configuration
- Check TLS certificates
- Ensure hostname is correctly configured

**Database connection failures**:
- Verify database credentials in secret
- Check network policies
- Ensure database is accessible from cluster

## Upgrading

### Operator Upgrade

1. Download new operator manifests:
   ```bash
   curl -sL https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/NEW_VERSION/kubernetes/kubernetes.yml -o operator/operator.yml
   ```

2. Apply updated manifests:
   ```bash
   kubectl apply -f operator/keycloaks-crd.yml
   kubectl apply -f operator/keycloakrealmimports-crd.yml
   kubectl apply -f operator/operator.yml
   ```

### Keycloak Version Upgrade

Update the image version in your Keycloak CR:

```yaml
spec:
  image: quay.io/keycloak/keycloak:NEW_VERSION
```

The operator will perform a rolling update automatically.

## Testing

### Local Testing with kind

```bash
# Create kind cluster
kind create cluster --name keycloak-test

# Install operator
kubectl apply -f operator/keycloaks-crd.yml
kubectl apply -f operator/keycloakrealmimports-crd.yml
kubectl apply -f operator/operator.yml

# Deploy minimal config
kubectl apply -f configs/minimal/keycloak.yml

# Verify
kubectl wait --for=condition=Ready keycloak/keycloak -n keycloak --timeout=300s
```

## References

- [Keycloak Official Documentation](https://www.keycloak.org/documentation)
- [Keycloak Operator Guide](https://www.keycloak.org/operator/installation)
- [Keycloak High Availability Guide](https://www.keycloak.org/high-availability/multi-cluster/deploy-keycloak-kubernetes)
- [OCM Documentation](https://ocm.software/docs/)

## Support

- **Keycloak Issues**: https://github.com/keycloak/keycloak/issues
- **Operator Issues**: https://github.com/keycloak/keycloak/issues (use operator label)
- **OCM Issues**: https://github.com/open-component-model/ocm/issues

## License

This OCM component packaging is provided under the same Apache 2.0 license as Keycloak.

Keycloak is a registered trademark of Red Hat, Inc.
