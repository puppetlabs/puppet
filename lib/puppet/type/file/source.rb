
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
            unless @resource.uri2obj(source)
                raise Puppet::Error, "Invalid source %s" % source
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
                return "creating from source %s with contents %s" % [@source, @metadata.checksum]
            else
                return "replacing from source %s with contents %s" % [@source, @metadata.checksum]
            end
        end
        
        def checksum
            if defined?(@metadata)
                @metadata.checksum
            else
                nil
            end
        end

        # Copy the values from the source to the resource.  Yay.
        def copy_source_values
            devfail "Somehow got asked to copy source values without any metadata" unless metadata

            # Take each of the stats and set them as states on the local file
            # if a value has not already been provided.
            [:owner, :mode, :group].each do |param|
                @resource[param] ||= metadata.send(param)
            end

            unless @resource.deleting?
                @resource[:ensure] = metadata.ftype
            end

            if metadata.ftype == "link"
                @resource[:target] = metadata.destination
            end
        end

        # Ask the file server to describe our file.
        def describe(source)
            begin
                Puppet::FileServing::Metadata.find source
            rescue => detail
                fail detail, "Could not retrieve file metadata for %s: %s" % [path, detail]
            end
        end
        
        # Use the info we get from describe() to check if we're in sync.
        def insync?(currentvalue)
            if currentvalue == :nocopy
                return true
            end
            
            # the only thing this actual state can do is copy files around.  Therefore,
            # only pay attention if the remote is a file.
            unless @metadata.ftype == "file" 
                return true
            end
            
            #FIXARB: Inefficient?  Needed to call retrieve on parent's ensure and checksum
            parentensure = @resource.property(:ensure).retrieve
            if parentensure != :absent and ! @resource.replace?
                return true
            end
            # Now, we just check to see if the checksums are the same
            parentchecksum = @resource.property(:checksum).retrieve
            result = (!parentchecksum.nil? and (parentchecksum == @metadata.checksum))

            # Diff the contents if they ask it.  This is quite annoying -- we need to do this in
            # 'insync?' because they might be in noop mode, but we don't want to do the file
            # retrieval twice, so we cache the value.
            if ! result and Puppet[:show_diff] and File.exists?(@resource[:path]) and ! @metadata._diffed
                @metadata._remote_content = get_remote_content
                string_file_diff(@resource[:path], @metadata._remote_content)
                @metadata._diffed = true
            end
            return result
        end

        def pinparams
            [:mode, :type, :owner, :group]
        end

        def found?
            ! (@metadata.nil? or @metadata.ftype.nil?)
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

        def retrieve
            copy_source_values
        end
        
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
            exists = File.exists?(@resource[:path])

            if content = Puppet::FileServing::Content.find(@metadata.source)
                @resource.write(content.content, :source, @metadata.checksum)
            else
                raise "Could not retrieve content"
            end

            if exists
                return :file_changed
            else
                return :file_created
            end
        end
    end
end
