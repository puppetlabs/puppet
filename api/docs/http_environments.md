Environments
============

The `environments` endpoint allows for enumeration of the environments known to the master, along with the modules available in each.
This endpoint is by default accessible to any client with a valid certificate, though this may be changed by `auth.conf`.

Get
---

Get the list of known environments.

    GET /v2/environments

### Supported Response Formats

PSON

### Parameters

None

### Example Request & Response

* Note: module lists shortened for readability.

    GET /v2/environments

    HTTP 200 OK
    Content-Type: text/pson

    {
      "search_paths": ["/etc/puppet/environments"]
      "environments": {
        "production": {
          "modules": {
            "a-module": { "version": "1.3.5" }
            "a-different-module": { "version": "2.4.6" }
          }
        }
      }
    }
