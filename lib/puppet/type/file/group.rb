require 'puppet/util/posix'

# Manage file group ownership.
module Puppet
    Puppet::Type.type(:file).newproperty(:group) do
        include Puppet::Util::POSIX

        require 'etc'
        desc "Which group should own the file.  Argument can be either group
            name or group ID."
        @event = :file_changed

        validate do |group|
            raise(Puppet::Error, "Invalid group name '%s'" % group.inspect) unless group and group != ""
        end

        def id2name(id)
            return id.to_s if id.is_a?(Symbol)
            return nil if id > Puppet[:maximum_uid].to_i
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
        def is_to_s(currentvalue)
            if currentvalue.is_a? Integer
                id2name(currentvalue) || currentvalue
            else
                return currentvalue.to_s
            end
        end

        def should_to_s(newvalue = @should)
            if newvalue.is_a? Integer
                id2name(newvalue) || newvalue
            else
                return newvalue.to_s
            end
        end

        def insync?(current)
            @should.each do |value|
                if value =~ /^\d+$/
                    gid = Integer(value)
                elsif value.is_a?(String)
                    fail "Could not find group %s" % value unless gid = gid(value)
                else
                    gid = value
                end

                return true if gid == current
            end
            return false
        end

        def retrieve
            return :absent unless stat = resource.stat(false)

            currentvalue = stat.gid

            # On OS X, files that are owned by -2 get returned as really
            # large GIDs instead of negative ones.  This isn't a Ruby bug,
            # it's an OS X bug, since it shows up in perl, too.
            if currentvalue > Puppet[:maximum_uid].to_i
                self.warning "Apparently using negative GID (%s) on a platform that does not consistently handle them" % currentvalue
                currentvalue = :silly
            end

            return currentvalue
        end

        # Determine if the group is valid, and if so, return the GID
        def validgroup?(value)
            begin
                number = Integer(value)
                return number
            rescue ArgumentError
                number = nil
            end
            if number = gid(value)
                return number
            else
                return false
            end
        end

        # Normal users will only be able to manage certain groups.  Right now,
        # we'll just let it fail, but we should probably set things up so
        # that users get warned if they try to change to an unacceptable group.
        def sync
            # Set our method appropriately, depending on links.
            if resource[:links] == :manage
                method = :lchown
            else
                method = :chown
            end

            gid = nil
            @should.each do |group|
                break if gid = validgroup?(group)
            end

            raise Puppet::Error, "Could not find group(s) %s" % @should.join(",") unless gid

            begin
                # set owner to nil so it's ignored
                File.send(method, nil, gid, resource[:path])
            rescue => detail
                error = Puppet::Error.new( "failed to chgrp %s to %s: %s" % [resource[:path], gid, detail.message])
                raise error
            end
            return :file_changed
        end
    end
end
