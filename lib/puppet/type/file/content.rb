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

        # Store a checksum as the value, rather than the actual content.
        # Simplifies everything.
        munge do |value|
            if value == :absent
                value
            else
                @actual_content = value
                "{#{checksum_type}}" + send(self.checksum_type, value)
            end
        end

        # Checksums need to invert how changes are printed.
        def change_to_s(currentvalue, newvalue)
            # Our "new" checksum value is provided by the source.
            unless source = resource.parameter(:source) and newvalue = source.checksum
                newvalue = "unknown checksum"
            end
            if currentvalue == :absent
                return "defined content as '%s'" % [newvalue]
            elsif newvalue == :absent
                return "undefined content from '%s'" % [currentvalue]
            else
                return "content changed '%s' to '%s'" % [currentvalue, newvalue]
            end
        end

        def checksum_type
            if source = resource.parameter(:source)
                result = source.checksum
            elsif checksum = resource.parameter(:checksum)
                result = checksum.checktype
            else
                return :md5
            end
            if result =~ /^\{(\w+)\}.+/
                return $1.to_sym
            else
                return result
            end
        end

        # If content was specified, return that; else try to return the source content;
        # else, return nil.
        def actual_content
            if defined?(@actual_content) and @actual_content
                return @actual_content
            end

            if s = resource.parameter(:source)
                return s.content
            end
            return nil
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
                result = super
            elsif source = resource.parameter(:source)
                fail "Got a remote source with no checksum" unless source.checksum
                result = (is == source.checksum)
            else
                # We've got no content specified, and no source from which to
                # get content.
                return true
            end

            if ! result and Puppet[:show_diff]
                string_file_diff(@resource[:path], actual_content)
            end
            return result
        end

        def retrieve
            return :absent unless stat = @resource.stat
            ftype = stat.ftype
            # Don't even try to manage the content on directories or links
            return nil if ["directory","link"].include? ftype or checksum_type.nil?

            begin
                "{#{checksum_type}}" + send(checksum_type.to_s + "_file", resource[:path]).to_s
            rescue => detail
                raise Puppet::Error, "Could not read #{ftype} #{@resource.title}: #{detail}"
            end
        end

        # Make sure we're also managing the checksum property.
        def should=(value)
            @resource.newattr(:checksum) unless @resource.parameter(:checksum)
            super
        end

        # Just write our content out to disk.
        def sync
            return_event = @resource.stat ? :file_changed : :file_created

            # We're safe not testing for the 'source' if there's no 'should'
            # because we wouldn't have gotten this far if there weren't at least
            # one valid value somewhere.
            @resource.write(actual_content, :content)

            return return_event
        end
    end
end
