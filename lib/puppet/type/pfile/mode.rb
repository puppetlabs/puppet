# Manage file modes.  This state should support different formats
# for specification (e.g., u+rwx, or -0011), but for now only supports
# specifying the full mode.
module Puppet
    class State
        class PFileMode < Puppet::State
            require 'etc'
            @doc = "Mode the file should be.  Currently relatively limited:
                you must specify the exact mode the file should be."
            @name = :mode
            @event = :inode_changed

            # Our modes are octal, so make sure they print correctly.
            def is_to_s
                if @is.is_a?(Integer)
                    return "%o" % @is
                else
                    return @is
                end
            end

            def should_to_s
                if @should.is_a?(Integer)
                    return "%o" % @should
                else
                    return @should
                end
            end

            def shouldprocess(should)
                # this is pretty hackish, but i need to make sure the number is in
                # octal, yet the number can only be specified as a string right now
                value = should
                if value.is_a?(String)
                    unless value =~ /^0/
                        value = "0" + value
                    end
                    value = Integer(value)
                end

                #self.warning "Should is %o from %s" % [value, should]

                return value
            end

            # If we're a directory, we need to be executable for all cases
            # that are readable.  This should probably be selectable, but eh.
            def dirmask(value)
                if FileTest.directory?(@parent.name)
                    if value & 0400 != 0
                        value |= 0100
                    end
                    if value & 040 != 0
                        value |= 010
                    end
                    if value & 04 != 0
                        value |= 01
                    end
                end

                return value
            end

            def retrieve
                if stat = @parent.stat(true)
                    self.is = stat.mode & 007777
                    unless defined? @fixed
                        if defined? @should and @should
                            @should = @should.collect { |s| self.dirmask(s) }
                        end
                    end
                else
                    self.is = :notfound
                end

                #self.debug "chmod state is %o" % self.is
            end

            def sync
                if @is == :notfound
                    @parent.stat(true)
                    self.retrieve
                    #self.debug "%s: after refresh, is '%s'" % [self.class.name,@is]
                    if @is == :notfound
                        self.info "File does not exist; cannot set mode" %
                            @parent.name
                        return nil
                    end

                    if self.insync?
                        # we're already in sync
                        return nil
                    end
                end

                mode = self.should

                if mode == :notfound
                    # This is really only valid for create states...
                    return nil
                end

                begin
                    File.chmod(mode,@parent[:path])
                rescue => detail
                    error = Puppet::Error.new("failed to chmod %s: %s" %
                        [@parent.name, detail.message])
                    raise error
                end
                return :inode_changed
            end
        end
    end
end

# $Id$
