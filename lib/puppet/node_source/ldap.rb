Puppet::Network::Handler::Node.newnode_source(:ldap, :fact_merge => true) do
    desc "Search in LDAP for node configuration information."

    # Find the ldap node, return the class list and parent node specially,
    # and everything else in a parameter hash.
    def ldapsearch(node)
        filter = Puppet[:ldapstring]
        classattrs = Puppet[:ldapclassattrs].split("\s*,\s*")
        if Puppet[:ldapattrs] == "all"
            # A nil value here causes all attributes to be returned.
            search_attrs = nil
        else
            search_attrs = classattrs + Puppet[:ldapattrs].split("\s*,\s*")
        end
        pattr = nil
        if pattr = Puppet[:ldapparentattr]
            if pattr == ""
                pattr = nil
            else
                search_attrs << pattr unless search_attrs.nil?
            end
        end

        if filter =~ /%s/
            filter = filter.gsub(/%s/, node)
        end

        parent = nil
        classes = []
        parameters = nil

        found = false
        count = 0

        begin
            # We're always doing a sub here; oh well.
            ldap.search(Puppet[:ldapbase], 2, filter, search_attrs) do |entry|
                found = true
                if pattr
                    if values = entry.vals(pattr)
                        if values.length > 1
                            raise Puppet::Error,
                                "Node %s has more than one parent: %s" %
                                [node, values.inspect]
                        end
                        unless values.empty?
                            parent = values.shift
                        end
                    end
                end

                classattrs.each { |attr|
                    if values = entry.vals(attr)
                        values.each do |v| classes << v end
                    end
                }

                parameters = entry.to_hash.inject({}) do |hash, ary|
                    if ary[1].length == 1
                        hash[ary[0]] = ary[1].shift
                    else
                        hash[ary[0]] = ary[1]
                    end
                    hash
                end
            end
        rescue => detail
            if count == 0
                # Try reconnecting to ldap
                @ldap = nil
                retry
            else
                raise Puppet::Error, "LDAP Search failed: %s" % detail
            end
        end

        classes.flatten!

        if classes.empty?
            classes = nil
        end

        if parent or classes or parameters
            return parent, classes, parameters
        else
            return nil
        end
    end

    # Look for our node in ldap.
    def nodesearch(node)
        unless ary = ldapsearch(node)
            return nil
        end
        parent, classes, parameters = ary

        while parent
            parent, tmpclasses, tmpparams = ldapsearch(parent)
            classes += tmpclasses if tmpclasses
            tmpparams.each do |param, value|
                # Specifically test for whether it's set, so false values are handled
                # correctly.
                parameters[param] = value unless parameters.include?(param)
            end
        end

        return newnode(node, :classes => classes, :source => "ldap", :parameters => parameters)
    end

    private

    # Create an ldap connection.
    def ldap
        unless defined? @ldap and @ldap
            unless Puppet.features.ldap?
                raise Puppet::Error, "Could not set up LDAP Connection: Missing ruby/ldap libraries"
            end
            begin
                if Puppet[:ldapssl]
                    @ldap = LDAP::SSLConn.new(Puppet[:ldapserver], Puppet[:ldapport])
                elsif Puppet[:ldaptls]
                    @ldap = LDAP::SSLConn.new(
                        Puppet[:ldapserver], Puppet[:ldapport], true
                    )
                else
                    @ldap = LDAP::Conn.new(Puppet[:ldapserver], Puppet[:ldapport])
                end
                @ldap.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
                @ldap.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_ON)
                @ldap.simple_bind(Puppet[:ldapuser], Puppet[:ldappassword])
            rescue => detail
                raise Puppet::Error, "Could not connect to LDAP: %s" % detail
            end
        end

        return @ldap
    end
end
