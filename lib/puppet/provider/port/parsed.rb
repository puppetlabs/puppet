require 'puppet/provider/parsedfile'

#services = nil
#case Facter.value(:operatingsystem)
#when "Solaris"; services = "/etc/inet/services"
#else
#    services = "/etc/services"
#end
#
#Puppet::Type.type(:port).provide(:parsed,
#    :parent => Puppet::Provider::ParsedFile,
#    :default_target => services,
#    :filetype => :flat
#) do
#    text_line :comment, :match => /^\s*#/
#    text_line :blank, :match => /^\s*$/
#
#    # We're cheating horribly here -- we don't support ddp, because it assigns
#    # the same number to already-used names, and the same name to different
#    # numbers.
#    text_line :ddp, :match => /^\S+\s+\d+\/ddp/
#
#    # Also, just ignore the lines on OS X that don't have service names.
#    text_line :funky_darwin, :match => /^\s+\d+\//
#
#    # We have to manually parse the line, since it's so darn complicated.
#    record_line :parsed, :fields => %w{name port protocols alias description},
#        :optional => %w{alias description} do |line|
#        if line =~ /\/ddp/
#            raise "missed ddp in %s" % line
#        end
#        # The record might contain multiple port lines separated by \n.
#        hashes = line.split("\n").collect { |l| parse_port(l) }
#
#        # It's easy if there's just one hash.
#        if hashes.length == 1
#            return hashes.shift
#        end
#
#        # Else, merge the two records into one.
#        return port_merge(*hashes)
#    end
#
#    # Override how we split into lines, so that we always treat both protocol
#    # lines as a single line.  This drastically simplifies merging the two lines
#    # into one record.
#    def self.lines(text)
#        names = {}
#        lines = []
#
#        # We organize by number, because that's apparently how the ports work.
#        # You'll never be able to use Puppet to manage multiple entries
#        # with the same name but different numbers, though.
#        text.split("\n").each do |line|
#            if line =~ /^([-\w]+)\s+(\d+)\/[^d]/ # We want to skip ddp proto stuff
#                names[$1] ||= []
#                names[$1] << line
#                lines << [:special, $1]
#            else
#                lines << line
#            end
#        end
#
#        # Now, return each line in order, but join the ones with the same name
#        lines.collect do |line|
#            if line.is_a?(Array)
#                name = line[1]
#                if names[name]
#                    t = names[name].join("\n")
#                    names.delete(name)
#                    t
#                end
#            else
#                line
#            end
#        end.reject { |l| l.nil? }
#    end
#
#    # Parse a single port line, returning a hash.
#    def self.parse_port(line)
#        hash = {}
#        if line.sub!(/^(\S+)\s+(\d+)\/(\w+)\s*/, '')
#            hash[:name] = $1
#            hash[:number] = $2
#            hash[:protocols] = [$3]
#
#            unless line == ""
#                line.sub!(/^([^#]+)\s*/) do |value|
#                    aliases = $1
#
#                    # Remove any trailing whitespace
#                    aliases.strip!
#                    unless aliases =~ /^\s*$/
#                        hash[:alias] = aliases.split(/\s+/)
#                    end
#
#                    ""
#                end
#
#                line.sub!(/^\s*#\s*(.+)$/) do |value|
#                    desc = $1
#                    unless desc =~ /^\s*$/
#                        hash[:description] = desc.sub(/\s*$/, '')
#                    end
#
#                    ""
#                end
#            end
#        else
#            if line =~ /^\s+\d+/ and
#                Facter["operatingsystem"].value == "Darwin"
#                    #Puppet.notice "Skipping wonky OS X port entry %s" %
#                    #    line.inspect
#                    next
#            end
#            Puppet.notice "Ignoring unparseable line '%s' in %s" % [line, self.target]
#        end
#
#        if hash.empty?
#            return nil
#        else
#            return hash
#        end
#    end
#
#    # Merge two records into one.
#    def self.port_merge(one, two)
#        keys = [one.keys, two.keys].flatten.uniq
#
#        # We'll be returning the 'one' hash. so make any necessary modifications
#        # to it.
#        keys.each do |key|
#            # The easy case
#            if one[key] == two[key]
#                next
#            elsif one[key] and ! two[key]
#                next
#            elsif ! one[key] and two[key]
#                one[key] = two[key]
#            elsif one[key].is_a?(Array) and two[key].is_a?(Array)
#                one[key] = [one[key], two[key]].flatten.uniq
#            else
#                # Keep the info from the first hash, so don't do anything
#                #Puppet.notice "Cannot merge %s in %s with %s" %
#                #    [key, one.inspect, two.inspect]
#            end
#        end
#
#        return one
#    end
#
#    # Convert the current object into one or more services entry.
#    def self.to_line(hash)
#        unless hash[:record_type] == :parsed
#            return super
#        end
#
#        # Strangely, most sites seem to use tabs as separators.
#        hash[:protocols].collect { |proto|
#            str = "%s\t\t%s/%s" % [hash[:name], hash[:number], proto]
#
#            if value = hash[:alias] and value != :absent
#                str += "\t\t%s" % value.join(" ")
#            end
#
#            if value = hash[:description] and value != :absent
#                str += "\t# %s" % value
#            end
#            str
#        }.join("\n")
#    end
#end

