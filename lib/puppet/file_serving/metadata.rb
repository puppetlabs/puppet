#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/base'
require 'puppet/util/checksums'
require 'puppet/file_serving/indirection_hooks'

# A class that handles retrieving file metadata.
class Puppet::FileServing::Metadata < Puppet::FileServing::Base

    include Puppet::Util::Checksums

    extend Puppet::Indirector
    indirects :file_metadata, :extend => Puppet::FileServing::IndirectionHooks

    attr_reader :path, :owner, :group, :mode, :checksum_type, :checksum, :ftype, :destination

    PARAM_ORDER = [:mode, :ftype, :owner, :group]

    def attributes_with_tabs
        raise(ArgumentError, "Cannot manage files of type #{ftype}") unless ['file','directory','link'].include? ftype
        desc = []
        PARAM_ORDER.each { |check|
            check = :ftype if check == :type
            desc << send(check)
        }

        desc << checksum
        desc << @destination rescue nil if ftype == 'link'

        return desc.join("\t")
    end

    def checksum_type=(type)
        raise(ArgumentError, "Unsupported checksum type %s" % type) unless respond_to?("%s_file" % type)

        @checksum_type = type
    end

    # Retrieve the attributes for this file, relative to a base directory.
    # Note that File.stat raises Errno::ENOENT if the file is absent and this
    # method does not catch that exception.
    def collect
        real_path = full_path()
        stat = stat()
        @owner = stat.uid
        @group = stat.gid
        @ftype = stat.ftype


        # We have to mask the mode, yay.
        @mode = stat.mode & 007777

        case stat.ftype
        when "file"
            @checksum = ("{%s}" % @checksum_type) + send("%s_file" % @checksum_type, real_path).to_s
        when "directory" # Always just timestamp the directory.
            @checksum_type = "ctime"
            @checksum = ("{%s}" % @checksum_type) + send("%s_file" % @checksum_type, path).to_s
        when "link"
            @destination = File.readlink(real_path)
            @checksum = ("{%s}" % @checksum_type) + send("%s_file" % @checksum_type, real_path).to_s rescue nil
        else
            raise ArgumentError, "Cannot manage files of type %s" % stat.ftype
        end
    end

    def initialize(path,data={})
        @owner       = data.delete('owner')
        @group       = data.delete('group')
        @mode        = data.delete('mode')
        if checksum = data.delete('checksum')
            @checksum_type = checksum['type']
            @checksum      = checksum['value']
        end
        @checksum_type ||= "md5"
        @ftype       = data.delete('type')
        @destination = data.delete('destination')
        super(path,data)
    end

    PSON.register_document_type('FileMetadata',self)
    def to_pson_data_hash
        {
            'document_type' => 'FileMetadata',
            'data'       => super['data'].update({
                'owner'        => owner,
                'group'        => group,
                'mode'         => mode,
                'checksum'     => {
                    'type'   => checksum_type,
                    'value'  => checksum
                },
                'type'         => ftype,
                'destination'  => destination,
                }),
            'metadata' => {
                'api_version' => 1
                }
       }
    end

    def to_pson(*args)
       to_pson_data_hash.to_pson(*args)
    end

    def self.from_pson(data)
       new(data.delete('path'), data)
    end

end
