#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/file_base'
require 'puppet/util/checksums'
require 'puppet/file_serving/terminus_selector'

# A class that handles retrieving file metadata.
class Puppet::FileServing::Metadata < Puppet::FileServing::FileBase
    include Puppet::Util::Checksums

    extend Puppet::Indirector
    indirects :file_metadata, :extend => Puppet::FileServing::TerminusSelector

    attr_reader :path, :owner, :group, :mode, :checksum_type, :checksum, :ftype, :destination

    def checksum_type=(type)
        raise(ArgumentError, "Unsupported checksum type %s" % type) unless respond_to?("%s_file" % type)

        @checksum_type = type
    end

    # Retrieve the attributes for this file, relative to a base directory.
    # Note that File.stat raises Errno::ENOENT if the file is absent and this
    # method does not catch that exception.
    def collect_attributes(base = nil)
        real_path = full_path(base)
        stat = stat(base)
        @owner = stat.uid
        @group = stat.gid
        @ftype = stat.ftype


        # Set the octal mode, but as a string.
        @mode = "%o" % (stat.mode & 007777)

        if stat.ftype == "symlink"
            @destination = File.readlink(real_path)
        else
            @checksum = get_checksum(real_path)
        end
    end

    def initialize(*args)
        @checksum_type = "md5"
        super
    end

    private

    # Retrieve our checksum.
    def get_checksum(path)
        ("{%s}" % @checksum_type) + send("%s_file" % @checksum_type, path)
    end
end
