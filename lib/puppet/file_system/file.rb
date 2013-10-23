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
  # @param mode [Integer] The mode to apply to the file if it is created
  # @param options [Integer] Extra file operation mode information to use
  # (defaults to read-only mode)
  # @yield The file handle, in read-write mode
  # @return [Void]
  # @api public
  def exclusive_open(mode, options = 'r', &block)
    written = false
    while !written
      ::File.open(@path, options, mode) do |rf|
        if rf.flock(::File::LOCK_EX|::File::LOCK_NB)
          yield rf
          written = true
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

  # @return [Boolean] Whether the path of this file is present
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

  # Compare the contents of this file against the contents of a stream.
  # @param stream [IO] The stream to compare the contents against
  # @return [Boolean] Whether the contents were the same
  def compare_stream(stream)
    open(0, 'rb') do |this|
      FileUtils.compare_stream(this, stream)
    end
  end
end
