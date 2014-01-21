class Puppet::FileSystem::MemoryImpl
  def initialize(*files)
    @files = files
  end

  def exist?(path)
    path.exist?
  end

  def directory?(path)
    path.directory?
  end

  def executable?(path)
    path.executable?
  end

  def children(path)
    path.children
  end

  def each_line(path, &block)
    path.each_line(&block)
  end

  def pathname(path)
    find(path)
  end

  def basename(path)
    path.duplicate_as(path_string(path).split(File::PATH_SEPARATOR).last)
  end

  def path_string(object)
    object.path
  end

  def assert_path(path)
    path
  end

  private

  def find(path)
    @files.find { |file| file.path == path }
  end
end
