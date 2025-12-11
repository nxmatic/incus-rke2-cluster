# fleet/rules.mk - Fleet manifests subtree helpers (@codebase)
# Self-guarding include so the layer can be pulled in multiple times safely.

ifndef make.d/fleet/rules.mk

-include make.d/make.mk

FLEET_DIR ?= fleet
FLEET_REMOTE ?= fleet
FLEET_BRANCH ?= rke2-subtree

.PHONY: fleet-remote fleet-finalize-merge fleet-check-clean fleet-pull fleet-push

fleet-remote:
	@if ! git remote get-url "$(FLEET_REMOTE)" >/dev/null 2>&1; then \
		git remote add "$(FLEET_REMOTE)" git@github.com:nxmatic/fleet-manifests.git; \
	fi

fleet-finalize-merge:
	@if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then \
		if git diff --name-only --diff-filter=U | grep -q .; then \
			echo "Merge in progress with unresolved conflicts; resolve before continuing." >&2; \
			exit 1; \
		fi; \
		echo "Completing pending fleet subtree merge..."; \
		GIT_MERGE_AUTOEDIT=no git commit --no-edit --quiet; \
	fi

fleet-check-clean:
	@if ! git diff --quiet -- "$(FLEET_DIR)"; then \
		echo "Uncommitted changes detected inside $(FLEET_DIR)." >&2; \
		exit 1; \
	fi; \
	untracked="$$(git ls-files --others --exclude-standard -- "$(FLEET_DIR)")"; \
	if [ -n "$$untracked" ]; then \
		echo "Untracked files detected inside $(FLEET_DIR)." >&2; \
		echo "Files:" >&2; \
		echo "$$untracked" >&2; \
		exit 1; \
	fi

fleet-pull: fleet-remote fleet-finalize-merge fleet-check-clean
	git fetch --prune "$(FLEET_REMOTE)" "$(FLEET_BRANCH)"
	git subtree pull --prefix="$(FLEET_DIR)" "$(FLEET_REMOTE)" "$(FLEET_BRANCH)" --squash

fleet-push: fleet-remote fleet-check-clean
	@split_sha="$$(git subtree split --prefix="$(FLEET_DIR)" HEAD)"; \
	remote_sha="$$(git ls-remote --heads "$(FLEET_REMOTE)" "$(FLEET_BRANCH)" | awk '{print $$1}')" || true; \
	if [ -n "$$remote_sha" ] && [ "$$split_sha" = "$$remote_sha" ]; then \
		echo "No new fleet revisions to push; skipping."; \
	else \
		git subtree push --prefix="$(FLEET_DIR)" "$(FLEET_REMOTE)" "$(FLEET_BRANCH)"; \
	fi

endif # make.d/fleet/rules.mk guard
