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

PSON

### Notes

The POST and GET methods are functionally equivalent. Both provide the 3 parameters specified below: the POST in the
request body, the GET in the query string.

Puppet originally used GET; POST was added because some web servers have a maximum URI length of
1024 bytes (which is easily exceeded with the `facts` parameter).

The examples below use the POST method.

### Parameters

Six parameters should be provided to the POST or GET:

- `environment`: the environment name
- `facts_format`: must be `pson`
- `facts`: serialized pson of the facts hash.  One odd note: due to a long-ago misunderstanding in the code, this is
doubly-escaped (it should just be singly-escaped).  To keep backward compatibility, the extraneous
escaping is still used/supported.
- `transaction_uuid`: a transaction uuid identifying the entire transaction (shows up in the report as well)
- `static_catalog`: a boolean requesting a static catalog if available; should always be `true`
- `checksum_type`: a checksum type supported by the agent, for use in file resources of a static catalog.

An optional parameter can be provided to the POST or GET to notify a node classifier that the client requested a specific
environment, which might differ from what the client believes is its current environment:

- `configured_environment`: the environment configured on the client

### Example Response

#### Catalog found

    POST /puppet/v3/catalog/elmo.mydomain.com

    environment=env&configured_environment=canary_env&facts_format=pson&facts=%7B%22name%22%3A%22elmo.mydomain.com%22%2C%22values%22%3A%7B%22architecture%22%3A%22x86_64%22%7D&transaction_uuid=aff261a2-1a34-4647-8c20-ff662ec11c4c&static_catalog=true&checksum_type=md5

    HTTP 200 OK
    Content-Type: text/pson

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

Schema
------

In the POST request body (or the GET query), the facts parameter should conform
to [the facts schema.](../schemas/facts.json)

A catalog response body conforms to
[the catalog schema.](../schemas/catalog.json)
