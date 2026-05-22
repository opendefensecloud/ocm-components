{{- $cli := index .OCIResources "cli-image" }}
cli:
  image: {{ $cli.Host }}/{{ $cli.Repository }}
  tag: {{ $cli.Tag }}

{{- $helmController := index .OCIResources "helm-controller-image" }}
helmController:
  image: {{ $helmController.Host }}/{{ $helmController.Repository }}
  tag: {{ $helmController.Tag }}

{{- $imageAutomationController := index .OCIResources "image-automation-controller-image" }}
imageAutomationController:
  image: {{ $imageAutomationController.Host }}/{{ $imageAutomationController.Repository }}
  tag: {{ $imageAutomationController.Tag }}

{{- $imageReflectionController := index .OCIResources "image-reflector-controller-image" }}
imageReflectionController:
  image: {{ $imageReflectionController.Host }}/{{ $imageReflectionController.Repository }}
  tag: {{ $imageReflectionController.Tag }}

{{- $kustomizeController := index .OCIResources "kustomize-controller-image" }}
kustomizeController:
  image: {{ $kustomizeController.Host }}/{{ $kustomizeController.Repository }}
  tag: {{ $kustomizeController.Tag }}

{{- $notificationController := index .OCIResources "notification-controller-image" }}
notificationController:
  image: {{ $notificationController.Host }}/{{ $notificationController.Repository }}
  tag: {{ $notificationController.Tag }}

{{- $sourceController := index .OCIResources "source-controller-image" }}
sourceController:
  image: {{ $sourceController.Host }}/{{ $sourceController.Repository }}
  tag: {{ $sourceController.Tag }}

{{- $sourceWatcher := index .OCIResources "source-watcher-image" }}
sourceWatcher:
  image: {{ $sourceWatcher.Host }}/{{ $sourceWatcher.Repository }}
  tag: {{ $sourceWatcher.Tag }}
