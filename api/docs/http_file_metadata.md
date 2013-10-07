File Metadata
=============

The `file_metadata` endpoint returns select metadata for a single file or many files. There are find and search variants
of the endpoint; the search variant has a trailing 's' so is actually `file_metadatas`.

Although the term 'file' is used generically in the endpoint name and documentation, each returned item can be one of
the following three types:

* file
* directory
* symbolic link

Note that an `:environment` must be specified in the endpoint, but is actually ignored since the puppet file server
is not environment-specific.  (In fact, the specified `:environment` does even need to be valid.)

The endpoint path includes a `:mount` which can be one of three types:

* custom file serving mounts as specified in fileserver.conf -- see [the puppet file serving guide](http://docs.puppetlabs.com/guides/file_serving.html#serving-files-from-custom-mount-points)
* `modules/<module>` -- a semi-magical mount point which allows access to the `files` subdirectory of `module` -- see [the puppet file serving guide](http://docs.puppetlabs.com/guides/file_serving.html#serving-module-files)
* `plugins` -- a highly magical mount point which merges many directories together: used for plugin sync, sub-paths can not be specified, not intended for general consumption

Note: pson responses in the examples below are pretty-printed for readability.
Find
----

Get file metadata for a single file

    GET /:environment/file_metadata/:mount/path/to/file

### Supported HTTP Methods

GET

### Supported Format

Accept: pson, text/pson

### Parameters

### Example Response

#### File metadata found for a file

    GET /env/file_metadata/modules/example/just_a_file.txt

    HTTP/1.1 200 OK
    Content-Type: text/pson

    {
        "data": {
            "checksum": {
                "type": "md5",
                "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
            },
            "destination": null,
            "group": 20,
            "links": "manage",
            "mode": 420,
            "owner": 501,
            "path": "/etc/puppet/conf/modules/example/files/just_a_file.txt",
            "relative_path": null,
            "type": "file"
        },
        "document_type": "FileMetadata",
        "metadata": {
            "api_version": 1
        }
    }

#### File metadata found for a directory

    GET /env/file_metadata/modules/example/subdirectory

    HTTP/1.1 200 OK
    Content-Type: text/pson

    {
        "data": {
            "checksum": {
                "type": "ctime",
                "value": "{ctime}2013-10-01 13:16:10 -0700"
            },
            "destination": null,
            "group": 20,
            "links": "manage",
            "mode": 493,
            "owner": 501,
            "path": "/etc/puppet/conf/modules/example/files/subdirectory",
            "relative_path": null,
            "type": "directory"
        },
        "document_type": "FileMetadata",
        "metadata": {
            "api_version": 1
        }
    }

#### File metadata found for a link

    GET /env/file_metadata/modules/example/link_to_file.txt

    HTTP/1.1 200 OK
    Content-Type: text/pson

    {
        "data": {
            "checksum": {
                "type": "md5",
                "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
            },
            "destination": "/etc/puppet/conf/modules/example/files/just_a_file.txt",
            "group": 20,
            "links": "manage",
            "mode": 493,
            "owner": 501,
            "path": "/etc/puppet/conf/modules/example/files/link_to_file.txt",
            "relative_path": null,
            "type": "link"
        },
        "document_type": "FileMetadata",
        "metadata": {
            "api_version": 1
        }
    }

#### File not found

    GET /env/file_metadata/modules/example/does_not_exist

    HTTP/1.1 404 Not Found: Could not find file_metadata modules/example/does_not_exist

Search
------

Get a list of metadata for multiple files

    GET /env/file_metadatas/foo.txt

### Supported HTTP Methods

GET

### Supported Format

Accept: pson, text/pson

### Parameters

* `recurse` -- should always be set to `yes`; unfortunately the default is `no` which causes renders this a Find operation
* `ignore` -- file or directory regex to ignore; can be repeated
* `links` -- either `manage` (default) or `follow`.  See examples below.

### Example Response

#### Basic search

    GET /env/file_metadatas/modules/example?recurse=yes

    HTTP 200 OK
    Content-Type: text/pson

    [
        {
            "data": {
                "checksum": {
                    "type": "ctime",
                    "value": "{ctime}2013-10-01 13:15:59 -0700"
                },
                "destination": null,
                "group": 20,
                "links": "manage",
                "mode": 493,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": ".",
                "type": "directory"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        },
        {
            "data": {
                "checksum": {
                    "type": "md5",
                    "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
                },
                "destination": null,
                "group": 20,
                "links": "manage",
                "mode": 420,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": "just_a_file.txt",
                "type": "file"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        },
        {
            "data": {
                "checksum": {
                    "type": "md5",
                    "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
                },
                "destination": "/etc/puppet/conf/modules/example/files/just_a_file.txt",
                "group": 20,
                "links": "manage",
                "mode": 493,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": "link_to_file.txt",
                "type": "link"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        },
        {
            "data": {
                "checksum": {
                    "type": "ctime",
                    "value": "{ctime}2013-10-01 13:15:59 -0700"
                },
                "destination": null,
                "group": 20,
                "links": "manage",
                "mode": 493,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": "subdirectory",
                "type": "directory"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        },
        {
            "data": {
                "checksum": {
                    "type": "md5",
                    "value": "{md5}d41d8cd98f00b204e9800998ecf8427e"
                },
                "destination": null,
                "group": 20,
                "links": "manage",
                "mode": 420,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": "subdirectory/another_file.txt",
                "type": "file"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        }
    ]

#### Search ignoring 'sub*' and links = manage

    GET /env/file_metadatas/modules/example?recurse=true&ignore=sub*&links=manage

    HTTP 200 OK
    Content-Type: text/pson

    [
        {
            "data": {
                "checksum": {
                    "type": "ctime",
                    "value": "{ctime}2013-10-01 13:15:59 -0700"
                },
                "destination": null,
                "group": 20,
                "links": "manage",
                "mode": 493,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": ".",
                "type": "directory"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        },
        {
            "data": {
                "checksum": {
                    "type": "md5",
                    "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
                },
                "destination": null,
                "group": 20,
                "links": "manage",
                "mode": 420,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": "just_a_file.txt",
                "type": "file"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        },
        {
            "data": {
                "checksum": {
                    "type": "md5",
                    "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
                },
                "destination": "/etc/puppet/conf/modules/example/files/just_a_file.txt",
                "group": 20,
                "links": "manage",
                "mode": 493,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": "link_to_file.txt",
                "type": "link"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        }
    ]

#### Search ignoring 'sub*' and links = follow

This example is identical to the above example, except for the different links parameter.  The result pson, then,
is identical to the above example, except for:

* the 'links' field is set to "follow" rather than "manage" in all metadata objects
* in the 'link_to_file.txt' metadata:
    * for 'manage' the 'destination' field is the link destination; for 'follow', it's null
    * for 'manage' the 'type' field is 'link'; for 'follow' it's 'file'
    * for 'manage' the 'mode', 'owner' and 'group' fields are the link's values; for 'follow' the destination's values

` `

    GET /env/file_metadatas/modules/example?recurse=true&ignore=sub*&links=follow

    HTTP 200 OK
    Content-Type: text/pson

    [
        {
            "data": {
                "checksum": {
                    "type": "ctime",
                    "value": "{ctime}2013-10-01 13:15:59 -0700"
                },
                "destination": null,
                "group": 20,
                "links": "follow",
                "mode": 493,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": ".",
                "type": "directory"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        },
        {
            "data": {
                "checksum": {
                    "type": "md5",
                    "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
                },
                "destination": null,
                "group": 20,
                "links": "follow",
                "mode": 420,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": "just_a_file.txt",
                "type": "file"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        },
        {
            "data": {
                "checksum": {
                    "type": "md5",
                    "value": "{md5}d0a10f45491acc8743bc5a82b228f89e"
                },
                "destination": null,
                "group": 20,
                "links": "follow",
                "mode": 420,
                "owner": 501,
                "path": "/etc/puppet/conf/modules/example/files",
                "relative_path": "link_to_file.txt",
                "type": "file"
            },
            "document_type": "FileMetadata",
            "metadata": {
                "api_version": 1
            }
        }
    ]

Schema
------

The representation of file metadata conforms to the api/schemas/file_metadata.json.

Sample Module
-------------

The examples above use this (faux) module:

    /etc/puppet/conf/modules/example/
      files/
        just_a_file.txt
        link_to_file.txt -> /etc/puppet/conf/modules/example/files/just_a_file.txt
        subdirectory/
          another_file.txt
