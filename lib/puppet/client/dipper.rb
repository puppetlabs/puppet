module Puppet
    class Client
        # The client class for filebuckets.
        class Dipper < Puppet::Client
            @drivername = :Bucket

            @handler = Puppet::Server::FileBucket
            
            attr_accessor :name

            # Create our bucket client
            def initialize(hash = {})
                if hash.include?(:Path)
                    bucket = Puppet::Server::FileBucket.new(
                        :Path => hash[:Path]
                    )
                    hash.delete(:Path)
                    hash[:Bucket] = bucket
                end

                super(hash)
            end

            # Back up a file to our bucket
            def backup(file)
                unless FileTest.exists?(file)
                    raise(BucketError, "File %s does not exist" % file)
                end
                contents = File.read(file)
                unless local?
                    contents = Base64.encode64(contents)
                end
                return @driver.addfile(contents,file)
            end

            # Restore the file
            def restore(file,sum)
                restore = true
                if FileTest.exists?(file)
                    cursum = Digest::MD5.hexdigest(File.read(file))

                    # if the checksum has changed...
                    # this might be extra effort
                    if cursum == sum
                        restore = false
                    end
                end

                if restore
                    if newcontents = @driver.getfile(sum)
                        unless local?
                            newcontents = Base64.decode64(newcontents)
                        end
                        tmp = ""
                        newsum = Digest::MD5.hexdigest(newcontents)
                        changed = nil
                        unless FileTest.writable?(file)
                            changed = File.stat(file).mode
                            File.chmod(changed | 0200, file)
                        end
                        File.open(file,File::WRONLY|File::TRUNC) { |of|
                            of.print(newcontents)
                        }
                        if changed
                            File.chmod(changed, file)
                        end
                    else
                        Puppet.err "Could not find file with checksum %s" % sum
                        return nil
                    end
                    return newsum
                else
                    return nil
                end
            end
        end
    end
end

# $Id$
