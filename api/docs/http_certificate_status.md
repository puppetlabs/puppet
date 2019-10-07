Certificate Status
===============

The `certificate status` endpoint allows a client to read or alter the
status of a certificate or pending certificate request. It is only
useful on the CA.

Under Puppet Server's CA service, the `environment` parameter is ignored and can
be omitted. Under a Rack or WEBrick Puppet master, `environment` is required and
must be a valid environment, but it has no effect on the response.

Find
----

    GET /puppet-ca/v1/certificate_status/:certname?environment=:environment
    Accept: application/json, text/pson

Retrieve information about the specified certificate. Similar to `puppet
cert --list :certname`.

Search
-----

    GET /puppet-ca/v1/certificate_statuses/:any_key?environment=:environment
    Accept: application/json, text/pson

Retrieve information about all known certificates. Similar to `puppet
cert --list --all`. A key is required but is ignored.

Save
----

    PUT /puppet-ca/v1/certificate_status/:certname?environment=:environment
    Content-Type: text/pson

Change the status of the specified certificate. The desired state
is sent in the body of the PUT request as a one-item PSON hash; the two
allowed complete hashes are `{"desired_state":"signed"}` (for signing a
certificate signing request; similar to `puppet cert --sign`) and
`{"desired_state":"revoked"}` (for revoking a certificate; similar to
`puppet cert --revoke`).

Note that revoking a certificate will not clean up other info about the
host - see the DELETE request for more information.

Delete
-----

    DELETE /puppet-ca/v1/certificate_status/:hostname?environment=:environment
    Accept: application/json, text/pson

Cause the certificate authority to discard all SSL information regarding
a host (including any certificates, certificate requests, and keys).
This does not revoke the certificate if one is present; if you wish to
emulate the behavior of `puppet cert --clean`, you must PUT a
`desired_state` of `revoked` before deleting the host’s SSL information.

If the deletion was successful, it returns a string listing the deleted
classes like

    "Deleted for myhost: Puppet::SSL::Certificate, Puppet::SSL::Key"

Otherwise it returns

    "Nothing was deleted"

### Supported HTTP Methods

This endpoint is disabled in the default configuration. It is
recommended to be careful with this endpoint, as it can allow control
over the certificates used by the puppet master.

GET, PUT, DELETE


### Supported Response Formats

`application/json`, `text/pson`, `pson`

This endpoint can produce yaml as well, but the returned data is
incomplete.

### Examples

#### Certificate information

    GET /puppet-ca/v1/certificate_status/mycertname?environment=env

    HTTP/1.1 200 OK
    Content-Type: text/pson

    {
      "name":"mycertname",
      "state":"signed",
      "fingerprint":"A6:44:08:A6:38:62:88:5B:32:97:20:49:8A:4A:4A:AD:65:C3:3E:A2:4C:30:72:73:02:C5:F3:D4:0E:B7:FC:2F",
      "fingerprints":{
        "default":"A6:44:08:A6:38:62:88:5B:32:97:20:49:8A:4A:4A:AD:65:C3:3E:A2:4C:30:72:73:02:C5:F3:D4:0E:B7:FC:2F",
        "SHA1":"77:E6:5A:7E:DD:83:78:DC:F8:51:E3:8B:12:71:F4:57:F1:C2:34:AE",
        "SHA256":"A6:44:08:A6:38:62:88:5B:32:97:20:49:8A:4A:4A:AD:65:C3:3E:A2:4C:30:72:73:02:C5:F3:D4:0E:B7:FC:2F",
        "SHA512":"CA:A0:8C:B9:FE:9D:C2:72:18:57:08:E9:4B:11:B7:BC:4E:F7:52:C8:9C:76:03:45:B4:B6:C5:D2:DC:E8:79:43:D7:71:1F:5C:97:FA:B2:F3:ED:AE:19:BD:A9:3B:DB:9F:A5:B4:8D:57:3F:40:34:29:50:AA:AA:0A:93:D8:D7:54"
      },
      "dns_alt_names":["DNS:puppet","DNS:mycertname"]
    }


#### Revoking a certificate

    PUT /puppet-ca/v1/certificate_status/mycertname?environment=production HTTP/1.1
    Content-Type: text/pson
    Content-Length: 27

    {"desired_state":"revoked"}

This has no meaningful return value.


#### Deleting the certificate information

    DELETE /puppet-ca/v1/certificate_status/mycertname?environment=production HTTP/1.1

Gets the response:

    "Deleted for mycertname: Puppet::SSL::Certificate, Puppet::SSL::Key"

Schema
-----

Find and search operations return objects which
conform to [the host schema.](../schemas/host.json)
