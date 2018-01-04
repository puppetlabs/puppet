require 'puppet/file_serving/content'
require 'puppet/file_serving/metadata'
require 'puppet/file_serving/terminus_helper'

require 'puppet/util/http_proxy'
require 'puppet/network/http'
require 'puppet/network/http/api/indirected_routes'
require 'puppet/network/http/compression'

module Puppet
  # Copy files from a local or remote source.  This state *only* does any work
  # when the remote file is an actual file; in that case, this state copies
  # the file down.  If the remote file is a dir or a link or whatever, then
  # this state, during retrieval, modifies the appropriate other states
  # so that things get taken care of appropriately.
  Puppet::Type.type(:file).newparam(:source) do
    include Puppet::Network::HTTP::Compression.module

    BINARY_MIME_TYPES = [
      Puppet::Network::FormatHandler.format_for('binary').mime
    ].join(', ').freeze

    attr_accessor :source, :local
    desc <<-'EOT'
      A source file, which will be copied into place on the local system. This
      attribute is mutually exclusive with `content` and `target`. Allowed
      values are:

      * `puppet:` URIs, which point to files in modules or Puppet file server
      mount points.
      * Fully qualified paths to locally available files (including files on NFS
      shares or Windows mapped drives).
      * `file:` URIs, which behave the same as local file paths.
      * `http:` URIs, which point to files served by common web servers

      The normal form of a `puppet:` URI is:

      `puppet:///modules/<MODULE NAME>/<FILE PATH>`

      This will fetch a file from a module on the Puppet master (or from a
      local module when using Puppet apply). Given a `modulepath` of
      `/etc/puppetlabs/code/modules`, the example above would resolve to
      `/etc/puppetlabs/code/modules/<MODULE NAME>/files/<FILE PATH>`.

      Unlike `content`, the `source` attribute can be used to recursively copy
      directories if the `recurse` attribute is set to `true` or `remote`. If
      a source directory contains symlinks, use the `links` attribute to
      specify whether to recreate links or follow them.

      *HTTP* URIs cannot be used to recursively synchronize whole directory
      trees. It is also not possible to use `source_permissions` values other
      than `ignore`. That's because HTTP servers do not transfer any metadata
      that translates to ownership or permission details.

      Multiple `source` values can be specified as an array, and Puppet will
      use the first source that exists. This can be used to serve different
      files to different system types:

          file { '/etc/nfs.conf':
            source => [
              "puppet:///modules/nfs/conf.${host}",
              "puppet:///modules/nfs/conf.${operatingsystem}",
              'puppet:///modules/nfs/conf'
            ]
          }

      Alternately, when serving directories recursively, multiple sources can
      be combined by setting the `sourceselect` attribute to `all`.
    EOT

    validate do |sources|
      sources = [sources] unless sources.is_a?(Array)
      sources.each do |source|
        next if Puppet::Util.absolute_path?(source)

        begin
          uri = URI.parse(Puppet::Util.uri_encode(source))
        rescue => detail
          self.fail Puppet::Error, "Could not understand source #{source}: #{detail}", detail
        end

        self.fail "Cannot use relative URLs '#{source}'" unless uri.absolute?
        self.fail "Cannot use opaque URLs '#{source}'" unless uri.hierarchical?
        unless %w{file puppet http https}.include?(uri.scheme)
          self.fail "Cannot use URLs of type '#{uri.scheme}' as source for fileserving"
        end
      end
    end

    SEPARATOR_REGEX = [Regexp.escape(File::SEPARATOR.to_s), Regexp.escape(File::ALT_SEPARATOR.to_s)].join

    munge do |sources|
      sources = [sources] unless sources.is_a?(Array)
      sources.map do |source|
        source = self.class.normalize(source)

        if Puppet::Util.absolute_path?(source)
          # CGI.unescape will butcher properly escaped URIs
          uri_string = Puppet::Util.path_to_uri(source).to_s
          # Ruby 1.9.3 and earlier have a URI bug in URI
          # to_s returns an ASCII string despite UTF-8 fragments
          # since its escaped its safe to universally call encode
          # URI.unescape always returns strings in the original encoding
          URI.unescape(uri_string.encode(Encoding::UTF_8))
        else
          source
        end
      end
    end

    def self.normalize(source)
      source.sub(/[#{SEPARATOR_REGEX}]+$/, '')
    end

    def change_to_s(currentvalue, newvalue)
      # newvalue = "{md5}#{@metadata.checksum}"
      if resource.property(:ensure).retrieve == :absent
        return "creating from source #{metadata.source} with contents #{metadata.checksum}"
      else
        return "replacing from source #{metadata.source} with contents #{metadata.checksum}"
      end
    end

    def checksum
      metadata && metadata.checksum
    end

    # Look up (if necessary) and return local content.
    def content
      return @content if @content
      raise Puppet::DevError, _("No source for content was stored with the metadata") unless metadata.source

      unless tmp = Puppet::FileServing::Content.indirection.find(metadata.source, :environment => resource.catalog.environment_instance, :links => resource[:links])
        self.fail "Could not find any content at %s" % metadata.source
      end
      @content = tmp.content
    end

    # Copy the values from the source to the resource.  Yay.
    def copy_source_values
      devfail "Somehow got asked to copy source values without any metadata" unless metadata

      # conditionally copy :checksum
      if metadata.ftype != "directory" && !(metadata.ftype == "link" && metadata.links == :manage)
        copy_source_value(:checksum)
      end

      # Take each of the stats and set them as states on the local file
      # if a value has not already been provided.
      [:owner, :mode, :group].each do |metadata_method|
        next if metadata_method == :owner and !Puppet.features.root?
        next if metadata_method == :group and !Puppet.features.root?

        case resource[:source_permissions]
        when :ignore
          next
        when :use_when_creating
          next if Puppet::FileSystem.exist?(resource[:path])
        end

        copy_source_value(metadata_method)
      end

      if resource[:ensure] == :absent
        # We know all we need to
      elsif metadata.ftype != "link"
        resource[:ensure] = metadata.ftype
      elsif resource[:links] == :follow
        resource[:ensure] = :present
      else
        resource[:ensure] = "link"
        resource[:target] = metadata.destination
      end
    end

    attr_writer :metadata

    # Provide, and retrieve if necessary, the metadata for this file.  Fail
    # if we can't find data about this host, and fail if there are any
    # problems in our query.
    def metadata
      return @metadata if @metadata

      if @metadata = resource.catalog.metadata[resource.title]
        return @metadata
      end

      return nil unless value
      value.each do |source|
        begin
          options = {
            :environment          => resource.catalog.environment_instance,
            :links                => resource[:links],
            :checksum_type        => resource[:checksum],
            :source_permissions   => resource[:source_permissions]
          }

          if data = Puppet::FileServing::Metadata.indirection.find(source, options)
            @metadata = data
            @metadata.source = source
            break
          end
        rescue => detail
          self.fail Puppet::Error, "Could not retrieve file metadata for #{source}: #{detail}", detail
        end
      end
      self.fail "Could not retrieve information from environment #{resource.catalog.environment} source(s) #{value.join(", ")}" unless @metadata
      @metadata
    end

    def local?
      found? and scheme == "file"
    end

    def full_path
      Puppet::Util.uri_to_path(uri) if found?
    end

    def server?
       uri and uri.host
    end

    def server
      (uri and uri.host) or Puppet.settings[:server]
    end

    def port
      (uri and uri.port) or Puppet.settings[:masterport]
    end

    def uri
      @uri ||= URI.parse(Puppet::Util.uri_encode(metadata.source))
    end

    def write(file)
      resource.parameter(:checksum).sum_stream { |sum|
        each_chunk_from { |chunk|
          sum << chunk
          file.print chunk
        }
      }
    end

    private

    def scheme
      (uri and uri.scheme)
    end

    def found?
      ! (metadata.nil? or metadata.ftype.nil?)
    end

    def copy_source_value(metadata_method)
      param_name = (metadata_method == :checksum) ? :content : metadata_method
      if resource[param_name].nil? or resource[param_name] == :absent
        if Puppet.features.microsoft_windows? && [:owner, :group, :mode].include?(metadata_method)
          devfail "Should not have tried to use source owner/mode/group on Windows"
        end

        value = metadata.send(metadata_method)
        # Force the mode value in file resources to be a string containing octal.
        value = value.to_s(8) if param_name == :mode && value.is_a?(Numeric)
        resource[param_name] = value

        if (metadata_method == :checksum)
          # If copying checksum, also copy checksum_type
          resource[:checksum] = metadata.checksum_type
        end
      end
    end

    def each_chunk_from
      if Puppet[:default_file_terminus] == :file_server
        yield content
      elsif local?
        chunk_file_from_disk { |chunk| yield chunk }
      else
        chunk_file_from_source { |chunk| yield chunk }
      end
    end

    def chunk_file_from_disk
      File.open(full_path, "rb") do |src|
        while chunk = src.read(8192)
          yield chunk
        end
      end
    end

    def get_from_puppet_source(source_uri, content_uri, &block)
      options = { :environment => resource.catalog.environment_instance }
      if content_uri
        options[:code_id] = resource.catalog.code_id
        request = Puppet::Indirector::Request.new(:static_file_content, :find, content_uri, nil, options)
      else
        request = Puppet::Indirector::Request.new(:file_content, :find, source_uri, nil, options)
      end

      request.do_request(:fileserver) do |req|
        connection = Puppet::Network::HttpPool.http_instance(req.server, req.port)
        connection.request_get(Puppet::Network::HTTP::API::IndirectedRoutes.request_to_uri(req), add_accept_encoding({"Accept" => BINARY_MIME_TYPES}), &block)
      end
    end

    def get_from_http_source(source_uri, &block)
      Puppet::Util::HttpProxy.request_with_redirects(URI(source_uri), :get, &block)
    end

    def get_from_source(&block)
      source_uri = metadata.source
      if source_uri =~ /^https?:/
        get_from_http_source(source_uri, &block)
      else
        get_from_puppet_source(source_uri, metadata.content_uri, &block)
      end
    end


    def chunk_file_from_source
      get_from_source do |response|
        case response.code
        when /^2/;  uncompress(response) { |uncompressor| response.read_body { |chunk| yield uncompressor.uncompress(chunk) } }
        else
          # Raise the http error if we didn't get a 'success' of some kind.
          message = "Error #{response.code} on SERVER: #{(response.body||'').empty? ? response.message : uncompress_body(response)}"
          raise Net::HTTPError.new(message, response)
        end
      end
    end
  end

  Puppet::Type.type(:file).newparam(:source_permissions) do
    desc <<-'EOT'
      Whether (and how) Puppet should copy owner, group, and mode permissions from
      the `source` to `file` resources when the permissions are not explicitly
      specified. (In all cases, explicit permissions will take precedence.)
      Valid values are `use`, `use_when_creating`, and `ignore`:

      * `ignore` (the default) will never apply the owner, group, or mode from
        the `source` when managing a file. When creating new files without explicit
        permissions, the permissions they receive will depend on platform-specific
        behavior. On POSIX, Puppet will use the umask of the user it is running as.
        On Windows, Puppet will use the default DACL associated with the user it is
        running as.
      * `use` will cause Puppet to apply the owner, group,
        and mode from the `source` to any files it is managing.
      * `use_when_creating` will only apply the owner, group, and mode from the
        `source` when creating a file; existing files will not have their permissions
        overwritten.
    EOT

    defaultto :ignore
    newvalues(:use, :use_when_creating, :ignore)
  end
end
