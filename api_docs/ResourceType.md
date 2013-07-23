Resource Type
=============

See the [source manifest](#Source) used to generate all example responses.

Find
----

```http
GET /:environment/resource_type/:name
```

### Parameters

None

### Response

```http
HTTP 200 OK
Content-Type: text/pson
```

```json
{
  "line": 7,
  "file": "/etc/puppet/manifests/site.pp",
  "name":"athing",
  "kind":"class"
}
```

Search
------

List all resource types matching a regular expression:

```http
GET /:environment/resource_types/:search_string
```

`search_string` is a Ruby regular expression. Surrounding slashes are
stripped. It can also be the string `*`, which will match all
resource types. It is required.

### Parameters

* `kind`: Filter the returned resource types by the `kind` field.
  Valid values are `class`, `node`, and `defined_type`.

### Response

```http
HTTP 200 OK
Content-Type: text/pson
```

```json
[
  {
    "line": 7,
    "file": "/etc/puppet/manifests/site.pp",
    "name":"athing",
    "kind":"class"
  },
  {
    "doc":"An example class\n",
    "line":11,
    "file":"/etc/puppet/manifests/site.pp",
    "parent":"athing",
    "name":"bthing",
    "kind":"class"
  },
  {
    "line":1,
    "file":"/etc/puppet/manifests/site.pp",
    "parameters":
    {
      "message":null,
      "a":"{key => \"val\", key2 => \"val2\"}"
    },
    "name":"hello",
    "kind":"defined_type"
  }
]
```

### Examples

List all classes:

```http
GET /:environment/resource_types/*?kind=class
```

Schema
------

It has the following fields, of which only name and kind are guaranteed
to be present:

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

```puppet
define hello ($message, $a = { key => 'val', key2 => 'val2' }) {
    notify {$message: }
}

hello { "there": }

class athing {
}

# An example class
class bthing inherits athing {
}
```

