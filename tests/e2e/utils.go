package e2e

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net"
	"os/exec"
	"time"

	"github.com/docker/docker/api/types/container"
	dockerImage "github.com/docker/docker/api/types/image"
	docker "github.com/docker/docker/client"
	"github.com/docker/go-connections/nat"
	"github.com/oklog/ulid/v2"
)

func buildBuilder(ctx context.Context, builderLoc, image string) error {
	args := []string{
		"builder",
		"create",
		image,
		"--config",
		builderLoc,
		"--target",
		"linux/amd64",
	}
	cmd := exec.CommandContext(
		ctx,
		"pack",
		args...,
	)
	output, err := cmd.CombinedOutput()
	if err != nil {
		err = errors.Join(err, fmt.Errorf("the command failed with output %s", string(output)))
		return err
	}
	log.Println("Builder was successfully built")
	log.Println(string(output))
	return nil
}

func buildImage(ctx context.Context, builderImg, source, image string, envs map[string]string) error {
	args := []string{
		"build",
		image,
		"--clear-cache",
		"--path",
		source,
		"--builder",
		builderImg,
		"--platform",
		"linux",
	}
	for k, v := range envs {
		args = append(args, "--env")
		args = append(args, fmt.Sprintf("%s=%s", k, v))
	}
	cmd := exec.CommandContext(
		ctx,
		"pack",
		args...,
	)
	output, err := cmd.CombinedOutput()
	if err != nil {
		err = errors.Join(err, fmt.Errorf("the command failed with output %s", string(output)))
		return err
	}
	log.Println("Image was successfully built")
	log.Println(string(output))
	return nil
}

func runImage(ctx context.Context, client docker.ContainerAPIClient, image string, envVars []string, portMaping map[int]int) (string, error) {
	exposedPorts := nat.PortSet{}
	portBinds := nat.PortMap{}
	for hostPort, containerPort := range portMaping {
		exposedPorts[nat.Port(fmt.Sprintf("%d/tcp", containerPort))] = struct{}{}
		hostBinding := nat.PortBinding{
			HostIP:   "127.0.0.1",
			HostPort: fmt.Sprintf("%d", hostPort),
		}
		portBinds[nat.Port(fmt.Sprintf("%d/tcp", containerPort))] = []nat.PortBinding{hostBinding}
	}
	config := container.Config{
		Image:        image,
		ExposedPorts: exposedPorts,
		Env:          envVars,
	}
	hostConfig := container.HostConfig{
		PortBindings: portBinds,
	}
	cont, err := client.ContainerCreate(ctx, &config, &hostConfig, nil, nil, "")
	if err != nil {
		return "", err
	}
	err = client.ContainerStart(ctx, cont.ID, container.StartOptions{})
	if err != nil {
		return "", err
	}
	return cont.ID, nil
}

func execInContainer(ctx context.Context, client docker.ContainerAPIClient, containerID string, cmd []string) (string, error) {
	execOpts := container.ExecOptions{
		Cmd:          cmd,
		AttachStderr: true,
		AttachStdout: true,
	}
	ex, err := client.ContainerExecCreate(ctx, containerID, execOpts)
	if err != nil {
		return "", err
	}
	attOpts := container.ExecAttachOptions{}
	res, err := client.ContainerExecAttach(ctx, ex.ID, attOpts)
	if err != nil {
		return "", err
	}
	defer res.Close()
	startOpts := container.ExecStartOptions{}
	err = client.ContainerExecStart(ctx, ex.ID, startOpts)
	if err != nil {
		return "", err
	}
	cont, err := io.ReadAll(res.Reader)
	if err != nil {
		return "", err
	}
	return string(cont), nil
}

func removeContainer(ctx context.Context, client docker.ContainerAPIClient, containerID string) error {
	opts := container.RemoveOptions{
		RemoveVolumes: true,
		Force:         true,
	}
	return client.ContainerRemove(ctx, containerID, opts)
}

func removeImage(ctx context.Context, client docker.ImageAPIClient, image string) error {
	opts := dockerImage.RemoveOptions{Force: true, PruneChildren: true}
	_, err := client.ImageRemove(ctx, image, opts)
	return err
}

func getULID() string {
	t := time.Unix(1000000, 0)
	entropy := ulid.Monotonic(rand.New(rand.NewSource(t.UnixNano())), 0)
	return ulid.MustNew(ulid.Timestamp(t), entropy).String()
}

func getFreePortOrDie() int {
	var a *net.TCPAddr
	var err error
	if a, err = net.ResolveTCPAddr("tcp", "localhost:0"); err == nil {
		var l *net.TCPListener
		if l, err = net.ListenTCP("tcp", a); err == nil {
			defer func() {
				err := l.Close()
				if err != nil {
					panic(err)
				}
			}()
			return l.Addr().(*net.TCPAddr).Port
		}
		panic(err)
	}
	panic(err)
}
