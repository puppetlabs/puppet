# An in-memory file abstraction. Commonly used with Puppet::FileSystem::File#overlay
# @api private
class Puppet::FileSystem::MemoryFile
  attr_reader :path, :children

  def self.a_missing_file(path)
    new(path, :exist? => false, :executable? => false)
  end

  def self.a_regular_file_containing(path, content)
    new(path, :exist? => true, :executable? => false, :content => content)
  end

  def self.an_executable(path)
    new(path, :exist? => true, :executable? => true)
  end

  def self.a_directory(path, children = [])
    new(path,
        :exist? => true,
        :excutable? => true,
        :directory? => true,
        :children => children)
  end

  def initialize(path, properties)
    @path = path
    @properties = properties
    @children = (properties[:children] || []).collect do |child|
      child.duplicate_as(File.join(@path, child.path))
    end
  end

  def directory?; @properties[:directory?]; end
  def exist?; @properties[:exist?]; end
  def executable?; @properties[:executable?]; end

  def each_line(&block)
    handle.each_line(&block)
  end

  def handle
    raise Errno::ENOENT unless exist?
    StringIO.new(@properties[:content] || '')
  end

  def duplicate_as(other_path)
    self.class.new(other_path, @properties)
  end

  def absolute?
    Pathname.new(path).absolute?
  end

  def to_path
    path
  end

  def to_s
    to_path
  end

  def inspect
    "<Puppet::FileSystem::MemoryFile:#{to_s}>"
  end
end
