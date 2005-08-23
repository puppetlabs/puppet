#!/usr/bin/ruby -w

#--------------------
# accept and serve files
#
# $Id$


require 'webrick'
#require 'webrick/https'
require 'xmlrpc/server'
require 'xmlrpc/client'
#require 'webrick/httpstatus'
require 'facter'
require 'digest/md5'
require 'base64'

class BucketError < RuntimeError; end

module FileBucket
    DEFAULTPORT = 8139
    # this doesn't work for relative paths
    def FileBucket.mkdir(dir)
        if FileTest.exist?(dir)
            return false
        else
            tmp = dir.sub(/^\//,'')
            path = [File::SEPARATOR]
            tmp.split(File::SEPARATOR).each { |dir|
                path.push dir
                unless FileTest.exist?(File.join(path))
                    Dir.mkdir(File.join(path))
                end
            }
            return true
        end
    end

    def FileBucket.paths(base,md5)
        return [
            File.join(base, md5),
            File.join(base, md5, "contents"),
            File.join(base, md5, "paths")
        ]
    end

    #---------------------------------------------------------------
    class Bucket
        def initialize(hash)
            # build our AST

            if hash.include?(:ConflictCheck)
                @conflictchk = hash[:ConflictCheck]
                hash.delete(:ConflictCheck)
            else
                @conflictchk = true
            end

            if hash.include?(:Path)
                @bucket = hash[:Path]
                hash.delete(:Path)
            else
                if defined? Puppet
                    @bucket = Puppet[:bucketdir]
                else
                    @bucket = File.expand_path("~/.filebucket")
                end
            end

            # XXX this should really be done using Puppet::Type instances...
            FileBucket.mkdir(@bucket)
        end

        # accept a file from a client
        def addfile(string,path)
            #puts "entering addfile"
            contents = Base64.decode64(string)
            #puts "string is decoded"

            md5 = Digest::MD5.hexdigest(contents)
            #puts "md5 is made"

            bpath, bfile, pathpath = FileBucket.paths(@bucket,md5)

            # if it's a new directory...
            if FileBucket.mkdir(bpath)
                # ...then just create the file
                #puts "creating file"
                File.open(bfile, File::WRONLY|File::CREAT) { |of|
                    of.print contents
                }
                #puts "File is created"
            else # if the dir already existed...
                # ...we need to verify that the contents match the existing file
                if @conflictchk
                    unless FileTest.exists?(bfile)
                        raise(BucketError,
                            "No file at %s for sum %s" % [bfile,md5], caller)
                    end

                    curfile = ""
                    File.open(bfile) { |of|
                        curfile = of.read
                    }

                    # if the contents don't match, then we've found a conflict
                    # unlikely, but quite bad
                    if curfile != contents
                        raise(BucketError,
                            "Got passed new contents for sum %s" % md5, caller)
                    end
                end
                #puts "Conflict check is done"
            end

            # in either case, add the passed path to the list of paths
            paths = nil
            addpath = false
            if FileTest.exists?(pathpath)
                File.open(pathpath) { |of|
                    paths = of.readlines
                }

                # unless our path is already there...
                unless paths.include?(path)
                    addpath = true
                end
            else
                addpath = true
            end
            #puts "Path is checked"

            # if it's a new file, or if our path isn't in the file yet, add it
            if addpath
                File.open(pathpath, File::WRONLY|File::CREAT|File::APPEND) { |of|
                    of.puts path
                }
                #puts "Path is added"
            end

            return md5
        end

        def getfile(md5)
            bpath, bfile, bpaths = FileBucket.paths(@bucket,md5)

            unless FileTest.exists?(bfile)
                return false
            end

            contents = nil
            File.open(bfile) { |of|
                contents = of.read
            }

            return Base64.encode64(contents)
        end

        private

        def on_init
            @default_namespace = 'urn:filebucket-server'
            add_method(self, 'addfile', 'string', 'path')
            add_method(self, 'getfile', 'md5')
        end

        def cert(filename)
            OpenSSL::X509::Certificate.new(File.open(File.join(@dir, filename)) { |f|
                f.read
            })
        end

        def key(filename)
            OpenSSL::PKey::RSA.new(File.open(File.join(@dir, filename)) { |f|
                f.read
            })
        end

    end
    #---------------------------------------------------------------

    class BucketWebserver < WEBrick::HTTPServer
        def initialize(hash)
            unless hash.include?(:Port)
                hash[:Port] = FileBucket::DEFAULTPORT
            end
            servlet = XMLRPC::WEBrickServlet.new
            @bucket = FileBucket::Bucket.new(hash)
            #puts @bucket
            servlet.add_handler("bucket",@bucket)
            super

            self.mount("/RPC2", servlet)
        end
    end

    class BucketClient < XMLRPC::Client
        @@methods = [ :addfile, :getfile ]

        @@methods.each { |method|
            self.send(:define_method,method) { |*args|
                begin
                    call("bucket.%s" % method.to_s,*args)
                rescue => detail
                    #puts detail
                end
            }
        }

        def initialize(hash)
            hash[:Path] ||= "/RPC2"
            hash[:Server] ||= "localhost"
            hash[:Port] ||= FileBucket::DEFAULTPORT
            super(hash[:Server],hash[:Path],hash[:Port])
        end
    end

    class Dipper
        def initialize(hash)
            if hash.include?(:Server)
                @bucket = FileBucket::BucketClient.new(
                    :Server => hash[:Server]
                )
            elsif hash.include?(:Bucket)
                @bucket = hash[:Bucket]
            elsif hash.include?(:Path)
                @bucket = FileBucket::Bucket.new(
                    :Path => hash[:Path]
                )
            end
        end

        def backup(file)
            unless FileTest.exists?(file)
                raise(BucketError, "File %s does not exist" % file, caller)
            end
            contents = File.open(file) { |of| of.read }

            string = Base64.encode64(contents)
            #puts "string is created"

            sum = @bucket.addfile(string,file)
            #puts "file %s is added" % file
            return sum
        end

        def restore(file,sum)
            restore = true
            if FileTest.exists?(file)
                contents = File.open(file) { |of| of.read }

                cursum = Digest::MD5.hexdigest(contents)

                # if the checksum has changed...
                # this might be extra effort
                if cursum == sum
                    restore = false
                end
            end

            if restore
                #puts "Restoring %s" % file
                newcontents = Base64.decode64(@bucket.getfile(sum))
                newsum = Digest::MD5.hexdigest(newcontents)
                File.open(file,File::WRONLY|File::TRUNC) { |of|
                    of.print(newcontents)
                }
                #puts "Done"
                return newsum
            else
                return nil
            end

        end
    end
    #---------------------------------------------------------------
end
