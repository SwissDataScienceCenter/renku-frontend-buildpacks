
# Makefile

# Buildpacks directory (assuming each subdirectory contains a buildpack)
BUILDPACKS := $(shell find buildpacks -maxdepth 1 -type d -not -path "buildpacks" -printf "%P ")

.PHONY: all buildpacks

all: buildpacks

buildpacks:
	@echo "Building buildpacks..."
	@for bp in $(BUILDPACKS); do \
		echo "  Building buildpack: $$bp"; \
		pack buildpack package $$bp --config buildpacks/$$bp/package.toml --target "linux"; \
	done
