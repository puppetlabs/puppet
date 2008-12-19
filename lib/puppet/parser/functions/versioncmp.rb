require 'puppet/util/package'

Puppet::Parser::Functions::newfunction(:versioncmp,  :doc => "Compares two versions.") do |args|

    unless args.length == 2
        raise Puppet::ParseError, "versioncmp should have 2 arguments"
    end

    return Puppet::Util::Package.versioncmp(args[0], args[1])
end
