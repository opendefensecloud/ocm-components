# ocm-monorepo

A monorepo for ocm packages.

This repository packages various cloud-native applications as an OCM (Open Component Model) component, including the operator (if available), the corresponding helm charts, all required container images, and extensive configuration options for controlling operator behavior and the applications they roll out. Each folder within the repository represents a single cloud-native application. The application can reference themselves. For instance the application "Keycloak" requires a postgresql database like the one delivered by CloudNativePG. The keycloak OCM component then can rather reference the CloudNativePG component to fullfil this requirement than including a database by itself.
