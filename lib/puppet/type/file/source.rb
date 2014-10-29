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
    desc <<-'EOT'
      A source file, which will be copied into place on the local system.
      Values can be URIs pointing to remote files, or fully qualified paths to
      files available on the local system (including files on NFS shares or
      Windows mapped drives). This attribute is mutually exclusive with
      `content` and `target`.

      The available URI schemes are *puppet* and *file*. *Puppet*
      URIs will retrieve files from Puppet's built-in file server, and are
      usually formatted as:

      `puppet:///modules/name_of_module/filename`

      This will fetch a file from a module on the puppet master (or from a
      local module when using puppet apply). Given a `modulepath` of
      `/etc/puppetlabs/puppet/modules`, the example above would resolve to
      `/etc/puppetlabs/puppet/modules/name_of_module/files/filename`.

      Unlike `content`, the `source` attribute can be used to recursively copy
      directories if the `recurse` attribute is set to `true` or `remote`. If
      a source directory contains symlinks, use the `links` attribute to
      specify whether to recreate links or follow them.

      Multiple `source` values can be specified as an array, and Puppet will
      use the first source that exists. This can be used to serve different
      files to different system types:

          file { "/etc/nfs.conf":
            source => [
              "puppet:///modules/nfs/conf.$host",
              "puppet:///modules/nfs/conf.$operatingsystem",
              "puppet:///modules/nfs/conf"
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
          uri = URI.parse(URI.escape(source))
        rescue => detail
          self.fail Puppet::Error, "Could not understand source #{source}: #{detail}", detail
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
      raise Puppet::DevError, "No source for content was stored with the metadata" unless metadata.source

      unless tmp = Puppet::FileServing::Content.indirection.find(metadata.source, :environment => resource.catalog.environment, :links => resource[:links])
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

        if Puppet.features.microsoft_windows?
          # Warn on Windows if source permissions are being used and the file resource
          # does not have mode owner and group all set (which would take precedence).
          if [:use, :use_when_creating].include?(resource[:source_permissions]) &&
            (resource[:owner] == nil || resource[:group] == nil || resource[:mode] == nil)

            warning = "Copying %s from the source" <<
                      " file on Windows is deprecated;" <<
                      " use source_permissions => ignore."
            Puppet.deprecation_warning(warning % 'owner/mode/group')
            resource.debug(warning % metadata_method.to_s)
          end
          # But never try to copy remote owner/group on Windows
          next if [:owner, :group].include?(metadata_method) && !local?
        end

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
      return nil unless value
      value.each do |source|
        begin
          options = {
            :environment          => resource.catalog.environment_instance,
            :links                => resource[:links],
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
      @uri ||= URI.parse(URI.escape(metadata.source))
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
        value = metadata.send(metadata_method)
        # Force the mode value in file resources to be a string containing octal.
        value = value.to_s(8) if param_name == :mode && value.is_a?(Numeric)
        resource[param_name] = value
      end
    end
  end

  Puppet::Type.type(:file).newparam(:source_permissions) do
    desc <<-'EOT'
      Whether (and how) Puppet should copy owner, group, and mode permissions from
      the `source` to `file` resources when the permissions are not explicitly
      specified. (In all cases, explicit permissions will take precedence.)
      Valid values are `use`, `use_when_creating`, and `ignore`:

      * `use` (the default) will cause Puppet to apply the owner, group,
        and mode from the `source` to any files it is managing.
      * `use_when_creating` will only apply the owner, group, and mode from the
        `source` when creating a file; existing files will not have their permissions
        overwritten.
      * `ignore` will never apply the owner, group, or mode from the `source` when
        managing a file. When creating new files without explicit permissions,
        the permissions they receive will depend on platform-specific behavior.
        On POSIX, Puppet will use the umask of the user it is running as. On
        Windows, Puppet will use the default DACL associated with the user it is
        running as.
    EOT

    defaultto :use
    newvalues(:use, :use_when_creating, :ignore)
  end
end
