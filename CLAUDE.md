# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a monorepo for packaging cloud-native applications as OCM (Open Component Model) components. Each folder in the repository represents a single cloud-native application packaged with:
- The operator (if available)
- Corresponding Helm charts
- All required container images
- Extensive configuration options for controlling operator behavior

### Component Architecture

Components can reference each other to fulfill dependencies rather than duplicating resources. For example:
- The Keycloak component references the CloudNativePG component for database requirements
- This enables composable, reusable infrastructure definitions

## Repository Structure

The monorepo follows a flat structure where each top-level directory represents a separate cloud-native application/component. As the repository grows, expect to find:
- Individual application directories (e.g., `keycloak/`, `cloudnative-pg/`)
- Each application directory will contain OCM component definitions, Helm charts, and configuration

## OCM (Open Component Model)

When working with this repository, be familiar with:
- OCM component descriptor formats and schemas
- How components reference other components as dependencies
- Packaging strategies for operators, Helm charts, and container images

## Development Notes

This repository is in its early stages. When adding new components:
- Try to use the offical helm chart and operator for the component to be added. If multiple options are available gather as much useful information related to maturity, open-source licenses and adoption about the options as possible and present them to me to make an informed decision
- Create a dedicated directory for each cloud-native application
- Package the complete application stack (operator, charts, images)
- Document configuration options thoroughly
- Consider existing components for dependency fulfillment before adding duplicates
- Ensure every component has a minimal default config that just works with minimal overhead and in as many environments as possible
- Ensure every component has an additional production grade config which fully utilizes all available high-availability settings and distributed setup modes of the respective application
- Ensure the ocm component exposes all available configuration parameters of the underlying helm charts and makes them configurable optionally in addition to the provided default configs for simple and production grade setups
- Ensure every component has comprehensive tests written. This includes deploying the applications to a local kind cluster
- **CRITICAL: ALWAYS RUN TESTS** - After creating or modifying any test scripts, ALWAYS run them immediately to verify they work 100%. Debug and fix any issues found before considering the task complete. This is non-negotiable.
- Ensure the created tests are working 100% by running and debugging them extensively
- Ensure the Readme.md in the project root is updated with the newly added component
- A github release pipeline for each ocm component is created to create an offline package of the component as described here: https://ocm.software/docs/tutorials/transport-to-air-gapped-environments/#create-offline-package
- Try to find packaged applications within the packaged component's helm chart that might make sense to add as components to the mono repo itself and suggest them in a suggested-components.md file in the project's root directory. Whenever possible try to use fully open source solutions rather than proprietary ones.

### ResourceGraphDefinitions (RGD) with KRO

Each component should include a ResourceGraphDefinition (RGD) for KRO (Kubernetes Resource Orchestrator) to enable bootstrapping and self-contained deployment. This pattern packages deployment instructions alongside the OCM component itself.

#### RGD Architecture Pattern

Components should follow this layered deployment architecture:

1. **OCM Component Resources**: Package the Helm chart, container images, and the RGD itself as component resources
2. **Bootstrap Layer**: Create `bootstrap.yaml` with OCM K8s Toolkit resources (Repository, Component, Resource, Deployer) that fetch and apply the RGD
3. **RGD Execution**: KRO processes the RGD to generate custom resources for the component
4. **Application Deployment**: FluxCD resources (OCIRepository, HelmRelease) handle the actual Helm chart deployment

#### Essential RGD Template Components

Every RGD should include:

- **Resource objects**: Reference OCM component resources by name (e.g., helm chart, container images) to access their metadata in status fields
- **OCIRepository**: Watch Helm chart location in the OCM registry and download from current registry path
- **HelmRelease**: Consume both the chart location and localized image references for deployment
- **Value injection**: Use Resource object status fields to inject localized image references into Helm values

#### Image Localization Strategy

Implement two-step localization to handle component transfers between registries:

1. **OCM Transfer**: Use `ocm transfer --copy-resources` flag so referential resources automatically update registry locations
2. **Runtime Injection**: RGD uses OCM K8s Toolkit Resource objects to extract updated image references from component metadata and inject them into HelmRelease values

This ensures images are pulled from the correct registry even after component transport.

#### Bootstrap Configuration Requirements

Create a `bootstrap.yaml` in each component directory containing:

- **Repository**: Points to the OCM registry containing the component
- **Component**: References the specific OCM component name and version
- **Resource**: Identifies which OCM resource contains the RGD template
- **Deployer**: Downloads the RGD content and applies it (cluster-scoped operation)
- **Credentials**: Use `ocmConfig` fields or reference a Kubernetes secret of type `dockerconfigjson` for private registry access

#### Credential Management

For private registries, ensure credentials are accessible to both:

- OCM K8s Toolkit resources (Repository, Component, Resource, Deployer)
- FluxCD resources (OCIRepository, HelmRelease)

Use a shared `dockerconfigjson` secret or configure `ocmConfig` in each resource.

#### Testing and Validation

After applying bootstrap resources, verify:

- RGD is created: `kubectl get rgd`
- Custom CRD exists: `kubectl get crd <component-name>.kro.run`
- Bootstrap instance reaches ACTIVE state with SYNCED=True
- Component resources are deployed correctly
- Images are pulled from the correct registry location

#### Benefits of RGD Pattern

This approach provides:

- **Self-contained deployment**: All deployment logic is packaged with the component
- **Registry portability**: Automatic image reference updates when components move between registries
- **Simplified operations**: Users only need to apply bootstrap.yaml, no manual configuration required
- **Reproducible deployments**: Deployment configuration is versioned with the component
- **Declarative dependencies**: RGD can reference other components' resources for dependency fulfillment
