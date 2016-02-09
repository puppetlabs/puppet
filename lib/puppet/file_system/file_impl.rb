# Abstract implementation of the Puppet::FileSystem
#
class Puppet::FileSystem::FileImpl

  def pathname(path)
    path.is_a?(Pathname) ? path : Pathname.new(path)
  end

  def assert_path(path)
    return path if path.is_a?(Pathname)

    # Some paths are string, or in the case of WatchedFile, it pretends to be
    # one by implementing to_str.
    if path.respond_to?(:to_str)
      Pathname.new(path)
    else
      raise ArgumentError, "FileSystem implementation expected Pathname, got: '#{path.class}'"
    end
  end

  def path_string(path)
    path.to_s
  end

  def open(path, mode, options, &block)
    ::File.open(path, options, mode, &block)
  end

  def dir(path)
    path.dirname
  end

  def basename(path)
    path.basename.to_s
  end

  def size(path)
    path.size
  end

  def exclusive_create(path, mode, &block)
    opt = File::CREAT | File::EXCL | File::WRONLY
    self.open(path, mode, opt, &block)
  end

  def exclusive_open(path, mode, options = 'r', timeout = 300, &block)
    wait = 0.001 + (Kernel.rand / 1000)
    written = false
    while !written
      ::File.open(path, options, mode) do |rf|
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

  def each_line(path, &block)
    ::File.open(path) do |f|
      f.each_line do |line|
        yield line
      end
    end
  end

  def read(path, opts = {})
    path.read(opts)
  end

  def read_preserve_line_endings(path)
    read(path)
  end

  def binread(path)
    raise NotImplementedError
  end

  def exist?(path)
    ::File.exist?(path)
  end

  def directory?(path)
    ::File.directory?(path)
  end

  def file?(path)
    ::File.file?(path)
  end

  def executable?(path)
    ::File.executable?(path)
  end

  def writable?(path)
    path.writable?
  end

  def touch(path)
    ::FileUtils.touch(path)
  end

  def mkpath(path)
    path.mkpath
  end

  def children(path)
    path.children
  end

  def symlink(path, dest, options = {})
    FileUtils.symlink(path, dest, options)
  end

  def symlink?(path)
    File.symlink?(path)
  end

  def readlink(path)
    File.readlink(path)
  end

  def unlink(*paths)
    File.unlink(*paths)
  end

  def stat(path)
    File.stat(path)
  end

  def lstat(path)
    File.lstat(path)
  end

  def compare_stream(path, stream)
    open(path, 0, 'rb') { |this| FileUtils.compare_stream(this, stream) }
  end

  def chmod(mode, path)
    FileUtils.chmod(mode, path)
  end
end
