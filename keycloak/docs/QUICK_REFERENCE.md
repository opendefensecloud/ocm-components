# Keycloak CR Quick Reference
## Keycloak Operator v26.4.5

Quick reference guide for the most commonly used Keycloak Custom Resource parameters.

## Essential Configuration Parameters

### Basic Deployment
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `spec.instances` | integer | Number of Keycloak replicas | `3` |
| `spec.image` | string | Custom Keycloak image | `quay.io/keycloak/keycloak:26.4.5` |
| `spec.imagePullSecrets` | array | Image pull secrets | `[{name: "my-secret"}]` |

### Database Configuration
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `spec.db.vendor` | string | Database vendor | `postgres`, `mysql`, `mariadb`, `mssql` |
| `spec.db.host` | string | Database hostname | `postgres.default.svc.cluster.local` |
| `spec.db.port` | integer | Database port | `5432` |
| `spec.db.database` | string | Database name | `keycloak` |
| `spec.db.usernameSecret` | object | Username secret reference | `{name: "db-creds", key: "username"}` |
| `spec.db.passwordSecret` | object | Password secret reference | `{name: "db-creds", key: "password"}` |
| `spec.db.poolMinSize` | integer | Min connection pool size | `10` |
| `spec.db.poolMaxSize` | integer | Max connection pool size | `50` |

### HTTP/HTTPS Configuration
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `spec.http.httpEnabled` | boolean | Enable HTTP listener | `false` |
| `spec.http.httpPort` | integer | HTTP port | `8080` |
| `spec.http.httpsPort` | integer | HTTPS port | `8443` |
| `spec.http.tlsSecret` | string | TLS certificate secret | `keycloak-tls-secret` |

### Hostname Configuration
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `spec.hostname.hostname` | string | Public hostname | `keycloak.example.com` |
| `spec.hostname.admin` | string | Admin console hostname | `admin.keycloak.example.com` |
| `spec.hostname.strict` | boolean | Disable dynamic hostname | `true` |
| `spec.hostname.backchannelDynamic` | boolean | Dynamic backchannel URLs | `false` |

### Ingress Configuration
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `spec.ingress.enabled` | boolean | Enable/disable ingress | `true` |
| `spec.ingress.className` | string | Ingress class | `nginx` |
| `spec.ingress.annotations` | object | Ingress annotations | `{cert-manager.io/cluster-issuer: "letsencrypt"}` |

### Resource Management
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `spec.resources.requests.cpu` | string | CPU request | N/A |
| `spec.resources.requests.memory` | string | Memory request | `1700Mi` |
| `spec.resources.limits.cpu` | string | CPU limit | N/A |
| `spec.resources.limits.memory` | string | Memory limit | `2Gi` |

### Health Probes
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `spec.readinessProbe.periodSeconds` | integer | Readiness check interval | `10` |
| `spec.readinessProbe.failureThreshold` | integer | Readiness failure threshold | `3` |
| `spec.livenessProbe.periodSeconds` | integer | Liveness check interval | `10` |
| `spec.livenessProbe.failureThreshold` | integer | Liveness failure threshold | `3` |
| `spec.startupProbe.periodSeconds` | integer | Startup check interval | `1` |
| `spec.startupProbe.failureThreshold` | integer | Startup failure threshold | `600` |

### Features
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `spec.features.enabled` | array | Enabled features | `["token-exchange", "authorization"]` |
| `spec.features.disabled` | array | Disabled features | `["admin-fine-grained-authz"]` |

### Monitoring & Tracing
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `spec.serviceMonitor.enabled` | boolean | Enable ServiceMonitor | `true` |
| `spec.serviceMonitor.interval` | string | Scrape interval | `30s` |
| `spec.tracing.enabled` | boolean | Enable OpenTelemetry | `true` |
| `spec.tracing.endpoint` | string | Tracing endpoint | `http://jaeger:4317` |
| `spec.tracing.samplerRatio` | number | Trace sample ratio | `0.1` |

### Advanced Configuration
| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `spec.additionalOptions` | array | Additional Keycloak options | See below |
| `spec.env` | array | Environment variables | See below |
| `spec.proxy.headers` | string | Proxy header mode | `xforwarded` or `forwarded` |

## Minimal Production Example

```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
spec:
  instances: 2
  db:
    vendor: postgres
    host: postgres.database.svc
    database: keycloak
    usernameSecret:
      name: keycloak-db-secret
      key: username
    passwordSecret:
      name: keycloak-db-secret
      key: password
  http:
    tlsSecret: keycloak-tls-secret
  hostname:
    hostname: keycloak.example.com
    strict: true
  resources:
    requests:
      cpu: "1"
      memory: "1Gi"
    limits:
      memory: "2Gi"
```

## Additional Options Example

Use `additionalOptions` for any Keycloak configuration not available as a dedicated field:

```yaml
spec:
  additionalOptions:
    - name: spi-connections-http-client-default-connection-pool-size
      value: "50"
    - name: db-password
      secret:
        name: db-secret
        key: password
```

## Environment Variables Example

```yaml
spec:
  env:
    - name: JAVA_OPTS_APPEND
      value: "-Djava.net.preferIPv4Stack=true -Xms1024m -Xmx2048m"
    - name: KC_LOG_LEVEL
      value: "INFO"
```

## Pod Scheduling Example

```yaml
spec:
  scheduling:
    priorityClassName: high-priority
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: keycloak
          topologyKey: kubernetes.io/hostname
    tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "keycloak"
      effect: "NoSchedule"
```

## Network Policy Example

```yaml
spec:
  networkPolicy:
    enabled: true
    https:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    management:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
```

## Reference Links

- [Keycloak Operator Documentation](https://www.keycloak.org/operator/installation)
- [Keycloak Server Configuration](https://www.keycloak.org/server/all-config)
- [CRD Source (v26.4.5)](https://github.com/keycloak/keycloak-k8s-resources/tree/26.4.5)

## Notes

1. **Database is required**: The operator does not provision databases. You must provide an external database.
2. **TLS is required for production**: Always use TLS secrets for production deployments.
3. **Default memory**: If not specified, defaults are 1700MiB request and 2GiB limit.
4. **Secrets format**: Use standard Kubernetes TLS secrets (containing `tls.crt` and `tls.key`).
5. **Proxy headers**: Set to `xforwarded` or `forwarded` when behind a reverse proxy.
