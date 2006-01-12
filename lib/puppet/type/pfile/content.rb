module Puppet
    Puppet.type(:file).newstate(:content) do
        desc "Specify the contents of a file as a string.  Newlines, tabs, and spaces
            can be specified using the escaped syntax (e.g., \\n for a newline).  The
            primary purpose of this parameter is to provide a kind of limited
            templating."

        def change_to_s
            "synced"
        end

        # We should probably take advantage of existing md5 sums if they're there,
        # but I really don't feel like dealing with the complexity right now.
        def retrieve
            unless FileTest.exists?(@parent.name)
                @is = :notfound
                return
            end
            begin
                @is = File.read(@parent.name)
            rescue => detail
                @is = nil
                raise Puppet::Error, "Could not read %s: %s" %
                    [@parent.name, detail]
            end
        end


        # Just write our content out to disk.
        def sync
            begin
                File.open(@parent.name, "w") { |f|
                    f.print self.should
                    f.flush
                }
            rescue => detail
                raise Puppet::Error, "Could not write content to %s: %s" %
                    [@parent.name, detail]
            end

            if @is == :notfound
                return :file_created
            else
                return :file_changed
            end
        end
    end
end

# $Id$
