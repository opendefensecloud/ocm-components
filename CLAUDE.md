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
- Ensure every component has proper tests written and verified them to be working. This includes deploying the applications to a local kind cluster
- Ensure the Readme.md in the project root is updated with the newly added component
- A github release pipeline for each ocm component is created to create an offline package of the component as described here: https://ocm.software/docs/tutorials/transport-to-air-gapped-environments/#create-offline-package
- Try to find packaged applications within the packaged component's helm chart that might make sense to add as components to the mono repo itself and suggest them in a suggested-components.md file in the project's root directory. Whenever possible try to use fully open source solutions rather than proprietary ones.
