require 'fileutils'
require 'tempfile'
require 'pathname'

# A support module for testing files.
module PuppetSpec::Files
  # This code exists only to support tests that run as root, pretty much.
  # Once they have finally been eliminated this can all go... --daniel 2011-04-08
  def self.in_tmp(path)
    tempdir = Dir.tmpdir

    Pathname.new(path).ascend do |dir|
      return true if File.identical?(tempdir, dir)
    end

    false
  end

  def self.cleanup
    $global_tempfiles ||= []
    while path = $global_tempfiles.pop do
      fail "Not deleting tmpfile #{path} outside regular tmpdir" unless in_tmp(path)

      begin
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

    # ...record it for cleanup,
    $global_tempfiles ||= []
    $global_tempfiles << File.expand_path(path)

    # ...and bam.
    path
  end

  def tmpdir(name) PuppetSpec::Files.tmpdir(name) end
  def self.tmpdir(name)
    path = tmpfile(name)
    FileUtils.mkdir_p(path)
    path
  end
end
