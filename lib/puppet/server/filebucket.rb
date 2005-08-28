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

module Puppet
class Server
    class BucketError < RuntimeError; end
    class FileBucket < Handler
        DEFAULTPORT = 8139

        @interface = XMLRPC::Service::Interface.new("puppetbucket") { |iface|
            iface.add_method("string addfile(string, string)")
            iface.add_method("string getfile(string)")
        }

        # this doesn't work for relative paths
        def FileBucket.paths(base,md5)
            return [
                File.join(base, md5),
                File.join(base, md5, "contents"),
                File.join(base, md5, "paths")
            ]
        end

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

            Puppet.recmkdir(@bucket)
        end

        # accept a file from a client
        def addfile(string,path, client = nil, clientip = nil)
            #puts "entering addfile"
            contents = Base64.decode64(string)
            #puts "string is decoded"

            md5 = Digest::MD5.hexdigest(contents)
            #puts "md5 is made"

            bpath, bfile, pathpath = FileBucket.paths(@bucket,md5)

            # if it's a new directory...
            if Puppet.recmkdir(bpath)
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

        def getfile(md5, client = nil, clientip = nil)
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
        #---------------------------------------------------------------
    end
end
end
