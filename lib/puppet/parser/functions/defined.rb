# Test whether a given class or definition is defined
Puppet::Parser::Functions::newfunction(:defined, :type => :rvalue, :doc => "Determine whether a given
    type is defined, either as a native type or a defined type, or whether a class is defined.
    This is useful for checking whether a class is defined and only including it if it is.
    This function can also test whether a resource has been defined, using resource references
    (e.g., ``if defined(File['/tmp/myfile']) { ... }``).  This function is unfortunately
    dependent on the parse order of the configuration when testing whether a resource is defined.") do |vals|
        result = false
        vals.each do |val|
            case val
            when String
                # For some reason, it doesn't want me to return from here.
                if Puppet::Type.type(val) or find_definition(val) or find_hostclass(val)
                    result = true
                    break
                end
            when Puppet::Parser::Resource::Reference
                if findresource(val.to_s)
                    result = true
                    break
                end
            else
                raise ArgumentError, "Invalid argument of type %s to 'defined'" % val.class
            end
        end
        result
end
