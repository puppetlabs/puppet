# Manage file group ownership.
module Puppet
    Puppet.type(:file).newstate(:group) do
        require 'etc'
        desc "Which group should own the file.  Argument can be either group
            name or group ID."
        @event = :file_changed

        def id2name(id)
            if id > 70000
                return nil
            end
            if id.is_a?(Symbol)
                return id.to_s
            end
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
            if @is.is_a? Integer
                id2name(@is) || @is
            else
                return @is.to_s
            end
        end

        def should_to_s
            should = self.should
            if should.is_a? Integer
                id2name(should) || should
            else
                return should.to_s
            end
        end

        def retrieve
            stat = @parent.stat(false)

            unless stat
                self.is = :absent
                return
            end

            # Set our method appropriately, depending on links.
            if stat.ftype == "link" and @parent[:links] != :follow
                @method = :lchown
            else
                @method = :chown
            end
            self.is = stat.gid
        end

        # Determine if the group is valid, and if so, return the GID
        def validgroup?(value)
            if value =~ /^\d+$/
                value = value.to_i
            end
        
            if gid = Puppet::Util.gid(value)
                return gid
            else
                return false
            end
        end
        
        munge do |value|
            if val = validgroup?(value)
                return val
            else
                return value
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
                    self.debug "File '%s' does not exist; cannot chgrp" %
                        @parent[:path]
                    return nil
                end

                if self.insync?
                    return nil
                end
            end

            gid = nil
            unless gid = Puppet::Util.gid(self.should)
                raise Puppet::Error, "Could not find group %s" % self.should
            end

            begin
                # set owner to nil so it's ignored
                File.send(@method,nil,gid,@parent[:path])
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
