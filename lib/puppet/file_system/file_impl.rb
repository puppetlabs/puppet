# frozen_string_literal: true

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
      raise ArgumentError, _("FileSystem implementation expected Pathname, got: '%{klass}'") % { klass: path.class }
    end
  end

  def path_string(path)
    path.to_s
  end

  def expand_path(path, dir_string = nil)
    # ensure `nil` values behave like underlying File.expand_path
    ::File.expand_path(path.nil? ? nil : path_string(path), dir_string)
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
    until written
      ::File.open(path, options, mode) do |rf|
        if rf.flock(::File::LOCK_EX | ::File::LOCK_NB)
          Puppet.debug { _("Locked '%{path}'") % { path: path } }
          yield rf
          written = true
          Puppet.debug { _("Unlocked '%{path}'") % { path: path } }
        else
          Puppet.debug { "Failed to lock '%s' retrying in %.2f milliseconds" % [path, wait * 1000] }
          sleep wait
          timeout -= wait
          wait *= 2
          if timeout < 0
            raise Timeout::Error, _("Timeout waiting for exclusive lock on %{path}") % { path: path }
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
    path.read(**opts)
  end

  def read_preserve_line_endings(path)
    default_encoding = Encoding.default_external.name
    encoding = default_encoding.downcase.start_with?('utf-') ? "bom|#{default_encoding}" : default_encoding
    read(path, encoding: encoding)
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

  def touch(path, mtime: nil)
    ::FileUtils.touch(path, mtime: mtime)
  end

  def mkpath(path)
    path.mkpath
  end

  def children(path)
    path.children
  end

  def symlink(path, dest, options = {})
    FileUtils.symlink(path, dest, **options)
  end

  def symlink?(path)
    ::File.symlink?(path)
  end

  def readlink(path)
    ::File.readlink(path)
  end

  def unlink(*paths)
    ::File.unlink(*paths)
  end

  def stat(path)
    ::File.stat(path)
  end

  def lstat(path)
    ::File.lstat(path)
  end

  def compare_stream(path, stream)
    ::File.open(path, 0, 'rb') { |this| FileUtils.compare_stream(this, stream) }
  end

  def chmod(mode, path)
    FileUtils.chmod(mode, path)
  end

  def replace_file(path, mode = nil)
    begin
      stat = lstat(path)
      gid = stat.gid
      uid = stat.uid
      mode ||= stat.mode & 07777
    rescue Errno::ENOENT
      mode ||= 0640
    end

    tempfile = Puppet::FileSystem::Uniquefile.new(Puppet::FileSystem.basename_string(path), Puppet::FileSystem.dir_string(path))
    begin
      begin
        yield tempfile
        tempfile.flush
        tempfile.fsync
      ensure
        tempfile.close
      end

      tempfile_path = tempfile.path
      FileUtils.chown(uid, gid, tempfile_path) if uid && gid
      chmod(mode, tempfile_path)
      ::File.rename(tempfile_path, path_string(path))
    ensure
      tempfile.close!
    end
  end
end
