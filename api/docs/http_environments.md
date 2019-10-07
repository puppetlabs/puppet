Environments
============

The `environments` endpoint allows for enumeration of the environments known to the master. Each environment contains information
about itself like its modulepath, manifest directory, environment timeout, and the config version.
This endpoint is by default accessible to any client with a valid certificate, though this may be changed by `auth.conf`.

Get
---

Get the list of known environments.

    GET /puppet/v3/environments

### Supported Response Formats

`application/json`

### Parameters

None

### Example Request & Response

    GET /puppet/v3/environments

    HTTP 200 OK
    Content-Type: application/json

    {
      "search_paths": ["/etc/puppetlabs/code/environments"]
      "environments": {
        "production": {
          "settings": {
            "modulepath": ["/etc/puppetlabs/code/environments/production/modules", "/etc/puppetlabs/code/environments/development/modules"],
            "manifest": ["/etc/puppetlabs/code/environments/production/manifests"]
            "environment_timeout": 180,
            "config_version": "/version/of/config"
          }
        }
      }
    }

The `environment_timeout` attribute could also be the string "unlimited".

Schema
------

An environments response body conforms to
[the environments schema.](../schemas/environments.json)
