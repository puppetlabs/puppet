# Group Puppet provider for AIX. It uses standard commands to manage groups:
#  mkgroup, rmgroup, lsgroup, chgroup
require 'puppet/provider/aix_object'

Puppet::Type.type(:group).provide :aix, :parent => Puppet::Provider::AixObject do
  desc "Group management for AIX."

  # This will the default provider for this platform
  defaultfor :operatingsystem => :aix
  confine :operatingsystem => :aix

  # Commands that manage the element
  commands :list      => "/usr/sbin/lsgroup"
  commands :add       => "/usr/bin/mkgroup"
  commands :delete    => "/usr/sbin/rmgroup"
  commands :modify    => "/usr/bin/chgroup"

  # Provider features
  has_features :manages_aix_lam
  has_features :manages_members

  class << self
    # Used by the AIX user provider. Returns a hash of:
    #   {
    #     :name => <group_name>,
    #     :gid  => <gid>
    #   }
    #
    # that matches the group, which can either be the group name or
    # the gid. Takes an optional set of ia_module_args
    def find(group, ia_module_args = [])
      groups = list_all(ia_module_args)

      id_property = mappings[:puppet_property][:id]

      if group.is_a?(String)
        # Find by name
        group_hash = groups.find { |cur_group| cur_group[:name] == group }
      else
        # Find by gid
        group_hash = groups.find do |cur_group|
          id_property.convert_attribute_value(cur_group[:id]) == group
        end
      end

      unless group_hash
        raise ArgumentError, _("No AIX group exists with a group name or gid of %{group}!") % { group: group }
      end

      # Convert :id => :gid
      id = group_hash.delete(:id)
      group_hash[:gid] = id_property.convert_attribute_value(id)

      group_hash
    end

    # Define some Puppet Property => AIX Attribute (and vice versa)
    # conversion functions here. This is so we can unit test them.

    def members_to_users(provider, members)
      members = members.split(',') if members.is_a?(String)
      unless provider.resource[:auth_membership]
        current_members = provider.members
        current_members = [] if current_members == :absent
        members = (members + current_members).uniq
      end

      members.join(',')
    end

    def users_to_members(users)
      users.split(',')
    end
  end

  mapping puppet_property: :members,
          aix_attribute: :users,
          property_to_attribute: method(:members_to_users),
          attribute_to_property: method(:users_to_members)

  numeric_mapping puppet_property: :gid,
                  aix_attribute: :id

  # Now that we have all of our mappings, let's go ahead and make
  # the resource methods (property getters + setters for our mapped
  # properties + a getter for the attributes property).
  mk_resource_methods

  # We could add this to the top-level members property since the
  # implementation is not platform-specific; however, it is best
  # to do it this way so that we do not accidentally break something.
  # This is ok for now, since we do plan on moving this and the
  # auth_membership management over to the property class in a future
  # Puppet release.
  def members_insync?(current, should)
    current.sort == @resource.parameter(:members).actual_should(current, should)
  end
end
