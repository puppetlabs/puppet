require 'puppet/util/watcher'

# Monitor a given file for changes on a periodic interval. Changes are detected
# by looking for a change in the file ctime.
class Puppet::Util::WatchedFile
  # @!attribute [r] filename
  #   @return [String] The fully qualified path to the file.
  attr_reader :filename

  # @param filename [String] The fully qualified path to the file.
  # @param timer [Puppet::Util::Watcher::Timer] The polling interval for checking for file
  #   changes. Setting the timeout to a negative value will treat the file as
  #   always changed. Defaults to `Puppet[:filetimeout]`
  def initialize(filename, timer = Puppet::Util::Watcher::Timer.new(Puppet[:filetimeout]))
    @filename = filename
    @timer = timer

    @info = Puppet::Util::Watcher::PeriodicWatcher.new(
      Puppet::Util::Watcher::Common.file_ctime_change_watcher(@filename),
      timer)
  end

  # @return [true, false] If the file has changed since it was last checked.
  def changed?
    @info.changed?
  end

  # Allow this to be used as the name of the file being watched in various
  # other methods (such as Puppet::FileSystem.exist?)
  def to_str
    @filename
  end

  def to_s
    "<WatchedFile: filename = #{@filename}, timeout = #{@timer.timeout}>"
  end
end
