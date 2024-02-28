# frozen_string_literal: true

require_relative '../../../puppet/file_serving/content'
require_relative '../../../puppet/file_serving/metadata'
require_relative '../../../puppet/file_serving/terminus_helper'

require_relative '../../../puppet/http'

module Puppet
  # Copy files from a local or remote source.  This state *only* does any work
  # when the remote file is an actual file; in that case, this state copies
  # the file down.  If the remote file is a dir or a link or whatever, then
  # this state, during retrieval, modifies the appropriate other states
  # so that things get taken care of appropriately.
  Puppet::Type.type(:file).newparam(:source) do
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
      * `http(s):` URIs, which point to files served by common web servers.

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

      _HTTP_ URIs cannot be used to recursively synchronize whole directory
      trees. You cannot use `source_permissions` values other than `ignore`
      because HTTP servers do not transfer any metadata that translates to
      ownership or permission details.

      Puppet determines if file content is synchronized by computing a checksum
      for the local file and comparing it against the `checksum_value`
      parameter. If the `checksum_value` parameter is not specified for
      `puppet` and `file` sources, Puppet computes a checksum based on its
      `Puppet[:digest_algorithm]`. For `http(s)` sources, Puppet uses the
      first HTTP header it recognizes out of the following list:
      `X-Checksum-Sha256`, `X-Checksum-Sha1`, `X-Checksum-Md5` or `Content-MD5`.
      If the server response does not include one of these headers, Puppet
      defaults to using the `Last-Modified` header. Puppet updates the local
      file if the header is newer than the modified time (mtime) of the local
      file.

      _HTTP_ URIs can include a user information component so that Puppet can
      retrieve file metadata and content from HTTP servers that require HTTP Basic
      authentication. For example `https://<user>:<pass>@<server>:<port>/path/to/file.`

      When connecting to _HTTPS_ servers, Puppet trusts CA certificates in the
      puppet-agent certificate bundle and the Puppet CA. You can configure Puppet
      to trust additional CA certificates using the `Puppet[:ssl_trust_store]`
      setting.

      Multiple `source` values can be specified as an array, and Puppet will
      use the first source that exists. This can be used to serve different
      files to different system types:

          file { '/etc/nfs.conf':
            source => [
              "puppet:///modules/nfs/conf.${host}",
              "puppet:///modules/nfs/conf.${os['name']}",
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
        unless %w[file puppet http https].include?(uri.scheme)
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
          # Puppet::Util.uri_unescape always returns strings in the original encoding
          Puppet::Util.uri_unescape(uri_string.encode(Encoding::UTF_8))
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
        when :ignore, nil
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
      @metadata ||= resource.catalog.metadata[resource.title]
      return @metadata if @metadata

      return nil unless value

      value.each do |source|
        begin
          options = {
            :environment => resource.catalog.environment_instance,
            :links => resource[:links],
            :checksum_type => resource[:checksum],
            :source_permissions => resource[:source_permissions]
          }

          data = Puppet::FileServing::Metadata.indirection.find(source, options)
          if data
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
      uri && uri.host && !uri.host.empty?
    end

    def server
      server? ? uri.host : Puppet.settings[:server]
    end

    def port
      (uri and uri.port) or Puppet.settings[:serverport]
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
      !(metadata.nil? or metadata.ftype.nil?)
    end

    def copy_source_value(metadata_method)
      param_name = (metadata_method == :checksum) ? :content : metadata_method
      if resource[param_name].nil? or resource[param_name] == :absent
        if Puppet::Util::Platform.windows? && [:owner, :group, :mode].include?(metadata_method)
          devfail "Should not have tried to use source owner/mode/group on Windows"
        end

        value = metadata.send(metadata_method)
        # Force the mode value in file resources to be a string containing octal.
        value = value.to_s(8) if param_name == :mode && value.is_a?(Numeric)
        resource[param_name] = value

        if metadata_method == :checksum
          # If copying checksum, also copy checksum_type
          resource[:checksum] = metadata.checksum_type
        end
      end
    end

    def each_chunk_from(&block)
      if Puppet[:default_file_terminus] == :file_server && scheme == 'puppet' && (uri.host.nil? || uri.host.empty?)
        chunk_file_from_disk(metadata.full_path, &block)
      elsif local?
        chunk_file_from_disk(full_path, &block)
      else
        chunk_file_from_source(&block)
      end
    end

    def chunk_file_from_disk(local_path)
      File.open(local_path, "rb") do |src|
        while chunk = src.read(8192) # rubocop:disable Lint/AssignmentInCondition
          yield chunk
        end
      end
    end

    def get_from_content_uri_source(url, &block)
      session = Puppet.lookup(:http_session)
      api = session.route_to(:fileserver, url: url)

      api.get_static_file_content(
        path: Puppet::Util.uri_unescape(url.path),
        environment: resource.catalog.environment_instance.to_s,
        code_id: resource.catalog.code_id,
        &block
      )
    end

    def get_from_source_uri_source(url, &block)
      session = Puppet.lookup(:http_session)
      api = session.route_to(:fileserver, url: url)

      api.get_file_content(
        path: Puppet::Util.uri_unescape(url.path),
        environment: resource.catalog.environment_instance.to_s,
        &block
      )
    end

    def get_from_http_source(url, &block)
      client = Puppet.runtime[:http]
      client.get(url, options: { include_system_store: true }) do |response|
        raise Puppet::HTTP::ResponseError, response unless response.success?

        response.read_body(&block)
      end
    end

    def chunk_file_from_source(&block)
      if uri.scheme =~ /^https?/
        # Historically puppet has not encoded the http(s) source URL before parsing
        # it, for example, if the path contains spaces, then it must be URL encoded
        # as %20 in the manifest. Puppet behaves the same when retrieving file
        # metadata via http(s), see Puppet::Indirector::FileMetadata::Http#find.
        url = URI.parse(metadata.source)
        get_from_http_source(url, &block)
      elsif metadata.content_uri
        content_url = URI.parse(Puppet::Util.uri_encode(metadata.content_uri))
        get_from_content_uri_source(content_url, &block)
      else
        get_from_source_uri_source(uri, &block)
      end
    rescue Puppet::HTTP::ResponseError => e
      handle_response_error(e.response)
    end

    def handle_response_error(response)
      message = "Error #{response.code} on SERVER: #{response.body.empty? ? response.reason : response.body}"
      raise Net::HTTPError.new(message, Puppet::HTTP::ResponseConverter.to_ruby_response(response))
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
    munge do |value|
      value = value ? value.to_sym : :ignore
      if @resource.file && @resource.line && value != :ignore
        # TRANSLATORS "source_permissions" is a parameter name and should not be translated
        Puppet.puppet_deprecation_warning(_("The `source_permissions` parameter is deprecated. Explicitly set `owner`, `group`, and `mode`."), file: @resource.file, line: @resource.line)
      end

      value
    end
  end
end
