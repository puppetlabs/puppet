
require 'puppet/file_serving/content'
require 'puppet/file_serving/metadata'

module Puppet
  # Copy files from a local or remote source.  This state *only* does any work
  # when the remote file is an actual file; in that case, this state copies
  # the file down.  If the remote file is a dir or a link or whatever, then
  # this state, during retrieval, modifies the appropriate other states
  # so that things get taken care of appropriately.
  Puppet::Type.type(:file).newparam(:source) do
    include Puppet::Util::Diff

    attr_accessor :source, :local
    desc <<-EOT
      Copy a file over the current file.  Uses `checksum` to
      determine when a file should be copied.  Valid values are either
      fully qualified paths to files, or URIs.  Currently supported URI
      types are *puppet* and *file*.

      This is one of the primary mechanisms for getting content into
      applications that Puppet does not directly support and is very
      useful for those configuration files that don't change much across
      sytems.  For instance:

          class sendmail {
            file { "/etc/mail/sendmail.cf":
              source => "puppet://server/modules/module_name/sendmail.cf"
            }
          }

      You can also leave out the server name, in which case `puppet agent`
      will fill in the name of its configuration server and `puppet apply`
      will use the local filesystem.  This makes it easy to use the same
      configuration in both local and centralized forms.

      Currently, only the `puppet` scheme is supported for source
      URL's. Puppet will connect to the file server running on
      `server` to retrieve the contents of the file. If the
      `server` part is empty, the behavior of the command-line
      interpreter (`puppet apply`) and the client demon (`puppet agent`) differs
      slightly: `apply` will look such a file up on the module path
      on the local host, whereas `agent` will connect to the
      puppet server that it received the manifest from.

      See the [fileserver configuration documentation](http://docs.puppetlabs.com/guides/file_serving.html)
      for information on how to configure and use file services within Puppet.

      If you specify multiple file sources for a file, then the first
      source that exists will be used.  This allows you to specify
      what amount to search paths for files:

          file { "/path/to/my/file":
            source => [
              "/modules/nfs/files/file.$host",
              "/modules/nfs/files/file.$operatingsystem",
              "/modules/nfs/files/file"
            ]
          }

      This will use the first found file as the source.

      You cannot currently copy links using this mechanism; set `links`
      to `follow` if any remote sources are links.
    EOT

    validate do |sources|
      sources = [sources] unless sources.is_a?(Array)
      sources.each do |source|
        next if Puppet::Util.absolute_path?(source)

        begin
          uri = URI.parse(URI.escape(source))
        rescue => detail
          self.fail "Could not understand source #{source}: #{detail}"
        end

        self.fail "Cannot use relative URLs '#{source}'" unless uri.absolute?
        self.fail "Cannot use opaque URLs '#{source}'" unless uri.hierarchical?
        self.fail "Cannot use URLs of type '#{uri.scheme}' as source for fileserving" unless %w{file puppet}.include?(uri.scheme)
      end
    end

    SEPARATOR_REGEX = [Regexp.escape(File::SEPARATOR.to_s), Regexp.escape(File::ALT_SEPARATOR.to_s)].join

    munge do |sources|
      sources = [sources] unless sources.is_a?(Array)
      sources.map do |source|
        source = source.sub(/[#{SEPARATOR_REGEX}]+$/, '')

        if Puppet::Util.absolute_path?(source)
          URI.unescape(Puppet::Util.path_to_uri(source).to_s)
        else
          source
        end
      end
    end

    def change_to_s(currentvalue, newvalue)
      # newvalue = "{md5}#{@metadata.checksum}"
      if @resource.property(:ensure).retrieve == :absent
        return "creating from source #{metadata.source} with contents #{metadata.checksum}"
      else
        return "replacing from source #{metadata.source} with contents #{metadata.checksum}"
      end
    end

    def checksum
      metadata && metadata.checksum
    end

    # Look up (if necessary) and return remote content.
    def content
      return @content if @content
      raise Puppet::DevError, "No source for content was stored with the metadata" unless metadata.source

      unless tmp = Puppet::FileServing::Content.indirection.find(metadata.source)
        fail "Could not find any content at %s" % metadata.source
      end
      @content = tmp.content
    end

    # Copy the values from the source to the resource.  Yay.
    def copy_source_values
      devfail "Somehow got asked to copy source values without any metadata" unless metadata

      # Take each of the stats and set them as states on the local file
      # if a value has not already been provided.
      [:owner, :mode, :group, :checksum].each do |metadata_method|
        param_name = (metadata_method == :checksum) ? :content : metadata_method
        next if metadata_method == :owner and !Puppet.features.root?
        next if metadata_method == :checksum and metadata.ftype == "directory"
        next if metadata_method == :checksum and metadata.ftype == "link" and metadata.links == :manage

        if resource[param_name].nil? or resource[param_name] == :absent
          resource[param_name] = metadata.send(metadata_method)
        end
      end

      if resource[:ensure] == :absent
        # We know all we need to
      elsif metadata.ftype != "link"
        resource[:ensure] = metadata.ftype
      elsif @resource[:links] == :follow
        resource[:ensure] = :present
      else
        resource[:ensure] = "link"
        resource[:target] = metadata.destination
      end
    end

    def found?
      ! (metadata.nil? or metadata.ftype.nil?)
    end

    attr_writer :metadata

    # Provide, and retrieve if necessary, the metadata for this file.  Fail
    # if we can't find data about this host, and fail if there are any
    # problems in our query.
    def metadata
      return @metadata if @metadata
      return nil unless value
      value.each do |source|
        begin
          if data = Puppet::FileServing::Metadata.indirection.find(source)
            @metadata = data
            @metadata.source = source
            break
          end
        rescue => detail
          fail detail, "Could not retrieve file metadata for #{source}: #{detail}"
        end
      end
      fail "Could not retrieve information from environment #{Puppet[:environment]} source(s) #{value.join(", ")}" unless @metadata
      @metadata
    end

    def local?
      found? and scheme == "file"
    end

    def full_path
      Puppet::Util.uri_to_path(uri) if found?
    end

    def server
      (uri and uri.host) or Puppet.settings[:server]
    end

    def port
      (uri and uri.port) or Puppet.settings[:masterport]
    end
    private

    def scheme
      (uri and uri.scheme)
    end

    def uri
      @uri ||= URI.parse(URI.escape(metadata.source))
    end
  end
end
