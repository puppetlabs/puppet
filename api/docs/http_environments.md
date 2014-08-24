Environments
============

The `environments` endpoint allows for enumeration of the environments known to the master. Each environment contains information
about itself like its modulepath, manifest directory, environment timeout, and the config version.
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
            "modulepath": ["/etc/puppetlabs/puppet/environments/production/modules", "/etc/puppetlabs/puppet/environments/development/modules"],
            "manifest": ["/etc/puppetlabs/puppet/environments/production/manifests"]
            "environment_timeout": 180,
            "config_version": "/version/of/config"
          }
        }
      }
    }

The `environment_timeout` attribute could also be the string "unlimited".

Schema
------

A environments response body adheres to the {file:api/schemas/environments.json
api/schemas/environments.json} schema.
