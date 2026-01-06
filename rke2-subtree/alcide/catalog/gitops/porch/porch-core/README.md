# Porch Package - Branch-Based Update Strategy

This package uses a **branch-based workflow** to separate upstream tracking from deployment.

## Architecture

### Main Branch (Production)
- `catalog/system/porch/Kptfile` - **Dependent package** (NO upstream)
- `rke2-subtree/bioskop/catalog/system/porch/Kptfile` - **Dependent package** (NO upstream)
- Contains git injection customizations
- Safe for deployment - upstream never reintroduced
- Syncs automatically to rke2-subtree via `make update@kpt`

### Develop Branch (Update/Staging)
- `catalog/system/porch/Kptfile` - **Independent package** (HAS nephio upstream)
- Used for pulling nephio updates via `kpt pkg update`
- Test and review changes before merging to main
- Git injection customizations preserved via resource-merge strategy

## Customizations

This package includes the following modifications from upstream nephio:

1. **Git Binary Injection**: Adds git to the porch-server container
   - `git-bin` emptyDir volume
   - `install-git` initContainer (alpine-based, installs git/ca-certificates/openssh-client)
   - Volume mounts for /usr/bin/git and /usr/bin/git-remote-https

2. **Custom Image**: Uses ARM64-compatible image `ghcr.io/nxmatic/porch-server:nxmatic-37254b4`

3. **RBAC**: Additional subjectaccessreviews permission for porch-server

## Update Workflow

### Updating from Nephio

```bash
# 1. Switch to develop branch
git checkout develop

# 2. Update porch from nephio
cd catalog/system/porch
kpt pkg update @main  # or @v0.x.y for specific version

# 3. Review changes - ensure git injection preserved
git diff
# Check that initContainer and volumeMounts are still present in 3-porch-server.yaml

# 4. Test the update
kpt fn render .

# 5. Commit on develop
git add .
git commit -m "Updated porch from nephio to <version>"

# 6. Merge to main
git checkout main
git merge develop
# The Kptfile on main branch has no upstream - this is preserved
```

### Deploying to Cluster

On main branch:

```bash
# Update deployment catalog from source catalog
make update@kpt

# Render manifests
make render@kpt unwrap@kpt

# Deploy (handled by RKE2)
# Manifests are automatically applied from rke2-subtree/bioskop/manifests.yaml
```

### Render / Unwrap Commit Workflow

To keep rendered artifacts aligned with sources:

1. `make render@kpt` → review → **commit** (captures catalog render state)
2. `make unwrap@kpt` → review → **commit** (captures manifests.yaml/manifests.d for deployment)
3. Deploy from the freshly unwrapped output

## Why This Strategy?

**Branch Separation:**
- ✅ **main**: Production-ready, no upstream tracking, never auto-updated
- ✅ **develop**: Tracks nephio upstream, explicit update control
- ✅ Git handles the Kptfile differences automatically

**Safety:**
- ✅ Git injection never automatically overwritten
- ✅ resource-merge preserves your modifications to resources
- ✅ Clear separation between update and deployment flows
- ✅ Full control over when/what to merge from nephio

**Traceability:**
- ✅ All nephio updates are explicit commits on develop
- ✅ Merges to main are deliberate, reviewable
- ✅ Easy to revert or cherry-pick specific updates

## Package Types by Branch

| Branch | catalog/system/porch | rke2-subtree/.../porch |
|--------|--------------------------|------------------------|
| main | Dependent (no upstream) | Dependent (no upstream) |
| develop | Independent (nephio upstream) | Dependent (no upstream) |

## Initial Setup (One-Time)

If develop branch doesn't exist yet:

```bash
# Create develop branch from main
git checkout -b develop

# Restore nephio upstream in porch Kptfile
# Edit catalog/system/porch/Kptfile to add:
# upstream:
#   type: git
#   git:
#     repo: https://github.com/nephio-project/catalog
#     directory: /nephio/core/porch
#     ref: main
#   updateStrategy: resource-merge
# upstreamLock: [...]

git commit -am "develop: Restored nephio upstream for porch updates"
git push -u origin develop
```

## Notes

- Always update porch on **develop** branch, never on main
- The deployment catalog (rke2-subtree) has NO upstream in both branches
- Git handles keeping different Kptfile versions per branch automatically
- Resource changes (3-porch-server.yaml, etc.) merge cleanly between branches
