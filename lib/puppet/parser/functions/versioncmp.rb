require 'puppet/util/package'

Puppet::Parser::Functions::newfunction( :versioncmp, :type => :rvalue, :arity => 2, :doc =>
"Compares two version numbers.

Prototype:

    \$result = versioncmp(a, b)

Where a and b are arbitrary version strings.

This function returns:

* `1` if version a is greater than version b
* `0` if the versions are equal
* `-1` if version a is less than version b

Example:

    if versioncmp('2.6-1', '2.4.5') > 0 {
        notice('2.6-1 is > than 2.4.5')
    }

This function uses the same version comparison algorithm used by Puppet's
`package` type.

") do |args|

  return Puppet::Util::Package.versioncmp(args[0], args[1])
end
