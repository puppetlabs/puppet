module Puppet
    Puppet.type(:file).newproperty(:content) do
        desc "Specify the contents of a file as a string.  Newlines, tabs, and
            spaces can be specified using the escaped syntax (e.g., \\n for a
            newline).  The primary purpose of this parameter is to provide a
            kind of limited templating::

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
            `PuppetTemplating templating`:trac:."

        def change_to_s(currentvalue, newvalue)
            newvalue = "{md5}" + Digest::MD5.hexdigest(newvalue)
            if currentvalue == :absent
                return "created file with contents %s" % newvalue
            else
                currentvalue = "{md5}" + Digest::MD5.hexdigest(currentvalue)
                return "changed file contents from %s to %s" % [currentvalue, newvalue]
            end
        end

        # We should probably take advantage of existing md5 sums if they're there,
        # but I really don't feel like dealing with the complexity right now.
        def retrieve
            stat = nil
            unless stat = @resource.stat
                return :absent
            end

            if stat.ftype == "link" and @resource[:links] == :ignore
                return self.should
            end

            # Don't even try to manage the content on directories
            if stat.ftype == "directory" and @resource[:links] == :ignore
                @resource.delete(:content)
                return nil
            end

            begin
                currentvalue = File.read(@resource[:path])
                return currentvalue
            rescue => detail
                raise Puppet::Error, "Could not read %s: %s" %
                    [@resource.title, detail]
            end
        end


        # Just write our content out to disk.
        def sync
            return_event = @resource.stat ? :file_changed : :file_created
            
            @resource.write { |f| f.print self.should }

            return return_event
        end
    end
end

# $Id$
