require 'puppet/server/fileserver'

module Puppet
    # Copy files from a local or remote source.
    Puppet.type(:file).newstate(:source) do
        PINPARAMS = Puppet::Server::FileServer::CHECKPARAMS

        attr_accessor :source, :local
        desc "Copy a file over the current file.  Uses ``checksum`` to
            determine when a file should be copied.  Valid values are either
            fully qualified paths to files, or URIs.  Currently supported URI
            types are *puppet* and *file*.

            This is one of the primary mechanisms for getting content into
            applications that Puppet does not directly support and is very
            useful for those configuration files that don't change much across
            sytems.  For instance:

                class sendmail {
                    file { \"/etc/mail/sendmail.cf\":
                        source => \"puppet://server/module/sendmail.cf\"
                    }
                }
            
            See the [fileserver docs][] for information on how to configure
            and use file services within Puppet.

            If you specify multiple file sources for a file, then the first
            source that exists will be used.  This allows you to specify
            what amount to search paths for files:

                file { \"/path/to/my/file\":
                    source => [
                        \"/nfs/files/file.$host\",
                        \"/nfs/files/file.$operatingsystem\",
                        \"/nfs/files/file\"
                    ]
                }
            
            This will use the first found file as the source.

            [fileserver docs]: fsconfigref.html

            "

        uncheckable

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
        def retrieve(remote = true)
            sum = nil

            unless defined? @shouldorig
                raise Puppet::DevError, "No sources defined for %s" %
                    @parent.title
            end

            @source = nil unless defined? @source

            # This is set to false by the File#retrieve function on the second
            # retrieve, so that we do not do two describes.
            if remote
                @source = nil
                # Find the first source that exists.  @shouldorig contains
                # the sources as specified by the user.
                @shouldorig.each { |source|
                    if @stats = self.describe(source)
                        @source = source
                        break
                    end
                }
            end

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
                            sum.retrieve(true)
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
                self.info @stats.inspect
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
                #else
                #    @parent.info "Already specified %s" % stat
                end
            }
        end

        # The special thing here is that we need to make sure that 'should'
        # is only set for files, not directories.  The processing we're doing
        # here doesn't really matter, because the @should values will be
        # overridden when we 'retrieve'.
        munge do |source|
            if source.is_a? Symbol
                return source
            end

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
                        @parent.title
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
