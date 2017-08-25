File Metadata
=============

The `file_metadata` endpoint returns select metadata for a single file or many files. There are find and search variants
of the endpoint; the search variant has a trailing 's' so is actually `file_metadatas`.

Although the term 'file' is used generically in the endpoint name and documentation, each returned item can be one of
the following three types:

* File
* Directory
* Symbolic link

The endpoint path includes a `:mount` which can be one of the following types:

* Custom file serving mounts as specified in fileserver.conf --- see [the docs on configuring mount points](https://docs.puppet.com/puppet/latest/reference/file_serving.html).
* `modules/<MODULE>` --- a semi-magical mount point which allows access to the `files` subdirectory of `<MODULE>` --- see [the docs on file serving](https://docs.puppet.com/puppet/latest/reference/file_serving.html).
* `plugins` --- a highly magical mount point which merges the `lib`  directory of every module together. Used for syncing plugins; not intended for general consumption. Per-module sub-paths can not be specified.
* `pluginfacts` --- a highly magical mount point which merges the `facts.d` directory of every module together. Used for syncing external facts; not intended for general consumption. Per-module sub-paths can not be specified.
* `tasks/<MODULE>` --- a semi-magical mount point which allows access to files in the `tasks` subdirectory of `<MODULE>` --- see the [the docs on file serving](https://docs.puppet.com/puppet/latest/reference/file_serving.html).

Note: PSON responses in the examples below are pretty-printed for readability.

Find
----

Get file metadata for a single file

    GET /puppet/v3/file_metadata/:mount/path/to/file?environment=:environment

### Supported HTTP Methods

GET

### Supported Response Formats

`application/json`, `text/pson`

### Parameters

Optional parameters to GET:

* `links` -- either `manage` (default) or `follow`. See examples in Search below.
* `checksum_type` -- the checksum type to calculate the checksum value for the result metadata; one of `md5` (default), `md5lite`, `sha256`, `sha256lite`, `mtime`, `ctime`, and `none`.
* `source_permissions` -- whether (and how) Puppet should copy owner, group, and mode permissions; one of
  * `ignore` (the default) will never apply the owner, group, or mode from the source when managing a file. When creating new files without explicit permissions, the permissions they receive will depend on platform-specific behavior. On POSIX, Puppet will use the umask of the user it is running as. On Windows, Puppet will use the default DACL associated with the user it is running as.
  * `use` will cause Puppet to apply the owner, group, and mode from the source to any files it is managing.
  * `use_when_creating` will only apply the owner, group, and mode from the source when creating a file; existing files will not have their permissions overwritten.

### Example Response

#### File metadata found for a file

    GET /puppet/v3/file_metadata/modules/example/just_a_file.txt?environment=env

    HTTP/1.1 200 OK
    Content-Type: text/pson

    {
        "checksum": {
            "type": "md5",
            "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
        },
        "destination": null,
        "group": 20,
        "links": "manage",
        "mode": 420,
        "owner": 501,
        "path": "/etc/puppetlabs/code/modules/example/files/just_a_file.txt",
        "relative_path": null,
        "type": "file"
    }

#### File metadata found for a directory

    GET /puppet/v3/file_metadata/modules/example/subdirectory?environment=env

    HTTP/1.1 200 OK
    Content-Type: text/pson

    {
        "checksum": {
            "type": "ctime",
            "value": "{ctime}2013-10-01 13:16:10 -0700"
        },
        "destination": null,
        "group": 20,
        "links": "manage",
        "mode": 493,
        "owner": 501,
        "path": "/etc/puppetlabs/code/modules/example/files/subdirectory",
        "relative_path": null,
        "type": "directory"
    }

#### File metadata found for a link ignoring source permissions

    GET /puppet/v3/file_metadata/modules/example/link_to_file.txt?environment=env&source_permissions=ignore

    HTTP/1.1 200 OK
    Content-Type: text/pson

    {
        "checksum": {
            "type": "md5",
            "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
        },
        "destination": "/etc/puppetlabs/code/modules/example/files/just_a_file.txt",
        "group": 20,
        "links": "manage",
        "mode": 420,
        "owner": 501,
        "path": "/etc/puppetlabs/code/modules/example/files/link_to_file.txt",
        "relative_path": null,
        "type": "link"
    }

#### File not found

    GET /puppet/v3/file_metadata/modules/example/does_not_exist?environment=env

    HTTP/1.1 404 Not Found

    Not Found: Could not find file_metadata modules/example/does_not_exist

Search
------

Get a list of metadata for multiple files

    GET /puppet/v3/file_metadatas/foo.txt?environment=env

### Supported HTTP Methods

GET

### Supported Response Formats

`application/json`, `text/pson`

### Parameters

* `recurse` -- should always be set to `yes`; unfortunately the default is `no`, which causes a search to behave like a find operation.
* `ignore` -- file or directory regex to ignore; can be repeated.
* `links` -- either `manage` (default) or `follow`. See examples below.
* `checksum_type` -- the checksum type to calculate the checksum value for the result metadata; one of `md5` (default), `md5lite`, `sha256`, `sha256lite`, `mtime`, `ctime`, and `none`.
* `source_permissions` -- whether (and how) Puppet should copy owner, group, and mode permissions; one of
  * `ignore` (the default) will never apply the owner, group, or mode from the source when managing a file. When creating new files without explicit permissions, the permissions they receive will depend on platform-specific behavior. On POSIX, Puppet will use the umask of the user it is running as. On Windows, Puppet will use the default DACL associated with the user it is running as.
  * `use` will cause Puppet to apply the owner, group, and mode from the source to any files it is managing.
  * `use_when_creating` will only apply the owner, group, and mode from the source when creating a file; existing files will not have their permissions overwritten.

### Example Response

#### Basic search

    GET /puppet/v3/file_metadatas/modules/example?environment=env&recurse=yes

    HTTP 200 OK
    Content-Type: text/pson

    [
        {
            "checksum": {
                "type": "ctime",
                "value": "{ctime}2013-10-01 13:15:59 -0700"
            },
            "destination": null,
            "group": 20,
            "links": "manage",
            "mode": 493,
            "owner": 501,
            "path": "/etc/puppetlabs/code/modules/example/files",
            "relative_path": ".",
            "type": "directory"
        },
        {
            "checksum": {
                "type": "md5",
                "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
            },
            "destination": null,
            "group": 20,
            "links": "manage",
            "mode": 420,
            "owner": 501,
            "path": "/etc/puppetlabs/code/modules/example/files",
            "relative_path": "just_a_file.txt",
            "type": "file"
        },
        {
            "checksum": {
                "type": "md5",
                "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
            },
            "destination": "/etc/puppetlabs/code/modules/example/files/just_a_file.txt",
            "group": 20,
            "links": "manage",
            "mode": 493,
            "owner": 501,
            "path": "/etc/puppetlabs/code/modules/example/files",
            "relative_path": "link_to_file.txt",
            "type": "link"
        },
        {
            "checksum": {
                "type": "ctime",
                "value": "{ctime}2013-10-01 13:15:59 -0700"
            },
            "destination": null,
            "group": 20,
            "links": "manage",
            "mode": 493,
            "owner": 501,
            "path": "/etc/puppetlabs/code/modules/example/files",
            "relative_path": "subdirectory",
            "type": "directory"
        },
        {
            "checksum": {
                "type": "md5",
                "value": "{md5}d41d8cd98f00b204e9800998ecf8427e"
            },
            "destination": null,
            "group": 20,
            "links": "manage",
            "mode": 420,
            "owner": 501,
            "path": "/etc/puppetlabs/code/modules/example/files",
            "relative_path": "subdirectory/another_file.txt",
            "type": "file"
        }
    ]

#### Search ignoring 'sub*' and links = manage

    GET /puppet/v3/file_metadatas/modules/example?environment=env&recurse=true&ignore=sub*&links=manage

    HTTP 200 OK
    Content-Type: text/pson

    [
        {
            "checksum": {
                "type": "ctime",
                "value": "{ctime}2013-10-01 13:15:59 -0700"
            },
            "destination": null,
            "group": 20,
            "links": "manage",
            "mode": 493,
            "owner": 501,
            "path": "/etc/puppetlabs/code/modules/example/files",
            "relative_path": ".",
            "type": "directory"
        },
        {
            "checksum": {
                "type": "md5",
                "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
            },
            "destination": null,
            "group": 20,
            "links": "manage",
            "mode": 420,
            "owner": 501,
            "path": "/etc/puppetlabs/code/modules/example/files",
            "relative_path": "just_a_file.txt",
            "type": "file"
        },
        {
            "checksum": {
                "type": "md5",
                "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
            },
            "destination": "/etc/puppetlabs/code/modules/example/files/just_a_file.txt",
            "group": 20,
            "links": "manage",
            "mode": 493,
            "owner": 501,
            "path": "/etc/puppetlabs/code/modules/example/files",
            "relative_path": "link_to_file.txt",
            "type": "link"
        }
    ]

#### Search ignoring "sub*" and links = follow

This example is identical to the above example, except for the links parameter. The resulting PSON, then,
is identical to the above example, except for:

* the "links" field is set to "follow" rather than "manage" in all metadata objects
* in the "link_to_file.txt" metadata:
    * for "manage" the "destination" field is the link destination; for "follow", it's null
    * for "manage" the "type" field is "link"; for "follow" it's "file"
    * for "manage" the "mode", "owner" and "group" fields are the link's values; for "follow" the destination's values

~~~
GET /puppet/v3/file_metadatas/modules/example?environment=env&recurse=true&ignore=sub*&links=follow

HTTP 200 OK
Content-Type: text/pson

[
    {
        "checksum": {
            "type": "ctime",
            "value": "{ctime}2013-10-01 13:15:59 -0700"
        },
        "destination": null,
        "group": 20,
        "links": "follow",
        "mode": 493,
        "owner": 501,
        "path": "/etc/puppetlabs/code/modules/example/files",
        "relative_path": ".",
        "type": "directory"
    },
    {
        "checksum": {
            "type": "md5",
            "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
        },
        "destination": null,
        "group": 20,
        "links": "follow",
        "mode": 420,
        "owner": 501,
        "path": "/etc/puppetlabs/code/modules/example/files",
        "relative_path": "just_a_file.txt",
        "type": "file"
    },
    {
        "checksum": {
            "type": "md5",
            "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
        },
        "destination": null,
        "group": 20,
        "links": "follow",
        "mode": 420,
        "owner": 501,
        "path": "/etc/puppetlabs/code/modules/example/files",
        "relative_path": "link_to_file.txt",
        "type": "file"
    }
]
~~~

Schema
------

The file metadata response body conforms to
[the `file_metadata` schema.](../schemas/file_metadata.json)

Sample Module
-------------

The examples above use this (faux) module:

    /etc/puppetlabs/code/modules/example/
      files/
        just_a_file.txt
        link_to_file.txt -> /etc/puppetlabs/code/modules/example/files/just_a_file.txt
        subdirectory/
          another_file.txt
