module Puppet
    Puppet::Type.type(:file).newproperty(:content) do
        include Puppet::Util::Diff

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

        def string_as_checksum(string)
            return "absent" if string == :absent
            "{md5}" + Digest::MD5.hexdigest(string)
        end

        def should_to_s(should)
            string_as_checksum(should)
        end

        def is_to_s(is)
            string_as_checksum(is)
        end

        # Override this method to provide diffs if asked for.
        # Also, fix #872: when content is used, and replace is true, the file
        # should be insync when it exists
        def insync?(is)
            if ! @resource.replace? and File.exists?(@resource[:path])
                return true
            end

            result = super
            if ! result and Puppet[:show_diff] and File.exists?(@resource[:path])
                string_file_diff(@resource[:path], self.should)
            end
            return result
        end

        def retrieve
            return :absent unless stat = @resource.stat

            return self.should if stat.ftype == "link" and @resource[:links] == :ignore

            # Don't even try to manage the content on directories
            return nil if stat.ftype == "directory"

            begin
                currentvalue = File.read(@resource[:path])
                return currentvalue
            rescue => detail
                raise Puppet::Error, "Could not read %s: %s" %
                    [@resource.title, detail]
            end
        end

        # Make sure we're also managing the checksum property.
        def should=(value)
            super
            @resource.newattr(:checksum) unless @resource.property(:checksum)
        end

        # Just write our content out to disk.
        def sync
            return_event = @resource.stat ? :file_changed : :file_created
            
            @resource.write(self.should, :content)

            return return_event
        end
    end
end
