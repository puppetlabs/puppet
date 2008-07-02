require 'puppet/indirector/terminus'

class Puppet::Indirector::Ldap < Puppet::Indirector::Terminus
    # Perform our ldap search and process the result.
    def find(request)
        return ldapsearch(search_filter(request.key)) { |entry| return process(entry) } || nil
    end

    # Process the found entry.  We assume that we don't just want the
    # ldap object.
    def process(entry)
        raise Puppet::DevError, "The 'process' method has not been overridden for the LDAP terminus for %s" % self.name
    end

    # Default to all attributes.
    def search_attributes
        nil
    end

    def search_base
        Puppet[:ldapbase]
    end

    # The ldap search filter to use.
    def search_filter(name)
        raise Puppet::DevError, "No search string set for LDAP terminus for %s" % self.name
    end

    # Find the ldap node, return the class list and parent node specially,
    # and everything else in a parameter hash.
    def ldapsearch(filter)
        raise ArgumentError.new("You must pass a block to ldapsearch") unless block_given?

        found = false
        count = 0

        begin
            connection.search(search_base, 2, filter, search_attributes) do |entry|
                found = true
                yield entry
            end
        rescue => detail
            if count == 0
                # Try reconnecting to ldap if we get an exception and we haven't yet retried.
                count += 1
                @connection = nil
                Puppet.warning "Retrying LDAP connection"
                retry
            else
                error = Puppet::Error.new("LDAP Search failed")
                error.set_backtrace(detail.backtrace)
                raise error
            end
        end

        return found
    end

    private

    # Create an ldap connection.
    def connection
        unless defined? @connection and @connection
            unless Puppet.features.ldap?
                raise Puppet::Error, "Could not set up LDAP Connection: Missing ruby/ldap libraries"
            end
            begin
                if Puppet[:ldapssl]
                    @connection = LDAP::SSLConn.new(Puppet[:ldapserver], Puppet[:ldapport])
                elsif Puppet[:ldaptls]
                    @connection = LDAP::SSLConn.new(
                        Puppet[:ldapserver], Puppet[:ldapport], true
                    )
                else
                    @connection = LDAP::Conn.new(Puppet[:ldapserver], Puppet[:ldapport])
                end
                @connection.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
                @connection.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_ON)
                @connection.simple_bind(Puppet[:ldapuser], Puppet[:ldappassword])
            rescue => detail
                raise Puppet::Error, "Could not connect to LDAP: %s" % detail
            end
        end

        return @connection
    end
end
