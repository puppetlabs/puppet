module Puppet
  require 'puppet/file_bucket/dipper'

  Type.newtype(:filebucket) do
    @doc = <<-EOT
      A repository for storing and retrieving file content by MD5 checksum. Can
      be local to each agent node, or centralized on a puppet master server. All
      puppet masters provide a filebucket service that agent nodes can access
      via HTTP, but you must declare a filebucket resource before any agents
      will do so.

      Filebuckets are used for the following features:

      - **Content backups.** If the `file` type's `backup` attribute is set to
        the name of a filebucket, Puppet will back up the _old_ content whenever
        it rewrites a file; see the documentation for the `file` type for more
        details. These backups can be used for manual recovery of content, but
        are more commonly used to display changes and differences in a tool like
        Puppet Dashboard.
      - **Content distribution.** The optional static compiler populates the
        puppet master's filebucket with the _desired_ content for each file,
        then instructs the agent to retrieve the content for a specific
        checksum. For more details,
        [see the `static_compiler` section in the catalog indirection docs](https://docs.puppetlabs.com/puppet/latest/reference/indirection.html#catalog).

      To use a central filebucket for backups, you will usually want to declare
      a filebucket resource and a resource default for the `backup` attribute
      in site.pp:

          # /etc/puppetlabs/puppet/manifests/site.pp
          filebucket { 'main':
            path   => false,                # This is required for remote filebuckets.
            server => 'puppet.example.com', # Optional; defaults to the configured puppet master.
          }

          File { backup => main, }

      Puppet master servers automatically provide the filebucket service, so
      this will work in a default configuration. If you have a heavily
      restricted `auth.conf` file, you may need to allow access to the
      `file_bucket_file` endpoint.
    EOT

    newparam(:name) do
      desc "The name of the filebucket."
      isnamevar
    end

    newparam(:server) do
      desc "The server providing the remote filebucket service. Defaults to the
        value of the `server` setting (that is, the currently configured
        puppet master server).

        This setting is _only_ consulted if the `path` attribute is set to `false`."
      defaultto { Puppet[:server] }
    end

    newparam(:port) do
      desc "The port on which the remote server is listening. Defaults to the
        value of the `masterport` setting, which is usually %s." % Puppet[:masterport]

      defaultto { Puppet[:masterport] }
    end

    newparam(:path) do
      desc "The path to the _local_ filebucket; defaults to the value of the
        `clientbucketdir` setting.  To use a remote filebucket, you _must_ set
        this attribute to `false`."

      defaultto { Puppet[:clientbucketdir] }

      validate do |value|
        if value.is_a? Array
          raise ArgumentError, "You can only have one filebucket path"
        end

        if value.is_a? String and not Puppet::Util.absolute_path?(value)
          raise ArgumentError, "Filebucket paths must be absolute"
        end

        true
      end
    end

    # Create a default filebucket.
    def self.mkdefaultbucket
      new(:name => "puppet", :path => Puppet[:clientbucketdir])
    end

    def bucket
      mkbucket unless defined?(@bucket)
      @bucket
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
        @bucket = Puppet::FileBucket::Dipper.new(args)
      rescue => detail
        message = "Could not create #{type} filebucket: #{detail}"
        self.log_exception(detail, message)
        self.fail(message)
      end

      @bucket.name = self.name
    end
  end
end
