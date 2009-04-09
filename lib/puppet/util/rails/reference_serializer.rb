
module Puppet::Util::ReferenceSerializer
    def unserialize_value(val)
        case val
        when /^--- /
            YAML.load(val)
        when "true"
            true
        when "false"
            false
        else
            val
        end
    end

    def serialize_value(val)
        case val
        when Puppet::Parser::Resource::Reference
            YAML.dump(val)
        when true, false
            # The database does this for us, but I prefer the
            # methods be their exact inverses.
            # Note that this means quoted booleans get returned
            # as actual booleans, but there doesn't appear to be
            # a way to fix that while keeping the ability to
            # search for parameters set to true.
            val.to_s
        else
            val
        end
    end
end
