# overlays

## Description
RKE2 cluster overlays

## Usage

### Fetch the package
`kpt pkg get REPO_URI[.git]/PKG_PATH[@VERSION] overlays`
Details: https://kpt.dev/reference/cli/pkg/get/

### View package content
`kpt pkg tree overlays`
Details: https://kpt.dev/reference/cli/pkg/tree/

### Apply the package
```
kpt live init overlays
kpt live apply overlays --reconcile-timeout=2m --output=table
```
Details: https://kpt.dev/reference/cli/live/
