Catalog
=============

The `catalog` endpoint returns a catalog for the specified node name given the provided facts.

Find
----

Retrieve a catalog.

    POST /puppet/v3/catalog/:nodename
    GET /puppet/v3/catalog/:nodename?environment=:environment

### Supported HTTP Methods

POST, GET

### Supported Response Formats

`application/json`, `text/pson`

### Notes

The POST and GET methods are functionally equivalent. Both provide the 3 parameters specified below: the POST in the
request body, the GET in the query string.

Puppet originally used GET; POST was added because some web servers have a maximum URI length of
1024 bytes (which is easily exceeded with the `facts` parameter).

The examples below use the POST method.

### Parameters

Four parameters should be provided to the POST or GET:

- `environment`: the environment name.
- `facts_format`: must be `application/json` or `pson`.
- `facts`: serialized JSON or PSON of the facts hash. Since facts can contain `&`, which
  is also the HTTP query parameter delimiter, facts are doubly-escaped.
- `transaction_uuid`: a transaction uuid identifying the entire transaction (shows up in the report as well).

Two optional parameters are required for static catalogs:
- `static_catalog`: a boolean requesting a
[static catalog](https://docs.puppetlabs.com/puppet/latest/reference/static_catalogs.html) if available; should always
be `true`.
- `checksum_type`: a dot-separated list of checksum types supported by the agent, for use in file resources of a static
catalog. The order signifies preference, highest first.

Optional parameters that may be provided to the POST or GET:

- `configured_environment`: the environment configured on the client. May be
  provided to notify an ENC that the client requested a specific environment
  which might differ from what the client believes is its current environment.
- `job_id`: which orchestration job triggered this catalog request.

### Example Response

#### Catalog found

    POST /puppet/v3/catalog/elmo.mydomain.com

    environment=env&configured_environment=canary_env&facts_format=application%2Fjson&facts=%257B%2522name%2522%253A%2522elmo.mydomain.com%2522%252C%2522values%2522%253A%257B%2522architecture%2522%253A%2522x86_64%2522%257D%257D&transaction_uuid=aff261a2-1a34-4647-8c20-ff662ec11c4c

    HTTP 200 OK
    Content-Type: application/json

    {
      "tags": [
        "settings",
        "multi_param_class",
        "class"
      ],
      "name": "elmo.mydomain.com",
      "version": 1377473054,
      "code_id": null,
      "catalog_uuid": "827a74c8-cf98-44da-9ff7-18c5e4bee41e",
      "catalog_format": 1,
      "environment": "production",
      "resources": [
        {
          "type": "Stage",
          "title": "main",
          "tags": [
            "stage"
          ],
          "exported": false,
          "parameters": {
            "name": "main"
          }
        },
        {
          "type": "Class",
          "title": "Settings",
          "tags": [
            "class",
            "settings"
          ],
          "exported": false
        },
        {
          "type": "Class",
          "title": "main",
          "tags": [
            "class"
          ],
          "exported": false,
          "parameters": {
            "name": "main"
          }
        },
        {
          "type": "Class",
          "title": "Multi_param_class",
          "tags": [
            "class",
            "multi_param_class"
          ],
          "line": 10,
          "exported": false,
          "parameters": {
            "one": "hello",
            "two": "world"
          }
        },
        {
          "type": "Notify",
          "title": "foo",
          "tags": [
            "notify",
            "foo",
            "class",
            "multi_param_class"
          ],
          "line": 4,
          "exported": false,
          "parameters": {
            "message": "One is hello, two is world"
          }
        }
      ],
      "edges": [
        {
          "source": "Stage[main]",
          "target": "Class[Settings]"
        },
        {
          "source": "Stage[main]",
          "target": "Class[main]"
        },
        {
          "source": "Stage[main]",
          "target": "Class[Multi_param_class]"
        },
        {
          "source": "Class[Multi_param_class]",
          "target": "Notify[foo]"
        }
      ],
      "classes": [
        "settings",
        "multi_param_class"
      ]
    }

#### Static Catalog found

~~~
POST /puppet/v3/catalog/elmo.mydomain.com

environment=env&configured_environment=canary_env&facts_format=application%2Fjson&facts=%7B%22name%22%3A%22elmo.mydomain.com%22%2C%22values%22%3A%7B%22architecture%22%3A%22x86_64%22%7D&transaction_uuid=aff261a2-1a34-4647-8c20-ff662ec11c4c&static_catalog=true&checksum_type=sha256.md5

HTTP 200 OK
Content-Type: application/json

{
  "tags": [
    "settings",
    "multi_param_class",
    "class"
  ],
  "name": "elmo.mydomain.com",
  "version": 1377473054,
  "code_id": "arbitrary_code_id_string",
  "catalog_uuid": "827a74c8-cf98-44da-9ff7-18c5e4bee41e",
  "catalog_format": 1,
  "environment": "production",
  "resources": [
    {
      "type": "Stage",
      "title": "main",
      "tags": [
        "stage"
      ],
      "exported": false,
      "parameters": {
        "name": "main"
      }
    },
    {
      "type": "Class",
      "title": "Settings",
      "tags": [
        "class",
        "settings"
      ],
      "exported": false
    },
    {
      "type": "Class",
      "title": "main",
      "tags": [
        "class"
      ],
      "exported": false,
      "parameters": {
        "name": "main"
      }
    },
    {
      "type": "Class",
      "title": "Multi_param_class",
      "tags": [
        "class",
        "multi_param_class"
      ],
      "line": 10,
      "exported": false,
      "parameters": {
        "one": "hello",
        "two": "world"
      }
    },
    {
      "type": "Notify",
      "title": "foo",
      "tags": [
        "notify",
        "foo",
        "class",
        "multi_param_class"
      ],
      "line": 4,
      "exported": false,
      "parameters": {
        "message": "One is hello, two is world"
      }
    },
    {
      "type": "File",
      "title": "/tmp/foo",
      "tags": [
        "file",
        "class"
      ],
      "line": 12,
      "exported": false,
      "parameters": {
        "ensure": "file",
        "source": "puppet:///modules/a_module/foo"
      }
    },
    {
      "type": "File",
      "title": "/tmp/bar",
      "tags": [
        "file",
        "class"
      ],
      "line": 16,
      "exported": false,
      "parameters": {
        "ensure": "present",
        "source": "puppet:///modules/a_module/bar",
        "recurse", "true"
      }
  ],
  "edges": [
    {
      "source": "Stage[main]",
      "target": "Class[Settings]"
    },
    {
      "source": "Stage[main]",
      "target": "Class[main]"
    },
    {
      "source": "Stage[main]",
      "target": "Class[Multi_param_class]"
    },
    {
      "source": "Class[Multi_param_class]",
      "target": "Notify[foo]"
    },
    {
      "source": "Class[Main]",
      "target": "File[/tmp/foo]"
    }
  ],
  "classes": [
    "settings",
    "multi_param_class"
  ]
  "metadata": {
    "/tmp/foo": {
      "checksum": {
        "type": "sha256",
        "value": "{sha256}5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"
      },
      "content_uri": "puppet:///modules/a_module/files/foo",
      "destination": null,
      "group": 20,
      "links": "manage",
      "mode": 420,
      "owner": 501,
      "path": "/etc/puppetlabs/code/environments/production/modules/a_module/files/foo.txt",
      "relative_path": null,
      "source": "puppet:///modules/a_module/foo",
      "type": "file"
    }
  },
  "recursive_metadata": {
    "/tmp/bar": {
      "puppet:///modules/a_module/bar": [
        {
          "checksum": {
            "type": "ctime",
            "value": "{ctime}2016-02-19 17:38:36 -0800"
          },
          "content_uri": "puppet:///modules/a_module/files/bar",
          "destination": null,
          "group": 20,
          "links": "manage",
          "mode": 420,
          "owner": 501,
          "path": "/etc/puppetlabs/code/environments/production/modules/a_module/files/bar",
          "relative_path": ".",
          "source": null,
          "type": "directory"
        },
        {
          "checksum": {
            "type": "sha256",
            "value": "{sha256}962dbd7362c34a20baac8afd13fba734d3d51cc2944477d96ee05a730e5edcb7"
          },
          "content_uri": "puppet:///modules/a_module/files/bar/baz",
          "destination": null,
          "group": 20,
          "links": "manage",
          "mode": 420,
          "owner": 501,
          "path": "/etc/puppetlabs/code/environments/production/modules/a_module/files/bar",
          "relative_path": "baz",
          "source": null,
          "type": "file"
        }
      ]
    }
  }
}
~~~

Schema
------

In the POST request body (or the GET query), the facts parameter should conform
to [the facts schema.](../schemas/facts.json)

A catalog response body conforms to
[the catalog schema.](../schemas/catalog.json)
