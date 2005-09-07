# An interface for managing filebuckets from puppet 

# $Id$

require 'puppet/server/filebucket'

module Puppet
	class Type
		class PFileBucket < Type
            attr_reader :bucket

			@states = []

			@parameters = [
                :name,
                :server,
                :path,
                :port
            ]

            @doc = "A repository for backing up files.  If no filebucket is
                defined, then files will be backed up in their current directory,
                but the filebucket can be either a host- or site-global repository
                for backing up.  It stores files and returns the MD5 sum, which
                can later be used to retrieve the file if restoration becomes
                necessary.  A filebucket does not do any work itself; instead,
                it can be specified as the value of *backup* in a **file** object."

            @paramdoc[:name] = "The name of the filebucket."
            @paramdoc[:server] = "The server providing the filebucket.  If this is
                not specified, then the bucket is local and *path* must be specified."
            @paramdoc[:port] = "The port on which the remote server is listening.
                Defaults to the normal Puppet port, %s." % Puppet[:masterport]
            @paramdoc[:path] = "The path to the local filebucket.  If this is
                not specified, then the bucket is remote and *server* must be
                specified."

            @name = :filebucket
			@namevar = :name

            # get the actual filebucket object
            def self.bucket(name)
                oname, object = @objects.find { |oname, o| oname == name }
                return object.bucket
            end

            def initialize(hash)
                super

                if @parameters.include?(:server)
                    @parameters[:port] ||= FileBucket::DEFAULTPORT
                    begin
                        @bucket = Puppet::Client::Dipper.new( 
                            :Server => @parameters[:server],
                            :Port => @parameters[:port]
                        )
                    rescue => detail
                        raise Puppet::Error.new(
                            "Could not create remote filebucket: %s" % detail
                        )
                    end
                else
                    @parameters[:path] ||= Puppet[:bucketdir]
                    begin
                        @bucket = Puppet::Client::Dipper.new(
                            :Path => @parameters[:path]
                        )
                    rescue => detail
                        raise Puppet::Error.new(
                            "Could not create local filebucket: %s" % detail
                        )
                    end
                end
            end

		end
	end
end

# $Id$
