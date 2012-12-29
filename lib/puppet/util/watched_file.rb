# A simple class that tells us when a file has changed and thus whether we
# should reload it

require 'puppet'

module Puppet
  class NoSuchFile < Puppet::Error; end
  class Util::WatchedFile
    attr_reader :filename, :statted

    # Provide a hook for setting the timestamp during testing, so we don't
    # have to depend on the granularity of the filesystem.
    attr_writer :previous_timestamp

    # Create the file.  Must be passed the file path.
    def initialize(filename)
      @filename = filename
      @last_stat = 0
      @current_timestamp = nil
      @previous_timestamp = current_timestamp
    end

    # Determine whether the file has changed and thus whether it should
    # be reparsed.
    def changed?
      # Allow the timeout to be disabled entirely.
      return true if Puppet[:filetimeout] < 0
      current_stamp = current_timestamp

      # We use a different internal variable than the stamp method
      # because it doesn't keep historical state and we do -- that is,
      # we will always be comparing two timestamps, whereas
      # stamp just always wants the latest one.
      if current_stamp == @previous_timestamp
        false
      else
        @previous_timestamp = current_stamp
        true
      end
    end

    def to_str
      @filename
    end
    alias_method :to_s, :to_str

    private

    # Retrieve the filestamp, but only refresh it if we're beyond our
    # filetimeout
    def current_timestamp
      if @current_timestamp.nil? or (Time.now.to_i - @last_stat >= Puppet[:filetimeout])
        @last_stat = Time.now.to_i
        begin
          @current_timestamp = File.stat(@filename).ctime
        rescue Errno::ENOENT, Errno::ENOTDIR
          @current_timestamp = Time.now
        end
      end
      @current_timestamp
    end
  end
end

