# kpt-vars.mk - KPT variables and paths (@codebase)
# Self-guarding include; safe for multiple -include occurrences.

ifndef make.d/kpt/vars.mk
make.d/kpt/vars.mk := make.d/kpt/vars.mk

# KPT catalog configuration (@codebase)
-include $(cluster.env.mk)
-include $(network.env.mk)

.kpt.dir := rke2.d/$(cluster.name)/$(node.name)
.kpt.upstream.repo := $(realpath $(top-dir))
.kpt.upstream.dir := rke2.d/catalog
.kpt.catalog.dir := $(.kpt.dir)/catalog
.kpt.rke2-config.dir := $(.kpt.catalog.dir)/runtime/rke2-config
.kpt.rke2-config.setters.file := $(.kpt.rke2-config.dir)/setters.yaml
.kpt.overlays.dir := $(.kpt.dir)/overlays
.kpt.overlays.Kustomization.file := $(.kpt.overlays.dir)/Kustomization
.kpt.Kustomization.file := $(.kpt.dir)/Kustomization
.kpt.render.dir := $(var-dir)/lib/kpt/$(cluster.name)/$(node.name)
.kpt.render.cmd := env PATH=$(realpath $(.kpt.catalog.dir)/bin):$(PATH) kpt fn render --allow-exec --truncate-output=false
.kpt.manifests.file := $(.kpt.dir)/manifests.yaml
.kpt.manifests.dir  := $(.kpt.dir)/manifests.d
.kpt.package.aux_files := .gitattributes .krmignore

.kpt.allow.dirty ?= false

kpt.catalog.dir := $(.kpt.catalog.dir)
kpt.render.dir := $(.kpt.render.dir)
kpt.manifests.file := $(.kpt.manifests.file)
kpt.manifests.dir := $(.kpt.manifests.dir)


endif
