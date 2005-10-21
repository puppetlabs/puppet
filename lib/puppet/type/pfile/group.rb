# Manage file group ownership.
module Puppet
    class State
        class PFileGroup < Puppet::State
            require 'etc'
            @doc = "Which group should own the file.  Argument can be either group
                name or group ID."
            @name = :group
            @event = :inode_changed

            def retrieve
                stat = @parent.stat(true)

                self.is = stat.gid
            end

            def shouldprocess(value)
                method = nil
                gid = nil
                gname = nil

                if value.is_a?(Integer)
                    method = :getgrgid
                else
                    method = :getgrnam
                end

                begin
                    group = Etc.send(method,value)

                    # at one time, os x was putting the gid into the passwd
                    # field of the group struct, but that appears to not
                    # be the case any more
                    #os = Puppet::Fact["Operatingsystem"]
                    #case os
                    #when "Darwin":
                    #    #gid = group.passwd
                    #    gid = group.gid
                    #else
                    #end

                    gid = group.gid
                    gname = group.name

                rescue ArgumentError => detail
                    raise Puppet::Error.new(
                        "Could not find group %s" % value)
                rescue => detail
                    raise Puppet::Error.new(
                        "Could not find group %s: %s" % [self.should,detail])
                end
                if gid.nil?
                    raise Puppet::Error.new(
                        "Could not retrieve gid for %s" % @parent.name)
                end

                #unless Process.uid == 0
                #    groups = %x{groups}.chomp.split(/\s/)
                #    unless groups.include?(gname)
                #        Puppet.notice "Cannot chgrp: not in group %s" % gname
                #        raise Puppet::Error.new(
                #            "Cannot chgrp: not in group %s" % gname)
                #    end
                #end

                if gid.nil?
                    raise Puppet::Error.new(
                        "Nil gid for %s" % @parent.name)
                else
                    return gid
                end
            end

            # Normal users will only be able to manage certain groups.  Right now,
            # we'll just let it fail, but we should probably set things up so
            # that users get warned if they try to change to an unacceptable group.
            def sync
                # now make sure the user is allowed to change to that group
                # We don't do this in the should section, so it can still be used
                # for noop.
                unless Process.uid == 0
                    unless defined? @@notifiedgroup
                        Puppet.notice(  
                            "Cannot manage group ownership unless running as root"
                        )
                        @@notifiedgroup = true
                    end
                    return nil
                end

                if @is == :notfound
                    @parent.stat(true)
                    self.retrieve
                    #Puppet.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                end

                unless @parent.stat
                    Puppet.err "File '%s' does not exist; cannot chgrp" %
                        @parent[:path]
                    return nil
                end

                begin
                    # set owner to nil so it's ignored
                    File.chown(nil,self.should,@parent[:path])
                rescue => detail
                    error = Puppet::Error.new( "failed to chgrp %s to %s: %s" %
                        [@parent[:path], self.should, detail.message])
                    raise error
                end
                return :inode_changed
            end
        end
    end
end

# $Id$
