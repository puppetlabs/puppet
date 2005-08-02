# An interface for managing filebuckets from puppet 

# $Id$

require 'puppet/filebucket'

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
                        @bucket = FileBucket::Dipper.new( 
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
                        @bucket = FileBucket::Dipper.new(
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
