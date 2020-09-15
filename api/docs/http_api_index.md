A Puppet server provides several services via HTTP API, and the Puppet
agent application uses those services to resolve a node's credentials, retrieve
a configuration catalog, retrieve file data, and submit reports.

In general, these APIs aren't designed for use by tools other than Puppet agent.
This is gradually changing, although we expect external use of these APIs to
remain low for the foreseeable future. The server ignores any parameters it isn't expecting.

V1/V2 HTTP APIs (Removed)
---------------

The V1 and V2 APIs were removed in Puppet 4.0.0. The routes that were previously
under `/` or `/v2.0` can now be found under the [`/puppet/v3`](#puppet-v3-http-api)
API or [`/puppet-ca/v1`](#ca-v1-http-api) API.

Starting with version 2.1, the Puppet Server 2.x series provides both the
current and previous API endpoints, and can serve nodes running Puppet agent 3.x
and 4.x. However, Rack masters, WEBrick masters, and Puppet Server 2.0 cannot
serve nodes running Puppet 3.x.

Puppet and Puppet CA APIs
------------------

Beginning with Puppet 4, Puppet's HTTP API has been split into two APIs, which
are versioned separately. There is now an API for configuration-related services
and a separate one for the certificate authority (CA).

All configuration endpoints are prefixed with `/puppet`, while all CA endpoints are
prefixed with `/puppet-ca`. All endpoints are explicitly versioned: the prefix
is always immediately followed by a string such as `/v3` (a directory separator,
the letter `v`, and the version number of the API).

### Authorization

As of Puppet 7, support for legacy auth.conf is removed. Puppet Server 7
enforces all authorization using its `auth.conf`. See
https://puppet.com/docs/puppetserver/latest/config_file_auth.html for more
details.

Puppet V3 HTTP API
------------------

The Puppet agent application uses several network services to manage systems.
These services are all grouped under the `/puppet` API. Other tools can access
these services and use the Puppet server's data for other purposes.

The V3 API contains endpoints of two types: those that are based on dispatching
to Puppet's internal "indirector" framework, and those that are not (namely the
[environment endpoints](#environment-endpoints)).

Every HTTP endpoint that dispatches to the indirector follows the form:
`/puppet/v3/:indirection/:key?environment=:environment` where:

* `:environment` is the name of the environment that should be in effect for
  the request. Not all endpoints need an environment, but the query
  parameter must always be specified.
* `:indirection` is the indirection to dispatch the request to.
* `:key` is the "key" portion of the indirection call.

Using this API requires significant understanding of how Puppet's internal
services are structured, but the following documents attempt to specify what is
available and how to interact with it.

### Configuration Management Services

These services are all directly used by the Puppet agent application, in order
to manage the configuration of a node.

These endpoints accept payload formats formatted as JSON or PSON (MIME types of
`application/json` and `text/pson`, respectively) except for `File Content` and
`File Bucket File` which always use `application/octet-stream`.

* [Facts](./http_facts.md)
* [Catalog](./http_catalog.md)
* [Node](./http_node.md)
* [File Bucket File](./http_file_bucket_file.md)
* [File Content](./http_file_content.md)
* [File Metadata](./http_file_metadata.md)
* [Report](./http_report.md)

### Informational Services

These services are not directly used by Puppet agent, but may be used by other
tools.

* [Status](./http_status.md)

### Environments Endpoint

The `/puppet/v3/environments` endpoint is different as it will only accept payloads
formatted as JSON and respond with JSON (MIME type of `application/json`).

* [Environments](./http_environments.md)

### Puppet Server-specific endpoints

Puppet Server adds additional `/puppet/v3/` endpoints:

* [Static File Content](https://puppet.com/docs/puppetserver/latest/puppet-api/v3/static_file_content.md)
* [Environment Classes](https://puppet.com/docs/puppetserver/latest/puppet-api/v3/environment_classes.md)

#### Error Responses

The `environments` endpoint will respond to error conditions in a uniform manner
and use standard HTTP response code to signify those errors.

* When the client submits a malformed request, the API will return a 400 Bad
  Request response.
* When the client is not authorized, the API will return a 403 Not Authorized
  response.
* When the client attempts to use an HTTP method that is not permissible for
  the endpoint, the API will return a 405 Method Not Allowed response.
* When the client asks for a response in a format other than JSON, the API will
  return a 406 Unacceptable response.
* When the server encounters an unexpected error during the handling of a
  request, it will return a 500 Server Error response.
* When the server is unable to find an endpoint handler for an http request,
  it will return a 404 Not Found response

All error responses will contain a body, except when it is a HEAD request. The
error responses will uniformly be a JSON object with the following properties:

* `message`: (`String`) A human readable message explaining the error.
* `issue_kind`: (`String`) A unique label to identify the error class.

A [JSON schema for the error objects](../schemas/error.json) is also available.

CA V1 HTTP API
--------------

The certificate authority (CA) API contains all of the endpoints supporting Puppet's public key infrastructure (PKI) system. This endpoint is now handled entirely through Puppet Server. See Puppet Server's [HTTP API](https://puppet.com/docs/puppetserver/latest/http_api_index.md) docs for detailed information.

Serialization Formats
---------------------

Puppet sends messages using several different serialization formats. Not all
REST services support all of the formats.

* [JSON](https://tools.ietf.org/html/rfc7159)
* [PSON](./pson.md)

`YAML` was supported in earlier versions of Puppet, but is no longer for security reasons.
