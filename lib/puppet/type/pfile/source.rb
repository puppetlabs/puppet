module Puppet
    # Copy files from a local or remote source.
    Puppet.type(:file).newstate(:source) do
        PINPARAMS = [:mode, :type, :owner, :group, :checksum]

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
            
            See the `fileserver docs`_ for information on how to configure
            and use file services within Puppet.


            .. _fileserver docs: /projects/puppet/documentation/fsconfigref

            "

        # Ask the file server to describe our file.
        def describe(source)
            sourceobj, path = @parent.uri2obj(source)
            server = sourceobj.server

            begin
                desc = server.describe(path, @parent[:links])
            rescue NetworkClientError => detail
                self.err "Could not describe %s: %s" %
                    [path, detail]
                return nil
            end

            args = {}
            PINPARAMS.zip(
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
            unless Process.uid == 0
                args.delete(:owner)
            end

            if args.empty?
                return nil
            else
                return args
            end
        end

        # This basically calls describe() on our file, and then sets all
        # of the local states appropriately.  If the remote file is a normal
        # file then we set it to copy; if it's a directory, then we just mark
        # that the local directory should be created.
        def retrieve
            sum = nil

            unless defined? @shouldorig
                raise Puppet::DevError, "No sources defined for %s" %
                    @parent.name
            end

            @source = nil
            
            # Find the first source that exists.  @shouldorig contains
            # the sources as specified by the user.
            @shouldorig.each { |source|
                if @stats = self.describe(source)
                    @source = source
                    break
                end
            }

            if @stats.nil? or @stats[:type].nil?
                @is = :notdescribed
                @source = nil
                return nil
            end

            # If we're a normal file, then set things up to copy the file down.
            case @stats[:type]
            when "file":
                if sum = @parent.state(:checksum)
                    if sum.is
                        if sum.is == :absent
                            sum.retrieve
                        end
                        @is = sum.is
                    else
                        @is = :absent
                    end
                else
                    self.info "File does not have checksum"
                    @is = :absent
                end

                @should = [@stats[:checksum]]
            # If we're a directory, then do not copy anything, and instead just
            # create the directory using the 'create' state.
            when "directory":
                if state = @parent.state(:ensure)
                    unless state.should == "directory"
                        state.should = "directory"
                    end
                else
                    @parent[:ensure] = "directory"
                    @parent.state(:ensure).retrieve
                end
                # we'll let the :ensure state do our work
                @should.clear
                @is = true
            when "link":
                case @parent[:links]
                when :ignore
                    @is = :nocopy
                    @should = [:nocopy]
                    self.info "Ignoring link %s" % @source
                    return
                when :follow
                    @stats = self.describe(source, :follow)
                    if @stats.empty?
                        raise Puppet::Error, "Could not follow link %s" % @source
                    end
                when :copy
                    raise Puppet::Error, "Cannot copy links yet"
                end
            else
                self.err "Cannot use files of type %s as sources" %
                    @stats[:type]
                @should = [:nocopy]
                @is = :nocopy
            end

            # Take each of the stats and set them as states on the local file
            # if a value has not already been provided.
            @stats.each { |stat, value|
                next if stat == :checksum
                next if stat == :type

                # was the stat already specified, or should the value
                # be inherited from the source?
                unless @parent.argument?(stat)
                    if state = @parent.state(stat)
                        state.should = value
                    else
                        @parent[stat] = value
                    end
                end
            }
        end

        # The special thing here is that we need to make sure that 'should'
        # is only set for files, not directories.  The processing we're doing
        # here doesn't really matter, because the @should values will be
        # overridden when we 'retrieve'.
        munge do |source|
            # Remove any trailing slashes
            source.sub!(/\/$/, '')
            unless @parent.uri2obj(source)
                raise Puppet::Error, "Invalid source %s" % source
            end

            if ! defined? @stats or @stats.nil?
                # stupid hack for now; it'll get overriden
                return source
            else
                if @stats[:type] == "directory"
                    @is = true
                    return nil
                else
                    return source
                end
            end
        end

        def sync
            if @is == :notdescribed
                self.retrieve # try again
                if @is == :notdescribed
                    @parent.log "Could not retreive information on %s" %
                        @parent.name
                    return nil
                end
                if @is == @should
                    return nil
                end
            end

            case @stats[:type]
            when "link":
            end
            unless @stats[:type] == "file"
                #if @stats[:type] == "directory"
                        #[@parent.name, @is.inspect, @should.inspect]
                #end
                raise Puppet::DevError, "Got told to copy non-file %s" %
                    @parent[:path]
            end

            unless defined? @source
                raise Puppet::DevError, "Somehow source is still undefined"
            end

            sourceobj, path = @parent.uri2obj(@source)

            begin
                contents = sourceobj.server.retrieve(path, @parent[:links])
            rescue NetworkClientError => detail
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

            if FileTest.exists?(@parent[:path])
                # this makes sure we have a copy for posterity
                @backed = @parent.handlebackup
            end

            # create the file in a tmp location
            args = [@parent[:path] + ".puppettmp", 
                File::CREAT | File::WRONLY | File::TRUNC]

            # try to create it with the correct modes to start
            # we should also be changing our effective uid/gid, but...
            if @parent.should(:mode) and @parent.should(:mode) != :absent
                args.push @parent.should(:mode)
            end

            # FIXME we should also change our effective user and group id

            exists = File.exists?(@parent[:path])
            begin
                File.open(*args) { |f|
                    f.print contents
                }
            rescue => detail
                # since they said they want a backup, let's error out
                # if we couldn't make one
                raise Puppet::Error, "Could not create %s to %s: %s" %
                    [@source, @parent[:path], detail.message]
            end

            if FileTest.exists?(@parent[:path])
                begin
                    File.unlink(@parent[:path])
                rescue => detail
                    self.err "Could not remove %s for replacing: %s" %
                        [@parent[:path], detail]
                end
            end

            begin
                File.rename(@parent[:path] + ".puppettmp", @parent[:path])
            rescue => detail
                self.err "Could not rename tmp %s for replacing: %s" %
                    [@parent[:path], detail]
            end

            if @stats.include? :checksum
                @parent.setchecksum @stats[:checksum]
            else
                raise Puppet::DevError, "We're somehow missing the remote checksum"
            end

            if exists
                return :file_changed
            else
                return :file_created
            end
        end
    end
end

# $Id$
