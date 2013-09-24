Facts
=============

The `facts` endpoint allows getting or setting the facts for the specified node name.  The `facts_search` endpoint
allows retrieving a list of node names containing the specified facts.

Find
----

Get facts for a node.

    GET /:environment/facts/:nodename

### Supported HTTP Methods

GET

### Supported Format

Accept: pson, text/pson

### Parameters

None

### Example Response

* Note: list of facts was shortened for readability.
* Note: pson was formatted for readability.

#### Facts found

    GET /env/facts/elmo.mydomain.com

    HTTP 200 OK
    Content-Type: text/pson

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

Save
----

Store facts for a node.  The request body should contain pson-formatted facts.

    PUT /:environment/facts/:nodename

### Supported HTTP Methods

PUT

### Supported Format

Accept: pson, text/pson

### Parameters

None

### Example Response

* Note: list of facts was shortened for readability.
* Note: pson was formatted for readability.

#### Facts found

    PUT /env/facts/elmo.mydomain.com

    Content-Type: text/pson

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
    Content-Type: text/pson

    "/etc/puppet/var/yaml/facts/joebob.local.yaml"

Search
----

Get the list of nodes matching the facts_search parameters

    GET /:environment/facts_search/search

### Supported HTTP Methods

GET

### Supported Format

Accept: pson, text/pson

### Parameters

For the parameters, see http://docs.puppetlabs.com/guides/rest_api.html#facts-search.

### Response

The response is an array of node names.  The array is square-bracket delimited; the node names are quoted and
comma separated.

### Example Response

#### Facts found

    GET /env/facts_search/search?facts.processorcount.ge=2

    HTTP 200 OK
    Content-Type: text/pson

    ["elmo.mydomain.com","kermit.mydomain.com"]

Schema
------

The representation of facts, whether returned from a GET or contained in a PUT body, should adhere to the
api/schemas/facts.json schema.
