
require 'puppet/file_serving/content'
require 'puppet/file_serving/metadata'

module Puppet
    # Copy files from a local or remote source.  This state *only* does any work
    # when the remote file is an actual file; in that case, this state copies
    # the file down.  If the remote file is a dir or a link or whatever, then
    # this state, during retrieval, modifies the appropriate other states
    # so that things get taken care of appropriately.
    Puppet.type(:file).newproperty(:source) do
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
                        source => \"puppet://server/module/sendmail.cf\"
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
                        \"/nfs/files/file.$host\",
                        \"/nfs/files/file.$operatingsystem\",
                        \"/nfs/files/file\"
                    ]
                }
            
            This will use the first found file as the source.
            
            You cannot currently copy links using this mechanism; set ``links``
            to ``follow`` if any remote sources are links.
            "

        uncheckable
        
        validate do |source|
            begin
                uri = URI.parse(URI.escape(source))
            rescue => detail
                self.fail "Could not understand source %s: %s" % [source, detail.to_s]
            end

            unless uri.scheme.nil? or %w{file puppet}.include?(uri.scheme)
                self.fail "Cannot use URLs of type '%s' as source for fileserving" % [uri.scheme]
            end
        end
            
        munge do |source|
            # if source.is_a? Symbol
            #     return source
            # end

            # Remove any trailing slashes
            source.sub(/\/$/, '')
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
            if defined?(@metadata)
                @metadata.checksum
            else
                nil
            end
        end

        # Look up (if necessary) and return remote content.
        def content
            raise Puppet::DevError, "No source for content was stored with the metadata" unless metadata.source

            unless defined?(@content) and @content
                unless tmp = Puppet::FileServing::Content.find(metadata.source)
                    fail "Could not find any content at %s" % metadata.source
                end
                @content = tmp.content
            end
            @content
        end

        # Copy the values from the source to the resource.  Yay.
        def copy_source_values
            devfail "Somehow got asked to copy source values without any metadata" unless metadata

            # Take each of the stats and set them as states on the local file
            # if a value has not already been provided.
            [:owner, :mode, :group, :checksum].each do |param|
                next if param == :owner and Puppet::Util::SUIDManager.uid != 0
                unless value = @resource[param] and value != :absent
                    @resource[param] = metadata.send(param)
                end
            end

            @resource[:ensure] = metadata.ftype

            if metadata.ftype == "link"
                @resource[:target] = metadata.destination
            end
        end

        # Remove any temporary attributes we manage.
        def flush
            @metadata = nil
            @content = nil
        end

        # Use the remote metadata to see if we're in sync.
        # LAK:NOTE This method should still get refactored.
        def insync?(currentvalue)
            # the only thing this actual state can do is copy files around.  Therefore,
            # only pay attention if the remote is a file.
            return true unless metadata.ftype == "file" 
            
            # The file is not in sync if it doesn't even exist.
            return false unless resource.stat
            
            # The file is considered in sync if it exists and 'replace' is false.
            return true unless resource.replace?

            # Now, we just check to see if the checksums are the same
            parentchecksum = @resource.property(:checksum).retrieve
            result = (!parentchecksum.nil? and (parentchecksum == metadata.checksum))

            # Diff the contents if they ask it.  This is quite annoying -- we need to do this in
            # 'insync?' because they might be in noop mode, but we don't want to do the file
            # retrieval twice, so we cache the value.
            if ! result and Puppet[:show_diff] and File.exists?(@resource[:path])
                string_file_diff(@resource[:path], content)
            end
            return result
        end

        def pinparams
            [:mode, :type, :owner, :group]
        end

        def found?
            ! (metadata.nil? or metadata.ftype.nil?)
        end

        # Provide, and retrieve if necessary, the metadata for this file.  Fail
        # if we can't find data about this host, and fail if there are any
        # problems in our query.
        attr_writer :metadata
        def metadata
            unless defined?(@metadata) and @metadata
                return @metadata = nil unless should
                should.each do |source|
                    begin
                        if data = Puppet::FileServing::Metadata.find(source)
                            @metadata = data
                            @metadata.source = source
                            break
                        end
                    rescue => detail
                        fail detail, "Could not retrieve file metadata for %s: %s" % [source, detail]
                    end
                end
                fail "Could not retrieve information from source(s) %s" % @should.join(", ") unless @metadata
            end
            return @metadata
        end

        # Just call out to our copy method.  Hopefully we'll refactor 'source' to
        # be a parameter soon, in which case 'retrieve' is unnecessary.
        def retrieve
            copy_source_values
        end
        
        # Return the whole array, rather than the first item.
        def should
            @should
        end
        
        # Make sure we're also checking the checksum
        def should=(value)
            super

            checks = (pinparams + [:ensure])
            checks.delete(:checksum)
            
            @resource[:check] = checks
            @resource[:checksum] = :md5 unless @resource.property(:checksum)
        end

        def sync
            exists = FileTest.exist?(@resource[:path])

            @resource.write(content, :source, @metadata.checksum)

            if exists
                return :file_changed
            else
                return :file_created
            end
        end
    end
end
