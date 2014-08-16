# Credentials

Each service `plan` defined at the [settings](https://github.com/cf-platform-eng/cf-containers-broker/blob/master/SETTINGS.md)
file can have a single set of credentials. Credentials can be predefined (statically defined in the container or at
the [settings](https://github.com/cf-platform-eng/cf-containers-broker/blob/master/SETTINGS.md) file), or generated
randomly and injected into the container at provision/bind time.

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
    <td>credentials</td>
    <td>N</td>
    <td>Hash</td>
    <td>Credentials properties.</td>
  </tr>
  <tr>
    <td>credentials.username</td>
    <td>N</td>
    <td>Hash</td>
    <td>Properties to build the `username` credentials field [1].</td>
  </tr>
  <tr>
    <td>credentials.username.key</td>
    <td>N</td>
    <td>String</td>
    <td>Name of the environment variable to pass to the container to set the service username.</td>
  </tr>
  <tr>
    <td>credentials.username.value</td>
    <td>N</td>
    <td>String</td>
    <td>Username to send to the container via the environment variable. If not set, and
    `credentials.username.key` is set, the broker will create a random username.</td>
  </tr>
  <tr>
    <td>credentials.password</td>
    <td>N</td>
    <td>Hash</td>
    <td>Properties to build the `password` credentials field [1].</td>
  </tr>
  <tr>
    <td>credentials.password.key</td>
    <td>N</td>
    <td>String</td>
    <td>Name of the environment variable to pass to the container to set the service password.</td>
  </tr>
  <tr>
    <td>credentials.password.value</td>
    <td>N</td>
    <td>String</td>
    <td>Password to send to the container via the environment variable. If not set, and
    `credentials.password.key` is set, the broker will create a random password.</td>
  </tr>
  <tr>
    <td>credentials.dname</td>
    <td>N</td>
    <td>Hash</td>
    <td>Properties to build the `dbname` to append to the `uri` credentials field [1].</td>
  </tr>
  <tr>
    <td>credentials.dbname.key</td>
    <td>N</td>
    <td>String</td>
    <td>Name of the environment variable to pass to the container to set the service dbname.</td>
  </tr>
  <tr>
    <td>credentials.dbname.value</td>
    <td>N</td>
    <td>String</td>
    <td>Dbname to send to the container via the environment variable. If not set, and
    `credentials.dbname.key` is set, the broker will create a random dbname.</td>
  </tr>
  <tr>
    <td>credentials.uri</td>
    <td>N</td>
    <td>Hash</td>
    <td>Properties to build the `uri` credentials field [1].</td>
  </tr>
  <tr>
    <td>credentials.uri.prefix</td>
    <td>N</td>
    <td>String</td>
    <td>Prefix (ie `dbtype`) to add at the `uri` part of the credentials.</td>
  </tr>
  <tr>
    <td>credentials.uri.port</td>
    <td>N</td>
    <td>String</td>
    <td>Container port to be exposed at the the `uri` part of the credentials (format: port&lt;/protocol&gt;). The
    broker will translate this port to the real exposed host port. This field is not required unless your container
    exposes more than 1 port (ie the server port and the web ui port) and you just want to send one of them to the
    application binding.</td>
  </tr>
</table>

[1] See [Binding credentials](http://docs.cloudfoundry.org/services/binding-credentials.html)

## Example

This example will use a predefined username named `admin` and it will create a random password and dbname.
Credentials will be sent to the container using the environment variables `SERVICE_USERNAME`,
`SERVICE_PASSWORD` and `SERVICE_DBNAME` respectively. When an application is bound to the
service, it will receive a credentials hash with an URI following this pattern: `mongodb://admin:<RANDOM
PASSWORD>@<HOST IP>:<HOST PORT MAPPED TO CONTAINER PORT 27017/tcp>/<RANDOM DBNAME>`.

```yaml
credentials:
  username:
    key: 'SERVICE_USERNAME'
    value: 'admin'
  password:
    key: 'SERVICE_PASSWORD'
  dbname:
    key: 'SERVICE_DBNAME'
  uri:
    prefix: 'mongodb'
    port: '27017/tcp'
```
