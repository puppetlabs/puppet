require 'puppet/util'

module Puppet::Util::FileLocking
    module_function

    # Create a shared lock for reading
    def readlock(file)
        Puppet::Util.sync(file).synchronize(Sync::SH) do
            File.open(file) { |f|
                f.lock_shared { |lf| yield lf }
            }
        end
    end

    # Create an exclusive lock for writing, and do the writing in a
    # tmp file.
    def writelock(file, mode = nil)
        unless FileTest.directory?(File.dirname(file))
            raise Puppet::DevError, "Cannot create %s; directory %s does not exist" % [file, File.dirname(file)]
        end
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

        Puppet::Util.sync(file).synchronize(Sync::EX) do
            File.open(file, "w", mode) do |rf|
                rf.lock_exclusive do |lrf|
                    yield lrf
                end
            end
        end
    end
end
