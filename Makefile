
# Makefile

# Define the sample images to build (assuming each subdirectory in samples is an app)
SAMPLE_IMAGES := $(shell cd samples && ls -d *)

# Buildpacks directory (assuming each subdirectory contains a buildpack)
BUILDPACKS := $(shell cd buildpacks && ls -d *)

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

.PHONY: all buildpacks builders samples run_image

## Tools
YQ = $(LOCALBIN)/yq
YQ_VERSION ?= v4.45.1

GINKGO = $(LOCALBIN)/ginkgo
GINKGO_VERSION ?= "v2.23.4"

SHELLCHECK = $(LOCALBIN)/shellcheck
SHELLCHECK_VERSION ?= "v0.10.0"

GOLANG_CI_LINT = $(LOCALBIN)/golangci-lint
GOLANG_CI_LINT_VERSION ?= "v2.1.5"

.PHONY: yq
yq: $(YQ)
$(YQ): $(LOCALBIN)
	$(call go-install-tool,$(YQ),github.com/mikefarah/yq/v4,$(YQ_VERSION))

.PHONY: ginkgo
ginkgo: $(GINKGO)
$(GINKGO): $(LOCALBIN)
	$(call go-install-tool,$(GINKGO),github.com/onsi/ginkgo/v2/ginkgo,$(GINKGO_VERSION))

.PHONY: shellcheck
shellcheck: $(SHELLCHECK)
$(SHELLCHECK): $(LOCALBIN)
	bash ./scripts/install_shellcheck.sh $(SHELLCHECK_VERSION) $(LOCALBIN)

.PHONY: golang_ci_lint
golang_ci_lint: $(GOLANG_CI_LINT)
$(GOLANG_CI_LINT): $(LOCALBIN)
	$(call go-install-tool,$(GOLANG_CI_LINT),github.com/golangci/golangci-lint/v2/cmd/golangci-lint,$(GOLANG_CI_LINT_VERSION))

all: buildpacks builders samples

buildpacks:
	@echo "Building buildpacks..."
	@for bp in $(BUILDPACKS); do \
		echo "  Building buildpack: $$bp"; \
		pack buildpack package $$bp --config buildpacks/$$bp/package.toml --target "linux/amd64"; \
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

REGISTRY_HOST=ghcr.io
REGISTRY_REPO=swissdatasciencecenter/renku-frontend-buildpacks

run_image:
	bash ./scripts/publish_run_image.sh $(REGISTRY_HOST)/$(REGISTRY_REPO)/base-image

.PHONY: publish_run_image
publish_run_image: run_image
	bash ./scripts/publish_run_image.sh $(REGISTRY_HOST)/$(REGISTRY_REPO)/base-image --publish

.PHONY: publish_buildpacks
publish_buildpacks: yq
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

.PHONY: tests
tests: ginkgo
	go vet ./...
	$(GINKGO) -r -v

.PHONY: lint
lint: shellcheck golang_ci_lint
	@echo "\n\n"
	@echo "===Running shellcheck==="
	@$(SHELLCHECK) -V
	@echo "Files to test"
	@git ls-files | egrep '.*.sh$$|build$$|detect$$'
	git ls-files | egrep '.*.sh$$|build$$|detect$$' | xargs $(SHELLCHECK)
	@echo "\n\n"
	@echo "===Running golang ci lint==="
	$(GOLANG_CI_LINT) run
	@echo "\n\n"
	@echo "===Running gofmt==="
	gofmt -l -e -d .

.PHONY: update-buildpack-versions
update-buildpack-versions:
	@echo "Updating buildpack versions to $(RELEASE_VERSION)..."
	@for bp in $(BUILDPACKS); do \
		FILE="buildpacks/$$bp/buildpack.toml"; \
		./scripts/update_buildpack_versions.sh "$(RELEASE_VERSION)" "$$FILE"; \
	done

.PHONY: update-builder-versions
update-builder-versions:
	@echo "Updating builder versions to $(RELEASE_VERSION)..."
	@for builder in $(BUILDERS); do \
		FILE="builders/$$builder/builder.toml"; \
	 ./scripts/update_builder_versions.sh "$(REGISTRY_HOST)/$(REGISTRY_REPO)/base-image" "$(RELEASE_VERSION)" "$$FILE"; \
	done

.PHONY: update-action-versions
update-action-versions:
	@echo "Updating default builder version in the image build action to $(RELEASE_VERSION)..."
	@$(YQ) -i '.inputs."builder-version".default = strenv(RELEASE_VERSION)' actions/build-image/action.yml
