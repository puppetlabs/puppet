File Content
=============

The `file_content` endpoint returns the contents of the specified file.

Find
----

Get a file.

    GET /puppet/v3/file_content/:mount_point/:name

The endpoint path includes a `:mount_point` which can be one of the following types:

* Custom file serving mounts as specified in fileserver.conf --- see [the docs on configuring mount points](https://docs.puppet.com/puppet/latest/reference/file_serving.html).
* `modules/<MODULE>` --- a semi-magical mount point which allows access to the `files` subdirectory of `<MODULE>` --- see [the docs on file serving](https://docs.puppet.com/puppet/latest/reference/file_serving.html).
* `plugins` --- a highly magical mount point which merges the `lib`  directory of every module together. Used for syncing plugins; not intended for general consumption. Per-module sub-paths can not be specified.
* `pluginfacts` --- a highly magical mount point which merges the `facts.d` directory of every module together. Used for syncing external facts; not intended for general consumption. Per-module sub-paths can not be specified.
* `tasks/<MODULE>` --- a semi-magical mount point which allows access to files in the `tasks` subdirectory of `<MODULE>` --- see the [the docs on file serving](https://docs.puppet.com/puppet/latest/reference/file_serving.html).

`:name` is the path to the file within the `:mount_point` that is requested.

### Supported HTTP Methods

GET

### Supported Response Formats

`application/octet-stream`

### Parameters

None

### Notes

### Responses

#### File found

    GET /puppet/v3/file_content/modules/example/my_file?environment=env
    Accept: application/octet-stream

    HTTP/1.1 200 OK
    Content-Type: application/octet-stream
    Content-Length: 16

    this is my file


#### File not found

    GET /puppet/v3/file_content/modules/example/not_found?environment=env
    Accept: application/octet-stream

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
