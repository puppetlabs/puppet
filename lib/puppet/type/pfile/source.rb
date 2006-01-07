module Puppet
    class State
        # Copy files from a local or remote source.
        class PFileSource < Puppet::State
            attr_accessor :source, :local
            @doc = "Copy a file over the current file.  Uses `checksum` to
                determine when a file should be copied.  Valid values are either
                fully qualified paths to files, or URIs.  Currently supported URI
                types are *puppet* and *file*."
            @name = :source

            # Ask the file server to describe our file.
            def describe(source)
                sourceobj, path = @parent.uri2obj(source)
                server = sourceobj.server

                begin
                    desc = server.describe(path)
                rescue NetworkClientError => detail
                    self.err "Could not describe %s: %s" %
                        [path, detail]
                    return nil
                end

                args = {}
                Puppet::Type::PFile::PINPARAMS.zip(
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

                # If we're a normal file, then set things up to copy the file down.
                case @stats[:type]
                when "file":
                    if sum = @parent.state(:checksum)
                        if sum.is
                            if sum.is == :notfound
                                sum.retrieve
                            end
                            @is = sum.is
                        else
                            @is = :notfound
                        end
                    else
                        self.info "File does not have checksum"
                        @is = :notfound
                    end

                    @should = [@stats[:checksum]]

                    if state = @parent.state(:create)
                        unless state.should == "file"
                            self.notice(
                                "File %s had both create and source enabled" %
                                    @parent.name
                            )
                            @parent.delete(:create)
                        end
                    end
                # If we're a directory, then do not copy anything, and instead just
                # create the directory using the 'create' state.
                when "directory":
                    if state = @parent.state(:create)
                        unless state.should == "directory"
                            state.should = "directory"
                        end
                    else
                        @parent[:create] = "directory"
                        @parent.state(:create).retrieve
                    end
                    # we'll let the :create state do our work
                    @should.clear
                    @is = true
                # FIXME We should at least support symlinks, I would think...
                else
                    self.err "Cannot use files of type %s as sources" %
                        @stats[:type]
                    @should = nil
                    @is = true
                end
            end

            # The special thing here is that we need to make sure that 'should'
            # is only set for files, not directories.  The processing we're doing
            # here doesn't really matter, because the @should values will be
            # overridden when we 'retrieve'.
            def shouldprocess(source)
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

                unless @stats[:type] == "file"
                    if @stats[:type] == "directory"
                            [@parent.name, @is.inspect, @should.inspect]
                    end
                    raise Puppet::DevError, "Got told to copy non-file %s" %
                        @parent.name
                end

                unless defined? @source
                    raise Puppet::DevError, "Somehow source is still undefined"
                end

                sourceobj, path = @parent.uri2obj(@source)

                begin
                    contents = sourceobj.server.retrieve(path)
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

                if FileTest.exists?(@parent.name)
                    # this makes sure we have a copy for posterity
                    @backed = @parent.handlebackup
                end

                # create the file in a tmp location
                args = [@parent.name + ".puppettmp", 
                    File::CREAT | File::WRONLY | File::TRUNC]

                # try to create it with the correct modes to start
                # we should also be changing our effective uid/gid, but...
                if @parent.should(:mode) and @parent.should(:mode) != :notfound
                    args.push @parent.should(:mode)
                end

                # FIXME we should also change our effective user and group id

                begin
                    File.open(*args) { |f|
                        f.print contents
                    }
                rescue => detail
                    # since they said they want a backup, let's error out
                    # if we couldn't make one
                    raise Puppet::Error, "Could not create %s to %s: %s" %
                        [@source, @parent.name, detail.message]
                end

                if FileTest.exists?(@parent.name)
                    begin
                        File.unlink(@parent.name)
                    rescue => detail
                        self.err "Could not remove %s for replacing: %s" %
                            [@parent.name, detail]
                    end
                end

                begin
                    File.rename(@parent.name + ".puppettmp", @parent.name)
                rescue => detail
                    self.err "Could not rename tmp %s for replacing: %s" %
                        [@parent.name, detail]
                end

                return :file_changed
            end
        end
    end
end

# $Id$
