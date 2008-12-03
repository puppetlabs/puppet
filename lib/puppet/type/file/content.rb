require 'puppet/util/checksums'

module Puppet
    Puppet::Type.type(:file).newproperty(:content) do
        include Puppet::Util::Diff
        include Puppet::Util::Checksums

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
            if source = resource.parameter(:source)
                newvalue = source.metadata.checksum
            else
                newvalue = "{md5}" + Digest::MD5.hexdigest(newvalue)
            end
            if currentvalue == :absent
                return "created file with contents %s" % newvalue
            else
                currentvalue = "{md5}" + Digest::MD5.hexdigest(currentvalue)
                return "changed file contents from %s to %s" % [currentvalue, newvalue]
            end
        end
        
        def content
            self.should || (s = resource.parameter(:source) and s.content)
        end

        # Override this method to provide diffs if asked for.
        # Also, fix #872: when content is used, and replace is true, the file
        # should be insync when it exists
        def insync?(is)
            if resource.should_be_file?
                return false if is == :absent
            else
                return true
            end

            return true if ! @resource.replace?

            if self.should
                return super
            elsif source = resource.parameter(:source)
                fail "Got a remote source with no checksum" unless source.checksum
                unless sum_method = sumtype(source.checksum)
                    fail "Could not extract checksum type from source checksum '%s'" % source.checksum
                end

                newsum = "{%s}" % sum_method + send(sum_method, is)
                result = (newsum == source.checksum)
            else
                # We've got no content specified, and no source from which to
                # get content.
                return true
            end

            if ! result and Puppet[:show_diff]
                string_file_diff(@resource[:path], content)
            end
            return result
        end

        def retrieve
            return :absent unless stat = @resource.stat

            # Don't even try to manage the content on directories or links
            return nil if stat.ftype == "directory"

            begin
                return File.read(@resource[:path])
            rescue => detail
                raise Puppet::Error, "Could not read %s: %s" % [@resource.title, detail]
            end
        end

        # Make sure we're also managing the checksum property.
        def should=(value)
            super
            @resource.newattr(:checksum) unless @resource.parameter(:checksum)
        end

        # Just write our content out to disk.
        def sync
            return_event = @resource.stat ? :file_changed : :file_created
            
            # We're safe not testing for the 'source' if there's no 'should'
            # because we wouldn't have gotten this far if there weren't at least
            # one valid value somewhere.
            content = self.should || resource.parameter(:source).content
            @resource.write(content, :content)

            return return_event
        end
    end
end
