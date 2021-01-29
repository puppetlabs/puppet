PSON
=============

PSON is a variant of [JSON](http://json.org) that puppet uses for serializing
data to transmit across the network or store on disk. Whereas JSON requires
that the serialized form is valid unicode (usually UTF-8), PSON is 8-bit ASCII,
which allows it to represent arbitrary byte sequences in strings.

PSON was forked from upstream [pure JSON v1.1.9](https://github.com/flori/json/tree/v1.1.9/lib/json/pure) and patches
were added to [allow binary data](https://github.com/puppetlabs/puppet/commit/3c56705a95c945778674f9792a07b66b879cb48e).

Puppet uses the MIME types "pson" and "text/pson" to refer to PSON.

JSON Strings
-------------

A JSON string is encoded in Unicode. The string must start and end with " (ASCII
0x22). Between these characters, double quote, reverse solidus (backslash) and
control characters (\u0000 - \u001F) must be escaped, all others may be escaped.

The escape process replaces each code point with "reverse solidus, followed by
the lowercase letter u, followed by four hexadecimal digits that encode the
character's code point." For example, the ASCII record separator character
(\u001F) is serialized in JSON as:

    0x5C 0x75 0x30 0x30 0x31 0x45

In addition, the double quote, reverse solidus and some printable control
characters are commonly escaped using a shorter form, using a single reverse
solidus:

    | Byte | ASCII Character | Encoded Sequence | Encoded ASCII Sequence |
    | ---- | --------------- | ---------------- | ---------------------- |
    | 0x22 | "               | 0x5C, 0x22       | \"                     |
    | 0x5c | \               | 0x5C, 0x5C       | \\                     |
    | 0x08 | Backspace       | 0x5C, 0x62       | \b                     |
    | 0x09 | Horizontal Tab  | 0x5C, 0x74       | \t                     |
    | 0x0A | Line Feed       | 0x5C, 0x6E       | \n                     |
    | 0x0C | Form Feed       | 0x5C, 0x66       | \f                     |
    | 0x0D | Carriage Return | 0x5C, 0x72       | \r                     |

UTF-8/16/32 encodings define a set of rules for how code points are encoded as
bytes. However, there are some byte sequences that are not a valid encoding for
any code point. For example, in UTF-8, 0x80 is used to indicate a two byte
sequence, so the following fails:

    JSON.generate("\x80")
    #=> JSON::GeneratorError (source sequence is illegal/malformed utf-8)

Differences from JSON
---------------------

PSON does *not differ* from JSON in its representation of objects, arrays,
numbers, booleans, and null values. PSON *does* serialize strings differently
from JSON.

PSON shares the same encoding process as JSON, except that a PSON string is a
sequence of 8-bit ASCII values. So the string containing 0x80 can be serialized
*unescaped* as PSON:

    PSON.generate("\x80").bytes.to_a.map { |b| b.to_s(16) }
    #=> ["22", "80", "22"]

One other difference is that PSON *may* produce strings with 8-bit ASCII
encoding, unlike JSON:

    PSON.generate("\u20AC").encoding
    #=> #<Encoding:ASCII-8BIT>
    JSON.generate("\u20AC").encoding
    #=> #<Encoding:UTF-8>

Finally, PSON does not roundtrip values that are not arrays or hashes in the same way as JSON:

    JSON.parse(JSON.generate("\x1E"))
    #=> "\u001E"
    PSON.parse(PSON.generate("\x1E"))
    #=> PSON::ParserError (source '"\u001e"' not in PSON!)

whereas PSON can roundtrip an array (or hash) containing that value:

    PSON.parse(PSON.generate(["\x1E"]))
    #=> ["\u001E"]

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

which represents:

     {    "    d    a    t    a    "   <sp>  "    \    u    0    0    0    7    \    b    0xc3 0xc3 "    }

Python Example:

    >>> import json
    >>> json.load(open("data.pson"), "latin_1")
    {u'data': u'\x07\x08\xc3\xc3'}

Clojure Example:

    user> (parse-string (slurp "data.pson" :encoding "ISO-8859-1"))
    {"data" "^G\bÃÃ"}

Ruby Example:

    irb> JSON.parse(File.read('data.pson', encoding: "ISO-8859-1"))
    => {"data"=>"\a\bÃÃ"}
