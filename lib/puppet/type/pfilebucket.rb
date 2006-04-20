require 'puppet/server/filebucket'

module Puppet
    newtype(:filebucket) do
        attr_reader :bucket

        @doc = "A repository for backing up files.  If no filebucket is
            defined, then files will be backed up in their current directory,
            but the filebucket can be either a host- or site-global repository
            for backing up.  It stores files and returns the MD5 sum, which
            can later be used to retrieve the file if restoration becomes
            necessary.  A filebucket does not do any work itself; instead,
            it can be specified as the value of *backup* in a **file** object.
            
            Currently, filebuckets are only useful for manual retrieval of
            accidentally removed files (e.g., you look in the log for the md5
            sum and retrieve the file with that sum from the filebucket), but
            when transactions are fully supported filebuckets will be used to
            undo transactions."

        @states = []

        newparam(:name) do
            desc "The name of the filebucket."
            isnamevar
        end

        newparam(:server) do
            desc "The server providing the filebucket.  If this is
                not specified, then the bucket is local and *path* must be
                specified."
        end

        newparam(:port) do
            desc "The port on which the remote server is listening.
                Defaults to the normal Puppet port, %s." % Puppet[:masterport]

            defaultto Puppet[:masterport]
        end

        newparam(:path) do
            desc "The path to the local filebucket.  If this is
                not specified, then the bucket is remote and *server* must be
                specified."
        end

        # get the actual filebucket object
        def self.bucket(name)
            if object = self[name]
                return object.bucket
            else
                return nil
            end
        end

        def self.list
            self.collect do |obj| obj.name end
        end

        def initialize(hash)
            super

            if self[:server]
                begin
                    @bucket = Puppet::Client::Dipper.new( 
                        :Server => self[:server],
                        :Port => self[:port]
                    )
                rescue => detail
                    self.fail(
                        "Could not create remote filebucket: %s" % detail
                    )
                end
            else
                unless self[:path]
                    self[:path] = Puppet[:bucketdir] 
                end
                begin
                    @bucket = Puppet::Client::Dipper.new(
                        :Path => self[:path]
                    )
                rescue => detail
                    self.fail(
                        "Could not create local filebucket: %s" % detail
                    )
                end
            end

            @bucket.name = self.name
        end
    end
end

# $Id$
