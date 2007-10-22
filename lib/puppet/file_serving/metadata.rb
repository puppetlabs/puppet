#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/util/checksums'
require 'puppet/file_serving/terminus_selector'

# A class that handles retrieving file metadata.
class Puppet::FileServing::Metadata
    include Puppet::Util::Checksums

    extend Puppet::Indirector
    indirects :file_metadata, :extend => Puppet::FileServing::TerminusSelector

    attr_reader :path, :owner, :group, :mode, :checksum_type, :checksum

    def checksum_type=(type)
        raise(ArgumentError, "Unsupported checksum type %s" % type) unless respond_to?("%s_file" % type)

        @checksum_type = type
    end

    def get_attributes
        stat = File.stat(path)
        @owner = stat.uid
        @group = stat.gid

        # Set the octal mode, but as a string.
        @mode = "%o" % (stat.mode & 007777)

        @checksum = get_checksum
    end

    def initialize(path = nil)
        if path
            raise ArgumentError.new("Files must be fully qualified") unless path =~ /^#{::File::SEPARATOR}/
            raise ArgumentError.new("Files must exist") unless FileTest.exists?(path)

            @path = path
        end

        @checksum_type = "md5"
    end

    private

    # Retrieve our checksum.
    def get_checksum
        ("{%s}" % @checksum_type) + send("%s_file" % @checksum_type, @path)
    end
end
