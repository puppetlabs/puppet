Catalog
=============

The `catalog` endpoint returns a catalog for the specified node name given the provided facts.

Find
----

Retrieve a catalog.

    POST /:environment/catalog/:nodename
    GET /:environment/catalog/:nodename

### Supported HTTP Methods

POST, GET

### Supported Format

Accept: pson, text/pson

### Notes

The POST and GET methods are functionally equivalent. Both provide the 3 parameters specified below: the POST in the
request body, the GET in the query string.

Puppet originally used GET; POST was added because some web servers have a maximum URI length of
1024 bytes (which is easily exceeded with the `facts` parameter).

The examples below use the POST method.

### Parameters

Three parameters should be provided to the POST or GET:
- `facts_format`: must be `pson`
- `facts`: serialized pson of the facts hash.  One odd note: due to a long-ago misunderstanding in the code, this is
           doubly-escaped (it should just be singly-escaped).  To keep backward compatibility, the extraneous
           escaping is still used/supported.
- `transaction_uuid`: a transaction uuid identifying the entire transaction (shows up in the report as well)

### Example Response

#### Catalog found

    POST /env/catalog/elmo.mydomain.com

    facts_format=pson&facts=%7B%22name%22%3A%22elmo.mydomain.com%22%2C%22values%22%3A%7B%22architecture%22%3A%22x86_64%22%7D&transaction_uuid=aff261a2-1a34-4647-8c20-ff662ec11c4c

    HTTP 200 OK
    Content-Type: text/pson

    {
      "document_type": "Catalog",
      "data": {
        "tags": [
          "settings",
          "multi_param_class",
          "class"
        ],
        "name": "elmo.mydomain.com",
        "version": 1377473054,
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
      },
      "metadata": {
        "api_version": 1
      }
    }

Schema
------

In the POST request body (or the GET query), the facts parameter should adhere to the
api/schemas/facts.json schema.

A catalog response body should adhere to the api/schemas/catalog.json schema.
