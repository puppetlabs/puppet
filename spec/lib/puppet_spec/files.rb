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
    path = source.path.encode(Encoding::UTF_8)
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

  def script_containing(name, contents) PuppetSpec::Files.script_containing(name, contents) end
  def self.script_containing(name, contents)
    file = tmpfile(name)
    if Puppet.features.microsoft_windows?
      file += '.bat'
      text = contents[:windows]
    else
      text = contents[:posix]
    end
    File.open(file, 'wb') { |f| f.write(text) }
    Puppet::FileSystem.chmod(0755, file)
    file
  end

  def tmpdir(name) PuppetSpec::Files.tmpdir(name) end
  def self.tmpdir(name)
    dir = Dir.mktmpdir(name).encode!(Encoding::UTF_8)

    record_tmp(dir)

    dir
  end

  def dir_containing(name, contents_hash) PuppetSpec::Files.dir_containing(name, contents_hash) end
  def self.dir_containing(name, contents_hash)
    dir_contained_in(tmpdir(name), contents_hash)
  end

  def dir_contained_in(dir, contents_hash) PuppetSpec::Files.dir_contained_in(dir, contents_hash) end
  def self.dir_contained_in(dir, contents_hash)
    contents_hash.each do |k,v|
      if v.is_a?(Hash)
        Dir.mkdir(tmp = File.join(dir,k))
        dir_contained_in(tmp, v)
      else
        file = File.join(dir, k)
        File.open(file, 'wb') {|f| f.write(v) }
      end
    end
    dir
  end

  def self.record_tmp(tmp)
    # ...record it for cleanup,
    $global_tempfiles ||= []
    $global_tempfiles << tmp
  end

  def expect_file_mode(file, mode)
    actual_mode = "%o" % Puppet::FileSystem.stat(file).mode
    target_mode = if Puppet.features.microsoft_windows?
      mode
    else
      "10" + "%04i" % mode.to_i
    end
    expect(actual_mode).to eq(target_mode)
  end
end
