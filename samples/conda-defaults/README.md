## Build with defaults conda channel
This build should fail with the `selector` builder or using the `conda-nodefaults` buildpack
because it contains the `defaults` channel in the `environment.yml` spec.
