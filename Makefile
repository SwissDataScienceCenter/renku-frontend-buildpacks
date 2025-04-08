
# Makefile

# Define the sample images to build (assuming each subdirectory in samples is an app)
SAMPLE_IMAGES := $(shell find samples -maxdepth 1 -type d -not -path "samples" -printf "%P ")

# Buildpacks directory (assuming each subdirectory contains a buildpack)
BUILDPACKS := $(shell find buildpacks -maxdepth 1 -type d -not -path "buildpacks" -printf "%P ")

# Builders directory (assuming each subdirectory contains a builder definition)
BUILDERS := $(shell find builders -maxdepth 1 -type d -not -path "builders" -printf "%P ")

# Define the builder image to use
BUILDER_IMAGE ?= $(word 1, $(BUILDERS))

# Define the frontend image to use
FRONTEND ?= jupyterlab

SAMPLE_IMAGE ?= $(word 1, $(SAMPLE_IMAGES))

.PHONY: all buildpacks builders samples clean

all: buildpacks builders samples

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

samples:
	@echo "Building sample images..."
	@for image in $(SAMPLE_IMAGES); do \
		echo "  Building image: $$image with $(BUILDER_IMAGE)"; \
		pack build $$image --path samples/$$image --env BP_REQUIRES=$(FRONTEND) --builder $(BUILDER_IMAGE) --platform "linux"; \
	done

run:
	@echo "Running sample image : $(SAMPLE_IMAGE)"
	docker run -it --rm --publish 8000:8000 --entrypoint $(FRONTEND) $(SAMPLE_IMAGE):latest
