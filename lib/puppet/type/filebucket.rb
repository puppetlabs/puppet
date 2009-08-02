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
            desc "The server providing the remote filebucket.  If this is not
                  specified then *path* is checked. If it is set, then the
                  bucket is local.  Otherwise the puppetmaster server specified
                  in the config or at the commandline is used."
            defaultto { Puppet[:server] }
        end

        newparam(:port) do
            desc "The port on which the remote server is listening.
                Defaults to the normal Puppet port, %s." % Puppet[:masterport]

            defaultto { Puppet[:masterport] }
        end

        newparam(:path) do
            desc "The path to the local filebucket.  If this is
                unset, then the bucket is remote.  The parameter *server* must
                can be specified to set the remote server."

            defaultto { Puppet[:clientbucketdir] }
        end

        # Create a default filebucket.
        def self.mkdefaultbucket
            new(:name => "puppet", :path => Puppet[:clientbucketdir])
        end

        def bucket
            mkbucket() unless defined? @bucket
            return @bucket
        end

        private

        def mkbucket
            # Default is a local filebucket, if no server is given.
            # If the default path has been removed, too, then
            # the puppetmaster is used as default server

            type = "local"
            args = {}
            if self[:path]
                args[:Path] = self[:path]
            else
                args[:Server] = self[:server]
                args[:Port] = self[:port]
            end

            begin
                @bucket = Puppet::Network::Client.client(:Dipper).new(args)
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                self.fail("Could not create %s filebucket: %s" % [type, detail])
            end

            @bucket.name = self.name
        end
    end
end

