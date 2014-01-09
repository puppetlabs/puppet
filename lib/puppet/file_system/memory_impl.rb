class Puppet::FileSystem::MemoryImpl
  def initialize(*files)
    @files = files
  end

  def exist?(path)
    find(path).exist?
  end

  def executable?(path)
    find(path).executable?
  end

  def each_line(path, &block)
    find(path).each_line(&block)
  end

  def pathname(path)
    path.to_s
  end

  def assert_path(path)
    path
  end

  private

  def find(path)
    @files.find { |file| file.path == path }
  end
end
