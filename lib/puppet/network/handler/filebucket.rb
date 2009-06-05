require 'fileutils'
require 'digest/md5'
require 'puppet/external/base64'

class Puppet::Network::Handler # :nodoc:
    class BucketError < RuntimeError; end
    # Accept files and store them by md5 sum, returning the md5 sum back
    # to the client.  Alternatively, accept an md5 sum and return the
    # associated content.
    class FileBucket < Handler
        desc "The interface to Puppet's FileBucket system.  Can be used to store
        files in and retrieve files from a filebucket."

        @interface = XMLRPC::Service::Interface.new("puppetbucket") { |iface|
            iface.add_method("string addfile(string, string)")
            iface.add_method("string getfile(string)")
        }

        Puppet::Util.logmethods(self, true)
        attr_reader :name, :path

        # this doesn't work for relative paths
        def self.oldpaths(base,md5)
            return [
                File.join(base, md5),
                File.join(base, md5, "contents"),
                File.join(base, md5, "paths")
            ]
        end

        # this doesn't work for relative paths
        def self.paths(base,md5)
            dir = File.join(md5[0..7].split(""))
            basedir = File.join(base, dir, md5)
            return [
                basedir,
                File.join(basedir, "contents"),
                File.join(basedir, "paths")
            ]
        end

        # Should we check each file as it comes in to make sure the md5
        # sums match?  Defaults to false.
        def conflict_check?
            @confictchk
        end

        def initialize(hash)
            if hash.include?(:ConflictCheck)
                @conflictchk = hash[:ConflictCheck]
                hash.delete(:ConflictCheck)
            else
                @conflictchk = false
            end

            if hash.include?(:Path)
                @path = hash[:Path]
                hash.delete(:Path)
            else
                if defined? Puppet
                    @path = Puppet[:bucketdir]
                else
                    @path = File.expand_path("~/.filebucket")
                end
            end

            Puppet.settings.use(:filebucket)

            @name = "Filebucket[#{@path}]"
        end

        # Accept a file from a client and store it by md5 sum, returning
        # the sum.
        def addfile(contents, path, client = nil, clientip = nil)
            if client
                contents = Base64.decode64(contents)
            end
            md5 = Digest::MD5.hexdigest(contents)

            bpath, bfile, pathpath = FileBucket.paths(@path,md5)

            # If the file already exists, just return the md5 sum.
            if FileTest.exists?(bfile)
                # If verification is enabled, then make sure the text matches.
                if conflict_check?
                    verify(contents, md5, bfile)
                end
                return md5
            end

            # Make the directories if necessary.
            unless FileTest.directory?(bpath)
                Puppet::Util.withumask(0007) do
                    FileUtils.mkdir_p(bpath)
                end
            end

            # Write the file to disk.
            msg = "Adding %s(%s)" % [path, md5]
            msg += " from #{client}" if client
            self.info msg

            # ...then just create the file
            Puppet::Util.withumask(0007) do
                File.open(bfile, File::WRONLY|File::CREAT, 0440) { |of|
                    of.print contents
                }
            end

            # Write the path to the paths file.
            add_path(path, pathpath)

            return md5
        end

        # Return the contents associated with a given md5 sum.
        def getfile(md5, client = nil, clientip = nil)
            bpath, bfile, bpaths = FileBucket.paths(@path,md5)

            unless FileTest.exists?(bfile)
                # Try the old flat style.
                bpath, bfile, bpaths = FileBucket.oldpaths(@path,md5)
                unless FileTest.exists?(bfile)
                    return false
                end
            end

            contents = nil
            File.open(bfile) { |of|
                contents = of.read
            }

            if client
                return Base64.encode64(contents)
            else
                return contents
            end
        end

        def paths(md5)
            self.class(@path, md5)
        end

        def to_s
            self.name
        end

        private

        # Add our path to the paths file if necessary.
        def add_path(path, file)
            if FileTest.exists?(file)
                File.open(file) { |of|
                    return if of.readlines.collect { |l| l.chomp }.include?(path)
                }
            end

            # if it's a new file, or if our path isn't in the file yet, add it
            File.open(file, File::WRONLY|File::CREAT|File::APPEND) { |of|
                of.puts path
            }
        end

        # If conflict_check is enabled, verify that the passed text is
        # the same as the text in our file.
        def verify(content, md5, bfile)
            curfile = File.read(bfile)

            # If the contents don't match, then we've found a conflict.
            # Unlikely, but quite bad.
            if curfile != contents
                raise(BucketError,
                    "Got passed new contents for sum %s" % md5, caller)
            else
                msg = "Got duplicate %s(%s)" % [path, md5]
                msg += " from #{client}" if client
                self.info msg
            end
        end
    end
end

