
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
        desc "Copy a file over the current file.  Uses ``checksum`` to
            determine when a file should be copied.  Valid values are either
            fully qualified paths to files, or URIs.  Currently supported URI
            types are *puppet* and *file*.

            This is one of the primary mechanisms for getting content into
            applications that Puppet does not directly support and is very
            useful for those configuration files that don't change much across
            sytems.  For instance::

                class sendmail {
                    file { \"/etc/mail/sendmail.cf\":
                        source => \"puppet://server/modules/module_name/sendmail.cf\"
                    }
                }

            You can also leave out the server name, in which case ``puppetd``
            will fill in the name of its configuration server and ``puppet``
            will use the local filesystem.  This makes it easy to use the same
            configuration in both local and centralized forms.

            Currently, only the ``puppet`` scheme is supported for source
            URL's. Puppet will connect to the file server running on
            ``server`` to retrieve the contents of the file. If the
            ``server`` part is empty, the behavior of the command-line
            interpreter (``puppet``) and the client demon (``puppetd``) differs
            slightly: ``puppet`` will look such a file up on the module path
            on the local host, whereas ``puppetd`` will connect to the
            puppet server that it received the manifest from.

            See the `FileServingConfiguration fileserver configuration documentation`:trac: for information on how to configure
            and use file services within Puppet.

            If you specify multiple file sources for a file, then the first
            source that exists will be used.  This allows you to specify
            what amount to search paths for files::

                file { \"/path/to/my/file\":
                    source => [
                        \"/modules/nfs/files/file.$host\",
                        \"/modules/nfs/files/file.$operatingsystem\",
                        \"/modules/nfs/files/file\"
                    ]
                }

            This will use the first found file as the source.

            You cannot currently copy links using this mechanism; set ``links``
            to ``follow`` if any remote sources are links.
            "

        validate do |sources|
            sources = [sources] unless sources.is_a?(Array)
            sources.each do |source|
                begin
                    uri = URI.parse(URI.escape(source))
                rescue => detail
                    self.fail "Could not understand source %s: %s" % [source, detail.to_s]
                end

                unless uri.scheme.nil? or %w{file puppet}.include?(uri.scheme)
                    self.fail "Cannot use URLs of type '%s' as source for fileserving" % [uri.scheme]
                end
            end
        end

        munge do |sources|
            sources = [sources] unless sources.is_a?(Array)
            sources.collect { |source| source.sub(/\/$/, '') }
        end

        def change_to_s(currentvalue, newvalue)
            # newvalue = "{md5}" + @metadata.checksum
            if @resource.property(:ensure).retrieve == :absent
                return "creating from source %s with contents %s" % [metadata.source, metadata.checksum]
            else
                return "replacing from source %s with contents %s" % [metadata.source, metadata.checksum]
            end
        end

        def checksum
            metadata && metadata.checksum
        end

        # Look up (if necessary) and return remote content.
        cached_attr(:content) do
            raise Puppet::DevError, "No source for content was stored with the metadata" unless metadata.source

            unless tmp = Puppet::FileServing::Content.find(metadata.source)
                fail "Could not find any content at %s" % metadata.source
            end
            tmp.content
        end

        # Copy the values from the source to the resource.  Yay.
        def copy_source_values
            devfail "Somehow got asked to copy source values without any metadata" unless metadata

            # Take each of the stats and set them as states on the local file
            # if a value has not already been provided.
            [:owner, :mode, :group, :checksum].each do |param|
                next if param == :owner and Puppet::Util::SUIDManager.uid != 0
                next if param == :checksum and metadata.ftype == "directory"
                unless value = resource[param] and value != :absent
                    resource[param] = metadata.send(param)
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

        def pinparams
            [:mode, :type, :owner, :group, :content]
        end

        def found?
            ! (metadata.nil? or metadata.ftype.nil?)
        end

        # Provide, and retrieve if necessary, the metadata for this file.  Fail
        # if we can't find data about this host, and fail if there are any
        # problems in our query.
        cached_attr(:metadata) do
            return nil unless value
            result = nil
            value.each do |source|
                begin
                    if data = Puppet::FileServing::Metadata.find(source)
                        result = data
                        result.source = source
                        break
                    end
                rescue => detail
                    fail detail, "Could not retrieve file metadata for %s: %s" % [source, detail]
                end
            end
            fail "Could not retrieve information from source(s) %s" % value.join(", ") unless result
            result
        end

        # Make sure we're also checking the checksum
        def value=(value)
            super

            checks = (pinparams + [:ensure])
            checks.delete(:checksum)

            resource[:check] = checks
            resource[:checksum] = :md5 unless resource.property(:checksum)
        end
    end
end
