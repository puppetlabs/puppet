# An abstraction over the ruby file system operations for a single file.
#
# For the time being this is being kept private so that we can evolve it for a
# while.
#
# @api private
class Puppet::FileSystem::File

  # create instance of the file system implementation to use for the current platform
  @impl = if RUBY_VERSION =~ /^1\.8/
           require 'puppet/file_system/file18'
           Puppet::FileSystem::File18
         elsif Puppet::Util::Platform.windows?
           require 'puppet/file_system/file19windows'
           Puppet::FileSystem::File19Windows
         else
           require 'puppet/file_system/file19'
           Puppet::FileSystem::File19
         end.new()

  # Overrides the automatic file system implementation selection that is based on the current platform
  # Should only be used for testing.
  # @return [Object] the previous file system implementation (to allow it to be restored)
  #
  # @api private
  #
  def self.set_file_system_implementation(impl)
    tmp = @impl
    @impl = impl
    tmp
  end

  # Opens the given path with given mode, and options and optionally yields it to the given block.
  #
  # @api public
  #
  def self.open(path, mode, options, &block)
    @impl.open(assert_path(path), options, mode, &block)
  end

  # @return [Pathname] The directory of this file
  #
  # @api public
  #
  def dir(path)
    @impl.dir(assert_path(path))
  end

  # @return [String] the name of the file
  #
  # @api public
  #
  def self.basename(path)
    @impl.basename(assert_path(path.basename))
  end

  # @return [Integer] the size of the file
  #
  # @api public
  #
  def self.basename(path)
    @impl.size(assert_path(path.basename))
  end

  # Allows exclusive updates to a file to be made by excluding concurrent
  # access using flock. This means that if the file is on a filesystem that
  # does not support flock, this method will provide no protection.
  #
  # While polling to aquire the lock the process will wait ever increasing
  # amounts of time in order to prevent multiple processes from wasting
  # resources.
  #
  # @param path [Pathname] the path to the file to operate on
  # @param mode [Integer] The mode to apply to the file if it is created
  # @param options [Integer] Extra file operation mode information to use
  #   (defaults to read-only mode)
  # @param timeout [Integer] Number of seconds to wait for the lock (defaults to 300)
  # @yield The file handle, in read-write mode
  # @return [Void]
  # @raise [Timeout::Error] If the timeout is exceeded while waiting to acquire the lock
  #
  # @api public
  #
  def self.exclusive_open(path, mode, options = 'r', timeout = 300, &block)
    @impl.exclusive_open(assert_path(path), mode, options, timeout, &block)
  end

  # Processes each line of the file by yielding it to the given block
  #
  # @api public
  #
  def self.each_line(path, &block)
    @impl.each_line(assert_path(path), &block)
  end

  # @return [String] The contents of the file
  #
  # @api public
  #
  def self.read(path)
    path.read
  end

  # @return [String] The binary contents of the file
  #
  # @api public
  #
  def binread(path)
    @impl.binread(assert_path(path))
  end

  # Determines if a file exists by verifying that the file can be stat'd.
  # Will follow symlinks and verify that the actual target path exists.
  #
  # @return [Boolean] true if the named file exists.
  #
  # @api public
  #
  def self.exist?(path)
    @impl.exist?(assert_path(path))
  end

  # Determines if a file is executable.
  #
  # @todo Should this take into account extensions on the windows platform?
  #
  # @return [Boolean] true if this file can be executed
  #
  # @api public
  #
  def self.executable?(path)
    @impl.executable?(assert_path(path))
  end

  # @return [Boolean] Whether the file is writable by the current process
  #
  # @api public
  #
  def self.writable?(path)
    @impl.writeable?(assert_path(path))
  end

  # Touches the file. On most systems this updates the mtime of the file.
  #
  # @api public
  #
  def self.touch(path)
    @impl.touch(assert_path(path))
  end

  # Creates directories for all parts of the given path.
  #
  # @api public
  #
  def self.mkpath(path)
    @impl.mkpath(assert_path(path))
  end

  # Creates a symbolic link dest which points to the current file.
  # If dest already exists:
  #
  # * and is a file, will raise Errno::EEXIST
  # * and is a directory, will return 0 but perform no action
  # * and is a symlink referencing a file, will raise Errno::EEXIST
  # * and is a symlink referencing a directory, will return 0 but perform no action
  #
  # With the :force option set to true, when dest already exists:
  #
  # * and is a file, will replace the existing file with a symlink (DANGEROUS)
  # * and is a directory, will return 0 but perform no action
  # * and is a symlink referencing a file, will modify the existing symlink
  # * and is a symlink referencing a directory, will return 0 but perform no action
  #
  # @param dest [String] The path to create the new symlink at
  # @param [Hash] options the options to create the symlink with
  # @option options [Boolean] :force overwrite dest
  # @option options [Boolean] :noop do not perform the operation
  # @option options [Boolean] :verbose verbose output
  #
  # @raise [Errno::EEXIST] dest already exists as a file and, :force is not set
  #
  # @return [Integer] 0
  #
  # @api public
  #
  def self.symlink(path, dest, options = {})
    @impl.symlink(assert_path(path), dest, options)
  end

  # @return [Boolean] true if the file is a symbolic link.
  # 
  # @api public
  #
  def self.symlink?(path)
    @impl.symlink?(assert_path(path))
  end

  # @return [String] the name of the file referenced by the given link.
  #
  # @api public
  #
  def self.readlink(path)
    @impl.readlink(assert_path(path))
  end

  # Deletes the given paths, returning the number of names passed as arguments.
  # See also Dir::rmdir.
  #
  # @raise an exception on any error.
  #
  # @return [Integer] the number of paths passed as arguments
  #
  # @api public
  #
  def self.unlink(*paths)
    paths.each {|p| assert_path(p) }
    @impl.unlink(*paths)
  end

  # @return [File::Stat] object for the named file.
  #
  # @api public
  #
  def stat(path)
    @impl.stat(assert_path(path))
  end

  # @return [File::Stat] Same as stat, but does not follow the last symbolic
  # link. Instead, reports on the link itself.
  #
  # @api public
  #
  def lstat(path)
    @impl.lstat(assert_path(path))
  end

  # Compares the contents of this file against the contents of a stream.
  #
  # @param stream [IO] The stream to compare the contents against
  # @return [Boolean] Whether the contents were the same
  #
  # @api public
  #
  def compare_stream(path, stream)
    @impl.compare_stream(assert_path(path), stream)
  end

  # Produces an opaque pathname "handle" object representing the given path.
  # Different implementations of the underlying file system may use different runtime
  # objects. The produced "handle" should be used in all other operations
  # that take a "path". No operation should be directly invoked on the returned opaque object
  #
  # @return [Object] An opaque path handle on which no operations should be directly performed
  #
  # @api public
  #
  def self.pathname(path)
    @impl.pathname(path)
  end

  # Asserts that the given path is of the expected type produced by #pathname
  #
  # @raise [ArgumentError] when path is not of the expected type
  #
  # @api public
  #
  def self.assert_path(path)
    @impl.assert_path(path)
  end

  # Produces a string representation of the opaque path handle.
  #
  # @return [String] a string representation of the path
  #
  def self.path_string(path)
    @impl.path_string(path)
  end

end
