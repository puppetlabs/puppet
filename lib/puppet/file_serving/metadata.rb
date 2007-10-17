#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/util/checksums'

# A class that handles retrieving file metadata.
class Puppet::FileServing::Metadata
    include Puppet::Util::Checksums

    extend Puppet::Indirector
    indirects :metadata, :terminus_class => :ral

    attr_reader :path, :owner, :group, :mode, :checksum_type, :checksum

    def checksum_type=(type)
        raise(ArgumentError, "Unsupported checksum type %s" % type) unless respond_to?("%s_file" % type)

        @checksum_type = type
    end

    def initialize(path, checksum_type = "md5")
        raise ArgumentError.new("Files must be fully qualified") unless path =~ /^#{::File::SEPARATOR}/
        raise ArgumentError.new("Files must exist") unless FileTest.exists?(path)

        @path = path

        stat = File.stat(path)
        @owner = stat.uid
        @group = stat.gid

        # Set the octal mode, but as a string.
        @mode = "%o" % (stat.mode & 007777)

        @checksum_type = checksum_type
        @checksum = get_checksum
    end

    private

    # Retrieve our checksum.
    def get_checksum
        ("{%s}" % @checksum_type) + send("%s_file" % @checksum_type, @path)
    end
end
