# build-image action

This action simplifies building images using the Renku buildpacks. It uses the identical buildpack configuration used in
production deployments of RenkuLab for building images from code, but allows users to do it in their own repositories
with CI if they prefer.

## Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| builder | Builder image to use | No | Most recent builder from this repository |
| frontend | Which frontend to add to the image; options are "vscodium", "jupyterlab", and "ttyd" | No | vscodium |
| run-image | Run image to use | No | Most recent run-image published from this repository |
| tags | Image tags to publish | yes | None |

## Example

The easiest way to use this action is together with the basic docker actions:

```yaml
name: build image

on:
  push:

jobs:
  build-image:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/<image-repository>
          tags: |
            type=sha,prefix=
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/master' }}
            type=semver,pattern={{version}},event=tag
      - uses: swissdatasciencecenter/renku-frontend-buildpacks/actions/build-image
        with:
          tags: ${{ steps.meta.outputs.tags }}
          frontend: jupyterlab
```
