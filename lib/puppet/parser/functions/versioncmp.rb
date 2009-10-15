require 'puppet/util/package'

Puppet::Parser::Functions::newfunction(:versioncmp, :type => :rvalue, 
    :doc => "Compares two versions

Prototype::

    \$result = versioncmp(a, b)

    where a and b are arbitrary version strings

This functions returns a number::

    * > 0 if version a is greater than version b
    * == 0 if both version are equals
    * < 0 if version a is less than version b

Example::

    if versioncmp('2.6-1', '2.4.5') > 0 {
        notice('2.6-1 is > than 2.4.5')
    }

") do |args|

    unless args.length == 2
        raise Puppet::ParseError, "versioncmp should have 2 arguments"
    end

    return Puppet::Util::Package.versioncmp(args[0], args[1])
end
