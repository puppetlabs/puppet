PSON
=============

PSON is a variant of [JSON](http://json.org) that puppet uses for serializing
data to transmit across the network or store on disk. Whereas JSON requires
that the serialized form is valid unicode (usually UTF-8), PSON is 8-bit ASCII,
which allows it to represent arbitrary byte sequences in strings.

Puppet uses the MIME types "pson" and "text/pson" to refer to PSON.

Differences from JSON
---------------------

PSON does *not differ* from JSON in its representation of objects, arrays,
numbers, booleans, and null values. PSON *does* serialize strings differently
from JSON.

A PSON string is a sequence of 8-bit ASCII encoded data. It must start and end
with " (ASCII 0x22) characters. Between these characters it may contain any
byte sequence. Some individual characters are represented by a sequence of
characters:

    | Byte | ASCII Character | Encoded Sequence | Encoded ASCII Sequence |
    | ---- | --------------- | ---------------- | ---------------------- |
    | 0x22 | "               | 0x5C, 0x22       | \"                     |
    | 0x5c | \               | 0x5C, 0x5C       | \\                     |
    | 0x08 | Backspace       | 0x5C, 0x62       | \b                     |
    | 0x09 | Horizontal Tab  | 0x5C, 0x74       | \t                     |
    | 0x0A | Line Feed       | 0x5C, 0x6E       | \n                     |
    | 0x0C | Form Feed       | 0x5C, 0x66       | \f                     |
    | 0x0D | Carriage Return | 0x5C, 0x72       | \r                     |

In addition, any character between 0x00 and 0x1F, (except the ones listed
above) must be encoded as a six byte sequence of \u followed by four ASCII
digits of the hex number of the desired character. For example the ASCII
Record Separator character (0x1E) is represented as \u001E (0x5C, 0x75, 0x30,
0x30, 0x31, 0x45).

Decoding PSON Using JSON Parsers
--------------------------------

Many languages have JSON parsers already, which can often be used to parse PSON
data. Although JSON requires that it is encoded as unicode most parsers will
produce usable output from PSON if they are instructed to interpret the input
as Latin-1 encoding.

In all these examples there is a file available called `data.pson` that
contains the ruby structure `{ "data" => "\x07\x08\xC3\xC3" }` encoded as
PSON (the value is an invalid unicode sequence). In bytes the data is:

    0x7b 0x22 0x64 0x61 0x74 0x61 0x22 0x3a 0x22 0x5c 0x75 0x30 0x30 0x30 0x37 0x5c 0x62 0xc3 0xc3 0x22 0x7d

Python Example:

    >>> import json
    >>> json.load(open("data.pson"), "latin_1")
    {u'data': u'\x07\x08\xc3\xc3'}

Clojure Example:

    user> (parse-string (slurp "data.pson" :encoding "ISO-8859-1"))
    {"data" "^G\bÃÃ"}
