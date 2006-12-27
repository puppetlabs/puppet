#--------------------
# accept and serve files


require 'webrick'
require 'xmlrpc/server'
require 'xmlrpc/client'
require 'facter'
require 'digest/md5'
require 'puppet/base64'

module Puppet
class Server
    class BucketError < RuntimeError; end
    class FileBucket < Handler
        Puppet.config.setdefaults("filebucket",
            :bucketdir => {
                :default => "$vardir/bucket",
                :mode => 0750,
                :owner => "$user",
                :group => "$group",
                :desc => "Where FileBucket files are stored."
            }
        )
        @interface = XMLRPC::Service::Interface.new("puppetbucket") { |iface|
            iface.add_method("string addfile(string, string)")
            iface.add_method("string getfile(string)")
        }

        Puppet::Util.logmethods(self, true)
        attr_reader :name, :path

        # this doesn't work for relative paths
        def FileBucket.paths(base,md5)
            return [
                File.join(base, md5),
                File.join(base, md5, "contents"),
                File.join(base, md5, "paths")
            ]
        end

        def initialize(hash)
            if hash.include?(:ConflictCheck)
                @conflictchk = hash[:ConflictCheck]
                hash.delete(:ConflictCheck)
            else
                @conflictchk = true
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

            Puppet.config.use(:filebucket)

            @name = "filebucket[#{@path}]"
        end

        # accept a file from a client
        def addfile(contents, path, client = nil, clientip = nil)
            if client
                contents = Base64.decode64(contents)
            end
            md5 = Digest::MD5.hexdigest(contents)

            bpath, bfile, pathpath = FileBucket.paths(@path,md5)

            # if it's a new directory...
            if Puppet.recmkdir(bpath)
                msg = "Adding %s(%s)" % [path, md5]
                msg += " from #{client}" if client
                self.info msg
                # ...then just create the file
                File.open(bfile, File::WRONLY|File::CREAT, 0440) { |of|
                    of.print contents
                }
            else # if the dir already existed...
                # ...we need to verify that the contents match the existing file
                if @conflictchk
                    unless FileTest.exists?(bfile)
                        raise(BucketError,
                            "No file at %s for sum %s" % [bfile,md5], caller)
                    end

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

            contents = ""

            # in either case, add the passed path to the list of paths
            paths = nil
            addpath = false
            if FileTest.exists?(pathpath)
                File.open(pathpath) { |of|
                    paths = of.readlines.collect { |l| l.chomp }
                }

                # unless our path is already there...
                unless paths.include?(path)
                    addpath = true
                end
            else
                addpath = true
            end

            # if it's a new file, or if our path isn't in the file yet, add it
            if addpath
                File.open(pathpath, File::WRONLY|File::CREAT|File::APPEND) { |of|
                    of.puts path
                }
            end

            return md5
        end

        def getfile(md5, client = nil, clientip = nil)
            bpath, bfile, bpaths = FileBucket.paths(@path,md5)

            unless FileTest.exists?(bfile)
                return false
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

        def to_s
            self.name
        end
    end
end
end
#
# $Id$
