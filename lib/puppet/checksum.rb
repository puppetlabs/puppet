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

    attr_reader :algorithm, :content

    def algorithm=(value)
        unless respond_to?(value)
            raise ArgumentError, "Checksum algorithm %s is not supported" % value
        end
        value = value.intern if value.is_a?(String)
        @algorithm = value
        # Reset the checksum so it's forced to be recalculated.
        @checksum = nil
    end

    # Calculate (if necessary) and return the checksum
    def checksum
        unless @checksum
            @checksum = send(algorithm)
        end
        @checksum
    end

    def initialize(content, algorithm = nil)
        raise ArgumentError.new("You must specify the content") unless content

        @content = content
        self.algorithm = algorithm || "md5"

        # Init to avoid warnings.
        @checksum = nil
    end

    # This can't be private, else respond_to? returns false.
    def md5
        require 'digest/md5'
        Digest::MD5.hexdigest(content)
    end

    # This is here so the Indirector::File terminus works correctly.
    def name
        checksum
    end

    def sha1
        require 'digest/sha1'
        Digest::SHA1.hexdigest(content)
    end

    def to_s
        "Checksum<{%s}%s>" % [algorithm, checksum]
    end
end
