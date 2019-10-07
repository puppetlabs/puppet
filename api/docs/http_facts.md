Facts
=====

The `facts` endpoint allows setting the facts for the specified node name.

Save
----

Store facts for a node. The request body should contain JSON-formatted facts.

    PUT /puppet/v3/facts/:nodename?environment=:environment

### Supported HTTP Methods

PUT

### Supported Format(s)

`application/json`, `text/pson`

### Parameters

None

### Example

* Note: list of facts was shortened for readability.
* Note: JSON was formatted for readability.

    PUT /puppet/v3/facts/elmo.mydomain.com?environment=env
    Content-Type: application/json

    {
      "name": "elmo.mydomain.com",
      "values": {
        "architecture": "x86_64",
        "kernel": "Darwin",
        "domain": "local",
        "macaddress": "70:11:24:8c:33:a9",
        "osfamily": "Darwin",
        "operatingsystem": "Darwin",
        "facterversion": "1.7.2",
        "fqdn": "elmo.mydomain.com",
      },
      "timestamp": "2013-09-09 15:49:27 -0700",
      "expiration": "2013-09-09 16:19:27 -0700"
    }

    HTTP/1.1 200 OK
    Content-Type: application/json

Schema
------

The representation of facts contained in a PUT body, should adhere to
[the facts schema.](../schemas/facts.json)
