require 'scanf'

Puppet::Parser::Functions::newfunction(
  :scanf,
  :type => :rvalue,
  :arity => 2,
  :doc => <<-DOC
Scans a string and returns an array of one or more converted values based on the given format string.
See the documentation of Ruby's String#scanf method for details about the supported formats (which
are similar but not identical to the formats used in Puppet's `sprintf` function.)

This function takes two mandatory arguments: the first is the string to convert, and the second is
the format string. The result of the scan is an array, with each successfully scanned and transformed value.
The scanning stops if a scan is unsuccessful, and the scanned result up to that point is returned. If there
was no successful scan, the result is an empty array.

```puppet
"42".scanf("%i")
```

You can also optionally pass a lambda to scanf, to do additional validation or processing.

```puppet
"42".scanf("%i") |$x| {
  unless $x[0] =~ Integer {
    fail "Expected a well formed integer value, got '$x[0]'"
  }
  $x[0]
}
```

- Since 4.0.0
DOC
) do |args|
  data = args[0]
  format = args[1]
  data.scanf(format)
end
