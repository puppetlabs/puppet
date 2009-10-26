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

            if decl = declarations.find { |d| d.match?(name, ip) }
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

        # does this auth store has any rules?
        def empty?
            @globalallow.nil? && @declarations.size == 0
        end

        def initialize
            @globalallow = nil
            @declarations = []
        end

        def to_s
            "authstore"
        end

        def interpolate(match)
            declarations = @declarations.collect do |ace|
                ace.interpolate(match)
            end
            declarations.sort!
            Thread.current[:declarations] = declarations
        end

        def reset_interpolation
            Thread.current[:declarations] = nil
        end

        private

        # returns our ACEs list, but if we have a modification of it
        # in our current thread, let's return it
        # this is used if we want to override the this purely immutable list
        # by a modified version in a multithread safe way.
        def declarations
            return Thread.current[:declarations] if Thread.current[:declarations]
            @declarations
        end

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
                when :allow; true
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

            # interpolate a pattern to replace any
            # backreferences by the given match
            # for instance if our pattern is $1.reductivelabs.com
            # and we're called with a MatchData whose capture 1 is puppet
            # we'll return a pattern of puppet.reductivelabs.com
            def interpolate(match)
                clone = dup
                clone.pattern = clone.pattern.reverse.collect do |p|
                    p.gsub(/\$(\d)/) { |m| match[$1.to_i] }
                end.join(".")
                clone
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
                # Change to x = name.downcase.split(".",-1).reverse for FQDN support
                x = name.downcase.split(".").reverse
            end

            # Parse our input pattern and figure out what kind of allowal
            # statement it is.  The output of this is used for later matching.
            def parse(value)
                # Use the IPAddr class to determine if we've got a
                # valid IP address.
                @length = Integer($1) if value =~ /\/(\d+)$/
                begin
                    @pattern = IPAddr.new(value)
                    @name = :ip
                rescue ArgumentError => detail
                    case value
                    when /^(\d+\.){1,3}\*$/ # an ip address with a '*' at the end
                        @name = :ip
                        segments = value.split(".")[0..-2]
                        @length = 8*segments.length
                        begin
                            @pattern = IPAddr.new((segments+[0,0,0])[0,4].join(".") + "/" + @length.to_s)
                        rescue ArgumentError => detail
                            raise AuthStoreError, "Invalid IP address pattern %s" % value
                        end
                    when /^([a-zA-Z0-9][-\w]*\.)+[-\w]+$/ # a full hostname
                        # Change to /^([a-zA-Z][-\w]*\.)+[-\w]+\.?$/ for FQDN support
                        @name = :domain
                        @pattern = munge_name(value)
                    when /^\*(\.([a-zA-Z][-\w]*)){1,}$/ # *.domain.com
                        @name = :domain
                        @pattern = munge_name(value)
                        @pattern.pop # take off the '*'
                        @length = @pattern.length
                    when /\$\d+/ # a backreference pattern ala $1.reductivelabs.com or 192.168.0.$1 or $1.$2
                        @name = :dynamic
                        @pattern = munge_name(value)
                    when /^[a-zA-Z0-9][-a-zA-Z0-9_.@]*$/
                        @pattern = [value]
                        @length = nil # force an exact match
                        @name = :opaque
                    else
                        raise AuthStoreError, "Invalid pattern %s" % value
                    end
                end
            end
        end
    end
end

