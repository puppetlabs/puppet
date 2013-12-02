Status
=============

The `status` endpoint provides information about a running master.

Find
----

Get status for a master

    GET /:environment/status/:name

The `:environment` and `:name` sections of the URL are both ignored, but a
value must be provided for both.

### Supported HTTP Methods

GET

### Supported Response Formats

PSON

### Parameters

None

### Example Response

    GET /env/status/whatever

    HTTP 200 OK
    Content-Type: text/pson

    {"is_alive":true,"version":"3.3.2"}

Schema
------

The returned status conforms to the
{file:api/schemas/status.json api/schemas/status.json} schema.
