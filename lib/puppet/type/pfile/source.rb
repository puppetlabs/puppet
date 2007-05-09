module Puppet
    # Copy files from a local or remote source.  This state *only* does any work
    # when the remote file is an actual file; in that case, this state copies
    # the file down.  If the remote file is a dir or a link or whatever, then
    # this state, during retrieval, modifies the appropriate other states
    # so that things get taken care of appropriately.
    Puppet.type(:file).newproperty(:source) do

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
            to ``follow`` if any remote sources are links."

        uncheckable
        
        validate do |source|
            unless @parent.uri2obj(source)
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
            if @parent.property(:ensure).retrieve == :absent
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
            sourceobj, path = @parent.uri2obj(source)
            server = sourceobj.server

            begin
                desc = server.describe(path, @parent[:links])
            rescue Puppet::Network::XMLRPCClientError => detail
                self.err "Could not describe %s: %s" %
                    [path, detail]
                return nil
            end

            args = {}
            pinparams.zip(
                desc.split("\t")
            ).each { |param, value|
                if value =~ /^[0-9]+$/
                    value = value.to_i
                end
                unless value.nil?
                    args[param] = value
                end
            }

            # we can't manage ownership as root, so don't even try
            unless Puppet::Util::SUIDManager.uid == 0
                args.delete(:owner)
            end

            if args.empty? or (args[:type] == "link" and @parent[:links] == :ignore)
                return nil
            else
                return args
            end
        end
        
        # Have we successfully described the remote source?
        def described?
            ! @stats.nil? and ! @stats[:type].nil? #and @is != :notdescribed
        end
        
        # Use the info we get from describe() to check if we're in sync.
        def insync?(currentvalue)
            unless described?
                info "No specified sources exist"
                return true
            end
            
            if currentvalue == :nocopy
                return true
            end
            
            # the only thing this actual state can do is copy files around.  Therefore,
            # only pay attention if the remote is a file.
            unless @stats[:type] == "file" 
                return true
            end
            
            #FIXARB: Inefficient?  Needed to call retrieve on parent's ensure and checksum
            parentensure = @parent.property(:ensure).retrieve
            if parentensure != :absent and ! @parent.replace?
                return true
            end
            # Now, we just check to see if the checksums are the same
            parentchecksum = @parent.property(:checksum).retrieve
            a = (!parentchecksum.nil? and (parentchecksum == @stats[:checksum]))
            return (!parentchecksum.nil? and (parentchecksum == @stats[:checksum]))
        end

        def pinparams
            Puppet::Network::Handler.handler(:fileserver).params
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

            if @stats.nil? or @stats[:type].nil?
                return nil # :notdescribed
            end
            
            case @stats[:type]
            when "directory", "file":
                unless @parent.deleting?
                    @parent[:ensure] = @stats[:type]
                end
            else
                self.info @stats.inspect
                self.err "Cannot use files of type %s as sources" %
                    @stats[:type]
                return :nocopy
            end

            # Take each of the stats and set them as states on the local file
            # if a value has not already been provided.
            @stats.each { |stat, value|
                next if stat == :checksum
                next if stat == :type

                # was the stat already specified, or should the value
                # be inherited from the source?
                unless @parent.argument?(stat)
                    @parent[stat] = value
                    @parent.property(stat).retrieve  # FIXARB: This is calling retrieve on all propertis of File.  What are we gonna do with the return values?
                end
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
            
            @parent[:check] = checks
            unless @parent.property(:checksum)
                @parent[:checksum] = :md5
            end
        end

        def sync
            unless @stats[:type] == "file"
                #if @stats[:type] == "directory"
                        #[@parent.name, @should.inspect]
                #end
                raise Puppet::DevError, "Got told to copy non-file %s" %
                    @parent[:path]
            end

            sourceobj, path = @parent.uri2obj(@source)

            begin
                contents = sourceobj.server.retrieve(path, @parent[:links])
            rescue Puppet::Network::XMLRPCClientError => detail
                self.err "Could not retrieve %s: %s" %
                    [path, detail]
                return nil
            end

            # FIXME It's stupid that this isn't taken care of in the
            # protocol.
            unless sourceobj.server.local
                contents = CGI.unescape(contents)
            end

            if contents == ""
                self.notice "Could not retrieve contents for %s" %
                    @source
            end
            exists = File.exists?(@parent[:path])

            @parent.write { |f| f.print contents }

            if exists
                return :file_changed
            else
                return :file_created
            end
        end
    end
end

# $Id$
