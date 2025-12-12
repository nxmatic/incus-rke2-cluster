# RKE2 Manifests Review: Migration Assessment

## Current State Analysis

### Manifests in `cloud-config.master.base.yaml`

#### 1. **Traefik HelmChartConfig** ✅ BOOTSTRAP VIA KPT PACKAGE

```yaml
/etc/systemd/system/rke2-traefik-config.service ➜ ${CLUSTER_STATE_DIR}/kpt/system/traefik-config
```

**Assessment**: **Bootstrap-critical, now sourced from kpt**

- **Reason**: Cluster still needs ingress before Porch/Flux render loops start
- **Change**: Manifest moved into `kpt/system/traefik-config` and is applied by `rke2-traefik-config.service`
- **Benefit**: Values now live in git, can be reviewed/versioned like other packages without inflating NoCloud user-data
- **Risk**: Remains HIGH if package missing—service has `ConditionPathExists` to guard against empty state
- **Operational note**: `rke2-kpt-package-sync` mirrors the package before the service runs, preserving the bootstrap order

#### 2. **OpenEBS ZFS Helm Chart** ⚠️ COULD MIGRATE (with caution)

```yaml
/var/lib/rancher/rke2/server/manifests/openebs-zfs.yaml
```

**Assessment**: **COULD MIGRATE** but deferred due to risk

- **Reason**: Storage provisioner - affects persistent volumes
- **Risk**: HIGH - Migration could impact existing PVs/PVCs
- **Dependencies**: Existing persistent volumes in cluster
- **Benefits of Migration**:
  - Declarative version management
  - Easier upgrades without container recreation
  - Better integration with GitOps
- **Migration Requirements**:
  - PV/PVC inventory and backup
  - StorageClass migration strategy
  - Rollback plan for active volumes
- **Decision**: **Phase 4 (Future)** - Requires proper PV migration tooling

#### 3. **Tailscale Operator** ✅ **CAN MIGRATE**

```yaml
- /var/lib/rancher/rke2/server/manifests/00-tailscale-namespace.yaml
- /var/lib/rancher/rke2/server/manifests/01-tailscale-operator.yaml
- /var/lib/rancher/rke2/server/manifests/02-tailscale-controlplane.yaml
```

**Assessment**: **EXCELLENT MIGRATION CANDIDATE**

- **Reason**: Operational component - not required for cluster bootstrap
- **Risk**: LOW-MEDIUM - Cluster functions without Tailscale
- **Dependencies**: Secrets (TSKEY_CLIENT_ID, TSKEY_CLIENT_TOKEN)
- **Benefits of Migration**:
  - ✅ Version control for Tailscale operator versions
  - ✅ Separate management of mesh networking from core cluster
  - ✅ Easier to enable/disable per environment
  - ✅ Better secret management with kpt + sops
  - ✅ Can update routes/config without container restart
- **Migration Strategy**:
  1. Create `kpt/catalog/mesh/tailscale/` package
  2. Extract namespace, HelmChart, and Connector resources
  3. Use kpt setters for: cluster-name, oauth-client-id, oauth-client-secret, vip-cidr, lb-cidr
  4. Deploy on fresh master, verify Tailscale connectivity
  5. Remove from cloud-config.master.base.yaml
- **Decision**: **RECOMMENDED FOR PHASE 4**

### Manifests in `cloud-config.server.yaml`

**Assessment**: **ALL MUST REMAIN**

