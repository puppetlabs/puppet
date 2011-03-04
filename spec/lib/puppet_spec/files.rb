require 'fileutils'
require 'tempfile'

# A support module for testing files.
module PuppetSpec::Files
  def self.cleanup
    if defined?($tmpfiles)
      $tmpfiles.each do |file|
        file = File.expand_path(file)
        if Puppet.features.posix? and file !~ /^\/tmp/ and file !~ /^\/var\/folders/
          puts "Not deleting tmpfile #{file} outside of /tmp or /var/folders"
          next
        elsif Puppet.features.microsoft_windows?
          tempdir = File.expand_path(File.join(Dir::LOCAL_APPDATA, "Temp"))
          if file !~ /^#{tempdir}/
            puts "Not deleting tmpfile #{file} outside of #{tempdir}"
            next
          end
        end
        if FileTest.exist?(file)
          system("chmod -R 755 '#{file}'")
          system("rm -rf '#{file}'")
        end
      end
      $tmpfiles.clear
    end
  end

  def tmpfile(name)
    source = Tempfile.new(name)
    path = source.path
    source.close!
    $tmpfiles ||= []
    $tmpfiles << path
    path
  end

  def tmpdir(name)
    file = tmpfile(name)
    FileUtils.mkdir_p(file)
    file
  end
end
