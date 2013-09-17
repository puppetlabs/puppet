File Content
=============

The `file_content` endpoint returns the contents of the specified file.

Find
----

Get a file.

    GET /:environment/file_content/:mount_point/:name

`:mount_point` is one of mounts configured in the `fileserver.conf`.
See [the puppet file server guide](http://docs.puppetlabs.com/guides/file_serving.html)
for more information about how mount points work.

`:name` is the path to the file within the `:mount_point` that is requested.

### Supported HTTP Methods

GET

### Supported Format

Accept: raw

### Parameters

None

### Notes

### Responses

#### File found

    GET /env/file_content/modules/example/my_file
    Accept: raw

    HTTP/1.1 200 OK
    Content-Type: application/x-raw
    Content-Length: 16

    this is my file


#### File not found

    GET /env/file_content/modules/example/not_found
    Accept: raw

    HTTP/1.1 404 Not Found: Could not find file_content modules/example/not_found
    Content-Type: text/plain

#### No file name given

    GET /env/file_content/

    HTTP/1.1 400 No request key specified in /env/file_content/
    Content-Type: text/plain

Schema
------

A file_content response body is not structured data according to any standard scheme such as
json/pson/yaml, so no schema is applicable.
