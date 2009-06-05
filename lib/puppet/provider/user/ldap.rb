require 'puppet/provider/ldap'

Puppet::Type.type(:user).provide :ldap, :parent => Puppet::Provider::Ldap do
    desc "User management via ``ldap``.  This provider requires that you
        have valid values for all of the ldap-related settings,
        including ``ldapbase``.  You will also almost definitely need settings
        for ``ldapuser`` and ``ldappassword``, so that your clients can write
        to ldap.

        Note that this provider will automatically generate a UID for you if
        you do not specify one, but it is a potentially expensive operation,
        as it iterates across all existing users to pick the appropriate next
        one."

    confine :feature => :ldap, :false => (Puppet[:ldapuser] == "")

    has_feature :manages_passwords

    manages(:posixAccount, :person).at("ou=People").named_by(:uid).and.maps :name => :uid,
        :password => :userPassword,
        :comment => :cn,
        :uid => :uidNumber,
        :gid => :gidNumber,
        :home => :homeDirectory,
        :shell => :loginShell

    # Use the last field of a space-separated array as
    # the sn.  LDAP requires a surname, for some stupid reason.
    manager.generates(:sn).from(:cn).with do |cn|
        x = 1
        cn[0].split(/\s+/)[-1]
    end

    # Find the next uid after the current largest uid.
    provider = self
    manager.generates(:uidNumber).with do
        largest = 500
        if existing = provider.manager.search
            existing.each do |hash|
                next unless value = hash[:uid]
                num = value[0].to_i
                if num > largest
                    largest = num
                end
            end
        end
        largest + 1
    end

    # Convert our gid to a group name, if necessary.
    def gid=(value)
        unless [Fixnum, Bignum].include?(value.class)
            value = group2id(value)
        end

        @property_hash[:gid] = value
    end

    # Find all groups this user is a member of in ldap.
    def groups
        # We want to cache the current result, so we know if we
        # have to remove old values.
        unless @property_hash[:groups]
            unless result = group_manager.search("memberUid=%s" % name)
                return @property_hash[:groups] = :absent
            end

            return @property_hash[:groups] = result.collect { |r| r[:name] }.join(",")
        end
        return @property_hash[:groups]
    end

    # Manage the list of groups this user is a member of.
    def groups=(values)
        should = values.split(",")

        if groups() == :absent
            is = []
        else
            is = groups().split(",")
        end

        modes = {}
        [is, should].flatten.uniq.each do |group|
            # Skip it when they're in both
            next if is.include?(group) and should.include?(group)

            # We're adding a group.
            modes[group] = :add and next unless is.include?(group)

            # We're removing a group.
            modes[group] = :remove and next unless should.include?(group)
        end

        modes.each do |group, form|
            self.fail "Could not find ldap group %s" % group unless ldap_group = group_manager.find(group)

            current = ldap_group[:members]

            if form == :add
                if current.is_a?(Array) and ! current.empty?
                    new = current + [name]
                else
                    new = [name]
                end
            else
                new = current - [name]
                new = :absent if new.empty?
            end

            group_manager.update(group, {:ensure => :present, :members => current}, {:ensure => :present, :members => new})
        end
    end

    # Convert a gropu name to an id.
    def group2id(group)
        Puppet::Type.type(:group).provider(:ldap).name2id(group)
    end

    private

    def group_manager
        Puppet::Type.type(:group).provider(:ldap).manager
    end

    def group_properties(values)
        if values.empty? or values == :absent
            {:ensure => :present}
        else
            {:ensure => :present, :members => values}
        end
    end
end
