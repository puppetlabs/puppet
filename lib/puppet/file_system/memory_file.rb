# An in-memory file abstraction. Commonly used with Puppet::FileSystem::File#overlay
# @api private
class Puppet::FileSystem::MemoryFile
  attr_reader :path

  def self.a_missing_file(path)
    new(path, :exist? => false, :executable? => false)
  end

  def self.a_regular_file_containing(path, content)
    new(path, :exist? => true, :executable? => false, :content => content)
  end

  def self.an_executable(path)
    new(path, :exist? => true, :executable? => true)
  end

  def initialize(path, options)
    @path = Pathname.new(path)
    @exist = options[:exist?]
    @executable = options[:executable?]
    @content = options[:content]
  end

  def exist?; @exist; end
  def executable?; @executable; end

  def each_line(&block)
    StringIO.new(@content).each_line(&block)
  end
end
