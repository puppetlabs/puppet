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
            begin
                mode = File.stat(file).mode
            rescue
                mode = 0600
            end
        end

        Puppet::Util.sync(file).synchronize(Sync::EX) do
            File.open(file, "w", mode) do |rf|
                rf.lock_exclusive do |lrf|
                    File.open(tmpfile, "w", mode) do |tf|
                        yield tf
                    end
                    begin
                        File.rename(tmpfile, file)
                    rescue => detail
                        File.unlink(tmpfile) if File.exist?(tmpfile)
                        raise Puppet::Error, "Could not rename %s to %s: %s; file %s was unchanged" % [file, tmpfile, Thread.current.object_id, detail, file]
                    end
                end
            end
        end
    end
end
