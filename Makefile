
# Makefile

# Buildpacks directory (assuming each subdirectory contains a buildpack)
BUILDPACKS := $(shell find buildpacks -maxdepth 1 -type d -not -path "buildpacks" -printf "%P ")

# Builders directory (assuming each subdirectory contains a builder definition)
BUILDERS := $(shell find builders -maxdepth 1 -type d -not -path "builders" -printf "%P ")

.PHONY: all buildpacks builders

all: buildpacks builders

buildpacks:
	@echo "Building buildpacks..."
	@for bp in $(BUILDPACKS); do \
		echo "  Building buildpack: $$bp"; \
		pack buildpack package $$bp --config buildpacks/$$bp/package.toml --target "linux"; \
	done

builders:
	@echo "Building builders..."
	@for builder in $(BUILDERS); do \
		echo "  Building builder: $$builder"; \
		pack builder create $$builder --config builders/$$builder/builder.toml --target "linux"; \
	done
