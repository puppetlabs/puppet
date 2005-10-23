module Puppet
    class State
        class PFileUID < Puppet::State
            require 'etc'
            @doc = "To whom the file should belong.  Argument can be user name or
                user ID."
            @name = :owner
            @event = :inode_changed

            def id2name(id)
                begin
                    user = Etc.getpwuid(id)
                rescue ArgumentError
                    return nil
                end
                if user.uid == ""
                    return nil
                else
                    return user.name
                end
            end

            # We want to print names, not numbers
            def is_to_s
                id2name(@is) || @is
            end

            def should_to_s
                id2name(self.should) || self.should
            end

            def retrieve
                unless stat = @parent.stat(true)
                    @is = :notfound
                    return
                end

                self.is = stat.uid
            end

            # If we're not root, we can check the values but we cannot change them
            def shouldprocess(value)
                if value.is_a?(Integer)
                    # verify the user is a valid user
                    begin
                        user = Etc.getpwuid(value)
                        if user.uid == ""
                            error = Puppet::Error.new(
                                "Could not retrieve uid for '%s'" %
                                    @parent.name)
                            raise error
                        end
                    rescue ArgumentError => detail
                        raise Puppet::Error.new("User ID %s does not exist" %
                            value
                        )
                    rescue => detail
                        raise Puppet::Error.new(
                            "Could not find user '%s': %s" % [value, detail])
                        raise error
                    end
                else
                    begin
                        user = Etc.getpwnam(value)
                        if user.uid == ""
                            error = Puppet::Error.new(
                                "Could not retrieve uid for '%s'" %
                                    @parent.name)
                            raise error
                        end
                        value = user.uid
                    rescue ArgumentError => detail
                        raise Puppet::Error.new("User %s does not exist" %
                            value
                        )
                    rescue => detail
                        error = Puppet::Error.new(
                            "Could not find user '%s': %s" % [value, detail])
                        raise error
                    end
                end

                return value
            end

            def sync
                unless Process.uid == 0
                    unless defined? @@notifieduid
                        Puppet.notice "Cannot manage ownership unless running as root"
                        #@parent.delete(self.name)
                        @@notifieduid = true
                    end
                    # there's a possibility that we never got retrieve() called
                    # e.g., if the file didn't exist
                    # thus, just delete ourselves now and don't do any work
                    #@parent.delete(self.name)
                    return nil
                end

                if @is == :notfound
                    @parent.stat(true)
                    self.retrieve
                    if @is == :notfound
                        Puppet.err "File '%s' does not exist; cannot chown" %
                            @parent[:path]
                        return nil
                    end
                    if self.insync?
                        return nil
                    end
                    #Puppet.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                begin
                    File.chown(self.should,nil,@parent[:path])
                rescue => detail
                    raise Puppet::Error, "Failed to set owner of '%s' to '%s': %s" %
                        [@parent[:path],self.should,detail]
                end

                return :inode_changed
            end
        end
    end
end

# $Id$
