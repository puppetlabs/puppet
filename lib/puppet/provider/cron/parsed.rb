require 'puppet/provider/parsedfile'

Puppet::Type.type(:cron).provide :parsed, :parent => Puppet::Provider::ParsedFile do
    @fields = [:minute, :hour, :monthday, :month, :weekday, :command]

    # XXX This should be switched to use providers or something similar on
    # the backend.
    def self.defaulttype
        case Facter["operatingsystem"].value
        when "Solaris":
            return Puppet::FileType.filetype(:suntab)
        else
            return Puppet::FileType.filetype(:crontab)
        end
    end

    self.filetype = self.defaulttype()

    # We have to maintain separate file objects for every user, unfortunately.
    def self.filetype(user)
        @tabs ||= {}
        @tabs[user] ||= @filetype.new(user)

        @tabs[user]
    end

    # Parse a user's cron job into individual cron objects.
    #
    # Autogenerates names for any jobs that don't already have one; these
    # names will get written back to the file.
    #
    # This method also stores existing comments, and it stores all cron
    # jobs in order, mostly so that comments are retained in the order
    # they were written and in proximity to the same jobs.
    def self.parse(user, text)
        count = 0

        envs = []
        instances = []
        text.chomp.split("\n").each { |line|
            hash = {}
            case line
            when /^# Puppet Name: (.+)$/
                hash[:name] = $1
                next
            when /^#/:
                # add other comments to the list as they are
                instances << line 
                next
            when /^\s*(\w+)\s*=\s*(.+)\s*$/:
                # Match env settings.
                if hash[:name]
                    envs << line
                else
                    instances << line 
                end
                next
            when /^@(\w+)\s+(.+)/ # FreeBSD special cron crap
                fields().each do |field|
                    next if field == :command
                    hash[field] = :absent
                end
                hash[:special] = $1
                hash[:command] = $2
            else
                if match = /^(\S+) (\S+) (\S+) (\S+) (\S+) (.+)$/.match(line)
                    fields().zip(match.captures).each { |param, value|
                        if value == "*"
                            hash[param] = [:absent]
                        else
                            if param == :command
                                hash[param] = [value]
                            else
                                # We always want the 'is' value to be an
                                # array
                                hash[param] = value.split(",")
                            end
                        end
                    }
                else
                    # Don't fail on unmatched lines, just warn on them
                    # and skip them.
                    Puppet.warning "Could not match '%s'" % line
                    next
                end
            end

            unless envs.empty?
                hash[:environment] = envs
            end

            hash[:user] = user

            instances << hash

            envs.clear
            count += 1
        }

        return instances
    end

    def self.retrieve(user)
        text = fileobj(user).read
        if text.nil? or text == ""
            return []
        else
            self.parse(user, text)
        end
    end

    # Another override.  This will pretty much only ever have one user's instances,
    def self.store(instances)
        instances.find_all { |i| i.is_a? Hash }.collect { |i| i[:user] }.each do |user|
            fileobj(user).write(self.to_file(instances))
        end
    end

    # Convert the current object a cron-style string.  Adds the cron name
    # as a comment above the cron job, in the form '# Puppet Name: <name>'.
    def self.to_record(hash)
        hash = {}

        str = ""

        str = "# Puppet Name: %s\n" % hash[:name]

        if @states.include?(:environment) and
            @states[:environment].should != :absent
                envs = @states[:environment].should
                unless envs.is_a? Array
                    envs = [envs]
                end

                envs.each do |line| str += (line + "\n") end
        end

        line = nil
        if special = hash[:special]
            line = str + "@%s %s" %
                [special, hash[:command]]
        else
            line = str + self.class.fields.collect { |f|
                if hash[f] and hash[f] != :absent
                    hash[f]
                else
                    "*"
                end
            }.join(" ")
        end

        return line
    end

    # Override the mechanism for retrieving instances, because we're user-specific.
    def allinstances
        self.class.retrieve(@model[:user])
    end
end

# $Id$
