{{- $apiserver := index .OCIResources "solution-arsenal-apiserver-image" }}
apiserver:
  image:
    repository: {{ $apiserver.Host }}/{{ $apiserver.Repository }}
    tag: {{ $apiserver.Tag }}

{{- $renderer := index .OCIResources "solution-arsenal-renderer-image" }}
renderer:
  image:
    repository: {{ $renderer.Host }}/{{ $renderer.Repository }}
    tag: {{ $renderer.Tag }}

{{- $controller := index .OCIResources "solution-arsenal-controller-manager-image" }}
controller:
  image:
    repository: {{ $controller.Host }}/{{ $controller.Repository }}
    tag: {{ $controller.Tag }}

{{- $etcd := index .OCIResources "etcd-image" }}
etcd:
  image:
    repository: {{ $etcd.Host }}/{{ $etcd.Repository }}
    tag: {{ $etcd.Tag }}
