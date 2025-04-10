# renku-frontend-buildpacks

This project provides a set of buildpacks and builders for deploying Renku frontend applications. It
includes buildpacks for various frontend frameworks and a builder that orchestrates the build
process.

## Directory Structure

*   **builders**: Contains builder definitions. A builder defines the environment and buildpacks 
    used to build an application. For now we only maintain the selector builder.
*   **buildpacks**: Contains individual buildpacks for different frontend frameworks. Each buildpack
    provides the necessary scripts and configurations to detect and build applications.
  *   **frontends**: composite buildpack for frontends.
  *   **frontend-selector**: Buildpack for selecting the appropriate frontend.
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
