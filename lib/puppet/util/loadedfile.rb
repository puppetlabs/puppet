# A simple class that tells us when a file has changed and thus whether we
# should reload it

require 'puppet'
require 'puppet/util/manifest_filetype_helper'

module Puppet
  class NoSuchFile < Puppet::Error; end
  class Util::LoadedFile
    attr_reader :file, :statted

    # Provide a hook for setting the timestamp during testing, so we don't
    # have to depend on the granularity of the filesystem.
    attr_writer :tstamp

    # Determine whether the file has changed (or considered to always be "changed") and thus whether it should
    # be reparsed.
    #
    def changed?
      # Allow the timeout to be disabled entirely.
      # Always trigger reparse of ruby files
      return true if Puppet[:filetimeout] < 0 || @always_stale
      tmp = stamp

      # We use a different internal variable than the stamp method
      # because it doesn't keep historical state and we do -- that is,
      # we will always be comparing two timestamps, whereas
      # stamp just always wants the latest one.
      if tmp == @tstamp
        return false
      else
        @tstamp = tmp
        return @tstamp
      end
    end

    # Create the file.  Must be passed the file path.
    # @param file [String] the path to watch
    # @param always_stale [Boolean] whether the file should be considered to always be changed
    # 
    def initialize(file, always_stale = false)
      @file = file
      @statted = 0
      @stamp = nil
      @tstamp = stamp
      @always_stale = always_stale
    end

    # Retrieve the filestamp, but only refresh it if we're beyond our
    # filetimeout
    def stamp
      if @stamp.nil? or (Time.now.to_i - @statted >= Puppet[:filetimeout])
        @statted = Time.now.to_i
        begin
          @stamp = File.stat(@file).ctime
        rescue Errno::ENOENT, Errno::ENOTDIR
          @stamp = Time.now
        end
      end
      @stamp
    end

    def to_s
      @file
    end
  end
end

