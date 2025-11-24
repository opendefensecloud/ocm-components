# Keycloak Custom Resource (CR) Complete Configuration Reference
## Keycloak Operator v26.4.5

This comprehensive reference documents all configuration parameters available in the Keycloak Custom Resource.
Each parameter includes its type, description, default value (if applicable), and practical examples.

---

## Instance Configuration

Configure the number of Keycloak instances, container images, and optimization settings.


#### `spec.instances`

| Property | Value |
|----------|-------|
| **Type** | `integer` |
| **Description** | Number of Keycloak instances. Default is 1. |

**Example:**
```yaml
instances: 3
```


#### `spec.image`

| Property | Value |
|----------|-------|
| **Type** | `string` |
| **Description** | Custom Keycloak image to be used. |

**Example:**
```yaml
image: quay.io/keycloak/keycloak:26.4.5
```


#### `spec.imagePullSecrets`

| Property | Value |
|----------|-------|
| **Type** | `array of object` |
| **Description** | Secret(s) that might be used when pulling an image from a private container image registry or repository. |

**Example:**
```yaml
imagePullSecrets: - name: my-registry-secret
```


#### `spec.startOptimized`

| Property | Value |
|----------|-------|
| **Type** | `boolean` |
| **Description** | Set to force the behavior of the --optimized flag for the start command. If left unspecified the operator will assume custom images have already been augmented. |

**Example:**
```yaml
startOptimized: true
```

## Database Configuration

Complete database connectivity configuration including vendor, connection pooling, and credentials management.


#### `spec.db`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can find all properties related to connect to a database. |

**Example:**
```yaml
db: (see nested properties below)
```

**Nested Properties:**

- **`database`** (`string`): Sets the database name of the default JDBC URL of the chosen vendor. If the `url` option is set, this option is ignored.
  ```yaml
  database: keycloak
  ```
- **`host`** (`string`): Sets the hostname of the default JDBC URL of the chosen vendor. If the `url` option is set, this option is ignored.
  ```yaml
  host: postgres.database.svc.cluster.local
  ```
- **`passwordSecret`** (`object`): The reference to a secret holding the password of the database user.
  ```yaml
  passwordSecret: name: keycloak-db-secret
      key: password
  ```
- **`poolInitialSize`** (`integer`): The initial size of the connection pool.
  ```yaml
  poolInitialSize: 5
  ```
- **`poolMaxSize`** (`integer`): The maximum size of the connection pool.
  ```yaml
  poolMaxSize: 20
  ```
- **`poolMinSize`** (`integer`): The minimal size of the connection pool.
  ```yaml
  poolMinSize: 5
  ```
- **`port`** (`integer`): Sets the port of the default JDBC URL of the chosen vendor. If the `url` option is set, this option is ignored.
  ```yaml
  port: 5432
  ```
- **`schema`** (`string`): The database schema to be used.
  ```yaml
  schema: public
  ```
- **`url`** (`string`): The full database JDBC URL. If not provided, a default URL is set based on the selected database vendor. For instance, if using 'postgres', the default JDBC URL would be 'jdbc:postgresql://localhost/keycloak'.
  ```yaml
  url: jdbc:postgresql://postgres.database.svc:5432/keycloak
  ```
- **`usernameSecret`** (`object`): The reference to a secret holding the username of the database user.
  ```yaml
  usernameSecret: name: keycloak-db-secret
      key: username
  ```
- **`vendor`** (`string`): The database vendor.
  ```yaml
  vendor: postgres
  ```

## HTTP/HTTPS Configuration

HTTP/HTTPS listeners, ports, TLS configuration, and reverse proxy settings.


#### `spec.http`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak features related to HTTP and HTTPS |

**Example:**
```yaml
http: (see nested properties below)
```

**Nested Properties:**

- **`annotations`** (`object`): Annotations to be appended to the Service object
  ```yaml
  annotations: nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
  ```
- **`httpEnabled`** (`boolean`): Enables the HTTP listener.
  ```yaml
  httpEnabled: true
  ```
