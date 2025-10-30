# renku-frontend-buildpacks

This project provides a comprehensive set of Cloud Native Buildpacks and a specialized `selector`
builder designed to streamline the deployment of Renku frontend applications and development
environments. Whether you're setting up JupyterLab, RStudio, or Vscodium in your Renku
project, these buildpacks simplify the process by intelligently detecting your project's needs and
configuring the appropriate environment.

The `selector` builder acts as an orchestrator, integrating various frontend frameworks and
essential tools (like Python dependency management and kernel installers) to create ready-to-use
images. This allows Renku users to focus on their data science work without deep knowledge of
underlying containerization.

For automated image building within your CI/CD pipelines, you can leverage the provided GitHub
Action [actions/build-image](actions/build-image/README.md). This action simplifies the `pack build`
process, allowing you to easily specify the desired `frontend`, `tags`, `builder-version`, and
`run-image` directly in your workflows.

To get started with manual builds, you'll primarily interact with the
[`pack` CLI](https://buildpacks.io/docs/for-platform-operators/how-to/integrate-ci/pack/), using the
`selector` builder to build your project. For example:

```bash
pack build my-renku-environment --builder ghcr.io/swissdatasciencecenter/renku-frontend-buildpacks/selector:0.1.0 --path .
```

This command will leverage the `selector` builder (using version `0.1.0` as an example) to
automatically detect and configure your Renku environment based on your project's files, and in this
example, push the resulting image to `my-renku-environment`.

## Directory Structure

*   **builders**: Contains builder definitions. A builder defines the environment and buildpacks
    used to build an application. For now we only maintain the selector builder.
*   **buildpacks**: Contains individual buildpacks for different frontend frameworks. Each buildpack
    provides the necessary scripts and configurations to detect and build applications.
  *   **jupyterlab**: Buildpack for JupyterLab frontend.
  *   **kernel-installer**: Buildpack for installing the correct kernel for the environment.
*   **samples**: Contains sample applications for different frontend frameworks. These samples can
    be used to test the buildpacks and builders.

## Makefile Targets

The `Makefile` provides several targets for building and running the project:

*   **all**: Builds buildpacks, builders, and sample images.
*   **buildpacks**: Builds all buildpacks defined in the `buildpacks` directory using `pack
    buildpack package`.
*   **builders**: Builds all builders defined in the `builders` directory using `pack builder
    create`.
*   **samples**: Builds sample images using the buildpacks and builders.  It utilizes the
    `pack build` command with the specified builder image and environment variables.
*   **run**: Runs a sample image with Docker, publishing port 8000.

## Building the Project

Note you have to have experimental features enabled on the `pack` CLI in order
to be able to use and build image extensions.

```bash
pack config experimental true

```

To build the project, run:

```bash
make
```

This will build all buildpacks, builders, and sample images.

To build only the buildpacks, run:

```bash
make buildpacks
```

To build only the builders, run:

```bash
make builders
```

To build only the sample images, run:

```bash
make samples
```

Please note that the builders must be set and that you may set the `BUILDER_IMAGE` variable to
select a builder

```bash
make samples BUILDER_IMAGE=selector
```

## Running a Sample Image

To run a sample image, use the `run` target:

```bash
make run
```

You can set the `SAMPLE_IMAGE` and `FRONTEND`. For example:

```bash
make run SAMPLE_IMAGE=conda FRONTEND=jupyterlab
```

## Dependencies

This project requires the following tools:

*   [pack](https://buildpacks.io/docs/tools/pack/)
*   Docker
