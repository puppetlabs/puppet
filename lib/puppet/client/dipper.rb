module Puppet
    class Client
        # The client class for filebuckets.
        class Dipper < Puppet::Client
            @drivername = :Bucket
            
            attr_accessor :name

            # Create our bucket client
            def initialize(hash = {})
                if hash.include?(:Path)
                    bucket = Puppet::Server::FileBucket.new(
                        :Bucket => hash[:Path]
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
                string = Base64.encode64(contents)

                sum = @driver.addfile(string,file)
                string = ""
                contents = ""
                return sum
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
                    #puts "Restoring %s" % file
                    if tmp = @driver.getfile(sum)
                        newcontents = Base64.decode64(tmp)
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
                    #puts "Done"
                    return newsum
                else
                    return nil
                end
            end
        end
    end
end

# $Id$
