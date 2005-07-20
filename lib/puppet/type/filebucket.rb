#!/usr/local/bin/ruby -w
# An interface for managing filebuckets from puppet 

require 'puppet/filebucket'

module Puppet
	class Type
		class FileBucket < Type
            attr_reader :bucket

			@states = []

			@parameters = [
                :name,
                :path
            ]

            @name = :filebucket
			@namevar = :name

            def initialize(hash)
                super

                unless self[:path] 
                    self[:path] = File.join(Puppet[:puppetroot], "bucket")
                end

                @bucket = FileBucket::Bucket.new(
                    :Bucket => self[:path]
                )
            end

		end # Puppet::Type::Service
	end # Puppet::Type
end

# $Id$
