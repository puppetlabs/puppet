require 'puppet/util/posix'

module Puppet
  # Manage file group ownership.
  Puppet::Type.type(:file).newproperty(:group) do
    desc <<-EOT
      Which group should own the file.  Argument can be either a group
      name or a group ID.

      On Windows, a user (such as "Administrator") can be set as a file's group
      and a group (such as "Administrators") can be set as a file's owner;
      however, a file's owner and group shouldn't be the same. (If the owner
      is also the group, files with modes like `"0640"` will cause log churn, as
      they will always appear out of sync.)
    EOT

    validate do |group|
      raise(Puppet::Error, "Invalid group name '#{group.inspect}'") unless group and group != ""
    end

    def insync?(current)
      # We don't want to validate/munge groups until we actually start to
      # evaluate this property, because they might be added during the catalog
      # apply.
      @should.map! do |val|
        provider.name2gid(val) or raise "Could not find group #{val}"
      end

      @should.include?(current)
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      super(provider.gid2name(currentvalue) || currentvalue)
    end

    def should_to_s(newvalue)
      super(provider.gid2name(newvalue) || newvalue)
    end
  end
end
