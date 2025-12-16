# system

## Description
RKE2 system packages

## Usage

### Fetch the package
`kpt pkg get REPO_URI[.git]/PKG_PATH[@VERSION] system`
Details: https://kpt.dev/reference/cli/pkg/get/

### View package content
`kpt pkg tree system`
Details: https://kpt.dev/reference/cli/pkg/tree/

### Apply the package
```
kpt live init system
kpt live apply system --reconcile-timeout=2m --output=table
```
Details: https://kpt.dev/reference/cli/live/
