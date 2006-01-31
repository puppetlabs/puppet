# Manage file group ownership.
module Puppet
    Puppet.type(:file).newstate(:group) do
        require 'etc'
        desc "Which group should own the file.  Argument can be either group
            name or group ID."
        @event = :file_changed

        def id2name(id)
            begin
                group = Etc.getgrgid(id)
            rescue ArgumentError
                return nil
            end
            if group.gid == ""
                return nil
            else
                return group.name
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
            stat = @parent.stat(false)

            if stat
                self.is = stat.gid
            else
                self.is = :absent
            end
        end

        munge do |value|
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
            #        self.notice "Cannot chgrp: not in group %s" % gname
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
            if @is == :absent
                @parent.stat(true)
                self.retrieve

                if @is == :absent
                    self.info "File '%s' does not exist; cannot chgrp" %
                        @parent[:path]
                    return nil
                end

                if self.insync?
                    return nil
                end
            end

            begin
                # set owner to nil so it's ignored
                File.chown(nil,self.should,@parent[:path])
            rescue => detail
                error = Puppet::Error.new( "failed to chgrp %s to %s: %s" %
                    [@parent[:path], self.should, detail.message])
                raise error
            end
            return :file_changed
        end
    end
end

# $Id$
