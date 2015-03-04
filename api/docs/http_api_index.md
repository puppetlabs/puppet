A Puppet master server provides several services via HTTP API, and the Puppet
agent application uses those services to resolve a node's credentials, retrieve
a configuration catalog, retrieve file data, and submit reports.

In general, these APIs aren't designed for use by tools other than Puppet agent,
and they've historically relied on a lot of shared code to work correctly.
This is gradually changing, although we expect external use of these APIs to
remain low for the foreseeable future.

V1/V2 HTTP APIs (Removed)
---------------

The V1 and V2 APIs were removed in Puppet 4.0.0. The routes that were previously
under `/` or `/v2.0` can now be found under the [master V3](#master-v3-http-api)
API or [CA V1](#ca-v1-http-api) API.

Notably, this means Puppet 3.x agent nodes cannot speak to a newer Puppet master
server.

Master and CA APIs
------------------

Beginning with Puppet 4, Puppet's HTTP API has been split into two APIs, which
are versioned separately. There is now one API for the Puppet master and one for
the certificate authority (CA).

All master endpoints are prefixed with `/puppet`, while all CA endpoints are
prefixed with `/puppet-ca`. All endpoints are explicitly versioned: the prefix
is always immediately followed by a string like `/v3` (a directory separator,
the letter `v`, and the version number of the API).

Authorization for these endpoints is still controlled with the `auth.conf`
authorization system in puppet. When specifying the authorization in
`auth.conf` the prefix (either `/puppet` or `/puppet-ca`) and the version
number on the paths must be retained; the full request path is used.

Master V3 HTTP API
------------------

The Puppet agent application uses several network services to manage systems.
These services are all grouped under the `/master` API. Other tools can access
these services and use the Puppet master's data for other purposes.

The V3 API contains endpoints of two types: those that are based on dispatching
to Puppet's internal "indirector" framework, and those that are not (namely the
[environments endpoint](#Environments-Endpoint)).

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

* [Catalog](./http_catalog.md)
* [Node](./http_node.md)
* [File Bucket File](./http_file_bucket_file.md)
* [File Content](./http_file_content.md)
* [File Metadata](./http_file_metadata.md)
* [Report](./http_report.md)

### Informational Services

These services are not directly used by Puppet agent, but may be used by other
tools.

* [Resource Type](./http_resource_type.md)
* [Status](./http_status.md)

### Environments Endpoint

The one endpoint with a different format is the `/puppet/v3/environments`
endpoint.

This endpoint will only accept payloads formatted as JSON and respond with JSON
(MIME type of `application/json`).

* [Environments](./http_environments.md)

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
* `stacktrace` (only for 5xx errors): (`Array<String>`) A stacktrace to where
  the error occurred.

A [JSON schema for the error objects](../schemas/error.json) is also available.

CA V1 HTTP API
--------------

The CA API contains all of the endpoints used in support of Puppet's PKI
system.

The CA V1 endpoints share the same basic format as the master V3 API, since
they are also based off of Puppet's internal "indirector". However, they have
a different prefix and version. The endpoints thus follow the form:
`/puppet-ca/v1/:indirection/:key?environment=:environment` where:

* `:environment` is an arbitrary placeholder word, required for historical
  reasons. No CA endpoints actually use an environment, but the query parameter
  must always be specified.
* `:indirection` is the indirection to dispatch the request to.
* `:key` is the "key" portion of the indirection call.

As with the master V3 API, using this API requires a significant amount of
understanding of how Puppet's internal services are structured. The following
documents provide additional specification.

### SSL Certificate Related Services

* [Certificate](./http_certificate.md)
* [Certificate Signing Requests](./http_certificate_request.md)
* [Certificate Status](./http_certificate_status.md)
* [Certificate Revocation List](./http_certificate_revocation_list.md)

Serialization Formats
---------------------

Puppet sends messages using several different serialization formats. Not all
REST services support all of the formats.

* [PSON](./pson.md)
* [YAML](http://www.yaml.org/spec/1.2/spec.html)

