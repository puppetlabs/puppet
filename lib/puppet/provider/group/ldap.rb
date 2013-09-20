require 'puppet/provider/ldap'

Puppet::Type.type(:group).provide :ldap, :parent => Puppet::Provider::Ldap do
  desc "Group management via LDAP.

    This provider requires that you have valid values for all of the
    LDAP-related settings in `puppet.conf`, including `ldapbase`.  You will
    almost definitely need settings for `ldapuser` and `ldappassword` in order
    for your clients to write to LDAP.

    Note that this provider will automatically generate a GID for you if you do
    not specify one, but it is a potentially expensive operation, as it
    iterates across all existing groups to pick the appropriate next one."

  confine :feature => :ldap, :false => (Puppet[:ldapuser] == "")

  # We're mapping 'members' here because we want to make it
  # easy for the ldap user provider to manage groups.  This
  # way it can just use the 'update' method in the group manager,
  # whereas otherwise it would need to replicate that code.
  manages(:posixGroup).at("ou=Groups").and.maps :name => :cn, :gid => :gidNumber, :members => :memberUid

  # Find the next gid after the current largest gid.
  provider = self
  manager.generates(:gidNumber).with do
    largest = 500
    if existing = provider.manager.search
        existing.each do |hash|
        next unless value = hash[:gid]
        num = value[0].to_i
        largest = num if num > largest
      end
    end
    largest + 1
  end

  # Convert a group name to an id.
  def self.name2id(group)
    return nil unless result = manager.search("cn=#{group}") and result.length > 0

    # Only use the first result.
    group = result[0]
    group[:gid][0]
  end
end
