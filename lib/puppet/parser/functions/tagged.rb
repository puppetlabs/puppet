# Test whether a given tag is set.  This functions as a big OR -- if any of the specified tags are unset, we return false.
Puppet::Parser::Functions::newfunction(:tagged, :type => :rvalue, :doc => "A boolean function that
    tells you whether the current container is tagged with the specified tags.
    The tags are ANDed, so that all of the specified tags must be included for
    the function to return true.") do |vals|
        configtags = compiler.catalog.tags
        resourcetags = resource.tags

        retval = true
        vals.each do |val|
            unless configtags.include?(val) or resourcetags.include?(val)
                retval = false
                break
            end
        end

        return retval
end
