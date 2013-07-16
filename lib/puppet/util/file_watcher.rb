class Puppet::Util::FileWatcher
  include Enumerable

  def each(&blk)
    @files.keys.each(&blk)
  end

  def initialize
    @files = {}
  end

  def changed?
    @files.values.any?(&:changed?)
  end

  def watch(filename)
    return if watching?(filename)
    @files[filename] = Puppet::Util::WatchedFile.new(filename)
  end

  def watching?(filename)
    @files.has_key?(filename)
  end

  def clear
    @files.clear
  end
end
