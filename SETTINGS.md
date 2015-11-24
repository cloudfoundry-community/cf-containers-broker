# Settings

To configure the service broker update the [config/settings.yml](https://github.com/cloudfoundry-community/cf-containers-broker/blob/master/config/settings.yml)
file according to your environment.

## Properties format

<table>
  <tr>
    <th>Field</th>
    <th>Required</th>
    <th>Type</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>auth_username</td>
    <td>Y</td>
    <td>String</td>
    <td>Username for authentication access to the service broker.</td>
  </tr>
  <tr>
    <td>auth_password</td>
    <td>Y</td>
    <td>String</td>
    <td>Password for authentication access to the service broker.</td>
  </tr>
  <tr>
    <td>cookie_secret</td>
    <td>Y</td>
    <td>String</td>
    <td>Session secret key for Rack::Session::Cookie.</td>
  </tr>
  <tr>
    <td>session_expiry</td>
    <td>Y</td>
    <td>String</td>
    <td>Session expiry for Rack::Session::Cookie.</td>
  </tr>
  <tr>
    <td>cc_api_uri</td>
    <td>Y</td>
    <td>String</td>
    <td>Cloud Foundry API URI.</td>
  </tr>
  <tr>
    <td>external_ip</td>
    <td>Y</td>
    <td>String</td>
    <td>Broker external IP address</td>
  </tr>
  <tr>
    <td>external_host</td>
    <td>Y</td>
    <td>String</td>
    <td>Hostname to use when exposing the dashboard url.</td>
  </tr>
  <tr>
    <td>ssl_enabled</td>
    <td>N</td>
    <td>Boolean</td>
    <td>Set if the service broker must use SSL or not (`false` by default).</td>
  </tr>
  <tr>
    <td>skip_ssl_validation</td>
    <td>N</td>
    <td>Boolen</td>
    <td>Set if the service broker must skip SSL validation or not when connecting to the CC API (`false` by
    default).</td>
  </tr>
  <tr>
    <td>host_directory</td>
    <td>Y</td>
    <td>String</td>
    <td>Host directory prefix to use when containers bind a volume to a host directory.</td>
  </tr>
  <tr>
    <td>max_containers</td>
    <td>N</td>
    <td>String</td>
    <td>Maximum number of containers allowed to provision. If not set or if the value is 0, it would mean users can
    provision unlimited containers.</td>
  </tr>
  <tr>
    <td>allocate_docker_host_ports</td>
    <td>N</td>
    <td>Boolean</td>
    <td>Allocate automatically host ports when binding a Docker container. This is useful in order to preserve the container exposed host ports in case of a VM restart.</td>
  </tr>
  <tr>
    <td>services</td>
    <td>Y</td>
    <td>Array</td>
    <td>Services that the service broker provides [1].</td>
  </tr>
  <tr>
    <td>services.plans</td>
    <td>Y</td>
    <td>Array</td>
    <td>Service Plans that the service broker provides [2].</td>
  </tr>
</table>

[1] See [Services Metadata Fields](http://docs.cloudfoundry.org/services/catalog-metadata.html#services-metadata-fields)

[2] See [Plan Metadata Fields](http://docs.cloudfoundry.org/services/catalog-metadata.html#plan-metadata-fields)
