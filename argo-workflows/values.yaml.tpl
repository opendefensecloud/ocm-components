{{- $controller := index .OCIResources "argo-workflows-controller-image" }}
controller:
  image:
    registry: {{ $controller.Host }}
    repository: {{ $controller.Repository }}
    tag: "{{ $controller.Tag }}"

{{- $server := index .OCIResources "argo-workflows-server-image" }}
server:
  image:
    registry: {{ $server.Host }}
    repository: {{ $server.Repository }}
    tag: "{{ $server.Tag }}"

{{- $executor := index .OCIResources "argo-workflows-executor-image" }}
executor:
  image:
    registry: {{ $executor.Host }}
    repository: {{ $executor.Repository }}
    tag: "{{ $executor.Tag }}"
