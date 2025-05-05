package e2e

import (
	"fmt"
	"log"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"path/filepath"
	"strings"
	"time"

	docker "github.com/docker/docker/client"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

const builderLoc = "../../builders/selector"
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
		Entry("using pip", "../../samples/pip"),
		Entry("using conda", "../../samples/conda"),
		Entry("using poetry", "../../samples/poetry"),
	)

	FDescribeTableSubtree(
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
					_, err := execInContainer(ctx, client, container, []string{"launcher", "bash", "-c", "R -e 'install.packages(\"dplyr\")'"})
					Expect(err).ToNot(HaveOccurred())
				})
			})
		},
		Entry("using random sample", "../../samples/pip"),
	)
})
