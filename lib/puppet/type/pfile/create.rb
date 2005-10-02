module Puppet
    class State
        class PFileCreate < Puppet::State
            require 'etc'
            @doc = "Whether to create files that don't currently exist.
                **false**/*true*/*file*/*directory*"
            @name = :create
            @event = :file_created

            def shouldprocess(value)
                # default to just about anything meaning 'true'
                case value
                when "false", false, nil:
                    return false
                when "true", true, "file", "plain", /^f/:
                    return "file"
                when "directory", /^d/:
                    return "directory"
                when :notfound:
                    # this is where a creation is being rolled back
                    return :notfound
                else
                    raise Puppet::Error, "Cannot create files of type %s" % value
                end
            end

            def retrieve
                if stat = @parent.stat(true)
                    @is = stat.ftype
                else
                    @is = :notfound
                end

                #Puppet.debug "'exists' state is %s" % self.is
            end


            def sync
                event = nil
                mode = @parent.should(:mode)
                begin
                    case self.should
                    when "file":
                        # just create an empty file
                        if mode
                            File.open(@parent[:path],"w", mode) {
                            }
                            @parent.delete(:mode)
                        else
                            File.open(@parent[:path],"w") {
                            }
                        end
                        event = :file_created
                    when "directory":
                        if mode
                            Dir.mkdir(@parent.name,mode)
                            @parent.delete(:mode)
                        else
                            Dir.mkdir(@parent.name)
                        end
                        event = :directory_created
                    when :notfound:
                        # this is where the file should be deleted...
                        unless FileTest.size(@parent.name) == 0
                            raise Puppet::Error.new(
                                "Created file %s has since been modified; cannot roll back."
                            )
                        end

                        File.unlink(@parent.name)
                    else
                        error = Puppet::Error.new(
                            "Somehow got told to create a %s file" % self.should)
                        raise error
                    end
                rescue => detail
                    raise Puppet::Error.new("Could not create %s: %s" %
                        [self.should, detail]
                    )
                end
                return event
            end
        end
    end
end

# $Id$
