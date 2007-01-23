module Puppet
    Puppet.type(:file).newstate(:owner) do
        require 'etc'
        desc "To whom the file should belong.  Argument can be user name or
            user ID."
        @event = :file_changed

        def id2name(id)
            if id.is_a?(Symbol)
                return id.to_s
            end
            if id > 70000
                return nil
            end
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

        def name2id(value)
            if value.is_a?(Symbol)
                return value.to_s
            end
            begin
                user = Etc.getpwnam(value)
                if user.uid == ""
                    return nil
                end
                return user.uid
            rescue ArgumentError => detail
                return nil
            end
        end

        # Determine if the user is valid, and if so, return the UID
        def validuser?(value)
            if value =~ /^\d+$/
                value = value.to_i
            end

            if value.is_a?(Integer)
                # verify the user is a valid user
                if tmp = id2name(value)
                    return value
                else
                    return false
                end
            else
                if tmp = name2id(value)
                    return tmp
                else
                    return false
                end
            end
        end

        # We want to print names, not numbers
        def is_to_s
            id2name(@is) || @is
        end

        def should_to_s
            case self.should
            when Symbol
                self.should.to_s
            when Integer
                id2name(self.should) || self.should
            when String
                self.should
            else
                raise Puppet::DevError, "Invalid uid type %s(%s)" %
                    [self.should.class, self.should]
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
            
            unless stat = @parent.stat(false)
                @is = :absent
                return
            end

            # Set our method appropriately, depending on links.
            if stat.ftype == "link" and @parent[:links] != :follow
                @method = :lchown
            else
                @method = :chown
            end

            self.is = stat.uid

            # On OS X, files that are owned by -2 get returned as really
            # large UIDs instead of negative ones.  This isn't a Ruby bug,
            # it's an OS X bug, since it shows up in perl, too.
            if @is > 120000
                self.warning "current state is silly: %s" % @is
                @is = :silly
            end
        end

        def sync
            unless Puppet::SUIDManager.uid == 0
                unless defined? @@notifieduid
                    self.notice "Cannot manage ownership unless running as root"
                    #@parent.delete(self.name)
                    @@notifieduid = true
                end
                return nil
            end

            user = nil
            unless user = self.validuser?(self.should)
                tmp = self.should
                unless defined? @@usermissing
                    @@usermissing = {}
                end

                if @@usermissing.include?(tmp)
                    @@usermissing[tmp] += 1
                else
                    self.notice "user %s does not exist" % tmp
                    @@usermissing[tmp] = 1
                end
                return nil
            end

            if @is == :absent
                @parent.stat(true)
                self.retrieve
                if @is == :absent
                    self.debug "File does not exist; cannot set owner"
                    return nil
                end
                if self.insync?
                    return nil
                end
                #self.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
            end

            begin
                File.send(@method, user, nil, @parent[:path])
            rescue => detail
                raise Puppet::Error, "Failed to set owner to '%s': %s" %
                    [user, detail]
            end

            return :file_changed
        end
    end
end

# $Id$
