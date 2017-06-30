File Bucket File
=============

The `file_bucket_file` endpoint manages the contents of files in the
file bucket. All access to files is managed with the md5 checksum of the
file contents, represented as `:md5`. Where used, `:filename` means the
full absolute path of the file on the client system. This is usually
optional and used as an error check to make sure correct file is
retrieved. The environment is required in all requests but ignored, as
the file bucket does not distinguish between environments.

Find
----

Retrieve the contents of a file.

    GET /puppet/v3/file_bucket_file/:md5?environment=:environment
    GET /puppet/v3/file_bucket_file/:md5/:original_path?environment=:environment

This will return the contents of the file if it's present. If
`:original_path` is provided then the contents will only be sent if the
file was uploaded with the same path at some point.

Head
----

Check if a file is present in the filebucket

    HEAD /puppet/v3/file_bucket_file/:md5?environment=:environment
    HEAD /puppet/v3/file_bucket_file/:md5/:original_path?environment=:environment

This behaves identically to find, only returning headers.

Save
----

Save a file to the filebucket

    PUT /puppet/v3/file_bucket_file/:md5?environment=:environment
    PUT /puppet/v3/file_bucket_file/:md5/:original_path?environment=:environment

The body should contain the file contents. This saves the file using the
md5 sum of the file contents. If `:original_path` is provided, it adds
the path to a list for the given file. If the md5 sum in the request is
incorrect, the file will be instead saved under the correct checksum.

### Supported HTTP Methods

GET, HEAD, PUT

### Supported Response Formats

`application/octet-stream`

### Parameters

None

### Examples

#### Saving a file

    > PUT /puppet/v3/file_bucket_file/md5/eb61eead90e3b899c6bcbe27ac581660//home/user/myfile.txt?environment=production HTTP/1.1

    > Content-Type: application/octet-stream
    > Content-Length: 24

    > This is the file content


    < HTTP/1.1 200 OK

#### Retrieving a file

    > GET /puppet/v3/file_bucket_file/md5/4949e56d376cc80ce5387e8e89a75396//home/user/myfile.txt?environment=production HTTP/1.1
    > Accept: application/octet-stream


    < HTTP/1.1 200 OK
    < Content-Length: 24

    < This is the file content

#### Wrong file name

    > GET /puppet/v3/file_bucket_file/md5/4949e56d376cc80ce5387e8e89a75396//home/user/wrong_name?environment=production HTTP/1.1
    > Accept: application/octet-stream


    < HTTP/1.1 404 Not Found
    <
    < Not Found: Could not find file_bucket_file md5/4949e56d376cc80ce5387e8e89a75396/home/user/wrong_name

Schema
------

A `file_bucket_file` response body is not structured data according to any standard scheme such as
json/yaml, so no schema is applicable.
