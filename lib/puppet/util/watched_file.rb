module Puppet
module Util

# Monitor a given file for changes on a periodic interval. Changes are detected
# by looking for a change in the file ctime.
class WatchedFile
  require 'puppet/util/watched_file/timer'

  # @!attribute [r] filename
  #   @return [String] The fully qualified path to the file.
  attr_reader :filename

  # @!attribute [rw] file_timeout
  #   @return [Integer] The file timeout for considering the last ctime as expired
  attr_accessor :file_timeout

  # @!attribute [w] ctime
  #   @api private
  #   This must only be used for testing purposes.
  attr_writer :ctime

  # Create a new WatchedFile instance.
  #
  # @param filename [String] The fully qualified path to the file.
  # @param file_timeout [Integer] The polling interval for checking for file
  #   changes. Setting the timeout to a negative value will treat the file as
  #   always changed. Defaults to `Puppet[:filetimeout]`
  # @param timer [Object] An object that responds to `#start(Numeric)` and
  #   `#expired?`. Defaults to Puppet::Util::WatchedFile::Timer
  def initialize(filename, file_timeout = Puppet[:filetimeout], timer = Puppet::Util::WatchedFile::Timer.new)
    @filename     = filename
    @file_timeout = file_timeout
    @timer        = timer

    @ctime   = file_ctime

    @timer.start(@file_timeout)
  end

  # @return [true, false] If the file has changed since it was last checked.
  def changed?
    # Allow the timeout to be disabled entirely.
    return true if @file_timeout < 0

    if !@timer.expired?
      # The file has been checked recently so we aren't going to recheck it.
      false
    else
      @timer.start(@file_timeout)

      last    = @ctime
      current = file_ctime
      @ctime  = current

      !(last == current)
    end
  end

  def to_str
    @filename
  end
  alias_method :to_s, :to_str

  private

  def file_ctime
    File.stat(@filename).ctime
  rescue Errno::ENOENT, Errno::ENOTDIR
    :absent
  end
end
end
end
