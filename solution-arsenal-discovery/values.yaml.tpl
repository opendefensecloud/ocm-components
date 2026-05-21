{{- $discovery := index .OCIResources "solution-arsenal-discovery-image" }}
image:
  repository: {{ $discovery.Host }}/{{ $discovery.Repository }}
  tag: {{ $discovery.Tag }}
