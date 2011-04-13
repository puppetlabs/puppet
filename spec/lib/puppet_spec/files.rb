require 'fileutils'
require 'tempfile'

# A support module for testing files.
module PuppetSpec::Files
  # This code exists only to support tests that run as root, pretty much.
  # Once they have finally been eliminated this can all go... --daniel 2011-04-08
  if Puppet.features.posix? then
    def self.in_tmp(path)
      path =~ /^\/tmp/ or path =~ /^\/var\/folders/
    end
  elsif Puppet.features.microsoft_windows?
    def self.in_tmp(path)
      tempdir = File.expand_path(File.join(Dir::LOCAL_APPDATA, "Temp"))
      path =~ /^#{tempdir}/
    end
  else
    fail "Help! Can't find in_tmp for this platform"
  end

  def self.cleanup
    $global_tempfiles ||= []
    while path = $global_tempfiles.pop do
      fail "Not deleting tmpfile #{path} outside regular tmpdir" unless in_tmp(path)

      begin
        FileUtils.rm_r path, :secure => true
      rescue Errno::ENOENT
        # nothing to do
      end
    end
  end

  def tmpfile(name)
    # Generate a temporary file, just for the name...
    source = Tempfile.new(name)
    path = source.path
    source.close!

    # ...record it for cleanup,
    $global_tempfiles ||= []
    $global_tempfiles << File.expand_path(path)

    # ...and bam.
    path
  end

  def tmpdir(name)
    path = tmpfile(name)
    FileUtils.mkdir_p(path)
    path
  end
end
