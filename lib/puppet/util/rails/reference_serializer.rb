
module Puppet::Util::ReferenceSerializer
    def unserialize_value(val)
        if val =~ /^--- [!:]/
            YAML.load(val)
        else
            val
        end
    end

    def serialize_value(val)
        if val.is_a?(Puppet::Parser::Resource::Reference)
            YAML.dump(val)
        else
            val
        end
    end
end