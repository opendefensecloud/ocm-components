# Suggested Components for OCM Monorepo

This file tracks potential cloud-native applications that could be added as OCM components to the monorepo. These suggestions are derived from dependencies and related applications discovered while packaging existing components.

## ✅ Completed Components

### CloudNativePG - COMPLETED ✅

- **Source**: Keycloak component dependency
- **Status**: Packaged as OCM component (v1.27.1)
- **Official Project**: https://cloudnative-pg.io/
- **Operator**: Yes (official CloudNativePG operator)
- **License**: Apache 2.0
- **Maturity**: CNCF Sandbox project, Level V Auto Pilot operator
- **Component**: [cloudnative-pg/](cloudnative-pg/)
- **Use Cases**:
  - Database for Keycloak
  - General PostgreSQL database workloads
  - Microservices requiring PostgreSQL
  - HA database clusters with automated backups

### cert-manager - COMPLETED ✅

- **Source**: Keycloak component dependency (production config)
- **Status**: Packaged as OCM component (v1.19.2)
- **Official Project**: https://cert-manager.io/
- **Operator**: Yes (official cert-manager)
- **License**: Apache 2.0
- **Maturity**: CNCF graduated project
- **Component**: [cert-manager/](cert-manager/)
- **Use Cases**:
  - TLS certificates for Keycloak
  - Certificate management for all services requiring HTTPS
  - Let's Encrypt integration
  - Self-signed certificates for internal services
  - CA-based certificate issuance

## Medium Priority

### External Secrets Operator
- **Source**: Keycloak component best practice (production config)
- **Reason**: Recommended for managing sensitive data (database passwords, API keys) in production. Integrates with external secret management systems (AWS Secrets Manager, HashiCorp Vault, etc.).
- **Official Project**: https://external-secrets.io/
- **Operator**: Yes
- **License**: Apache 2.0
- **Maturity**: CNCF Sandbox project
- **Use Cases**:
  - Keycloak database credentials
  - Secure secret management across all components
  - Integration with cloud provider secret stores

### Prometheus Operator (kube-prometheus-stack)
- **Source**: Keycloak component monitoring (production config)
- **Reason**: Keycloak exposes metrics endpoints. Production deployments need monitoring, alerting, and observability. Includes Prometheus, Grafana, and Alertmanager.
- **Official Project**: https://prometheus-operator.dev/
- **Helm Chart**: prometheus-community/kube-prometheus-stack
- **License**: Apache 2.0
- **Maturity**: CNCF graduated project (Prometheus)
- **Use Cases**:
  - Keycloak metrics and monitoring
  - Cluster-wide monitoring and alerting
  - Application performance monitoring

### Traefik Ingress Controller

- **Source**: Keycloak component ingress (both configs)
- **Reason**: Required for exposing Keycloak (and other services) externally. Modern, actively maintained ingress controller with built-in Let's Encrypt support and Gateway API compatibility.
- **Official Project**: <https://traefik.io/traefik/>
- **Helm Chart**: traefik/traefik
- **License**: MIT
- **Maturity**: CNCF Incubating project, widely adopted
- **Note**: Recommended over kubernetes/ingress-nginx which is being retired in March 2026
- **Use Cases**:
  - HTTP/HTTPS ingress for Keycloak
  - Load balancing and TLS termination
  - Automatic Let's Encrypt integration
  - Ingress for all web-exposed services
  - Gateway API support (future-proof)

## Low Priority (Consider for Future)

### Sealed Secrets
- **Source**: Alternative to External Secrets Operator
- **Reason**: GitOps-friendly secret management (Bitnami)
- **Official Project**: https://github.com/bitnami-labs/sealed-secrets
- **License**: Apache 2.0

### Grafana Loki
- **Source**: Log aggregation for production deployments
- **Reason**: Centralized logging for troubleshooting and auditing
- **Official Project**: https://grafana.com/oss/loki/
- **License**: AGPL-3.0

### HashiCorp Vault
- **Source**: Enterprise secret management
- **Reason**: Advanced secret management, encryption, and PKI
- **Official Project**: https://www.vaultproject.io/
- **License**: BSL 1.1 (Business Source License)

## Dependencies Already Handled

These components are NOT needed because they're already included:

- **PostgreSQL (Ephemeral)**: Included in minimal Keycloak config for dev/test
- **TLS Secrets**: Self-signed cert example provided in minimal config

## Notes

- Components are suggested based on production best practices
- Priority is based on frequency of need across different deployment scenarios
- All suggestions should follow the same standards as the Keycloak component:
  - Official operator/chart when available
  - Both minimal and production configurations
  - Proper testing on kind cluster
  - OCM component descriptor
  - GitHub release pipeline
