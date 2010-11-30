require 'fileutils'
require 'digest/md5'
require 'puppet/external/base64'

class Puppet::Network::Handler # :nodoc:
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

    def initialize(hash)
      @path = hash[:Path] || Puppet[:bucketdir]
      @name = "Filebucket[#{@path}]"
    end

    # Accept a file from a client and store it by md5 sum, returning
    # the sum.
    def addfile(contents, path, client = nil, clientip = nil)
      contents = Base64.decode64(contents) if client
      bucket = Puppet::FileBucket::File.new(contents)
      Puppet::FileBucket::File.indirection.save(bucket)
    end

    # Return the contents associated with a given md5 sum.
    def getfile(md5, client = nil, clientip = nil)
      bucket = Puppet::FileBucket::File.indirection.find("md5:#{md5}")
      contents = bucket.contents

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

