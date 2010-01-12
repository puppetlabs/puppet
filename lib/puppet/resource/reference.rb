#
#  Created by Luke Kanies on 2007-11-28.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/resource'

# A simple class to canonize how we refer to and retrieve
# resources.
class Puppet::Resource::Reference
    attr_reader :type, :title
    attr_accessor :catalog

    def ==(other)
        other.respond_to?(:title) and self.type == other.type and self.title == other.title
    end

    def builtin_type?
        builtin_type ? true : false
    end

    def initialize(argtype, argtitle = nil)
        self.type,self.title = 
	    if    (argtitle || argtype) =~ /^([^\[\]]+)\[(.+)\]$/m then [ $1,                 $2            ]
	    elsif argtitle                                         then [ argtype,            argtitle      ]
	    elsif argtype.is_a?(Puppet::Type)                      then [ argtype.class.name, argtype.title ]
	    else raise ArgumentError, "No title provided and #{argtype.inspect} is not a valid resource reference"
	    end
        @builtin_type = nil
    end

    # Find our resource.
    def resolve
        return catalog.resource(to_s) if catalog
        return nil
    end

    def title=(value)
        if @type and klass = Puppet::Type.type(@type.to_s.downcase)
            value = klass.canonicalize_ref(value)
        end
        @title = value
    end

    # Canonize the type so we know it's always consistent.
    def type=(value)
        if value.nil? or value.to_s.downcase == "component"
            @type = "Class"
        else
            # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
            x = @type = value.to_s.split("::").collect { |s| s.capitalize }.join("::")
        end

        if @title
            self.title = @title
        end
    end

    # Convert to the reference format that TransObject uses.  Yay backward
    # compatibility.
    def to_trans_ref
        # We have to return different cases to provide backward compatibility
        # from 0.24.x to 0.23.x.
        if builtin_type?
            return [type.to_s.downcase, title.to_s]
        else
            return [type.to_s, title.to_s]
        end
    end

    # Convert to the standard way of referring to resources.
    def to_s
        "%s[%s]" % [@type, @title]
    end

    private

    def builtin_type
        if @builtin_type.nil?
            if @type =~ /::/
                @builtin_type = false
            elsif klass = Puppet::Type.type(@type.to_s.downcase)
                @builtin_type = true
            else
                @builtin_type = false
            end
        end
        @builtin_type
    end
end
