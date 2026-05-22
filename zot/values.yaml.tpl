{{- $zot := index .OCIResources "zot-image" }}
image:
  repository: {{ $zot.Host }}/{{ $zot.Repository }}
  tag: {{ $zot.Tag }}

{{- $alpine := index .OCIResources "alpine-image" }}
test:
  image:
    repository: {{ $alpine.Host }}/{{ $alpine.Repository }}
    tag: "{{ $alpine.Tag }}"
