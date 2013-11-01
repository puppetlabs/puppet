# An abstraction over the ruby file system operations for a single file.
#
# For the time being this is being kept private so that we can evolve it for a
# while.
#
# @api private
class Puppet::FileSystem::File
  attr_reader :path

  IMPL = if RUBY_VERSION =~ /^1\.8/
           require 'puppet/file_system/file18'
           Puppet::FileSystem::File18
         else
           require 'puppet/file_system/file19'
           Puppet::FileSystem::File19
         end

  def self.new(path)
    file = IMPL.allocate
    file.send(:initialize, path)
    file
  end

  def initialize(path)
    if path.is_a?(Pathname)
      @path = path
    else
      @path = Pathname.new(path)
    end
  end

  def open(mode, options, &block)
    ::File.open(@path, options, mode, &block)
  end

  # @return [Puppet::FileSystem::File] The directory of this file
  # @api public
  def dir
    Puppet::FileSystem::File.new(@path.dirname)
  end

  # @return [Num] The size of this file
  # @api public
  def size
    @path.size
  end

  # Allows exclusive updates to a file to be made by excluding concurrent
  # access using flock. This means that if the file is on a filesystem that
  # does not support flock, this method will provide no protection.
  #
  # While polling to aquire the lock the process will wait ever increasing
  # amounts of time in order to prevent multiple processes from wasting
  # resources.
  #
  # @param mode [Integer] The mode to apply to the file if it is created
  # @param options [Integer] Extra file operation mode information to use
  # (defaults to read-only mode)
  # @param timeout [Integer] Number of seconds to wait for the lock (defaults to 300)
  # @yield The file handle, in read-write mode
  # @return [Void]
  # @raise [Timeout::Error] If the timeout is exceeded while waiting to aquire the lock
  # @api public
  def exclusive_open(mode, options = 'r', timeout = 300, &block)
    wait = 0.001 + (Kernel.rand / 1000)
    written = false
    while !written
      ::File.open(@path, options, mode) do |rf|
        if rf.flock(::File::LOCK_EX|::File::LOCK_NB)
          yield rf
          written = true
        else
          sleep wait
          timeout -= wait
          wait *= 2
          if timeout < 0
            raise Timeout::Error, "Timeout waiting for exclusive lock on #{@path}"
          end
        end
      end
    end
  end

  def each_line(&block)
    ::File.open(@path) do |f|
      f.each_line do |line|
        yield line
      end
    end
  end

  # @return [String] The contents of the file
  def read
    @path.read
  end

  # @return [String] The binary contents of the file
  def binread
    raise NotImplementedError
  end

  # Determine if a file exists by verifying that the file can be stat'd.
  # Will follow symlinks and verify that the actual target path exists.
  #
  # @return [Boolean] true if the named file exists.
  def self.exist?(path)
    File.exist?(path)
  end

  # Determine if a file exists by verifying that the file can be stat'd.
  # Will follow symlinks and verify that the actual target path exists.
  #
  # @return [Boolean] true if the path of this file is present
  def exist?
    @path.exist?
  end

  # @return [Boolean] Whether the file is writable by the current
  # process
  def writable?
    @path.writable?
  end

  # Touches the file. On most systems this updates the mtime of the file.
  def touch
    ::FileUtils.touch(@path)
  end

  # Create the entire path as directories
  def mkpath
    @path.mkpath
  end

  # Creates a symbolic link dest which points to the current file. If dest
  # already exists and it is a directory, creates a symbolic link dest/the
  # current file. If dest already exists and it is not a directory,
  # raises Errno::EEXIST. But if :force option is set, overwrite dest.
  #
  # @param dest [String] The mode to apply to the file if it is created
  # @param [Hash] options the options to create a message with.
  # @option options [Boolean] :force overwrite dest
  # @option options [Boolean] :noop do not perform the operation
  # @option options [Boolean] :verbose verbose output
  #
  # @raise [Errno::EEXIST] dest already exists and it is not a directory
  #
  # @return [Integer] 0
  def symlink(dest, options = {})
    FileUtils.symlink(@path, dest, options)
  end

  # @return [Boolean] true if the file is a symbolic link.
  def symlink?
    File.symlink?(@path)
  end

  # @return [String] the name of the file referenced by the given link.
  def readlink
    File.readlink(@path)
  end


  # @return [File::Stat] object for the named file.
  def stat
    File.stat(@path)
  end

  # @return [File::Stat] Same as stat, but does not follow the last symbolic
  # link. Instead, reports on the link itself.
  def lstat
    File.lstat(@path)
  end

  # Compare the contents of this file against the contents of a stream.
  # @param stream [IO] The stream to compare the contents against
  # @return [Boolean] Whether the contents were the same
  def compare_stream(stream)
    open(0, 'rb') do |this|
      FileUtils.compare_stream(this, stream)
    end
  end
end
