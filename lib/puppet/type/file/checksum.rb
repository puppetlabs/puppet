require 'puppet/util/checksums'

# Keep a copy of the file checksums, and notify when they change.  This
# property never actually modifies the system, it only notices when the system
# changes on its own.
Puppet::Type.type(:file).newproperty(:checksum) do
    include Puppet::Util::Checksums

    desc "How to check whether a file has changed.  This state is used internally
        for file copying, but it can also be used to monitor files somewhat
        like Tripwire without managing the file contents in any way.  You can
        specify that a file's checksum should be monitored and then subscribe to
        the file from another object and receive events to signify
        checksum changes, for instance.

        There are a number of checksum types available including MD5 hashing (and
        an md5lite variation that only hashes the first 500 characters of the
        file.

        The default checksum parameter, if checksums are enabled, is md5."

    @event = :file_changed

    @unmanaged = true

    @validtypes = %w{md5 md5lite timestamp mtime time none}

    def self.validtype?(type)
        @validtypes.include?(type)
    end

    @validtypes.each do |ctype|
        newvalue(ctype) do
            handlesum()
        end
    end

    str = @validtypes.join("|")

    # This is here because Puppet sets this internally, using
    # {md5}......
    newvalue(/^\{#{str}\}/) do
        handlesum()
    end

    # If they pass us a sum type, behave normally, but if they pass
    # us a sum type + sum, stick the sum in the cache.
    munge do |value|
        if value =~ /^\{(\w+)\}(.+)$/
            type = symbolize($1)
            sum = $2
            cache(type, sum)
            return type
        else
            return :none if value.nil? or value.to_s == "" or value.to_s == "none"
            if FileTest.directory?(@resource[:path])
                return :time
            elsif @resource[:source] and value.to_s != "md5"
                 self.warning("Files with source set must use md5 as checksum. Forcing to md5 from %s for %s" % [ value, @resource[:path] ])
                return :md5
            else
                return symbolize(value)
            end
        end
    end

    # Store the checksum in the data cache, or retrieve it if only the
    # sum type is provided.
    def cache(type, sum = nil)
        return unless c = resource.catalog and c.host_config?
        unless type
            raise ArgumentError, "A type must be specified to cache a checksum"
        end
        type = symbolize(type)
        type = :mtime if type == :timestamp
        type = :ctime if type == :time

        unless state = @resource.cached(:checksums)
            self.debug "Initializing checksum hash"
            state = {}
            @resource.cache(:checksums, state)
        end

        if sum
            unless sum =~ /\{\w+\}/
                sum = "{%s}%s" % [type, sum]
            end
            state[type] = sum
        else
            return state[type]
        end
    end

    # Because source and content and whomever else need to set the checksum
    # and do the updating, we provide a simple mechanism for doing so.
    def checksum=(value)
        munge(@should)
        self.updatesum(value)
    end

    def checktype
        self.should || :md5
    end

    # Checksums need to invert how changes are printed.
    def change_to_s(currentvalue, newvalue)
        begin
            if currentvalue == :absent
                return "defined '%s' as '%s'" %
                    [self.name, self.currentsum]
            elsif newvalue == :absent
                return "undefined %s from '%s'" %
                    [self.name, self.is_to_s(currentvalue)]
            else
                if defined? @cached and @cached
                    return "%s changed '%s' to '%s'" %
                        [self.name, @cached, self.is_to_s(currentvalue)]
                else
                    return "%s changed '%s' to '%s'" %
                        [self.name, self.currentsum, self.is_to_s(currentvalue)]
                end
            end
        rescue Puppet::Error, Puppet::DevError
            raise
        rescue => detail
            raise Puppet::DevError, "Could not convert change %s to string: %s" %
                [self.name, detail]
        end
    end

    def currentsum
        cache(checktype())
    end

    # Calculate the sum from disk.
    def getsum(checktype, file = nil)
        sum = ""

        checktype = :mtime if checktype == :timestamp
        checktype = :ctime if checktype == :time
        self.should = checktype = :md5 if @resource.property(:source)

        file ||= @resource[:path]

        return nil unless FileTest.exist?(file)

        if ! FileTest.file?(file)
            checktype = :mtime
        end
        method = checktype.to_s + "_file"

        self.fail("Invalid checksum type %s" % checktype) unless respond_to?(method)

        return "{%s}%s" % [checktype, send(method, file)]
    end

    # At this point, we don't actually modify the system, we modify
    # the stored state to reflect the current state, and then kick
    # off an event to mark any changes.
    def handlesum
        currentvalue = self.retrieve
        if currentvalue.nil?
            raise Puppet::Error, "Checksum state for %s is somehow nil" %
                @resource.title
        end

        if self.insync?(currentvalue)
            self.debug "Checksum is already in sync"
            return nil
        end
        # If we still can't retrieve a checksum, it means that
        # the file still doesn't exist
        if currentvalue == :absent
            # if they're copying, then we won't worry about the file
            # not existing yet
            return nil unless @resource.property(:source)
        end

        # If the sums are different, then return an event.
        if self.updatesum(currentvalue)
            return :file_changed
        else
            return nil
        end
    end

    def insync?(currentvalue)
        @should = [checktype()]
        if cache(checktype())
            return currentvalue == currentsum()
        else
            # If there's no cached sum, then we don't want to generate
            # an event.
            return true
        end
    end

    # Even though they can specify multiple checksums, the insync?
    # mechanism can really only test against one, so we'll just retrieve
    # the first specified sum type.
    def retrieve(usecache = false)
        # When the 'source' is retrieving, it passes "true" here so
        # that we aren't reading the file twice in quick succession, yo.
        currentvalue = currentsum()
        return currentvalue if usecache and currentvalue

        stat = nil
        return :absent unless stat = @resource.stat

        if stat.ftype == "link" and @resource[:links] != :follow
            self.debug "Not checksumming symlink"
            # @resource.delete(:checksum)
            return currentvalue
        end

        # Just use the first allowed check type
        currentvalue = getsum(checktype())

        # If there is no sum defined, then store the current value
        # into the cache, so that we're not marked as being
        # out of sync.  We don't want to generate an event the first
        # time we get a sum.
        self.updatesum(currentvalue) unless cache(checktype())

        # @resource.debug "checksum state is %s" % self.is
        return currentvalue
    end

    # Store the new sum to the state db.
    def updatesum(newvalue)
        return unless c = resource.catalog and c.host_config?
        result = false

        # if we're replacing, vs. updating
        if sum = cache(checktype())
            return false if newvalue == sum

            self.debug "Replacing %s checksum %s with %s" % [@resource.title, sum, newvalue]
            result = true
        else
            @resource.debug "Creating checksum %s" % newvalue
            result = false
        end

        # Cache the sum so the log message can be right if possible.
        @cached = sum
        cache(checktype(), newvalue)
        return result
    end
end
