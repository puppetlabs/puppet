module Puppet
    Puppet.type(:file).newstate(:content) do
        desc "Specify the contents of a file as a string.  Newlines, tabs, and
            spaces can be specified using the escaped syntax (e.g., \\n for a
            newline).  The primary purpose of this parameter is to provide a
            kind of limited templating:

                define resolve(nameserver1, nameserver2, domain, search) {
                    $str = \"search $search
                domain $domain
                nameserver $nameserver1
                nameserver $nameserver2
                \"

                    file { \"/etc/resolv.conf\":
                        content => $str
                    }
                }
            
                This attribute is especially useful when used with
                [templating](templating.html)."

        def change_to_s
            "synced"
        end

        # We should probably take advantage of existing md5 sums if they're there,
        # but I really don't feel like dealing with the complexity right now.
        def retrieve
            stat = nil
            unless stat = @parent.stat
                return :absent
            end

            if stat.ftype == "link" and @parent[:links] == :ignore
                return self.should
            end

            # Don't even try to manage the content on directories
            if stat.ftype == "directory" and @parent[:links] == :ignore
                @parent.delete(:content)
                return :notmanaged
            end

            begin
                retval = File.read(@parent[:path])
            rescue => detail
                retval = :unknown
                raise Puppet::Error, "Could not read %s: %s" %
                    [@parent.title, detail]
            end

            return retval
        end


        # Just write our content out to disk.
        def sync(value)
            @parent.write { |f| f.print value }

            if self.is == :absent
                return :file_created
            else
                return :file_changed
            end
        end
    end
end

# $Id$
