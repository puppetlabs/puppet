class Puppet::FileSystem::MemoryImpl
  def initialize(*files)
    @files = files + all_children_of(files)
  end

  def expand_path(path, dir_string = nil)
    File.expand_path(path, dir_string)
  end

  def exist?(path)
    path.exist?
  end

  def directory?(path)
    path.directory?
  end

  def file?(path)
    path.file?
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
    find(path) || Puppet::FileSystem::MemoryFile.a_missing_file(path)
  end

  def basename(path)
    path.duplicate_as(File.basename(path_string(path)))
  end

  def path_string(object)
    object.path
  end

  def read(path, opts = {})
    handle = assert_path(path).handle
    handle.read
  end

  def read_preserve_line_endings(path)
    read(path)
  end

  def open(path, *args, &block)
    handle = assert_path(path).handle
    if block_given?
      yield handle
    else
      return handle
    end
  end

  def assert_path(path)
    if path.is_a?(Puppet::FileSystem::MemoryFile)
      path
    else
      find(path) or raise ArgumentError, _("Unable to find registered object for %{path}") % { path: path.inspect }
    end
  end

  private

  def find(path)
    @files.find { |file| file.path == path }
  end

  def all_children_of(files)
    children = files.collect(&:children).flatten
    if children.empty?
      []
    else
      children + all_children_of(children)
    end
  end
end
