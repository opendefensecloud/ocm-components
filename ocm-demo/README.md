# ocm-demo

A minimal example OCM component used to demonstrate the packaging, transfer, and runtime image-localization flow used by this monorepo. It is intentionally trivial: a single Helm chart that deploys an `nginx` Pod and Service.

## Contents

- `component-constructor.yaml` — OCM component descriptor (`opendefense.cloud/ocm-demo`)
- `charts/demo/` — minimal Helm chart deploying `nginx`
- `values.yaml.tpl` — Helm values template that consumes the localized `nginx-image` reference from the component's OCI resources, so the chart pulls from whichever registry the component currently lives in
- `nginx-image` — referential `ociImage` resource (`ghcr.io/linuxserver/nginx:1.28.3`); rewritten on `ocm transfer --copy-resources`

## Build locally

```bash
cd ocm-demo
ocm add componentversion --version 0.1.0 --create --file ./ctf component-constructor.yaml
```

## Transfer to a registry

```bash
ocm transfer ctf --copy-local-resources ./ctf ghcr.io/<owner>
```

Releases are produced automatically by `.github/workflows/release-ocm-components.yml` when a `v*` tag is pushed.
