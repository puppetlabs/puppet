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
            # newvalue = "{md5}" + @stats[:checksum]
            if @resource.property(:ensure).retrieve == :absent
                return "creating from source %s with contents %s" % [@source, @stats[:checksum]]
            else
                return "replacing from source %s with contents %s" % [@source, @stats[:checksum]]
            end
        end
        
        def checksum
            if defined?(@stats)
                @stats[:checksum]
            else
                nil
            end
        end

        # Ask the file server to describe our file.
        def describe(source)
            sourceobj, path = @resource.uri2obj(source)
            server = sourceobj.server

            begin
                desc = server.describe(path, @resource[:links])
            rescue Puppet::Network::XMLRPCClientError => detail
                fail detail, "Could not describe %s: %s" % [path, detail]
            end

            return nil if desc == ""

            # Collect everything except the checksum
            values = desc.split("\t")
            other = values.pop
            args = {}
            pinparams.zip(values).each { |param, value|
                if value =~ /^[0-9]+$/
                    value = value.to_i
                end
                unless value.nil?
                    args[param] = value
                end
            }

            # Now decide whether we're doing checksums or symlinks
            if args[:type] == "link"
                args[:target] = other
            else
                args[:checksum] = other
            end

            # we can't manage ownership unless we're root, so don't even try
            unless Puppet::Util::SUIDManager.uid == 0
                args.delete(:owner)
            end
            
            return args
        end
        
        # Use the info we get from describe() to check if we're in sync.
        def insync?(currentvalue)
            if currentvalue == :nocopy
                return true
            end
            
            # the only thing this actual state can do is copy files around.  Therefore,
            # only pay attention if the remote is a file.
            unless @stats[:type] == "file" 
                return true
            end
            
            #FIXARB: Inefficient?  Needed to call retrieve on parent's ensure and checksum
            parentensure = @resource.property(:ensure).retrieve
            if parentensure != :absent and ! @resource.replace?
                return true
            end
            # Now, we just check to see if the checksums are the same
            parentchecksum = @resource.property(:checksum).retrieve
            result = (!parentchecksum.nil? and (parentchecksum == @stats[:checksum]))

            # Diff the contents if they ask it.  This is quite annoying -- we need to do this in
            # 'insync?' because they might be in noop mode, but we don't want to do the file
            # retrieval twice, so we cache the value.
            if ! result and Puppet[:show_diff] and File.exists?(@resource[:path]) and ! @stats[:_diffed]
                @stats[:_remote_content] = get_remote_content
                string_file_diff(@resource[:path], @stats[:_remote_content])
                @stats[:_diffed] = true
            end
            return result
        end

        def pinparams
            [:mode, :type, :owner, :group]
        end

        def found?
            ! (@stats.nil? or @stats[:type].nil?)
        end

        # This basically calls describe() on our file, and then sets all
        # of the local states appropriately.  If the remote file is a normal
        # file then we set it to copy; if it's a directory, then we just mark
        # that the local directory should be created.
        def retrieve(remote = true)
            sum = nil
            @source = nil

            # This is set to false by the File#retrieve function on the second
            # retrieve, so that we do not do two describes.
            if remote
                # Find the first source that exists.  @shouldorig contains
                # the sources as specified by the user.
                @should.each { |source|
                    if @stats = self.describe(source)
                        @source = source
                        break
                    end
                }
            end

            if !found?
                raise Puppet::Error, "No specified source was found from" + @should.inject("") { |s, source| s + " #{source},"}.gsub(/,$/,"")
            end
            
            case @stats[:type]
            when "directory", "file", "link":
                @resource[:ensure] = @stats[:type] unless @resource.deleting?
            else
                self.info @stats.inspect
                self.err "Cannot use files of type %s as sources" % @stats[:type]
                return :nocopy
            end

            # Take each of the stats and set them as states on the local file
            # if a value has not already been provided.
            @stats.each { |stat, value|
                next if stat == :checksum
                next if stat == :type

                # was the stat already specified, or should the value
                # be inherited from the source?
                @resource[stat] = value unless @resource.argument?(stat)
            }

            return @stats[:checksum]
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
            contents = @stats[:_remote_content] || get_remote_content()

            exists = File.exists?(@resource[:path])

            @resource.write(contents, :source, @stats[:checksum])

            if exists
                return :file_changed
            else
                return :file_created
            end
        end

        private

        def get_remote_content
            raise Puppet::DevError, "Got told to copy non-file %s" % @resource[:path] unless @stats[:type] == "file"

            sourceobj, path = @resource.uri2obj(@source)

            begin
                contents = sourceobj.server.retrieve(path, @resource[:links])
            rescue => detail
                self.fail "Could not retrieve %s: %s" % [path, detail]
            end

            contents = CGI.unescape(contents) unless sourceobj.server.local

            if contents == ""
                self.notice "Could not retrieve contents for %s" % @source
            end

            return contents
        end
    end
end
