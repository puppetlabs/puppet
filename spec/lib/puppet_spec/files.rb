require 'fileutils'
require 'tempfile'
require 'tmpdir'
require 'pathname'

# A support module for testing files.
module PuppetSpec::Files
  def self.cleanup
    $global_tempfiles ||= []
    while path = $global_tempfiles.pop do
      begin
        Dir.unstub(:entries)
        FileUtils.rm_rf path, :secure => true
      rescue Errno::ENOENT
        # nothing to do
      end
    end
  end

  def make_absolute(path) PuppetSpec::Files.make_absolute(path) end
  def self.make_absolute(path)
    path = File.expand_path(path)
    path[0] = 'c' if Puppet.features.microsoft_windows?
    path
  end

  def tmpfile(name, dir = nil) PuppetSpec::Files.tmpfile(name, dir) end
  def self.tmpfile(name, dir = nil)
    # Generate a temporary file, just for the name...
    source = dir ? Tempfile.new(name, dir) : Tempfile.new(name)
    path = source.path
    source.close!

    record_tmp(File.expand_path(path))

    path
  end

  def file_containing(name, contents) PuppetSpec::Files.file_containing(name, contents) end
  def self.file_containing(name, contents)
    file = tmpfile(name)
    File.open(file, 'wb') { |f| f.write(contents) }
    file
  end

  def tmpdir(name) PuppetSpec::Files.tmpdir(name) end
  def self.tmpdir(name)
    dir = Dir.mktmpdir(name)

    record_tmp(dir)

    dir
  end

  def self.record_tmp(tmp)
    # ...record it for cleanup,
    $global_tempfiles ||= []
    $global_tempfiles << tmp
  end
end
