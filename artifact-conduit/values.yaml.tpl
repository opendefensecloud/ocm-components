{{- $apiserver := index .OCIResources "arc-apiserver-image" }}
apiserver:
  image:
    repository: "{{ $apiserver.Host }}/{{ $apiserver.Repository }}"
    tag: "{{ $apiserver.Tag }}"

{{- $controller := index .OCIResources "arc-controller-manager-image" }}
controller:
  image:
    repository: "{{ $controller.Host }}/{{ $controller.Repository }}"
    tag: "{{ $controller.Tag }}"

{{- $etcd := index .OCIResources "etcd-image" }}
etcd:
  image:
    repository: "{{ $etcd.Host }}/{{ $etcd.Repository }}"
    tag: "{{ $etcd.Tag }}"
