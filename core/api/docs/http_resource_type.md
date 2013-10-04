Resource Type
=============

The `resource_type` and `resource_types` endpoints return information about the
following kinds of objects available to the puppet master:

* Classes (`class myclass { ... }`)
* Defined types (`define mytype ($parameter) { ... }`)
* Node definitions (`node 'web01.example.com' { ... }`)

For an object to be available to the puppet master, it must be present in the
site manifest (configured by the `manifest` setting) or in a module located in
the modulepath (configured by the `modulepath` setting; classes and defined
types only).

Note that this endpoint does **not** return information about native resource
types written in Ruby.

See the end of this page for the source manifest used to generate all example
responses.

Find
----

Get info about a specific class, defined type, or node, by name. Returns a
single resource_type response object (see "Schema" below).

    GET /:environment/resource_type/:nodename

> **Note:** Although no two classes or defined types may have the same name,
> it's possible for a node definition to have the same name as a class or
> defined type. If this happens, the class or defined type will be returned
> instead of the node definition. The order in which kinds of objects are
> searched is classes, then defined types, then node definitions.


### Supported HTTP Methods

GET

### Supported Formats

Accept: pson, text/pson

### Parameters

None

### Responses

#### Resource Type Found

    GET /env/resource_type/athing

    HTTP 200 OK
    Content-Type: text/pson

    {
      "line": 7,
      "file": "/etc/puppet/manifests/site.pp",
      "name":"athing",
      "kind":"class"
    }

#### Resource Type Not Found

    GET /env/resource_type/resource_type_does_not_exist

    HTTP 404 Not Found: Could not find resource_type resource_type_does_not_exist
    Content-Type: text/plain

    Not Found: Could not find resource_type resource_type_does_not_exist

#### No Resource Type Name Given

    GET /env/resource_type/

    HTTP/1.1 400 No request key specified in /env/resource_type/
    Content-Type: text/plain

    No request key specified in /env/resource_type/

Search
------

List all resource types matching a regular expression. Returns an array of
resource_type response objects (see "Schema" below).

    GET /:environment/resource_types/:search_string

The `search_string` is required. It must be either a Ruby regular expression or
the string `*` (which will match all resource types). Surrounding slashes are
stripped. Note that if you want to use the `?` character in a regular
expression, it must be escaped as `%3F`.

### Supported HTTP Methods

GET

### Supported Formats

Accept: pson, text/pson

### Parameters

* `kind`: Optional. Filter the returned resource types by the `kind` field.
  Valid values are `class`, `node`, and `defined_type`.

### Responses

#### Search With Results

    GET /env/resource_types/*

    HTTP 200 OK
    Content-Type: text/pson

    [
      {
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "class",
        "line": 7,
        "name": "athing"
      },
      {
        "doc": "An example class\n",
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "class",
        "line": 11,
        "name": "bthing",
        "parent": "athing"
      },
      {
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "defined_type",
        "line": 1,
        "name": "hello",
        "parameters": {
          "a": "{key2 => \"val2\", key => \"val\"}",
          "message": "$title"
        }
      },
      {
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "node",
        "line": 14,
        "name": "web01.example.com"
      },
      {
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "node",
        "line": 17,
        "name": "default"
      }
    ]


#### Search Not Found

    GET /env/resource_types/pattern.that.finds.no.resources

    HTTP/1.1 404 Not Found: Could not find instances in resource_type with 'pattern.that.finds.no.resources'
    Content-Type: text/plain

    Not Found: Could not find instances in resource_type with 'pattern.that.finds.no.resources'

#### No Search Term Given

    GET /env/resource_types/

    HTTP/1.1 400 No request key specified in /env/resource_types/
    Content-Type: text/plain

    No request key specified in /env/resource_types/

#### Search Term Is an Invalid Regular Expression

Searching on `[-` for instance.

    GET /env/resource_types/%5b-

    HTTP/1.1 400 Invalid regex '[-': premature end of char-class: /[-/
    Content-Type: text/plain

    Invalid regex '[-': premature end of char-class: /[-/

### Examples

List all classes:

    GET /:environment/resource_types/*?kind=class

List matching a regular expression:

    GET /:environment/resource_types/foo.*bar

Schema
------

A resource_type response body has has the following fields, of which only name
and kind are guaranteed to be present:

    doc: string
        Any documentation comment from the type definition

    line: integer
        The line number where the type is defined

    file: string
        The full path of the file where the type is defined

    name: string
        The fully qualified name

    kind: string, one of "class", "node", or "defined_type"
        The kind of object the type represents

    parent: string
        If the type inherits from another type, the name of that type

    parameters: hash{string => (string or "null")}
        The default arguments to the type. If an argument has no default value,
        the value is represented by a literal "null" (without quotes in pson).
        Default values are the string representation of that value, even for more
        complex structures (e.g. the hash { key => 'val', key2 => 'val2' } would
        be represented in pson as "{key => \"val\", key2 => \"val2\"}".

Source
------

Example site.pp used to generate all the responses in this file:

    define hello ($message = $title, $a = { key => 'val', key2 => 'val2' }) {
      notify {$message: }
    }

    hello { "there": }

    class athing {
    }

    # An example class
    class bthing inherits athing {
    }

    node 'web01.example.com' {}
    node default {}

