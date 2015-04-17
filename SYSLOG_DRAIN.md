# Syslog Drain

Each service `plan` defined at the [settings](https://github.com/cf-platform-eng/cf-containers-broker/blob/master/SETTINGS.md)
file can have a single syslog drain. If defined, Cloud Foundry would drain events and logs to the service for the
bound applications.

As defined at the [Application Log Streaming](http://docs.cloudfoundry.org/services/app-log-streaming.html), a `syslog_drain`
permission is required for events and logs to be automatically wired to applications.

## Properties format

Each service `plan` defined at the [settings](https://github.com/cf-platform-eng/cf-containers-broker/blob/master/SETTINGS.md)
file might contain the following properties:

<table>
  <tr>
    <th>Field</th>
    <th>Required</th>
    <th>Type</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>syslog_drain_port</td>
    <td>N</td>
    <td>String</td>
    <td>Container port to be exposed (format: port&lt;/protocol&gt;).</td>
  </tr>
  <tr>
    <td>syslog_drain_protocol</td>
    <td>N</td>
    <td>String</td>
    <td>Syslog protocol (syslog, syslog-tls, https).</td>
  </tr>
</table>

## Example

This example will create a plan that will provision a [logstash](http://logstash.net/) service container
([Dockerfile](https://github.com/frodenas/docker-logstash)) and it will expose the syslog drain container port
`514/tcp`. When an application is bound to the service, it will receive a syslog drain URL following this pattern:
`syslog-tls://<HOST IP>:#<HOST PORT MAPPED TO CONTAINER PORT 514/tcp>`. Cloud Foundry will automatically drain all the
application events and logs to this URL.

```yaml
plans:
  - id: '5218782d-7fab-4534-92b8-434204d88c7b'
    name: 'free'
    container:
      backend: 'docker'
      image: 'frodenas/logstash'
    syslog_drain_port: '514/tcp'
    syslog_drain_protocol: 'syslog-tls'
```
