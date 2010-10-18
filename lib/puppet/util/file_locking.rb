require 'puppet/util'

module Puppet::Util::FileLocking
  module_function

  # Create a shared lock for reading
  def readlock(file)
    raise ArgumentError, "#{file} is not a file" unless !File.exists?(file) or File.file?(file)
    Puppet::Util.synchronize_on(file,Sync::SH) do
      File.open(file) { |f|
        f.lock_shared { |lf| yield lf }
      }
    end
  end

  # Create an exclusive lock for writing, and do the writing in a
  # tmp file.
  def writelock(file, mode = nil)
    raise Puppet::DevError, "Cannot create #{file}; directory #{File.dirname(file)} does not exist" unless FileTest.directory?(File.dirname(file))
    raise ArgumentError, "#{file} is not a file" unless !File.exists?(file) or File.file?(file)
    tmpfile = file + ".tmp"

    unless mode
      # It's far more likely that the file will be there than not, so it's
      # better to stat once to check for existence and mode.
      # If we can't stat, it's most likely because the file's not there,
      # but could also be because the directory isn't readable, in which case
      # we won't be able to write anyway.
      begin
        mode = File.stat(file).mode
      rescue
        mode = 0600
      end
    end

    Puppet::Util.synchronize_on(file,Sync::EX) do
      File.open(file, File::Constants::CREAT | File::Constants::WRONLY, mode) do |rf|
        rf.lock_exclusive do |lrf|
          # poor's man open(2) O_EXLOCK|O_TRUNC
          lrf.seek(0, IO::SEEK_SET)
          lrf.truncate(0)
          yield lrf
        end
      end
    end
  end
end
