module RGen

module Util

# WARNING: the mechanism of taking timestamps of directories in order to find out if the
# content has changed doesn't work reliably across all kinds of filesystems
#
class CachedGlob

  def initialize(dir_glob, file_glob)
    @dir_glob = dir_glob
    @file_glob = file_glob
    @root_dirs = []
    @dirs = {}
    @files = {}
    @timestamps = {}
  end

  # returns all files contained in directories matched by +dir_glob+ which match +file_glob+.
  # +file_glob+ must be relative to +dir_glob+.
  # dir_glob "*/a" with file_glob "**/*.txt" is basically equivalent with Dir.glob("*/a/**/*.txt")
  # the idea is that the file glob will only be re-eavluated when the content of one of the 
  # directories matched by dir_glob has changed.
  # this will only be faster than a normal Dir.glob if the number of dirs matched by dir_glob is
  # relatively large and changes in files affect only a few of them at a time.
  def glob
    root_dirs = Dir.glob(@dir_glob)
    (@root_dirs - root_dirs).each do |d|
      remove_root_dir(d)
    end
    (@root_dirs & root_dirs).each do |d|
      update_root_dir(d) if dir_changed?(d)
    end
    (root_dirs - @root_dirs).each do |d|
      update_root_dir(d)
    end
    @root_dirs = root_dirs
    @root_dirs.sort.collect{|d| @files[d]}.flatten
  end

  private

  def dir_changed?(dir)
    @dirs[dir].any?{|d| File.mtime(d) != @timestamps[dir][d]}
  end

  def update_root_dir(dir)
    @dirs[dir] = Dir.glob(dir+"/**/")
    @files[dir] = Dir.glob(dir+"/"+@file_glob)
    @timestamps[dir] = {}
    @dirs[dir].each do |d|
      @timestamps[dir][d] = File.mtime(d)
    end
  end

  def remove_root_dir(dir)
    @dirs.delete(dir)
    @files.delete(dir)
    @timestamps.delete(dir)
  end

end

end

end

