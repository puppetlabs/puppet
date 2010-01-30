# Test whether a given class or definition is defined
Puppet::Parser::Functions::newfunction(:defined, :type => :rvalue, :doc => "Determine whether a given
    type is defined, either as a native type or a defined type, or whether a class is defined.
    This is useful for checking whether a class is defined and only including it if it is.
    This function can also test whether a resource has been defined, using resource references
    (e.g., ``if defined(File['/tmp/myfile']) { ... }``).  This function is unfortunately
    dependent on the parse order of the configuration when testing whether a resource is defined.") do |vals|
        result = false
        vals = [vals] unless vals.is_a?(Array)
        vals.each do |val|
            case val
            when String
                if Puppet::Type.type(val) or find_definition(val) or find_hostclass(val)
                    result = true
                    break
                end
            when Puppet::Resource
                if findresource(val.to_s)
                    result = true
                    break
                end
            else
                raise ArgumentError, "Invalid argument of type '#{val.class}' to 'defined'"
            end
        end
        result
end
