class Puppet::FileSystem::File
  attr_reader :path

  def initialize(path)
    @path = Pathname.new(path)
  end

  def open(mode, options, &block)
    ::File.open(@path, options, mode, &block)
  end

  def dir
    @path.dirname
  end

  def size
    @path.size
  end

  # Allows exclusive updates to a file to be made by excluding concurrent
  # access using flock. This means that if the file is on a filesystem that
  # does not support flock, this method will provide no protection.
  #
  # @param mode [Integer] The mode to apply to the file if it is created
  # @param options [Integer] Extra file operation mode information to use
  # (defaults to create and read-write mode)
  # @yield The file handle, in read-write mode
  # @return [Void]
  # @api public
  def exclusive_open(mode, options = ::File::CREAT|::File::RDWR, &block)
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
    @path.binread
  end

  # @return [Boolean] Whether the path of this file is present
  def exist?
    @path.exist?
  end

  def touch
    ::FileUtils.touch(@path)
  end
end
