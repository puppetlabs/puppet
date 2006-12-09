# standard module for determining whether a given hostname or IP has access to
# the requested resource

require 'ipaddr'

module Puppet
class Server
    class AuthStoreError < Puppet::Error; end
    class AuthorizationError < Puppet::Error; end

    class AuthStore
        # This has to be an array, not a hash, else it loses its ordering.
        ORDER = [
            [:ip, [:ip]],
            [:name, [:hostname, :domain]]
        ]

        Puppet::Util.logmethods(self, true)

        def allow(pattern)
            # a simple way to allow anyone at all to connect
            if pattern == "*"
                @globalallow = true
            else
                store(pattern, @allow)
            end
        end

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
            if @globalallow
                return true
            end

            value = nil
            ORDER.each { |nametype, array|
                if nametype == :ip
                    value = IPAddr.new(ip)
                else
                    value = name.split(".").reverse
                end


                array.each { |type|
                    [[@deny, false], [@allow, true]].each { |ary|
                        hash, retval = ary
                        if hash.include?(type)
                            hash[type].each { |pattern|
                                if match?(nametype, value, pattern)
                                    return retval
                                end
                            }
                        end
                    }
                }
            }

            self.info "defaulting to no access for %s" % name
            # default to false
            return false
        end

        def deny(pattern)
            store(pattern, @deny)
        end

        def initialize
            @globalallow = nil
            @allow = Hash.new { |hash, key|
                hash[key] = []
            }
            @deny = Hash.new { |hash, key|
                hash[key] = []
            }
        end

        private

        def match?(nametype, value, pattern)
            if value == pattern # simplest shortcut
                return true
            end

            case nametype
            when :ip: matchip?(value, pattern)
            when :name: matchname?(value, pattern)
            else
                raise Puppet::DevError, "Invalid match type %s" % nametype
            end
        end

        def matchip?(value, pattern)
            # we're just using builtin stuff for this, thankfully
            if pattern.include?(value)
                return true
            else
                return false
            end
        end

        def matchname?(value, pattern)
            # yay, horribly inefficient
            if pattern[-1] != '*' # the pattern has no metachars and is not equal
                                    # thus, no match
                #Puppet.info "%s is not equal with no * in %s" % [value, pattern]
                return false
            else
                # we know the last field of the pattern is '*'
                # if everything up to that doesn't match, we're definitely false
                if pattern[0..-2] != value[0..pattern.length-2]
                    #Puppet.notice "subpatterns didn't match; %s vs %s" %
                    #    [pattern[0..-2], value[0..pattern.length-2]]
                    return false
                end

                case value.length <=> pattern.length
                when -1: # value is shorter than pattern
                    if pattern.length - value.length == 1
                        # only ever allowed when the value is the domain of a
                        # splatted pattern
                        #Puppet.info "allowing splatted domain %s" % [value]
                        return true
                    else
                        return false
                    end
                when 0: # value is the same length as pattern
                    if pattern[-1] == "*"
                        #Puppet.notice "same length with *"
                        return true
                    else
                        return false
                    end
                when 1: # value is longer than pattern
                    # at this point we've already verified that everything up to
                    # the '*' in the pattern matches, so we are true
                    return true
                end
            end
        end

        def store(pattern, hash)
            type, value = type(pattern)

            if type and value
                # this won't work once we get beyond simple stuff...
                hash[type] << value
            else
                raise AuthStoreError, "Invalid pattern %s" % pattern
            end
        end

        def type(pattern)
            type = value = nil
            case pattern
            when /^(\d+\.){3}\d+$/:
                type = :ip
                begin
                    value = IPAddr.new(pattern)
                rescue ArgumentError => detail
                    raise AuthStoreError, "Invalid IP address pattern %s" % pattern
                end
            when /^(\d+\.){3}\d+\/(\d+)$/:
                mask = Integer($2)
                if mask < 1 or mask > 32
                    raise AuthStoreError, "Invalid IP mask %s" % mask
                end
                type = :ip
                begin
                    value = IPAddr.new(pattern)
                rescue ArgumentError => detail
                    raise AuthStoreError, "Invalid IP address pattern %s" % pattern
                end
            when /^(\d+\.){1,3}\*$/: # an ip address with a '*' at the end
                type = :ip
                match = $1
                match.sub!(".", '')
                ary = pattern.split(".")

                mask = case ary.index(match)
                when 0: 8
                when 1: 16
                when 2: 24
                else
                    raise AuthStoreError, "Invalid IP pattern %s" % pattern
                end

                ary.pop
                while ary.length < 4
                    ary.push("0")
                end

                begin
                    value = IPAddr.new(ary.join(".") + "/" + mask.to_s)
                rescue ArgumentError => detail
                    raise AuthStoreError, "Invalid IP address pattern %s" % pattern
                end
            when /^[\d.]+$/: # necessary so incomplete IP addresses can't look
                             # like hostnames
                raise AuthStoreError, "Invalid IP address pattern %s" % pattern
            when /^([a-zA-Z][-\w]*\.)+[-\w]+$/: # a full hostname
                type = :hostname
                value = pattern.split(".").reverse
            when /^\*(\.([a-zA-Z][-\w]*)){1,}$/:
                type = :domain
                value = pattern.split(".").reverse
            else
                raise AuthStoreError, "Invalid pattern %s" % pattern
            end

            return [type, value]
        end
    end
end
end
#
# $Id$
