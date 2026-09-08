package e2e

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	docker "github.com/docker/docker/client"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// Needed if publishing the builder image when testing image extensions
// const registry = "ghcr.io"
// const repository = "swissdatasciencecenter/renku-frontend-buildpacks"
const testBuilder = "selector"
const builderLoc = "../../builders/" + testBuilder
const customPackage = "cowpy"

var _ = Describe("Testing samples", Label("samples"), Ordered, func() {
	var builderImg string
	var client docker.APIClient
	var err error
	var httpClient http.Client

	BeforeAll(func(ctx SpecContext) {
		builderImg = strings.ToLower(fmt.Sprintf("test-builder-image-%s", getULID()))
		Expect(buildBuilder(ctx, filepath.Join(builderLoc, "builder.toml"), builderImg)).To(Succeed())
		client, err = docker.NewClientWithOpts(docker.FromEnv, docker.WithAPIVersionNegotiation())
		Expect(err).ToNot(HaveOccurred())
		httpClient = *http.DefaultClient
	})

	BeforeEach(func() {
		jar, err := cookiejar.New(&cookiejar.Options{})
		Expect(err).ToNot(HaveOccurred())
		httpClient.Jar = jar
	})

	AfterAll(func(ctx SpecContext) {
		if builderImg != "" && client != nil {
			log.Println("Cleaning up builder image")
			err = removeImage(ctx, client, builderImg)
			if err != nil {
				log.Println(err)
			}
		}
		if client != nil {
			log.Println("Closing docker client")
			err = client.Close()
			if err != nil {
				log.Println(err)
			}
		}
	})

	DescribeTableSubtree(
		"jupyterlab",
		func(source string) {
			var image string
			var container string
			var port int
			var baseURL url.URL
			BeforeAll(func(ctx SpecContext) {
				image = strings.ToLower(fmt.Sprintf("test-image-%s", getULID()))
				Expect(buildImage(ctx, builderImg, source, image, map[string]string{"BP_RENKU_FRONTENDS": "jupyterlab"})).To(Succeed())
				port = getFreePortOrDie()
				envVars := []string{fmt.Sprintf("RENKU_SESSION_PORT=%d", port)}
				ports := map[int]int{port: port}
				container, err = runImage(ctx, client, image, envVars, ports)
				Expect(err).ToNot(HaveOccurred())
				baseURL = url.URL{
					Host:   fmt.Sprintf("127.0.0.1:%d", port),
					Scheme: "http",
				}
			})

			AfterAll(func(ctx SpecContext) {
				if container != "" && client != nil {
					log.Println("Cleaning up container")
					err = removeContainer(ctx, client, container)
					if err != nil {
						log.Println(err)
					}
				}
				if image != "" && client != nil {
					log.Println("Cleaning up image")
					err = removeImage(ctx, client, image)
					if err != nil {
						log.Println(err)
					}
				}
			})

			Context("when the container is running", func() {
				It("jupyterlab should respond with 200 on the base url", func(ctx SpecContext) {
					req, err := http.NewRequestWithContext(ctx, "GET", baseURL.String(), nil)
					Expect(err).ToNot(HaveOccurred())
					Eventually(func(g Gomega) int {
						res, err := httpClient.Do(req)
						g.Expect(err).ToNot(HaveOccurred())
						return res.StatusCode
					}).WithTimeout(time.Minute * 1).WithOffset(1).Should(Equal(200))
				})
				It("python should contain the custom package and not contain jupyter_server", func(ctx SpecContext) {
					output, err := execInContainer(ctx, client, container, []string{"launcher", "bash", "-c", "python -m pip list"})
					Expect(err).ToNot(HaveOccurred())
					Expect(output).To(ContainSubstring(customPackage))
					Expect(output).ToNot(ContainSubstring("jupyter_server"))
				})
			})
		},
		Entry("using pip with init-scripts", "../../samples/init-scripts"),
		Entry("using conda", "../../samples/conda"),
		Entry("using poetry", "../../samples/poetry"),
	)

	DescribeTableSubtree(
		"rstudio",
		func(source string) {
			var image string
			var container string
			var port int
			var baseURL url.URL
			BeforeAll(func(ctx SpecContext) {
				image = strings.ToLower(fmt.Sprintf("test-image-%s", getULID()))
				Expect(buildImage(ctx, builderImg, source, image, map[string]string{"BP_RENKU_FRONTENDS": "rstudio"})).To(Succeed())
				port = getFreePortOrDie()
				envVars := []string{fmt.Sprintf("RENKU_SESSION_PORT=%d", port)}
				ports := map[int]int{port: port}
				container, err = runImage(ctx, client, image, envVars, ports)
				Expect(err).ToNot(HaveOccurred())
				baseURL = url.URL{
					Host:   fmt.Sprintf("127.0.0.1:%d", port),
					Scheme: "http",
				}
			})

			AfterAll(func(ctx SpecContext) {
				if container != "" && client != nil {
					log.Println("Cleaning up container")
					err = removeContainer(ctx, client, container)
					if err != nil {
						log.Println(err)
					}
				}
				if image != "" && client != nil {
					log.Println("Cleaning up image")
					err = removeImage(ctx, client, image)
					if err != nil {
						log.Println(err)
					}
				}
			})

			Context("when the container is running", func() {
				It("rstudio should respond with 200 on the base url", func(ctx SpecContext) {
					req, err := http.NewRequestWithContext(ctx, "GET", baseURL.String(), nil)
					Expect(err).ToNot(HaveOccurred())
					Eventually(func(g Gomega) int {
						res, err := httpClient.Do(req)
						g.Expect(err).ToNot(HaveOccurred())
						return res.StatusCode
					}).WithTimeout(time.Minute * 1).WithOffset(1).Should(Equal(200))
				})
				It("Users should be install packages in the container", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"bash", "-c", "R -e '.libPaths(\"'$RENKU_WORKING_DIR/.rstudio'\"); install.packages(\"dplyr\", repos = \"https://cloud.r-project.org\")'"})
					Expect(err).ToNot(HaveOccurred())
				})
			})
		},
		Entry("using r sample", "../../samples/r"),
	)

	DescribeTableSubtree(
		"conda-nodefaults-fail",
		func(source string) {
			var image string

			Context("image building", func() {
				It("should fail when the defaults channel is included", func(ctx SpecContext) {
					image = strings.ToLower(fmt.Sprintf("test-image-%s", getULID()))
					err = buildImage(ctx, builderImg, source, image, map[string]string{"BP_RENKU_FRONTENDS": "vscodium"})
					Expect(err).To(HaveOccurred())
				})
			})
		},
		Entry("using conda-defaults sample", "../../samples/conda-defaults"),
	)

	DescribeTableSubtree(
		"conda-nodefaults-pass",
		func(source string) {
			var image string
			Context("image building", func() {
				It("should pass when the defaults channel is not included or conda is not used", func(ctx SpecContext) {
					image = strings.ToLower(fmt.Sprintf("test-image-%s", getULID()))
					err = buildImage(ctx, builderImg, source, image, map[string]string{"BP_RENKU_FRONTENDS": "vscodium"})
					Expect(err).ToNot(HaveOccurred())
				})
			})
		},
		Entry("using conda sample", "../../samples/conda"),
		Entry("using pip sample", "../../samples/pip"),
	)

	DescribeTableSubtree(
		"deb-packages",
		func(source string) {
			var image string
			var container string
			var port int
			var baseURL url.URL
			BeforeAll(func(ctx SpecContext) {
				image = strings.ToLower(fmt.Sprintf("test-image-%s", getULID()))
				Expect(buildImage(ctx, builderImg, source, image, map[string]string{"BP_RENKU_FRONTENDS": "ttyd"})).To(Succeed())
				port = getFreePortOrDie()
				envVars := []string{fmt.Sprintf("RENKU_SESSION_PORT=%d", port)}
				ports := map[int]int{port: port}
				container, err = runImage(ctx, client, image, envVars, ports)
				Expect(err).ToNot(HaveOccurred())
				baseURL = url.URL{
					Host:   fmt.Sprintf("127.0.0.1:%d", port),
					Scheme: "http",
				}
			})

			AfterAll(func(ctx SpecContext) {
				if container != "" && client != nil {
					log.Println("Cleaning up container")
					err = removeContainer(ctx, client, container)
					if err != nil {
						log.Println(err)
					}
				}
				if image != "" && client != nil {
					log.Println("Cleaning up image")
					err = removeImage(ctx, client, image)
					if err != nil {
						log.Println(err)
					}
				}
			})

			Context("when the container is running", func() {
				It("ttyd should respond with 200 on the base url", func(ctx SpecContext) {
					req, err := http.NewRequestWithContext(ctx, "GET", baseURL.String(), nil)
					Expect(err).ToNot(HaveOccurred())
					Eventually(func(g Gomega) int {
						res, err := httpClient.Do(req)
						g.Expect(err).ToNot(HaveOccurred())
						return res.StatusCode
					}).WithTimeout(time.Minute * 1).WithOffset(1).Should(Equal(200))
				})
				It("tree should exist as a command in the container", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"launcher", "tree"})
					Expect(err).ToNot(HaveOccurred())
				})
				It("ag should not exist as a command in the container", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"launcher", "ag"})
					Expect(err).To(HaveOccurred())
				})
			})
		},
		Entry("using deb sample", "../../samples/deb"),
	)

	DescribeTableSubtree(
		"homebrew",
		func(source string) {
			var image string
			var container string
			var port int
			BeforeAll(func(ctx SpecContext) {
				image = strings.ToLower(fmt.Sprintf("test-image-%s", getULID()))
				Expect(buildImage(ctx, builderImg, source, image, map[string]string{})).To(Succeed())
				port = getFreePortOrDie()
				envVars := []string{fmt.Sprintf("RENKU_SESSION_PORT=%d", port)}
				ports := map[int]int{port: port}
				container, err = runImage(ctx, client, image, envVars, ports)
				Expect(err).ToNot(HaveOccurred())
			})

			AfterAll(func(ctx SpecContext) {
				if container != "" && client != nil {
					log.Println("Cleaning up container")
					err = removeContainer(ctx, client, container)
					if err != nil {
						log.Println(err)
					}
				}
				if image != "" && client != nil {
					log.Println("Cleaning up image")
					err = removeImage(ctx, client, image)
					if err != nil {
						log.Println(err)
					}
				}
			})

			Context("when the container is running", func() {
				It("lazygit should exist as a command in the container", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"launcher", "lazygit", "--version"})
					Expect(err).ToNot(HaveOccurred())
				})
				It("brew should not exist as a command in the container", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"launcher", "brew"})
					Expect(err).To(HaveOccurred())
				})
			})
		},
		Entry("using homebrew sample", "../../samples/homebrew"),
	)

	DescribeTableSubtree(
		"coding-agent",
		func(source string) {
			var image string
			var container string
			var port int
			BeforeAll(func(ctx SpecContext) {
				image = strings.ToLower(fmt.Sprintf("test-image-%s", getULID()))
				Expect(buildImage(ctx, builderImg, source, image, map[string]string{})).To(Succeed())
				port = getFreePortOrDie()
				envVars := []string{fmt.Sprintf("RENKU_SESSION_PORT=%d", port)}
				ports := map[int]int{port: port}
				container, err = runImage(ctx, client, image, envVars, ports)
				Expect(err).ToNot(HaveOccurred())
			})

			AfterAll(func(ctx SpecContext) {
				if container != "" && client != nil {
					log.Println("Cleaning up container")
					err = removeContainer(ctx, client, container)
					if err != nil {
						log.Println(err)
					}
				}
				if image != "" && client != nil {
					log.Println("Cleaning up image")
					err = removeImage(ctx, client, image)
					if err != nil {
						log.Println(err)
					}
				}
			})

			Context("when the container is running", func() {
				It("pi should exist as a command in the container", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"launcher", "pi", "--version"})
					Expect(err).ToNot(HaveOccurred())
				})
				It("users should be able to install pi npm packages", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"launcher", "pi", "install", "npm:pi-adaptive-thinking"})
					Expect(err).ToNot(HaveOccurred())
				})
				It("claude should exist as a command in the container", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"launcher", "claude", "--version"})
					Expect(err).ToNot(HaveOccurred())
				})
				It("codex should exist as a command in the container", func(ctx SpecContext) {
					_, err := execInContainer(ctx, client, container, []string{"launcher", "codex", "--version"})
					Expect(err).ToNot(HaveOccurred())
				})
			})
		},
		Entry("using coding-agent sample", "../../samples/coding-agent"),
	)

	DescribeTableSubtree(
		"ssh",
		func(source string) {
			var image string
			var container string
			var webPort int
			var sshPort int
			var baseURL url.URL
			var keyPath string
			BeforeAll(func(ctx SpecContext) {
				image = strings.ToLower(fmt.Sprintf("test-image-%s", getULID()))
				Expect(buildImage(ctx, builderImg, source, image, map[string]string{"BP_RENKU_FRONTENDS": "ssh"})).To(Succeed())
				webPort = getFreePortOrDie()
				sshPort = getFreePortOrDie()
				// because getFreePortOrDie releases its listener before returning,
				// we fail loudly rather than silently collapsing the port bindings
				Expect(sshPort).ToNot(Equal(webPort))
				envVars := []string{fmt.Sprintf("RENKU_SESSION_PORT=%d", webPort), "RENKU_WORKING_DIR=/workspace", "LD_LIBRARY_PATH=/opt/conda-e2e-libs"}
				ports := map[int]int{webPort: webPort, sshPort: 2222}
				container, err = runImage(ctx, client, image, envVars, ports)
				Expect(err).ToNot(HaveOccurred())
				baseURL = url.URL{
					Host:   fmt.Sprintf("127.0.0.1:%d", webPort),
					Scheme: "http",
				}
				keyDir := GinkgoT().TempDir()
				keyPath = filepath.Join(keyDir, "id_ed25519")
				Expect(exec.Command("ssh-keygen", "-t", "ed25519", "-N", "", "-q", "-f", keyPath).Run()).To(Succeed())
				pub, err := os.ReadFile(keyPath + ".pub")
				Expect(err).ToNot(HaveOccurred())
				// runImage cannot mount volumes; dropbear reads ~/.ssh/authorized_keys
				// per-login, so write the key the same way a secret mount would provide it
				_, err = execInContainer(ctx, client, container, []string{"bash", "-c",
					fmt.Sprintf("mkdir -p ~/.ssh && echo '%s' > ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys",
						strings.TrimSpace(string(pub)))})
				Expect(err).ToNot(HaveOccurred())
			})

			AfterAll(func(ctx SpecContext) {
				if container != "" && client != nil {
					log.Println("Cleaning up container")
					err = removeContainer(ctx, client, container)
					if err != nil {
						log.Println(err)
					}
				}
				if image != "" && client != nil {
					log.Println("Cleaning up image")
					err = removeImage(ctx, client, image)
					if err != nil {
						log.Println(err)
					}
				}
			})

			Context("when the container is running", func() {
				It("placeholder page should respond with 200 on the session port", func(ctx SpecContext) {
					req, err := http.NewRequestWithContext(ctx, "GET", baseURL.String(), nil)
					Expect(err).ToNot(HaveOccurred())
					Eventually(func(g Gomega) int {
						res, err := httpClient.Do(req)
						g.Expect(err).ToNot(HaveOccurred())
						return res.StatusCode
					}).WithTimeout(time.Minute * 1).WithOffset(1).Should(Equal(200))
				})
				It("should allow SSH login with the provided public key", func(ctx SpecContext) {
					sshIntoSession := func(g Gomega) {
						cmd := exec.CommandContext(ctx, "ssh",
							"-i", keyPath,
							"-p", fmt.Sprintf("%d", sshPort),
							"-o", "StrictHostKeyChecking=no",
							"-o", "UserKnownHostsFile=/dev/null",
							"-o", "LogLevel=ERROR",
							"-o", "BatchMode=yes",
							"-o", "IdentitiesOnly=yes",
							"renku@127.0.0.1", "whoami")
						out, err := cmd.CombinedOutput()
						g.Expect(err).ToNot(HaveOccurred(), "ssh output: %s", string(out))
						g.Expect(strings.TrimSpace(string(out))).To(Equal("renku"))
					}
					Eventually(sshIntoSession).WithTimeout(time.Minute * 1).WithPolling(time.Second * 5).Should(Succeed())
				})

				It("should expose the CNB launch environment to SSH sessions", func(ctx SpecContext) {
					sshIntoSession := func(g Gomega) {
						cmd := exec.CommandContext(ctx, "ssh",
							"-i", keyPath,
							"-p", fmt.Sprintf("%d", sshPort),
							"-o", "StrictHostKeyChecking=no",
							"-o", "UserKnownHostsFile=/dev/null",
							"-o", "LogLevel=ERROR",
							"-o", "BatchMode=yes",
							"-o", "IdentitiesOnly=yes",
							"renku@127.0.0.1", "printenv PATH")
						out, err := cmd.CombinedOutput()
						g.Expect(err).ToNot(HaveOccurred(), "ssh output: %s", string(out))
						// the ssh layer's bin dir (prepended via env.launch) must survive
						g.Expect(string(out)).To(ContainSubstring("/layers/renku_ssh/ssh/bin"))
					}
					Eventually(sshIntoSession).WithTimeout(time.Minute * 1).WithPolling(time.Second * 5).Should(Succeed())
				})

				It("should wrap interactive SSH sessions in tmux", func(ctx SpecContext) {
					sshIntoTmux := func(g Gomega) {
						runCtx, cancel := context.WithTimeout(ctx, time.Minute)
						defer cancel()
						cmd := exec.CommandContext(runCtx, "ssh",
							"-tt",
							"-i", keyPath,
							"-p", fmt.Sprintf("%d", sshPort),
							"-o", "StrictHostKeyChecking=no",
							"-o", "UserKnownHostsFile=/dev/null",
							"-o", "LogLevel=ERROR",
							"-o", "BatchMode=yes",
							"-o", "IdentitiesOnly=yes",
							"renku@127.0.0.1")
						stdin, err := cmd.StdinPipe()
						g.Expect(err).ToNot(HaveOccurred())
						var out bytes.Buffer
						cmd.Stdout = &out
						cmd.Stderr = &out
						g.Expect(cmd.Start()).To(Succeed())
						// wait for the tmux server to come up, give the client a beat to
						// finish attaching (keys typed before the client sets raw mode are
						// mangled by the pty's canonical-mode echo and reach the pane instead),
						// then detach via tmux's prefix key (C-b d)
						Eventually(func(g Gomega) {
							_, err := execInContainer(ctx, client, container, []string{"tmux", "list-sessions"})
							g.Expect(err).ToNot(HaveOccurred())
						}).WithTimeout(time.Second * 30).WithPolling(time.Millisecond * 500).Should(Succeed())
						time.Sleep(time.Second)
						_, err = execInContainer(ctx, client, container, []string{"tmux", "send-keys",
							"-t", "0", "printenv LD_LIBRARY_PATH > /tmp/pane_ld_library_path", "Enter"})
						g.Expect(err).ToNot(HaveOccurred())
						_, _ = stdin.Write([]byte{0x02, 'd'})
						_ = stdin.Close()
						g.Expect(cmd.Wait()).ToNot(HaveOccurred(), "ssh output: %s", out.String())
						// the tmux server must have outlived the detached session
						_, err = execInContainer(runCtx, client, container, []string{"tmux", "list-sessions"})
						g.Expect(err).ToNot(HaveOccurred())
					}
					Eventually(sshIntoTmux).WithTimeout(time.Minute * 2).WithPolling(time.Second * 5).Should(Succeed())
				})

				It("should preserve LD_LIBRARY_PATH inside tmux panes", func(ctx SpecContext) {
					Eventually(func(g Gomega) {
						out, err := execInContainer(ctx, client, container, []string{"cat", "/tmp/pane_ld_library_path"})
						g.Expect(err).ToNot(HaveOccurred())
						// the pane env must carry the launch-env value exported by the
						// conda buildpack AND the container-injected test value
						g.Expect(out).To(ContainSubstring("paketo-buildpacks_conda-env-update/conda-env/lib"))
						g.Expect(out).To(ContainSubstring("/opt/conda-e2e-libs"))
					}).WithTimeout(time.Second * 30).WithPolling(time.Second).Should(Succeed())
				})

				scpIntoSession := func(ctx SpecContext, g Gomega, extraArgs ...string) {
					src := filepath.Join(GinkgoT().TempDir(), "hello_scp.txt")
					Expect(os.WriteFile(src, []byte("hello scp\n"), 0o644)).To(Succeed())
					args := append([]string{
						"-i", keyPath,
						"-P", fmt.Sprintf("%d", sshPort),
						"-o", "StrictHostKeyChecking=no",
						"-o", "UserKnownHostsFile=/dev/null",
						"-o", "LogLevel=ERROR",
						"-o", "BatchMode=yes",
						"-o", "IdentitiesOnly=yes",
					}, extraArgs...)
					args = append(args, src, "renku@127.0.0.1:")
					cmd := exec.CommandContext(ctx, "scp", args...)
					out, err := cmd.CombinedOutput()
					g.Expect(err).ToNot(HaveOccurred(), "scp output: %s", string(out))
					// relative remote targets resolve against the session working dir
					content, err := execInContainer(ctx, client, container, []string{"cat", "/workspace/hello_scp.txt"})
					g.Expect(err).ToNot(HaveOccurred())
					g.Expect(content).To(ContainSubstring("hello scp"))
				}
				It("should start SSH sessions in the session working dir", func(ctx SpecContext) {
					sshIntoSession := func(g Gomega) {
						cmd := exec.CommandContext(ctx, "ssh",
							"-i", keyPath,
							"-p", fmt.Sprintf("%d", sshPort),
							"-o", "StrictHostKeyChecking=no",
							"-o", "UserKnownHostsFile=/dev/null",
							"-o", "LogLevel=ERROR",
							"-o", "BatchMode=yes",
							"-o", "IdentitiesOnly=yes",
							"renku@127.0.0.1", "pwd")
						out, err := cmd.CombinedOutput()
						g.Expect(err).ToNot(HaveOccurred(), "ssh output: %s", string(out))
						g.Expect(strings.TrimSpace(string(out))).To(Equal("/workspace"))
					}
					Eventually(sshIntoSession).WithTimeout(time.Minute * 1).WithPolling(time.Second * 5).Should(Succeed())
				})

				It("should allow scp file upload via sftp protocol (modern scp default)", func(ctx SpecContext) {
					Eventually(func(g Gomega) { scpIntoSession(ctx, g) }).
						WithTimeout(time.Minute * 1).WithPolling(time.Second * 5).Should(Succeed())
				})
				It("should allow scp file upload via legacy protocol (scp -O)", func(ctx SpecContext) {
					Eventually(func(g Gomega) { scpIntoSession(ctx, g, "-O") }).
						WithTimeout(time.Minute * 1).WithPolling(time.Second * 5).Should(Succeed())
				})
			})
		},
		Entry("using conda sample", "../../samples/conda"),
	)
})
