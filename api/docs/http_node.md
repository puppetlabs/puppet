Node
====

The `node` endpoint is used by the puppet agent to get basic information
about a node. The returned information includes the node name and
environment, and optionally any classes set by an External Node
Classifier and a hash of parameters which may include the node's facts.
The returned node may have a different environment from the one given in
the request if Puppet is configured with an ENC.

Find
----

Retrieve data for a node

    GET /puppet/v3/node/:certname?environment=:environment&transaction_uuid=:transaction_uuid&configured_environment=:environment


### Supported HTTP Methods

GET

### Supported Response Formats

`application/json`, `text/pson`

### Parameters

One parameter should be provided to the GET:

- `transaction_uuid`: a transaction uuid identifying the entire transaction (shows up in the report as well)

An optional parameter can be provided to the GET to notify a node classifier that the client requested a specific
environment, which might differ from what the client believes is its current environment:

- `configured_environment`: the environment configured on the client

### Examples

    > GET /puppet/v3/node/mycertname?environment=production&transaction_uuid=aff261a2-1a34-4647-8c20-ff662ec11c4c&configured_environment=production HTTP/1.1
    > Accept: application/json, text/pson

    < HTTP/1.1 200 OK
    < Content-Type: application/json
    < Content-Length: 4630

    {
      "name":"thinky.corp.puppetlabs.net",
      "parameters":{
        "architecture":"amd64",
        "kernel":"Linux",
        "blockdevices":"sda,sr0",
        "clientversion":"3.3.1",
        "clientnoop":"false",
        "environment":"production",
        ...
      },
      "environment":"production"
    }

Schema
------

A node response body conforms to
[the node schema.](../schemas/node.json)
