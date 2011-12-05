require 'digest/md5'

module Puppet::Module::Tool

  # = Checksums
  #
  # This class proides methods for generating checksums for data and adding
  # them to +Metadata+.
  class Checksums
    include Enumerable

    # Instantiate object with string +path+ to create checksums from.
    def initialize(path)
      @path = Pathname.new(path)
    end

    # Return checksum for the +Pathname+.
    def checksum(pathname)
      return Digest::MD5.hexdigest(pathname.read)
    end

    # Return checksums for object's +Pathname+, generate if it's needed.
    # Result is a hash of path strings to checksum strings.
    def data
      unless @data
        @data = {}
        @path.find do |descendant|
          if Puppet::Module::Tool.artifact?(descendant)
            Find.prune
          elsif descendant.file?
            path = descendant.relative_path_from(@path)
            @data[path.to_s] = checksum(descendant)
          end
        end
      end
      return @data
    end

    # TODO: Why?
    def each(&block)
      data.each(&block)
    end

    # Update +Metadata+'s checksums with this object's.
    def annotate(metadata)
      metadata.checksums.replace(data)
    end

    # TODO: Move the Checksummer#run checksum checking to here?

  end
end
