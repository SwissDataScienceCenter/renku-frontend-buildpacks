package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/BurntSushi/toml"
	"github.com/alecthomas/kong"
)

var cli struct {
	Builder    BuildersCmds  `cmd:"" help:"Commands to modify builders"`
	Buildpacks BuildpackCmds `cmd:"" help:"Commands to modify buildpacks"`
}

type BuildersCmds struct {
	File          string           `short:"f" default:"builder.toml" help:"Path to builder.toml." type:"existingfile"`
	SetBuildpacks SetBuildpacksCmd `cmd:"" help:"Update the version of the renku buildpacks in a builder."`
	SetBuilder    SetBuilderCmd    `cmd:"" help:"Update the version of the builder image."`
	SetRunner     SetRunnerCmd     `cmd:"" help:"Update the version of the runner image."`
}

type BuildpackCmds struct {
	SetVersion SetBuildpackVersionCmd `cmd:"" help:"Update the version of all buildpacks image."`
}

type SetBuildpacksCmd struct {
	Version string `arg:"" help:"New version (tag) to set."`
}

type SetBuilderCmd struct {
	Version string `arg:"" help:"New version (tag) to set."`
}

type SetRunnerCmd struct {
	Version string `arg:"" help:"New version (tag) to set."`
}

type SetBuildpackVersionCmd struct {
	Version string `arg:"" help:"New version (tag) to set."`
}

func main() {
	ctx := kong.Parse(&cli,
		kong.Name("bpu"),
		kong.Description("Buildpack Utilities (bpu)"),
		kong.UsageOnError(),
	)

	switch ctx.Command() {
	case "builder set-buildpacks <version>":
		cfg := mustLoadBuilder(cli.Builder.File)
		cli.Builder.SetBuildpacks.Run(cfg, cli.Builder.File)
	case "builder set-builder <version>":
		cfg := mustLoadBuilder(cli.Builder.File)
		cli.Builder.SetBuilder.Run(cfg, cli.Builder.File)
	case "builder set-runner <version>":
		cfg := mustLoadBuilder(cli.Builder.File)
		cli.Builder.SetRunner.Run(cfg, cli.Builder.File)
	case "buildpacks set-version <version>":
		cli.Buildpacks.SetVersion.Run()
	}
}

func (c *SetBuildpacksCmd) Run(cfg *BuilderConfig, path string) {
	changed := 0
	buildpacks := getBuildpacks()

	for _, bp := range buildpacks {
		applyToBuildpacks(cfg.Buildpacks, fmt.Sprintf("../../buildpacks/%s", bp), c.Version, "[[buildpacks]]", &changed)
	}
	for _, bp := range buildpacks {
		applyToOrder(cfg.Order, fmt.Sprintf("renku/%s", bp), c.Version, "[[order]]", &changed)
	}

	if changed == 0 {
		fmt.Fprintf(os.Stderr, "warning: no entries matching found in builder at %q\n", path)
		os.Exit(1)
	}

	mustSaveBuilder(path, cfg)
	fmt.Printf("\n✓ Updated %d field(s) in %s\n", changed, path)
}

func (c *SetBuilderCmd) Run(cfg *BuilderConfig, path string) {
	oldImg := cfg.Build.Image
	newImg, _ := updateTag(oldImg, c.Version)
	cfg.Build.Image = newImg
	fmt.Printf("✓ Updated builder at %s %s -> %s\n", path, oldImg, newImg)
	mustSaveBuilder(path, cfg)
}

func (c *SetRunnerCmd) Run(cfg *BuilderConfig, path string) {
	for runImgInd, runImg := range cfg.Run.Images {
		oldImg := runImg.Image
		newImg, _ := updateTag(oldImg, c.Version)
		cfg.Run.Images[runImgInd].Image = newImg
		fmt.Printf("✓ Updated runner at %s with ind %d %s -> %s\n", path, runImgInd, oldImg, newImg)
		mustSaveBuilder(path, cfg)
	}
}

func (c *SetBuildpackVersionCmd) Run() {
	bps := getBuildpacks()
	for _, bp := range bps {
		path := fmt.Sprintf("buildpacks/%s/buildpack.toml", bp)
		spec := mustLoadBuildpack(path)
		spec.Buildpack["version"] = c.Version
		fmt.Printf("Updated buildpack at %s to %s\n", path, c.Version)
		mustSaveBuildpack(path, spec)
	}
}

// mutation helpers

func applyToBuildpacks(bps []BuilderBuildpack, target, newVer, section string, changed *int) {
	for i := range bps {
		bp := &bps[i]
		if !matchesTarget(bp, target) {
			continue
		}
		if bp.Version != "" && bp.Version != newVer {
			fmt.Printf("  %s uri=%s  version  %q -> %q\n", section, target, bp.Version, newVer)
			bp.Version = newVer
			(*changed)++
		}
	}
}

func applyToOrder(orders []Order, target, newVer, section string, changed *int) {
	for oi := range orders {
		for gi := range orders[oi].Group {
			g := &orders[oi].Group[gi]
			if g.ID != target {
				continue
			}
			if g.Version != newVer {
				fmt.Printf("  %s  id=%s  version  %q -> %q\n", section, g.ID, g.Version, newVer)
				g.Version = newVer
				(*changed)++
			}
		}
	}
}

// toml I/O

func mustLoadBuilder(path string) *BuilderConfig {
	var cfg BuilderConfig
	if _, err := toml.DecodeFile(path, &cfg); err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot parse %s: %v\n", path, err)
		os.Exit(1)
	}
	return &cfg
}

func mustSaveBuilder(path string, cfg *BuilderConfig) {
	f, err := os.Create(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot write %s: %v\n", path, err)
		os.Exit(1)
	}
	defer f.Close()
	if err := toml.NewEncoder(f).Encode(cfg); err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot encode toml: %v\n", err)
		os.Exit(1)
	}
}

func mustLoadBuildpack(path string) *BuildpackSpec {
	var cfg BuildpackSpec
	_, err := toml.DecodeFile(path, &cfg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot parse %s: %v\n", path, err)
		os.Exit(1)
	}
	return &cfg
}

func mustSaveBuildpack(path string, cfg *BuildpackSpec) {
	f, err := os.Create(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot write %s: %v\n", path, err)
		os.Exit(1)
	}
	defer f.Close()
	if err := toml.NewEncoder(f).Encode(cfg); err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot encode toml: %v\n", err)
		os.Exit(1)
	}
}

// utilities

func matchesTarget(bp *BuilderBuildpack, target string) bool {
	return strings.Trim(bp.URI, " \n\t") == target || strings.Trim(bp.ID, " \n\t") == target
}

func updateTag(ref, newTag string) (string, bool) {
	i := strings.LastIndex(ref, ":")
	if i < 0 {
		return ref, false
	}
	if ref[i+1:] == newTag {
		return ref, false
	}
	return ref[:i+1] + newTag, true
}

func getBuildpacks() []string {
	buildpackDirsRaw, err := os.ReadDir("buildpacks")
	buildpackDirs := []string{}
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v", err)
	}
	for _, e := range buildpackDirsRaw {
		if e.IsDir() {
			buildpackDirs = append(buildpackDirs, e.Name())
		}
	}
	return buildpackDirs
}
