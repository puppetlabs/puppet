# standard module for determining whether a given hostname or IP has access to
# the requested resource

require 'ipaddr'
require 'puppet/util/logging'

module Puppet
    class AuthStoreError < Puppet::Error; end
    class AuthorizationError < Puppet::Error; end

    class Network::AuthStore
        include Puppet::Util::Logging

        # Mark a given pattern as allowed.
        def allow(pattern)
            # a simple way to allow anyone at all to connect
            if pattern == "*"
                @globalallow = true
            else
                store(:allow, pattern)
            end

            return nil
        end

        # Is a given combination of name and ip address allowed?  If either input
        # is non-nil, then both inputs must be provided.  If neither input
        # is provided, then the authstore is considered local and defaults to "true".
        def allowed?(name, ip)
            if name or ip
                # This is probably unnecessary, and can cause some weirdnesses in
                # cases where we're operating over localhost but don't have a real
                # IP defined.
                unless name and ip
                    raise Puppet::DevError, "Name and IP must be passed to 'allowed?'"
                end
                # else, we're networked and such
            else
                # we're local
                return true
            end

            # yay insecure overrides
            if globalallow?
                return true
            end

            if decl = @declarations.find { |d| d.match?(name, ip) }
                return decl.result
            end

            self.info "defaulting to no access for %s" % name
            return false
        end

        # Deny a given pattern.
        def deny(pattern)
            store(:deny, pattern)
        end

        # Is global allow enabled?
        def globalallow?
            @globalallow
        end

        def initialize
            @globalallow = nil
            @declarations = []
        end

        def to_s
            "authstore"
        end

        private

        # Store the results of a pattern into our hash.  Basically just
        # converts the pattern and sticks it into the hash.
        def store(type, pattern)
            @declarations << Declaration.new(type, pattern)
            @declarations.sort!

            return nil
        end

        # A single declaration.  Stores the info for a given declaration,
        # provides the methods for determining whether a declaration matches,
        # and handles sorting the declarations appropriately.
        class Declaration
            include Puppet::Util
            include Comparable

            # The type of declaration: either :allow or :deny
            attr_reader :type

            # The name: :ip or :domain
            attr_accessor :name

            # The pattern we're matching against.  Can be an IPAddr instance,
            # or an array of strings, resulting from reversing a hostname
            # or domain name.
            attr_reader :pattern

            # The length.  Only used for iprange and domain.
            attr_accessor :length

            # Sort the declarations specially.
            def <=>(other)
                # Sort first based on whether the matches are exact.
                if r = compare(exact?, other.exact?)
                    return r
                end

                # Then by type
                if r = compare(self.ip?, other.ip?)
                    return r
                end

                # Next sort based on length
                unless self.length == other.length
                    # Longer names/ips should go first, because they're more
                    # specific.
                    return other.length <=> self.length
                end

                # Then sort deny before allow
                if r = compare(self.deny?, other.deny?)
                    return r
                end

                # We've already sorted by name and length, so all that's left
                # is the pattern
                if ip?
                    return self.pattern.to_s <=> other.pattern.to_s
                else
                    return self.pattern <=> other.pattern
                end
            end

            def deny?
                self.type == :deny
            end

            # Are we an exact match?
            def exact?
                self.length.nil?
            end

            def initialize(type, pattern)
                self.type = type
                self.pattern = pattern
            end

            # Are we an IP type?
            def ip?
                self.name == :ip
            end

            # Does this declaration match the name/ip combo?
            def match?(name, ip)
                if self.ip?
                    return pattern.include?(IPAddr.new(ip))
                else
                    return matchname?(name)
                end
            end

            # Set the pattern appropriately.  Also sets the name and length.
            def pattern=(pattern)
                parse(pattern)
                @orig = pattern
            end

            # Mapping a type of statement into a return value.
            def result
                case @type
                when :allow: true
                else
                    false
                end
            end

            def to_s
                "%s: %s" % [self.type, self.pattern]
            end

            # Set the declaration type.  Either :allow or :deny.
            def type=(type)
                type = symbolize(type)
                unless [:allow, :deny].include?(type)
                    raise ArgumentError, "Invalid declaration type %s" % type
                end
                @type = type
            end

            private

            # Returns nil if both values are true or both are false, returns
            # -1 if the first is true, and 1 if the second is true.  Used
            # in the <=> operator.
            def compare(me, them)
                unless me and them
                    if me
                        return -1
                    elsif them
                        return 1
                    else
                        return false
                    end
                end
                return nil
            end

            # Does the name match our pattern?
            def matchname?(name)
                name = munge_name(name)
                return true if self.pattern == name

                # If it's an exact match, then just return false, since the
                # exact didn't match.
                if exact?
                    return false
                end

                # If every field in the pattern matches, then we consider it
                # a match.
                pattern.zip(name) do |p,n|
                    unless p == n
                        return false
                    end
                end

                return true
            end

            # Convert the name to a common pattern.
            def munge_name(name)
                # LAK:NOTE http://snurl.com/21zf8  [groups_google_com]
                x = name.downcase.split(".").reverse
            end

            # Parse our input pattern and figure out what kind of allowal
            # statement it is.  The output of this is used for later matching.
            def parse(value)
                case value
                when /^(\d+\.){1,3}\*$/: # an ip address with a '*' at the end
                    @name = :ip
                    match = $1
                    match.sub!(".", '')
                    ary = value.split(".")

                    mask = case ary.index(match)
                    when 0: 8
                    when 1: 16
                    when 2: 24
                    else
                        raise AuthStoreError, "Invalid IP pattern %s" % value
                    end

                    @length = mask

                    ary.pop
                    while ary.length < 4
                        ary.push("0")
                    end

                    begin
                        @pattern = IPAddr.new(ary.join(".") + "/" + mask.to_s)
                    rescue ArgumentError => detail
                        raise AuthStoreError, "Invalid IP address pattern %s" % value
                    end
                when /^([a-zA-Z][-\w]*\.)+[-\w]+$/: # a full hostname
                    @name = :domain
                    @pattern = munge_name(value)
                when /^\*(\.([a-zA-Z][-\w]*)){1,}$/: # *.domain.com
                    @name = :domain
                    @pattern = munge_name(value)
                    @pattern.pop # take off the '*'
                    @length = @pattern.length
                else
                    # Else, use the IPAddr class to determine if we've got a
                    # valid IP address.
                    if value =~ /\/(\d+)$/
                        @length = Integer($1)
                    end
                    begin
                        @pattern = IPAddr.new(value)
                    rescue ArgumentError => detail
                        raise AuthStoreError, "Invalid pattern %s" % value
                    end
                    @name = :ip
                end
            end
        end
    end
end

