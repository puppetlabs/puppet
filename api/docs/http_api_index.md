V1 API Services
---------------

Puppet Agents use various network services which the Puppet Master provides in
order to manage systems. Other systems can access these services in order to
put the information that the Puppet Master has to use.

### Configuration Management Services

These services are all related to how the Puppet Agent is able to manage the
configuration of a node.

* {file:api/docs/http_catalog.md Catalog}
* {file:api/docs/http_file_bucket_file.md File Bucket File}
* {file:api/docs/http_file_content.md File Content}
* {file:api/docs/http_file_metadata.md File Metadata}
* {file:api/docs/http_report.md Report}

### Informational Services

These services all provide extra information that can be used to understand how
the Puppet Master will be providing configuration management information to
Puppet Agents.

* {file:api/docs/http_facts.md Facts}
* {file:api/docs/http_node.md Node}
* {file:api/docs/http_resource_type.md Resource Type}
* {file:api/docs/http_status.md Status}

### SSL Certificate Related Services

These services are all in support of Puppet's PKI system.

* {file:api/docs/http_certificate.md Certificate}
* {file:api/docs/http_certificate_request.md Certificate Signing Requests}
* {file:api/docs/http_certificate_status.md Certificate Status}
* {file:api/docs/http_certificate_revocation_list.md Certificate Revocation List}


Serialization Formats
---------------------

Puppet sends messages using several different serialization formats. Not all
REST services support all of the formats; notably, V2 API endpoints only support
PSON.

* {file:api/docs/pson.md PSON}
* {http://www.yaml.org/spec/1.2/spec.html YAML}


V2 HTTP API
-----------

These endpoints differ uniformly from the others in the following ways:

* The first component of the URL path is always `v2`, rather than an environment name, and environment name is no longer a required path component.
* The only acceptable serialization format is PSON.

### Endpoints

* {file:api/docs/http_environments.md Environments}

### V2 API Errors

V2 API endpoints may return several different HTTP error responses:

* When the client submits a malformed request, the API will return a 400 Bad Request response.
* When the client is not authorized, the API will return a 403 Not Authorized response.
* When the client attempts to use an HTTP method that is not permissible for the route, the API will return a 405 Method Not Allowed response.
* When the client asks for a response in a format other than PSON, the API will return a 406 Unacceptable response.
* When the server encounters an unexpected error during the handling of a request, it will return a 500 Server Error response.

Note that the V1 API is a fallback for the V2 API, meaning that if a request does not match a V2 API endpoint, that request will be handed off to the V1 API.
This means that the V2 API is not able to return 404 Not Found responses for requests that do not match a V2 endpoint; instead you will receive a 400 Bad Request response from the V1 API.
