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

            info "defaulting to no access for %s" % name
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
            Thread.current[:declarations] = @declarations.collect { |ace| ace.interpolate(match) }.sort
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
            Thread.current[:declarations] || @declarations
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

            # Sort the declarations most specific first.
            def <=>(other)
                compare(exact?, other.exact?) || 
                compare(ip?, other.ip?)  ||
                ((length != other.length) &&  (other.length <=> length)) ||
                compare(deny?, other.deny?) ||
                ( ip? ? pattern.to_s <=> other.pattern.to_s : pattern <=> other.pattern)
            end

            def deny?
                type == :deny
            end

            def exact?
                @exact == :exact
            end

            def initialize(type, pattern)
                self.type = type
                self.pattern = pattern
            end

            # Are we an IP type?
            def ip?
                name == :ip
            end

            # Does this declaration match the name/ip combo?
            def match?(name, ip)
                ip? ? pattern.include?(IPAddr.new(ip)) : matchname?(name)
            end

            # Set the pattern appropriately.  Also sets the name and length.
            def pattern=(pattern)
                parse(pattern)
                @orig = pattern
            end

            # Mapping a type of statement into a return value.
            def result
                type == :allow
            end

            def to_s
                "#{type}: #{pattern}"
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
            # for instance if our pattern is $1.puppetlabs.com
            # and we're called with a MatchData whose capture 1 is puppet
            # we'll return a pattern of puppet.puppetlabs.com
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
                (me and them) ? nil : me ? -1 : them ? 1 : nil
            end

            # Does the name match our pattern?
            def matchname?(name)
                name = munge_name(name)
                (pattern == name) or (not exact? and pattern.zip(name).all? { |p,n| p == n })
            end

            # Convert the name to a common pattern.
            def munge_name(name)
                # LAK:NOTE http://snurl.com/21zf8  [groups_google_com]
                # Change to name.downcase.split(".",-1).reverse for FQDN support
                name.downcase.split(".").reverse
            end

            # Parse our input pattern and figure out what kind of allowal
            # statement it is.  The output of this is used for later matching.
            Octet = '(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])'
            IPv4 = "#{Octet}\.#{Octet}\.#{Octet}\.#{Octet}"
            IPv6_full    = "_:_:_:_:_:_:_:_|_:_:_:_:_:_::_?|_:_:_:_:_::((_:)?_)?|_:_:_:_::((_:){0,2}_)?|_:_:_::((_:){0,3}_)?|_:_::((_:){0,4}_)?|_::((_:){0,5}_)?|::((_:){0,6}_)?"
            IPv6_partial = "_:_:_:_:_:_:|_:_:_:_::(_:)?|_:_::(_:){0,2}|_::(_:){0,3}"
            # It should be:
            #     IP = "#{IPv4}|#{IPv6_full}|(#{IPv6_partial}#{IPv4})".gsub(/_/,'([0-9a-fA-F]{1,4})').gsub(/\(/,'(?:')
            # but ruby's ipaddr lib doesn't support the hybrid format
            IP = "#{IPv4}|#{IPv6_full}".gsub(/_/,'([0-9a-fA-F]{1,4})').gsub(/\(/,'(?:')
            def parse(value)
                @name,@exact,@length,@pattern = *case value
                when /^(?:#{IP})\/(\d+)$/                                   # 12.34.56.78/24, a001:b002::efff/120, c444:1000:2000::9:192.168.0.1/112
                    [:ip,:inexact,$1.to_i,IPAddr.new(value)]
                when /^(#{IP})$/                                          # 10.20.30.40, 
                    [:ip,:exact,nil,IPAddr.new(value)]
                when /^(#{Octet}\.){1,3}\*$/                              # an ip address with a '*' at the end
                    segments = value.split(".")[0..-2]
                    bits = 8*segments.length
                    [:ip,:inexact,bits,IPAddr.new((segments+[0,0,0])[0,4].join(".") + "/#{bits}")]
                when /^(\w[-\w]*\.)+[-\w]+$/                              # a full hostname
                    # Change to /^(\w[-\w]*\.)+[-\w]+\.?$/ for FQDN support
                    [:domain,:exact,nil,munge_name(value)]
                when /^\*(\.(\w[-\w]*)){1,}$/                             # *.domain.com
                    host_sans_star = munge_name(value)[0..-2]
                    [:domain,:inexact,host_sans_star.length,host_sans_star]
                when /\$\d+/                                              # a backreference pattern ala $1.puppetlabs.com or 192.168.0.$1 or $1.$2
                    [:dynamic,:exact,nil,munge_name(value)]
                when /^\w[-.@\w]*$/                                       # ? Just like a host name but allow '@'s and ending '.'s
                    [:opaque,:exact,nil,[value]]
                else
                    raise AuthStoreError, "Invalid pattern %s" % value
                end
            end
        end
    end
end

