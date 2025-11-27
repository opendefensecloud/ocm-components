# Suggested Components for Artifact Conduit

This document lists components and tools that would complement Artifact Conduit (ARC) or could be packaged as OCM components based on dependencies and common use cases discovered in the Artifact Conduit ecosystem.

## High Priority

### Argo Workflows
- **Status**: Required dependency for ARC
- **Description**: Workflow engine that ARC uses for orchestrating artifact processing pipelines
- **Use Case**: Already required by ARC for executing Order resources
- **License**: Apache 2.0
- **Links**:
  - https://argoproj.github.io/workflows/
  - https://github.com/argoproj/argo-workflows

### cert-manager
- **Status**: Required dependency for ARC
- **Description**: Kubernetes add-on to automate TLS certificate management
- **Use Case**: ARC requires cert-manager for managing certificates for its API server
- **License**: Apache 2.0
- **Links**:
  - https://cert-manager.io/
  - https://github.com/cert-manager/cert-manager

## Medium Priority

### MinIO
- **Status**: Commonly used with ARC
- **Description**: High-performance object storage compatible with Amazon S3 API
- **Use Case**: ARC can use S3-compatible storage as a source/destination for artifacts and for storing backups
- **License**: AGPL v3 (server), Apache 2.0 (client)
- **Links**:
  - https://min.io/
  - https://github.com/minio/minio

### Harbor
- **Status**: Common artifact registry
- **Description**: Cloud-native registry for container images and Helm charts with security scanning
- **Use Case**: Can serve as destination registry for ARC-transferred artifacts, provides vulnerability scanning
- **License**: Apache 2.0
- **CNCF**: Graduated Project
- **Links**:
  - https://goharbor.io/
  - https://github.com/goharbor/harbor

### Prometheus Operator
- **Status**: Recommended for production
- **Description**: Kubernetes operator for Prometheus monitoring
- **Use Case**: ARC exposes Prometheus metrics when enabled in production configuration
- **License**: Apache 2.0
- **CNCF**: Graduated Project (Prometheus)
- **Links**:
  - https://prometheus.io/
  - https://github.com/prometheus-operator/prometheus-operator

### Grafana
- **Status**: Recommended for monitoring
- **Description**: Observability and data visualization platform
- **Use Case**: Visualize ARC metrics and create dashboards for artifact transfer operations
- **License**: AGPL v3
- **Links**:
  - https://grafana.com/
  - https://github.com/grafana/grafana

## Low Priority

### Trivy
- **Status**: Security scanning tool
- **Description**: Comprehensive security scanner for containers and other artifacts
- **Use Case**: Can be integrated with ARC for CVE scanning and vulnerability detection
- **License**: Apache 2.0
- **Links**:
  - https://trivy.dev/
  - https://github.com/aquasecurity/trivy

### Cosign
- **Status**: Artifact signing
- **Description**: Container signing and verification tool
- **Use Case**: ARC can verify artifact signatures as part of policy enforcement
- **License**: Apache 2.0
- **Links**:
  - https://docs.sigstore.dev/cosign/overview/
  - https://github.com/sigstore/cosign

### External Secrets Operator
- **Status**: Secret management
- **Description**: Synchronizes secrets from external secret management systems
- **Use Case**: Manage credentials for ARC's source and destination endpoints
- **License**: Apache 2.0
- **CNCF**: Sandbox Project
- **Links**:
  - https://external-secrets.io/
  - https://github.com/external-secrets/external-secrets

### Velero
- **Status**: Backup solution
- **Description**: Kubernetes backup and disaster recovery
- **Use Case**: Back up ARC configuration and etcd data
- **License**: Apache 2.0
- **CNCF**: Graduated Project
- **Links**:
  - https://velero.io/
  - https://github.com/vmware-tanzu/velero

## Future Considerations

### Kubernetes Resource Orchestrator (KRO)
- **Status**: Already integrated via RGD
- **Description**: Orchestrates complex Kubernetes resource graphs
- **Use Case**: ARC component includes KRO ResourceGraphDefinition for bootstrapping
- **License**: Apache 2.0
- **Links**:
  - https://kro.run/
  - https://github.com/kro-run/kro

### Open Policy Agent (OPA) / Gatekeeper
- **Status**: Policy enforcement
- **Description**: Policy-based control for cloud-native environments
- **Use Case**: Advanced policy enforcement for ARC artifact transfers
- **License**: Apache 2.0
- **CNCF**: Graduated Project
- **Links**:
  - https://www.openpolicyagent.org/
  - https://github.com/open-policy-agent/opa
  - https://open-policy-agent.github.io/gatekeeper/

## Notes

- All components listed here integrate well with the artifact management and security ecosystem
- Priority is based on likelihood of co-deployment with ARC
- Components marked as "Required" are prerequisites for ARC functionality
- Consider containerizing and packaging these as OCM components for air-gapped environments where ARC is deployed
