File Content
=============

The `file_content` endpoint returns the contents of the specified file.

Find
----

Get a file.

    GET /puppet/v3/file_content/:mount_point/:name

`:mount_point` is one of mounts configured in the `fileserver.conf`.
See [the puppet file server guide](http://docs.puppetlabs.com/guides/file_serving.html)
for more information about how mount points work.

`:name` is the path to the file within the `:mount_point` that is requested.

### Supported HTTP Methods

GET

### Supported Response Formats

binary (the raw binary content)

### Parameters

None

### Notes

### Responses

#### File found

    GET /puppet/v3/file_content/modules/example/my_file?environment=env
    Accept: binary

    HTTP/1.1 200 OK
    Content-Type: application/octet-stream
    Content-Length: 16

    this is my file


#### File not found

    GET /puppet/v3/file_content/modules/example/not_found?environment=env
    Accept: binary

    HTTP/1.1 404 Not Found
    Content-Type: text/plain

    Not Found: Could not find file_content modules/example/not_found

#### No file name given

    GET /puppet/v3/file_content?environment=env

    HTTP/1.1 400 Bad Request
    Content-Type: text/plain

    No request key specified in /puppet/v3/file_content/

Schema
------

A `file_content` response body is not structured data according to any standard scheme such as
json/pson/yaml, so no schema is applicable.
