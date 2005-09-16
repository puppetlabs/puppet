module Puppet
    class Type
        def self.posixmethod
            if defined? @posixmethod and @posixmethod
                return @posixmethod
            else
                return @name
            end
        end
    end

    module NameService
        # This is the base module for basically all of the NSS stuff.  It
        # should be able to retrieve the info for almost any system, but
        # it can't create any information on its own.  You need to define
        # a subclass of these classes to actually modify the system.
        module POSIX
            class POSIXState < Puppet::State
                def self.doc
                    if defined? @extender
                        @extender.doc
                    else
                        nil
                    end
                end

                def self.posixmethod
                    if defined? @extender
                        if @extender.respond_to?(:posixmethod)
                        else
                            return @name
                        end
                    else
                        return @name
                    end
                end

                def self.name
                    @extender.name
                end
                # we use the POSIX interfaces to retrieve all information,
                # so we don't have to worry about abstracting that across
                # the system
                def retrieve
                    if obj = @parent.getinfo(true)

                        method = self.class.posixmethod
                        @is = obj.send(method)
                    else
                        @is = :notfound
                    end

                end
                def sync
                    obj = @parent.getinfo

                    # if the object needs to be created or deleted,
                    # depend on another method to do it all at once
                    if @is == :notfound or @should == :notfound
                        return syncname()
                    end

                    if obj.nil?
                        raise Puppet::DevError,
                            "%s %s does not exist; cannot set %s" %
                            [@parent.class.name, @parent.name, self.class.name]
                    end

                    # this needs to be set either by the individual state
                    # or its parent class
                    cmd = self.modifycmd

                    output = %x{#{cmd} 2>&1}

                    unless $? == 0
                        raise Puppet::Error, "Could not modify %s on %s %s: %s" %
                            [self.class.name, @parent.class.name,
                                @parent.name, output]
                    end

                    return "#{@parent.class.name}_modified".intern
                end

                private
                def syncname
                    obj = @parent.getinfo
                    
                    cmd = nil
                    event = nil
                    if @should == :notfound
                        # we need to remove the object...
                        if obj.nil?
                            # the group already doesn't exist
                            return nil
                        end

                        # again, needs to be set by the ind. state or its
                        # parent
                        cmd = self.deletecmd
                        type = "delete"
                    else
                        unless obj.nil?
                            raise Puppet::DevError,
                                "Got told to create a %s that already exists" %
                                @parent.class.name
                        end

                        # blah blah, define elsewhere, blah blah
                        cmd = self.addcmd
                        type = "create"
                    end

                    output = %x{#{cmd} 2>&1}

                    unless $? == 0
                        raise Puppet::Error, "Could not %s %s %s: %s" %
                            [type, @parent.class.name, @parent.name, output]
                    end

                    return "#{@parent.class.name}_#{type}d".intern
                end

                class POSIXGID
                end
            end
        end
    end
end