- **`httpPort`** (`integer`): The used HTTP port.
  ```yaml
  httpPort: 8080
  ```
- **`httpsPort`** (`integer`): The used HTTPS port.
  ```yaml
  httpsPort: 8443
  ```
- **`labels`** (`object`): Labels to be appended to the Service object
  ```yaml
  labels: app: keycloak
      environment: production
  ```
- **`tlsSecret`** (`string`): A secret containing the TLS configuration for HTTPS. Reference: https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets.
  ```yaml
  tlsSecret: keycloak-tls-secret
  ```


#### `spec.httpManagement`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak's management interface setting. |

**Example:**
```yaml
httpManagement: (see nested properties below)
```

**Nested Properties:**

- **`port`** (`integer`): Port of the management interface.
  ```yaml
  port: 9000
  ```


#### `spec.proxy`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak's reverse proxy setting |

**Example:**
```yaml
proxy: (see nested properties below)
```

**Nested Properties:**

- **`headers`** (`string`): The proxy headers that should be accepted by the server. Misconfiguration might leave the server exposed to security vulnerabilities.
  ```yaml
  headers: xforwarded
  ```

## Hostname Configuration

Frontend and backchannel hostname configuration for external and internal access.


#### `spec.hostname`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak hostname and related properties. |

**Example:**
```yaml
hostname: (see nested properties below)
```

**Nested Properties:**

- **`admin`** (`string`): The hostname for accessing the administration console. Applicable for Hostname v1 and v2.
  ```yaml
  admin: admin.keycloak.example.com
  ```
- **`adminUrl`** (`string`): DEPRECATED. Sets the base URL for accessing the administration console, including scheme, host, port and path. Applicable for Hostname v1.
- **`backchannelDynamic`** (`boolean`): Enables dynamic resolving of backchannel URLs, including hostname, scheme, port and context path. Set to true if your application accesses Keycloak via a private network. Applicable for Hostname v2.
  ```yaml
  backchannelDynamic: false
  ```
- **`hostname`** (`string`): Hostname for the Keycloak server. Applicable for Hostname v1 and v2.
  ```yaml
  hostname: keycloak.example.com
  ```
- **`strict`** (`boolean`): Disables dynamically resolving the hostname from request headers. Applicable for Hostname v1 and v2.
  ```yaml
  strict: true
  ```
- **`strictBackchannel`** (`boolean`): DEPRECATED. By default backchannel URLs are dynamically resolved from request headers to allow internal and external applications. Applicable for Hostname v1.

## Ingress Configuration

Kubernetes Ingress resource configuration for external access to Keycloak.


#### `spec.ingress`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | The deployment is, by default, exposed through a basic ingress. You can change this behaviour by setting the enabled property to false. |

**Example:**
```yaml
ingress: (see nested properties below)
```

**Nested Properties:**

- **`annotations`** (`object`): Additional annotations to be appended to the Ingress object
  ```yaml
  annotations: cert-manager.io/cluster-issuer: letsencrypt-prod
  ```
- **`className`** (`string`): No description available
  ```yaml
  className: nginx
  ```
- **`enabled`** (`boolean`): No description available
  ```yaml
  enabled: true
  ```
- **`labels`** (`object`): Additional labels to be appended to the Ingress object
- **`tlsSecret`** (`string`): A secret containing the TLS configuration for re-encrypt or TLS termination scenarios. Reference: https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets.
  ```yaml
  tlsSecret: keycloak-ingress-tls
  ```

## Features

Enable or disable specific Keycloak features and capabilities.


#### `spec.features`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak features, which should be enabled/disabled. |

**Example:**
```yaml
features: (see nested properties below)
```

**Nested Properties:**

- **`disabled`** (`array of string`): Disabled Keycloak features
  ```yaml
  disabled: - admin-fine-grained-authz
    - step-up-authentication
  ```
