module Puppet
    Puppet::Type.type(:file).newproperty(:owner) do
        include Puppet::Util::POSIX
        include Puppet::Util::Warnings

        require 'etc'
        desc "To whom the file should belong.  Argument can be user name or
            user ID."
        @event = :file_changed

        def id2name(id)
            return id.to_s if id.is_a?(Symbol)
            return nil if id > Puppet[:maximum_uid].to_i

            begin
                user = Etc.getpwuid(id)
            rescue TypeError
                return nil
            rescue ArgumentError
                return nil
            end

            if user.uid == ""
                return nil
            else
                return user.name
            end
        end

        def insync?(current)
            return true unless should

            @should.each do |value|
                if value =~ /^\d+$/
                    uid = Integer(value)
                elsif value.is_a?(String)
                    fail "Could not find user %s" % value unless uid = uid(value)
                else
                    uid = value
                end

                return true if uid == current
            end

            unless Puppet::Util::SUIDManager.uid == 0
                warnonce "Cannot manage ownership unless running as root"
                return true
            end

            return false
        end

        # Determine if the user is valid, and if so, return the UID
        def validuser?(value)
            begin
                number = Integer(value)
                return number
            rescue ArgumentError
                number = nil
            end
            if number = uid(value)
                return number
            else
                return false
            end
        end

        # We want to print names, not numbers
        def is_to_s(currentvalue)
            id2name(currentvalue) || currentvalue
        end

        def should_to_s(newvalue = @should)
            case newvalue
            when Symbol
                newvalue.to_s
            when Integer
                id2name(newvalue) || newvalue
            when String
                newvalue
            else
                raise Puppet::DevError, "Invalid uid type %s(%s)" %
                    [newvalue.class, newvalue]
            end
        end

        def retrieve
            if self.should
                @should = @should.collect do |val|
                    unless val.is_a?(Integer)
                        if tmp = validuser?(val)
                            val = tmp
                        else
                            raise "Could not find user %s" % val
                        end
                    else
                        val
                    end
                end
            end

            unless stat = @resource.stat(false)
                return :absent
            end

            currentvalue = stat.uid

            # On OS X, files that are owned by -2 get returned as really
            # large UIDs instead of negative ones.  This isn't a Ruby bug,
            # it's an OS X bug, since it shows up in perl, too.
            if currentvalue > Puppet[:maximum_uid].to_i
                self.warning "Apparently using negative UID (%s) on a platform that does not consistently handle them" % currentvalue
                currentvalue = :silly
            end

            return currentvalue
        end

        def sync
            # Set our method appropriately, depending on links.
            if resource[:links] == :manage
                method = :lchown
            else
                method = :chown
            end

            uid = nil
            @should.each do |user|
                break if uid = validuser?(user)
            end

            raise Puppet::Error, "Could not find user(s) %s" % @should.join(",") unless uid

            begin
                File.send(method, uid, nil, @resource[:path])
            rescue => detail
                raise Puppet::Error, "Failed to set owner to '%s': %s" % [uid, detail]
            end

            return :file_changed
        end
    end
end

