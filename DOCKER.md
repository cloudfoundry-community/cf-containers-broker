# Docker backend

This backend will use [Docker](https://www.docker.com/) for container management. It will leverage the
[Docker Remote API](https://docs.docker.com/reference/api/docker_remote_api/) over a unix socket or tcp connection to
perform actions against Docker. It supports:

* Prefetching Docker images when the broker is started to speed up containers creation.
* Creating Docker containers when the broker provisions a service.
* Creating random usernames, passwords and dbnames when binding an application to the service. Those credentials are
sent to the Docker container via environment variables, so the Docker image must support those variables in order to
create the right username/password and dbname (see [CREDENTIALS.md](https://github.com/cf-platform-eng/cf-containers-broker/blob/master/CREDENTIALS.md)
for details).
* Exposing a container port where the bound applications can drain their logs
(see [SYSLOG_DRAIN.md](https://github.com/cf-platform-eng/cf-containers-broker/blob/master/SYSLOG_DRAIN.md)
for details).
* Destroying Docker containers when the broker unprovisions a service.
* Exposing a Management Dashboard with Docker container information, top processes running inside the container,
and the latest stdout and stderr logs.

## Prerequisites

The service broker does not deploy Docker, so you must have a Docker daemon up and running.

**You must use Docker 1.1.2 or greater.**

If you are running Docker locally as a socket, there is no setup to do. If you are not or you have changed the path of
the socket, you will have to set the `DOCKER_URL` environment variable to point to your socket or local/remote port.
For example:

```
DOCKER_URL=unix:///var/run/docker.sock
DOCKER_URL=tcp://localhost:4243
```

Remember that if you are running this service broker as a Docker container and the Docker remote API is going to use
the unix sockets, you must expose the  container's directory `/var/run` to the host directory containing the Docker
unix socket:

```
docker run -d --name cf-containers-broker \
       --publish 80:80 \
       --volume /var/run:/var/run \
       frodenas/cf-containers-broker
```

## Properties format

Each service `plan` defined at the [settings](https://github.com/cf-platform-eng/cf-containers-broker/blob/master/SETTINGS.md) file must contain the following properties:

<table>
  <tr>
    <th>Field</th>
    <th>Required</th>
    <th>Type</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>container</td>
    <td>Y</td>
    <td>Hash</td>
    <td>Properties of the container to deploy.</td>
  </tr>
  <tr>
    <td>container.backend</td>
    <td>Y</td>
    <td>String</td>
    <td>Container Backend. It must be `docker`.</td>
  </tr>
  <tr>
    <td>container.image</td>
    <td>Y</td>
    <td>String</td>
    <td>Name of the image fo fetch and run. The image will be pre-fetched at broker startup.</td>
  </tr>
  <tr>
    <td>container.tag</td>
    <td>N</td>
    <td>String</td>
    <td>Tag of the image. If not set, it will use `latest` by default.</td>
  </tr>
  <tr>
    <td>container.command</td>
    <td>N</td>
    <td>String</td>
    <td>Command to run the container (including arguments).</td>
  </tr>
  <tr>
    <td>container.entrypoint</td>
    <td>N</td>
    <td>Array of Strings</td>
    <td>Entrypoint for the container (only if you want to override the default entrypoint set by the image).</td>
  </tr>
  <tr>
    <td>container.workdir</td>
    <td>N</td>
    <td>String</td>
    <td>Working directory inside the container.</td>
  </tr>
  <tr>
    <td>container.restart</td>
    <td>N</td>
    <td>String</td>
    <td>Restart policy to apply when a container exits (no, on-failure, always). If not set,
    it will use `always` by default. The restart policy will apply also in case the VM hosting the container is
    killed and CF/BOSH resurrects it. Might happen that the new VM gets a new IP address, and probably the containers
    will use a new random port. In order to make any application bound to a container work again,
    the user must unbind/bind the application to the service again in order to pick the new IP/port.</td>
  </tr>
  <tr>
    <td>container.environment[]</td>
    <td>N</td>
    <td>Array of Strings</td>
    <td>Environment variables to pass to the container.</td>
  </tr>
  <tr>
    <td>container.expose_ports[]</td>
    <td>N</td>
    <td>Array of Strings</td>
    <td>Network ports to map from the container to random host ports (format: port&lt;/protocol&gt;). If not set,
    the broker will inspect the Docker image and it will expose all declared container ports [1] to a random host
    port.</td>
  </tr>
  <tr>
    <td>container.persistent_volumes[]</td>
    <td>N</td>
    <td>Array of Strings</td>
    <td>Volume mountpoints to bind from the container to a host directory. The broker will create automatically a
    host directory and it will bind it to the container volume mountpoint.</td>
  </tr>
  <tr>
    <td>container.user</td>
    <td>N</td>
    <td>String</td>
    <td>Username or UID to run the first container process.</td>
  </tr>
  <tr>
    <td>container.memory</td>
    <td>N</td>
    <td>String</td>
    <td>Memory limit to assign to the container (format: number&lt;optional unit&gt;, where unit = b, k, m or g).</td>
  </tr>
  <tr>
    <td>container.memory_swap</td>
    <td>N</td>
    <td>String</td>
    <td>Memory swap limit to assign to the container (format: number&lt;optional unit&gt;, where unit = b, k, m or g).</td>
  </tr>
  <tr>
    <td>container.cpu_shares</td>
    <td>N</td>
    <td>String</td>
    <td>CPU shares to assign to the container (relative weight).</td>
  </tr>
  <tr>
    <td>container.privileged</td>
    <td>N</td>
    <td>Boolean</td>
    <td>Enable/disable extended privileges for this container.</td>
  </tr>
  <tr>
    <td>container.cap_adds[]</td>
    <td>N</td>
    <td>Array of Strings</td>
    <td>Linux capabilities to add</td>
  </tr>
  <tr>
    <td>container.cap_drops[]</td>
    <td>N</td>
    <td>Array of Strings</td>
    <td>Linux capabilities to drop</td>
  </tr>
</table>

[1] See the Docker builder [EXPOSE](https://docs.docker.com/reference/builder/#expose) instruction

## Example

This example will create a [MongoDB 2.6](http://www.mongodb.org/) service using the Docker image
`frodenas/mongodb:2.6` ([Dockerfile](https://github.com/frodenas/docker-mongodb)). When the container is
started, it will use the default entrypoint and the following command arguments `--smallfiles
--httpinterface`. It will expose the container volume `/data` to a host directory created automatically by the
service broker.

```yaml
container:
  backend: 'docker'
  image: 'frodenas/mongodb'
  tag: '2.6'
  command: '--smallfiles --httpinterface'
  persistent_volumes:
    - '/data'
```
