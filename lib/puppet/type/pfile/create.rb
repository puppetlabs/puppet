module Puppet
    Puppet.type(:file).newstate(:create) do
        require 'etc'
        desc "Whether to create files that don't currently exist.
            **false**/*true*/*file*/*directory*"

        @event = :file_created

        munge do |value|
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

            #self.debug "'exists' state is %s" % self.is
        end


        def sync
            event = nil
            mode = @parent.should(:mode)

            # First, determine if a user has been specified and if so if
            # that user has write access to the parent dir
            asuser = nil
            if @parent.should(:owner) and ! @parent.should(:owner).is_a?(Symbol)
                writeable = Puppet::Util.asuser(@parent.should(:owner)) {
                    FileTest.writable?(File.dirname(@parent[:path]))
                }

                # If the parent directory is writeable, then we execute
                # as the user in question.  Otherwise we'll rely on
                # the 'owner' state to do things.
                if writeable
                    asuser = @parent.should(:owner)
                end
            end
            begin
                case self.should
                when "file":
                    # just create an empty file
                    Puppet::Util.asuser(asuser, @parent.should(:group)) {
                        if mode
                            File.open(@parent[:path],"w", mode) {
                            }
                        else
                            File.open(@parent[:path],"w") {
                            }
                        end
                    }
                    event = :file_created
                when "directory":
                    Puppet::Util.asuser(asuser) {
                        if mode
                            Dir.mkdir(@parent.name,mode)
                        else
                            Dir.mkdir(@parent.name)
                        end
                    }
                    event = :directory_created
                when :notfound:
                    # this is where the file should be deleted...

                    # This value is only valid when we're rolling back a creation,
                    # so we verify that the file has not been modified since then.
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

# $Id$
