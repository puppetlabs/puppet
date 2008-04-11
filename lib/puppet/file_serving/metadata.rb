#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/file_base'
require 'puppet/util/checksums'
require 'puppet/file_serving/indirection_hooks'

# A class that handles retrieving file metadata.
class Puppet::FileServing::Metadata < Puppet::FileServing::FileBase

    include Puppet::Util::Checksums

    extend Puppet::Indirector
    indirects :file_metadata, :extend => Puppet::FileServing::IndirectionHooks

    attr_reader :path, :owner, :group, :mode, :checksum_type, :checksum, :ftype, :destination

    PARAM_ORDER = [:mode, :ftype, :owner, :group]

    def attributes_with_tabs
        desc = []
        PARAM_ORDER.each { |check|
            check = :ftype if check == :type
            desc << send(check)
        }

        case ftype
        when "file", "directory": desc << checksum
        when "link": desc << @destination
        else
            raise ArgumentError, "Cannot manage files of type %s" % ftype
        end

        return desc.join("\t")
    end

    def checksum_type=(type)
        raise(ArgumentError, "Unsupported checksum type %s" % type) unless respond_to?("%s_file" % type)

        @checksum_type = type
    end

    # Retrieve the attributes for this file, relative to a base directory.
    # Note that File.stat raises Errno::ENOENT if the file is absent and this
    # method does not catch that exception.
    def collect_attributes
        real_path = full_path()
        stat = stat()
        @owner = stat.uid
        @group = stat.gid
        @ftype = stat.ftype


        # We have to mask the mode, yay.
        @mode = stat.mode & 007777

        case stat.ftype
        when "file":
            @checksum = ("{%s}" % @checksum_type) + send("%s_file" % @checksum_type, real_path)
        when "directory": # Always just timestamp the directory.
            sumtype = @checksum_type.to_s =~ /time/ ? @checksum_type : "ctime"
            @checksum = ("{%s}" % sumtype) + send("%s_file" % sumtype, path).to_s
        when "link":
            @destination = File.readlink(real_path)
        else
            raise ArgumentError, "Cannot manage files of type %s" % stat.ftype
        end
    end

    def initialize(*args)
        @checksum_type = "md5"
        super
    end
end
