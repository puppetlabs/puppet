#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/indirector'

# A checksum class to model translating checksums to file paths.  This
# is the new filebucket.
class Puppet::Checksum
    extend Puppet::Indirector

    indirects :checksum

    attr_accessor :name, :content
    attr_reader :algorithm

    def algorithm=(value)
        value = value.intern if value.respond_to?(:intern)
        @algorithm = value
    end

    def initialize(name)
        raise ArgumentError.new("You must specify the checksum") unless name

        if name =~ /^\{(\w+)\}(.+$)$/
            @algorithm, @name = $1.intern, $2
        else
            @name = name
            @algorithm = :md5
        end
    end

    def to_s
        "Checksum<{%s}%s>" % [algorithm, name]
    end
end
