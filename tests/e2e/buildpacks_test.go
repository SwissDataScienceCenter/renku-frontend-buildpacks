package e2e

import (
	"fmt"
	"log"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
	"time"

	docker "github.com/docker/docker/client"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

const builderLoc = "../../builders/selector"

var _ = Describe("Testing samples", Label("samples"), Ordered, func() {
	var builderImg string
	var client docker.APIClient
	var err error

	BeforeAll(func(ctx SpecContext) {
		builderImg = strings.ToLower(fmt.Sprintf("test-builder-image-%s", getULID()))
		Expect(buildBuilder(ctx, filepath.Join(builderLoc, "builder.toml"), builderImg)).To(Succeed())
		client, err = docker.NewClientWithOpts(docker.FromEnv, docker.WithAPIVersionNegotiation())
		Expect(err).ToNot(HaveOccurred())
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

	When("using pip", func() {
		var image string
		var container string
		const source = "../../samples/pip"
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
					res, err := http.DefaultClient.Do(req)
					g.Expect(err).ToNot(HaveOccurred())
					return res.StatusCode
				}).WithTimeout(time.Minute * 1).WithOffset(1).Should(Equal(200))
			})
		})
	})
})
