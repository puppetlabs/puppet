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

  module_function

  def make_absolute(path)
    path = File.expand_path(path)
    path[0] = 'c' if Puppet.features.microsoft_windows?
    path
  end

  def tmpfile(name, dir = nil)
    dir ||= Dir.tmpdir
    path = Puppet::FileSystem.expand_path(make_tmpname(name, nil).encode(Encoding::UTF_8), dir)
    record_tmp(File.expand_path(path))

    path
  end

  def file_containing(name, contents)
    file = tmpfile(name)
    File.open(file, 'wb') { |f| f.write(contents) }
    file
  end

  def script_containing(name, contents)
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

  def tmpdir(name)
    dir = Puppet::FileSystem.expand_path(Dir.mktmpdir(name).encode!(Encoding::UTF_8))

    record_tmp(dir)

    dir
  end

  # Copied from ruby 2.4 source
  def make_tmpname((prefix, suffix), n)
    prefix = (String.try_convert(prefix) or
              raise ArgumentError, "unexpected prefix: #{prefix.inspect}")
    suffix &&= (String.try_convert(suffix) or
                raise ArgumentError, "unexpected suffix: #{suffix.inspect}")
    t = Time.now.strftime("%Y%m%d")
    path = "#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}".dup
    path << "-#{n}" if n
    path << suffix if suffix
    path
  end

  def dir_containing(name, contents_hash)
    dir_contained_in(tmpdir(name), contents_hash)
  end

  def dir_contained_in(dir, contents_hash)
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

  def record_tmp(tmp)
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
