Environments
============

The `environments` endpoint allows for enumeration of the environments known to the master, along with the modules available in each.
This endpoint is by default accessible to any client with a valid certificate, though this may be changed by `auth.conf`.

Get
---

Get the list of known environments.

    GET /v2.0/environments

### Parameters

None

### Example Request & Response

    GET /v2.0/environments

    HTTP 200 OK
    Content-Type: application/json

    {
      "search_paths": ["/etc/puppet/environments"]
      "environments": {
        "production": {
          "settings": {
            "modulepath": ["/first/module/directory", "/second/module/directory"],
            "manifest": ["/location/of/manifests"]
          }
        }
      }
    }

Schema
------

A environments response body adheres to the {file:api/schemas/environments.json
api/schemas/environments.json} schema.