- **`enabled`** (`array of string`): Enabled Keycloak features
  ```yaml
  enabled: - docker
    - authorization
    - token-exchange
  ```

## Bootstrap Admin

Initial admin user and service account configuration for cluster bootstrap.


#### `spec.bootstrapAdmin`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak's bootstrap admin - will be used only for initial cluster creation. |

**Example:**
```yaml
bootstrapAdmin: (see nested properties below)
```

**Nested Properties:**

- **`service`** (`object`): Configures the bootstrap admin service account
- **`user`** (`object`): Configures the bootstrap admin user

## Cache Configuration

Distributed cache configuration using Infinispan for clustered deployments.


#### `spec.cache`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak's cache |

**Example:**
```yaml
cache: (see nested properties below)
```

**Nested Properties:**

- **`configMapFile`** (`object`): No description available
  ```yaml
  configMapFile: name: keycloak-cache-config
      key: cache-ispn.xml
  ```

## Environment Variables & Options

Environment variables and additional Keycloak server configuration options not covered by dedicated fields.


#### `spec.env`

| Property | Value |
|----------|-------|
| **Type** | `array of object` |
| **Description** | Environment variables for the Keycloak server. Values can be either direct values or references to secrets. Use additionalOptions for first-class options rather than KC_ values here. |

**Example:**
```yaml
env: - name: JAVA_OPTS_APPEND
      value: "-Djava.net.preferIPv4Stack=true"
    - name: KC_LOG_LEVEL
      value: "INFO"
```


#### `spec.additionalOptions`

