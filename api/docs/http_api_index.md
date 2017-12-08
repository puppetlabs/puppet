A Puppet master server provides several services via HTTP API, and the Puppet
agent application uses those services to resolve a node's credentials, retrieve
a configuration catalog, retrieve file data, and submit reports.

In general, these APIs aren't designed for use by tools other than Puppet agent,
and they've historically relied on a lot of shared code to work correctly.
This is gradually changing, although we expect external use of these APIs to
remain low for the foreseeable future.

Puppet will often send garbage URL parameters, such as `fail_on_404` and
`ignore_cache`. The server will ignore any parameters it isn't expecting.

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
is always immediately followed by a string like `/v3` (a directory separator,
the letter `v`, and the version number of the API).

### Authorization

Authorization for `/puppet` endpoints is still controlled with Puppet's `auth.conf`
authorization system.

Puppet Server ignores `auth.conf` for `/puppet-ca` endpoints. Access to the
`certificate_status` endpoint is configured in Puppet Server's `ca.conf` file,
and the remaining CA endpoints are always accessible. Rack Puppet master servers
still use `auth.conf` for `/puppet-ca`.

When specifying authorization in `auth.conf`, the prefix and the version number
(e.g. `/puppet/v3`) on the paths must be retained, since Puppet matches
authorization rules against the full request path.

Puppet V3 HTTP API
------------------

The Puppet agent application uses several network services to manage systems.
These services are all grouped under the `/puppet` API. Other tools can access
these services and use the Puppet master's data for other purposes.

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

### Environment Endpoints

The endpoints with a different format are the `/puppet/v3/environments` and
the `/puppet/v3/environment/:environment` endpoints.

These endpoints will only accept payloads formatted as JSON and respond
with JSON (MIME type of `application/json`).

* [Environments](./http_environments.md)
* [Environment Catalog](./http_environment.md)

### Puppet Server-specific endpoints

When using [Puppet Server 2.3 or newer](https://docs.puppet.com/puppetserver/2.3/)
as a Puppet master, Puppet Server adds additional `/puppet/v3/` endpoints:

* [Static File Content](https://docs.puppet.com/puppetserver/latest/puppet-api/v3/static_file_content.md)
* [Environment Classes](https://docs.puppet.com/puppetserver/latest/puppet-api/v3/environment_classes.md)

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

The CA API contains all of the endpoints used in support of Puppet's PKI
system.

The CA V1 endpoints share the same basic format as the Puppet V3 API, since
they are also based off of Puppet's internal "indirector". However, they have
a different prefix and version. The endpoints thus follow the form:
`/puppet-ca/v1/:indirection/:key?environment=:environment` where:

* `:environment` is an arbitrary placeholder word, required for historical
  reasons. No CA endpoints actually use an environment, but the query parameter
  must always be specified.
* `:indirection` is the indirection to dispatch the request to.
* `:key` is the "key" portion of the indirection call.

As with the Puppet V3 API, using this API requires a significant amount of
understanding of how Puppet's internal services are structured. The following
documents provide additional specification.

### SSL Certificate Related Services

These endpoints only accept plain text payload formats. Historically, Puppet has
used the MIME type `s` to mean `text/plain`. In Puppet 5, it will always use
`text/plain`, but will continue to accept `s` to mean the same thing.

* [Certificate](./http_certificate.md)
* [Certificate Signing Requests](./http_certificate_request.md)
* [Certificate Status](./http_certificate_status.md)
* [Certificate Revocation List](./http_certificate_revocation_list.md)

Serialization Formats
---------------------

Puppet sends messages using several different serialization formats. Not all
REST services support all of the formats.

* [JSON](https://tools.ietf.org/html/rfc7159)
* [PSON](./pson.md)

`YAML` was supported in earlier versions of Puppet, but is no longer for security reasons.
