module Puppet::Parser::YamlTrimmer
    REMOVE = %w{@scope @source}

    def to_yaml_properties
        r = instance_variables - REMOVE
        if respond_to?(:skip_for_yaml)
            r -= skip_for_yaml()
        end
        r
    end
end