| Property | Value |
|----------|-------|
| **Type** | `array of object` |
| **Description** | Configuration of the Keycloak server. expressed as a keys (reference: https://www.keycloak.org/server/all-config) and values that can be either direct values or references to secrets. |

**Example:**
```yaml
additionalOptions: - name: spi-connections-http-client-default-connection-pool-size
      value: "50"
    - name: spi-email-template-mycustomprovider-enabled
      value: "true"
    - name: db-password
      secret:
        name: db-secret
        key: password
```

## Health Probes

Kubernetes health probe configuration for liveness, readiness, and startup checks.


#### `spec.livenessProbe`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | Configuration for liveness probe, by default it is 10 for periodSeconds and 3 for failureThreshold |

**Example:**
```yaml
livenessProbe: (see nested properties below)
```

**Nested Properties:**

- **`failureThreshold`** (`integer`): No description available
  ```yaml
  failureThreshold: 3
  ```
- **`periodSeconds`** (`integer`): No description available
  ```yaml
  periodSeconds: 30
  ```


#### `spec.readinessProbe`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | Configuration for readiness probe, by default it is 10 for periodSeconds and 3 for failureThreshold |

**Example:**
```yaml
readinessProbe: (see nested properties below)
```

**Nested Properties:**

- **`failureThreshold`** (`integer`): No description available
  ```yaml
  failureThreshold: 3
  ```
- **`periodSeconds`** (`integer`): No description available
  ```yaml
  periodSeconds: 10
  ```


#### `spec.startupProbe`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | Configuration for startup probe, by default it is 1 for periodSeconds and 600 for failureThreshold |

**Example:**
```yaml
startupProbe: (see nested properties below)
```

**Nested Properties:**

- **`failureThreshold`** (`integer`): No description available
  ```yaml
  failureThreshold: 600
  ```
- **`periodSeconds`** (`integer`): No description available
  ```yaml
  periodSeconds: 1
  ```

## Resource Management

CPU and memory resource requests and limits for Keycloak pods.


#### `spec.resources`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | Compute Resources required by Keycloak container |

**Example:**
```yaml
resources: requests:
      cpu: "1"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "2Gi"
```

**Nested Properties:**

- **`claims`** (`array of object`): No description available
- **`limits`** (`object`): No description available
- **`requests`** (`object`): No description available

## Pod Scheduling

Pod scheduling configuration including affinity, tolerations, priority, and topology spread.


#### `spec.scheduling`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak's scheduling |

**Example:**
```yaml
scheduling: (see nested properties below)
```

**Nested Properties:**

- **`affinity`** (`object`): No description available
  ```yaml
  affinity: podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - keycloak
          topologyKey: kubernetes.io/hostname
  ```
- **`priorityClassName`** (`string`): No description available
  ```yaml
  priorityClassName: high-priority
  ```
- **`tolerations`** (`array of object`): No description available
  ```yaml
  tolerations: - key: "dedicated"
      operator: "Equal"
      value: "keycloak"
      effect: "NoSchedule"
  ```
- **`topologySpreadConstraints`** (`array of object`): No description available

## Observability

Prometheus ServiceMonitor and OpenTelemetry distributed tracing configuration.


#### `spec.serviceMonitor`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | Configuration related to the generated ServiceMonitor |

**Example:**
```yaml
serviceMonitor: (see nested properties below)
```

**Nested Properties:**

- **`enabled`** (`boolean`): Enables or disables the creation of the ServiceMonitor.
  ```yaml
  enabled: true
  ```
- **`interval`** (`string`): Interval at which metrics should be scraped
  ```yaml
  interval: 30s
  ```
- **`scrapeTimeout`** (`string`): Timeout after which the scrape is ended
  ```yaml
  scrapeTimeout: 10s
  ```


#### `spec.tracing`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure OpenTelemetry Tracing for Keycloak. |

**Example:**
```yaml
tracing: (see nested properties below)
```

**Nested Properties:**

- **`compression`** (`string`): OpenTelemetry compression method used to compress payloads. If unset, compression is disabled. Possible values are: gzip, none.
  ```yaml
  compression: gzip
  ```
- **`enabled`** (`boolean`): Enables the OpenTelemetry tracing.
  ```yaml
  enabled: true
  ```
- **`endpoint`** (`string`): OpenTelemetry endpoint to connect to.
  ```yaml
  endpoint: http://jaeger-collector:4317
  ```
- **`protocol`** (`string`): OpenTelemetry protocol used for the telemetry data (default 'grpc'). For more information, check the Tracing guide.
  ```yaml
  protocol: grpc
  ```
- **`resourceAttributes`** (`object`): OpenTelemetry resource attributes present in the exported trace to characterize the telemetry producer.
- **`samplerRatio`** (`number`): OpenTelemetry sampler ratio. Probability that a span will be sampled. Expected double value in interval [0,1].
  ```yaml
  samplerRatio: 1.0
  ```
- **`samplerType`** (`string`): OpenTelemetry sampler to use for tracing (default 'traceidratio'). For more information, check the Tracing guide.
  ```yaml
  samplerType: traceidratio
  ```
- **`serviceName`** (`string`): OpenTelemetry service name. Takes precedence over 'service.name' defined in the 'resourceAttributes' map.
  ```yaml
  serviceName: keycloak
  ```

## Transactions

Transaction manager configuration and XA datasource settings.


#### `spec.transaction`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can find all properties related to the settings of transaction behavior. |

**Example:**
```yaml
transaction: (see nested properties below)
```

**Nested Properties:**

- **`xaEnabled`** (`boolean`): Determine whether Keycloak should use a non-XA datasource in case the database does not support XA transactions.
  ```yaml
  xaEnabled: false
  ```

## TLS Truststores

Custom TLS truststore configuration for external service connections.


#### `spec.truststores`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure Keycloak truststores. |

## Network Policy

Kubernetes NetworkPolicy configuration to control ingress traffic to Keycloak pods.


#### `spec.networkPolicy`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | Controls the ingress traffic flow into Keycloak pods. |

**Example:**
```yaml
networkPolicy: (see nested properties below)
```

**Nested Properties:**

- **`enabled`** (`boolean`): Enables or disables the ingress traffic control.
  ```yaml
  enabled: true
  ```
- **`http`** (`array of object`): A list of sources which should be able to access this endpoint. Items in this list are combined using a logical OR operation. If this field is empty or missing, this rule matches all sources (traffic not restricted by source). If this field is present and contains at least one item, this rule allows traffic only if the traffic matches at least one item in the from list.
- **`https`** (`array of object`): A list of sources which should be able to access this endpoint. Items in this list are combined using a logical OR operation. If this field is empty or missing, this rule matches all sources (traffic not restricted by source). If this field is present and contains at least one item, this rule allows traffic only if the traffic matches at least one item in the from list.
  ```yaml
  https: - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ingress-nginx
  ```
- **`management`** (`array of object`): A list of sources which should be able to access this endpoint. Items in this list are combined using a logical OR operation. If this field is empty or missing, this rule matches all sources (traffic not restricted by source). If this field is present and contains at least one item, this rule allows traffic only if the traffic matches at least one item in the from list.

## Import Jobs

Configuration for Keycloak realm import Kubernetes Jobs.


#### `spec.import`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure import Jobs |

**Example:**
```yaml
import: (see nested properties below)
```

**Nested Properties:**

- **`scheduling`** (`object`): In this section you can configure import jobs scheduling

## Update Strategy

Deployment update strategy and rolling update configuration.


#### `spec.update`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | Configuration related to Keycloak deployment updates. |

**Example:**
```yaml
update: (see nested properties below)
```

**Nested Properties:**

- **`revision`** (`string`): When use the Explicit strategy, the revision signals if a rolling update can be used or not.
- **`scheduling`** (`object`): In this section you can configure the update job's scheduling
- **`strategy`** (`string`): Sets the update strategy to use.
  ```yaml
  strategy: rolling
  ```

## Advanced/Unsupported

Advanced pod template customization for unsupported scenarios. Use at your own risk.


#### `spec.unsupported`

| Property | Value |
|----------|-------|
| **Type** | `object` |
| **Description** | In this section you can configure podTemplate advanced features, not production-ready, and not supported settings. Use at your own risk and open an issue with your use-case if you don't find an alternative way. |

**Example:**
```yaml
unsupported: (see nested properties below)
```

**Nested Properties:**

- **`podTemplate`** (`object`): You can configure that will be merged with the one configured by default by the operator. Use at your own risk, we reserve the possibility to remove/change the way any field gets merged in future releases without notice. Reference: https://kubernetes.io/docs/concepts/workloads/pods/#pod-templates


---

## Complete Example CR

Here's a comprehensive example showing multiple configuration options:

```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak-production
  namespace: keycloak
spec:
  # Instance configuration
  instances: 3
  image: quay.io/keycloak/keycloak:26.4.5
  
  # Database
  db:
    vendor: postgres
    host: postgres.database.svc.cluster.local
    port: 5432
    database: keycloak
    usernameSecret:
      name: keycloak-db-secret
      key: username
    passwordSecret:
      name: keycloak-db-secret
      key: password
    poolMinSize: 10
    poolMaxSize: 50
  
  # HTTP/HTTPS
  http:
    httpEnabled: false
    httpsPort: 8443
    tlsSecret: keycloak-tls-secret
  
  # Hostname
  hostname:
    hostname: keycloak.example.com
    admin: admin.keycloak.example.com
    strict: true
  
  # Ingress
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
  
  # Features
  features:
    enabled:
      - token-exchange
      - authorization
  
  # Resources
  resources:
    requests:
      cpu: "2"
      memory: "2Gi"
    limits:
      cpu: "4"
      memory: "4Gi"
  
  # Health probes
  readinessProbe:
    periodSeconds: 10
    failureThreshold: 3
  livenessProbe:
    periodSeconds: 30
    failureThreshold: 3
  
  # Scheduling
  scheduling:
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: keycloak
          topologyKey: kubernetes.io/hostname
  
  # Monitoring
  serviceMonitor:
    enabled: true
    interval: 30s
  
  # Tracing
  tracing:
    enabled: true
    endpoint: http://jaeger-collector:4317
    samplerType: traceidratio
    samplerRatio: 0.1

```
