package main

import "github.com/BurntSushi/toml"

type BuilderConfig struct {
	Description     string             `toml:"description,omitempty"`
	Buildpacks      []BuilderBuildpack `toml:"buildpacks,omitempty"`
	Extensions      []BuilderBuildpack `toml:"extensions,omitempty"`
	Order           []Order            `toml:"order,omitempty"`
	OrderExtensions []Order            `toml:"order-extensions,omitempty"`
	Stack           *toml.Primitive    `toml:"stack,omitempty"`
	Build           *BuildImage        `toml:"build,omitempty"`
	Run             *RunConfig         `toml:"run,omitempty"`
	Lifecycle       *toml.Primitive    `toml:"lifecycle,omitempty"`
	Targets         *toml.Primitive    `toml:"targets,omitempty"`
}

type BuilderBuildpack struct {
	URI     string `toml:"uri,omitempty"`
	ID      string `toml:"id,omitempty"`
	Version string `toml:"version,omitempty"`
}

type Order struct {
	Group []GroupEntry `toml:"group,omitempty"`
}

type GroupEntry struct {
	ID       string `toml:"id"`
	Version  string `toml:"version,omitempty"`
	Optional bool   `toml:"optional,omitempty"`
}

type BuildImage struct {
	Image string          `toml:"image,omitempty"`
	Env   *toml.Primitive `toml:"env,omitempty"`
}

type RunConfig struct {
	Images []RunImage `toml:"images,omitempty"`
}

type RunImage struct {
	Image   string          `toml:"image,omitempty"`
	Mirrors *toml.Primitive `toml:"mirrors,omitempty"`
}

type BuildpackSpec struct {
	Api       *toml.Primitive   `toml:"api,omitempty"`
	Targets   *toml.Primitive   `toml:"targets,omitempty"`
	Buildpack map[string]string `toml:"buildpack,omitempty"`
}
