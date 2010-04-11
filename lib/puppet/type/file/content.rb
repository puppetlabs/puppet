require 'net/http'
require 'uri'

require 'puppet/util/checksums'
require 'puppet/network/http/api/v1'
require 'puppet/network/http/compression'

module Puppet
    Puppet::Type.type(:file).newproperty(:content) do
        include Puppet::Util::Diff
        include Puppet::Util::Checksums
        include Puppet::Network::HTTP::API::V1
        include Puppet::Network::HTTP::Compression.module

        attr_reader :actual_content

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
            elsif checksum?(value)
                # XXX This is potentially dangerous because it means users can't write a file whose
                # entire contents are a plain checksum
                value
            else
                @actual_content = value
                resource.parameter(:checksum).sum(value)
            end
        end

        # Checksums need to invert how changes are printed.
        def change_to_s(currentvalue, newvalue)
            # Our "new" checksum value is provided by the source.
            if source = resource.parameter(:source) and tmp = source.checksum
                newvalue = tmp
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
            else checksum = resource.parameter(:checksum)
                result = resource[:checksum]
            end
            if result =~ /^\{(\w+)\}.+/
                return $1.to_sym
            else
                return result
            end
        end

        def length
            (actual_content and actual_content.length) || 0
        end

        def content
            self.should
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
            return true unless self.should

            result = super

            if ! result and Puppet[:show_diff]
                string_file_diff(@resource[:path], actual_content)
            end
            return result
        end

        def retrieve
            return :absent unless stat = @resource.stat
            ftype = stat.ftype
            # Don't even try to manage the content on directories or links
            return nil if ["directory","link"].include?(ftype)

            begin
                resource.parameter(:checksum).sum_file(resource[:path])
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
            @resource.write(:content)

            return return_event
        end

        def write(file)
            self.fail "Writing content that wasn't provided" unless actual_content || resource.parameter(:source)
            resource.parameter(:checksum).sum_stream { |sum|
                each_chunk_from(actual_content || resource.parameter(:source)) { |chunk|
                    sum << chunk
                    file.print chunk
                }
            }
        end

        def each_chunk_from(source_or_content)
            if source_or_content.is_a?(String)
                yield source_or_content
            elsif source_or_content.nil?
                nil
            elsif source_or_content.local?
                File.open(source_or_content.full_path, "r") do |src|
                    while chunk = src.read(8192)
                        yield chunk
                    end
                end
            else
                request = Puppet::Indirector::Request.new(:file_content, :find, source_or_content.full_path)
                connection = Puppet::Network::HttpPool.http_instance(source_or_content.server, source_or_content.port)
                connection.request_get(indirection2uri(request), add_accept_encoding({"Accept" => "raw"})) do |response|
                    case response.code
                    when "404"; nil
                    when /^2/;  uncompress(response) { |uncompressor| response.read_body { |chunk| yield uncompressor.uncompress(chunk) } }
                    else
                        # Raise the http error if we didn't get a 'success' of some kind.
                        message = "Error %s on SERVER: %s" % [response.code, (response.body||'').empty? ? response.message : uncompress_body(response)]
                        raise Net::HTTPError.new(message, response)
                    end
                end
            end
        end
    end
end