- Core RKE2 configuration files (config.yaml.d/*)
- Systemd service overrides
- Pre-start/post-start scripts
- **Reason**: Bootstrap infrastructure, not Kubernetes resources
- **Decision**: Not applicable for kpt migration

### Manifests in `cloud-config.master.cilium.yaml`

#### 1. **Cilium HelmChartConfig** ✅ BOOTSTRAP VIA KPT PACKAGE

```yaml
/etc/systemd/system/rke2-cilium-config.service ➜ ${CLUSTER_STATE_DIR}/kpt/system/cilium-config
```

**Assessment**: **Still core bootstrap, but now mirrored via kpt**

- **Reason**: CNI must reconcile before anything else; service order enforces this
- **Change**: The HelmChartConfig left NoCloud and lives in `kpt/system/cilium-config` (with setters for cluster name/id)
- **Benefit**: Declarative history + ability to reuse the same package across clusters while passing setters via `rke2-kpt-deploy`
- **Risk**: CRITICAL if package absent; systemd unit will fail fast so troubleshooting happens outside NoCloud space
- **Status**: Advanced Cilium features remain in dedicated packages; only the bootstrap slice runs here

### Previously Migrated (Now in kpt)

✅ **Headscale** - Migrated to `kpt/catalog/mesh/headscale/`

✅ **Envoy Gateway** - Migrated to `kpt/catalog/networking/envoy-gateway/`

✅ **Kube-VIP** - Migrated to `kpt/catalog/ha/kube-vip/`

✅ **Cilium Advanced Features** - Migrated to `kpt/catalog/networking/cilium/`

## Migration Recommendation Summary

### Phase 4: Tailscale Operator (RECOMMENDED)

**Priority**: HIGH - Good candidate, low risk

**Components**:

- Tailscale namespace
- Tailscale operator Helm chart (v1.82.0)
- Connector resource (subnet router for control plane VIP + LoadBalancer pool)

**Benefits**:

- Decouple mesh networking from cluster bootstrap
- Enable/disable Tailscale per environment
- Version management without container recreation
- Better secret management (kpt + sops integration)
- Update advertised routes without cluster restart

**Risk Level**: LOW-MEDIUM

- Cluster remains functional without Tailscale
- Only affects external connectivity via Tailscale mesh
- Easy rollback: delete kpt package, redeploy from cloud-config

**Migration Effort**: LOW (similar to Headscale migration)

**Package Structure**:

```text
kpt/catalog/mesh/tailscale/
├── Kptfile (setters: version, cluster-name, vip, lb-cidr)
├── 00-namespace.yaml
├── 01-operator-helmchart.yaml
├── 02-connector.yaml
├── 03-oauth-secret.yaml (encrypted with sops)
├── resourcegroup.yaml
├── .kptignore
└── README.md
```

### Phase 5: OpenEBS ZFS (OPTIONAL, HIGH RISK)

**Priority**: LOW - Defer until proper tooling available

**Risk Level**: HIGH

- Affects persistent storage
- Requires PV/PVC migration strategy
- Potential data loss if misconfigured

**Decision**: Keep in RKE2 for now, revisit when:

- Velero or similar PV backup/restore tooling deployed
- Non-production cluster available for testing
- Clear rollback strategy with PV preservation

### Components to Keep in RKE2 (Permanent)

These should **NOT** be migrated:

1. **Traefik HelmChartConfig** - Bootstrap ingress controller
2. **Cilium CNI HelmChartConfig** - Core networking bootstrap
3. **RKE2 config.yaml.d/** - Cluster configuration
4. **Systemd services** - Bootstrap infrastructure

## Next Steps

### Recommended: Proceed with Tailscale Migration

1. **Create Tailscale kpt package**
   - Extract 3 manifests from cloud-config.master.base.yaml
   - Add kpt setters for configurability
   - Create sops-encrypted secret for OAuth credentials
   - Write comprehensive README with deployment/rollback procedures

2. **Test on fresh master**
   - Deploy master without Tailscale in cloud-config
   - Apply Tailscale kpt package
   - Verify connectivity to cluster via Tailscale mesh
   - Confirm subnet routes advertised (VIP + LoadBalancer pool)

3. **Update cloud-config**
   - Remove Tailscale manifests
   - Add comment referencing kpt package

4. **Commit and document**
   - Git commit with verification results
   - Update migration plan documentation

**Estimated Effort**: 1-2 hours
**Risk**: Low (cluster functional without Tailscale)
**Value**: High (better secret management, version control)

## Summary Table

| Component | Location | Can Migrate? | Priority | Risk | Status |
|-----------|----------|--------------|----------|------|--------|
| Traefik Config | master.base | ✅ Done (kpt/system/traefik-config) | High | CRITICAL | Applied by rke2-traefik-config.service |
| OpenEBS ZFS | master.base | ⚠️ Maybe | Low | HIGH | Defer (Phase 5) |
| Tailscale Operator | master.base | ✅ Yes | High | LOW-MED | **Recommended (Phase 4)** |
| Cilium CNI Config | master.cilium | ✅ Done (kpt/system/cilium-config) | High | CRITICAL | Applied by rke2-cilium-config.service |
| Headscale | master.headscale | ✅ Yes | - | - | ✅ Migrated (Phase 1) |
| Envoy Gateway | master.cilium | ✅ Yes | - | - | ✅ Migrated (Phase 1) |
| Kube-VIP | master.kube-vip | ✅ Yes | - | - | ✅ Migrated (Phase 2) |
| Cilium Advanced | master.cilium | ✅ Yes | - | - | ✅ Migrated (Phase 3a) |

## Conclusion

**Recommended Next Step**: Migrate Tailscale Operator to kpt (Phase 4)

This completes the logical migration of operational components to kpt while keeping essential bootstrap components safely in RKE2. The remaining components (Traefik, Core CNI, OpenEBS) are either critical for bootstrap or too risky to migrate without specialized tooling.

**Final State**:

- **kpt-managed**: 5 packages, ~35-40 resources (operational layer)
- **RKE2-managed**: Bootstrap essentials (CNI, ingress, storage, config)
- **Clean separation**: Bootstrap vs. operational layers
