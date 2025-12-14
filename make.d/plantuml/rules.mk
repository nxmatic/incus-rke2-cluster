# plantuml.mk - Documentation diagram generation layer (@codebase)

ifndef make.d/plantuml/rules.mk

-include make.d/make.mk

.plantuml.dir := $(call top-dir.to,docs)
.plantuml.images_dir := $(.plantuml.dir)/images
.plantuml.include_dir := $(.plantuml.dir)/plantuml
.plantuml.sources := $(wildcard $(.plantuml.dir)/*.puml)
.plantuml.svg_files := $(patsubst $(.plantuml.dir)/%.puml,$(.plantuml.images_dir)/%.svg,$(.plantuml.sources))

$(call register-config-targets,$(.plantuml.svg_files))

.PHONY: diagrams@plantuml
diagrams@plantuml: $(.plantuml.svg_files) ## Regenerate committed PlantUML SVGs under docs/images
	: "[plantuml] Diagrams are up to date (sources: docs/*.puml)"

$(.plantuml.images_dir)/:
	: "[plantuml] Ensuring images directory exists"
	mkdir -p $@

$(.plantuml.svg_files): $(.plantuml.images_dir)/%.svg: $(.plantuml.dir)/%.puml | $(.plantuml.images_dir)/
	: "[plantuml] Rendering $(@F)"
	flox activate --dir $(.plantuml.dir) -- 
		env PLANTUML_INCLUDE_PATH="$(.plantuml.include_dir)" plantuml -tsvg -charset UTF-8 -o images $(notdir $<)

endif # make.d/plantuml/rules.mk
