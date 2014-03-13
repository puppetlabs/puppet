require 'digest/md5'
require 'puppet/network/format_support'

module Puppet::ModuleTool

  # = Checksums
  #
  # This class proides methods for generating checksums for data and adding
  # them to +Metadata+.
  class Checksums
    include Puppet::Network::FormatSupport
    include Enumerable

    # Instantiate object with string +path+ to create checksums from.
    def initialize(path)
      @path = Pathname.new(path)
    end

    # Return checksum for the +Pathname+.
    def checksum(pathname)
      return Digest::MD5.hexdigest(Puppet::FileSystem.binread(pathname))
    end

    # Return checksums for object's +Pathname+, generate if it's needed.
    # Result is a hash of path strings to checksum strings.
    def data
      unless @data
        @data = {}
        @path.find do |descendant|
          if Puppet::ModuleTool.artifact?(descendant)
            Find.prune
          elsif descendant.file?
            path = descendant.relative_path_from(@path)
            @data[path.to_s] = checksum(descendant)
          end
        end
      end
      return @data
    end

    alias :to_data_hash :data
    alias :to_hash :data

    # TODO: Why?
    def each(&block)
      data.each(&block)
    end
  end
end
