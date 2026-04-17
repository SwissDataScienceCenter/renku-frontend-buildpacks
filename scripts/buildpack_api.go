package main

import "github.com/BurntSushi/toml"

type BuilderConfig struct {
	Description     string          `toml:"description,omitempty"`
	Buildpacks      []Buildpack     `toml:"buildpacks,omitempty"`
	Extensions      []Buildpack     `toml:"extensions,omitempty"`
	Order           []Order         `toml:"order,omitempty"`
	OrderExtensions []Order         `toml:"order-extensions,omitempty"`
	Stack           *Stack          `toml:"stack,omitempty"`
	Build           *BuildImage     `toml:"build,omitempty"`
	Run             *RunConfig      `toml:"run,omitempty"`
	Lifecycle       *toml.Primitive `toml:"lifecycle,omitempty"`
	Targets         *toml.Primitive `toml:"targets,omitempty"`
}

type Buildpack struct {
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

type Stack struct {
	ID         string `toml:"id,omitempty"`
	BuildImage string `toml:"build-image,omitempty"`
	RunImage   string `toml:"run-image,omitempty"`
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
