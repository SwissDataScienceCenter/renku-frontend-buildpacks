
# Makefile

# Define the sample images to build (assuming each subdirectory in samples is an app)
SAMPLE_IMAGES := $(shell cd samples && ls -d *)

# Buildpacks directory (assuming each subdirectory contains a buildpack)
BUILDPACKS := $(shell cd buildpacks && ls -d *)

# Buildpacks directory (assuming each subdirectory contains a buildpack)
EXTENSIONS := $(shell cd extensions && ls -d *)

# Builders directory (assuming each subdirectory contains a builder definition)
BUILDERS := $(shell cd builders && ls -d *)

# Define the builder image to use
BUILDER_IMAGE ?= $(word 1, $(BUILDERS))

# Define the allowed frontends
FRONTENDS := jupyterlab

# Define the frontend image to use
FRONTEND ?= $(word 1, $(FRONTENDS))

SAMPLE_IMAGE ?= $(word 1, $(SAMPLE_IMAGES))

LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f "$(1)-$(3)" ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
rm -f $(1) || true ;\
GOBIN=$(LOCALBIN) go install $${package} ;\
mv $(1) $(1)-$(3) ;\
} ;\
ln -sf $(1)-$(3) $(1)
endef

.PHONY: all buildpacks extensions builders samples run_image

## Tools
YQ = $(LOCALBIN)/yq
YQ_VERSION ?= v4.45.1

.PHONY: yq
yq: $(YQ)
$(YQ): $(LOCALBIN)
	$(call go-install-tool,$(YQ),github.com/mikefarah/yq/v4,$(YQ_VERSION))

all: buildpacks extensions builders samples

buildpacks:
	@echo "Building buildpacks..."
	@for bp in $(BUILDPACKS); do \
		echo "  Building buildpack: $$bp"; \
		pack buildpack package $$bp --config buildpacks/$$bp/package.toml --target "linux/amd64"; \
	done

extensions:
	@echo "Building extensions..."
	@for extension in $(EXTENSIONS); do \
		echo "  Building extension: $$extension"; \
		pack extension package $$extension --config extensions/$$extension/package.toml; \
	done

builders:
	@echo "Building builders..."
	@for builder in $(BUILDERS); do \
		echo "  Building builder: $$builder"; \
		pack builder create $$builder --config builders/$$builder/builder.toml --target "linux/amd64"; \
	done

samples:
	@echo "Building sample images..."
	@for image in $(SAMPLE_IMAGES); do \
		echo "  Building image: $$image with $(BUILDER_IMAGE)"; \
		pack build $$image-$(FRONTEND) --clear-cache --path samples/$$image --env BP_RENKU_FRONTENDS=$(FRONTEND) --builder $(BUILDER_IMAGE) --platform "linux"; \
	done

run:
	@echo "Running sample image : $(SAMPLE_IMAGE)-$(FRONTEND)"
	docker run -it --rm --publish 8000:8000 --entrypoint $(FRONTEND) $(SAMPLE_IMAGE)-$(FRONTEND):latest

run_image:
	# TODO: Upgrade to properly tag based on commit/tag
	docker build -t ghcr.io/swissdatasciencecenter/renku-frontend-buildpacks/base-image:0.0.1 -f ./extensions/renku/generate/run.Dockerfile ./extensions/renku/generate/context/

REGISTRY_HOST=ghcr.io
REGISTRY_REPO=swissdatasciencecenter/renku-frontend-buildpacks

.PHONY: publish_buildpacks
publish_buildpacks:
	@for bp in $(BUILDPACKS); do \
		echo "Publishing buildpack: $(REGISTRY_HOST)/$(REGISTRY_REPO)/$$bp"; \
		./scripts/publish_buildpack.sh $(REGISTRY_HOST)/$(REGISTRY_REPO)/$$bp buildpacks/$$bp --publish; \
	done

.PHONY: publish_builders
publish_builders:
	@echo "Publishing builders..."
	@for builder in $(BUILDERS); do \
		echo "Publishing builder: $$builder"; \
		./scripts/publish_builder.sh $(REGISTRY_HOST)/$(REGISTRY_REPO)/$$builder builders/$$builder --publish; \
	done
