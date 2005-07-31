#!/usr/local/bin/ruby -w
# An interface for managing filebuckets from puppet 

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

            @@buckets = {}

            def self.bucket(name)
                @@buckets[name]
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
                    @parameters[:path] ||= File.join(
                        Puppet[:puppetroot], "bucket"
                    )
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

                @@buckets[self.name] = @bucket
            end

		end # Puppet::Type::Service
	end # Puppet::Type
end

# $Id$
