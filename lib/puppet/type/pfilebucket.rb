module Puppet
    require 'puppet/network/client'

    newtype(:filebucket) do
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
            undo transactions.
            
            You will normally want to define a single filebucket for your
            whole network and then use that as the default backup location::
            
                # Define the bucket
                filebucket { main: server => puppet }

                # Specify it as the default target
                File { backup => main }

            Puppetmaster servers create a filebucket by default, so this will
            work in a default configuration."

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

            defaultto { Puppet[:clientbucketdir] }
        end

        # Create a default filebucket.
        def self.mkdefaultbucket
            self.create(:name => "puppet", :path => Puppet[:clientbucketdir])
        end

        def self.instances
            []
        end

        def bucket
            unless defined? @bucket
                mkbucket()
            end

            @bucket
        end

        def mkbucket
            if self[:server]
                begin
                    @bucket = Puppet::Network::Client.client(:Dipper).new( 
                        :Server => self[:server],
                        :Port => self[:port]
                    )
                rescue => detail
                    self.fail(
                        "Could not create remote filebucket: %s" % detail
                    )
                end
            else
                begin
                    @bucket = Puppet::Network::Client.client(:Dipper).new(
                        :Path => self[:path]
                    )
                rescue => detail
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                    self.fail(
                        "Could not create local filebucket: %s" % detail
                    )
                end
            end

            @bucket.name = self.name
        end
    end
end

