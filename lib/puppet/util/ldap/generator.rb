#
#  Created by Luke Kanies on 2008-3-28.
#  Copyright (c) 2008. All rights reserved.
require 'puppet/util/ldap'

class Puppet::Util::Ldap::Generator
    # Declare the attribute we'll use to generate the value.
    def from(source)
        @source = source
        return self
    end

    # Actually do the generation.
    def generate(value = nil)
        if value.nil?
            @generator.call
        else
            @generator.call(value)
        end
    end

    # Initialize our generator with the name of the parameter
    # being generated.
    def initialize(name)
        @name = name
    end

    def name
        @name.to_s
    end

    def source
        if defined?(@source) and @source
            @source.to_s
        else
            nil
        end
    end

    # Provide the code that does the generation.
    def with(&block)
        @generator = block
        return self
    end
end
