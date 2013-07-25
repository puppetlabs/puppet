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

### Responses

#### Resource type found

```http
GET /env/resource_type/athing
```

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

#### Resource type not found

```http
GET /env/resource_type/resource_type_does_not_exist
```

```http
HTTP 404 Not Found: Could not find resource_type resource_type_does_not_exist
Content-Type: text/plain
```

```
Not Found: Could not find resource_type resource_type_does_not_exist
```

#### No resource type name given

```http
GET /env/resource_type/
```

```http
HTTP/1.1 400 No request key specified in /env/resource_type/
Content-Type: text/plain
```

```
No request key specified in /env/resource_type/
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

### Responses

#### Search with results

```http
GET /env/resource_types/*
```

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

#### Search not found

```http
GET /env/resource_types/pattern.that.finds.no.resources
```

```http
HTTP/1.1 404 Not Found: Could not find instances in resource_type with 'pattern.that.finds.no.resources'
Content-Type: text/plain
```

```
Not Found: Could not find instances in resource_type with 'pattern.that.finds.no.resources'
```

#### No search term given

```http
GET /env/resource_types/
```

```http
HTTP/1.1 400 No request key specified in /env/resource_types/ 
Content-Type: text/plain
```

```
No request key specified in /env/resource_types/
```

#### Search term is an invalid regular expression

Searching on `[-` for instance.

```http
GET /env/resource_types/%5b-
```

```http
HTTP/1.1 400 Invalid regex '[-': premature end of char-class: /[-/ 
Content-Type: text/plain
```

```
Invalid regex '[-': premature end of char-class: /[-/
```

### Examples

List all classes:

```http
GET /:environment/resource_types/*?kind=class
```

List matching a regular expression

```http
GET /:environment/resource_types/foo.*bar
```

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

