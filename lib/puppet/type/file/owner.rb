module Puppet
  Puppet::Type.type(:file).newproperty(:owner) do
    include Puppet::Util::Warnings

    desc <<-EOT
      The user to whom the file should belong.  Argument can be a user name or a
      user ID.

      On Windows, a group (such as "Administrators") can be set as a file's owner
      and a user (such as "Administrator") can be set as a file's group; however,
      a file's owner and group shouldn't be the same. (If the owner is also
      the group, files with modes like `0640` will cause log churn, as they
      will always appear out of sync.)
    EOT

    def insync?(current)
      # We don't want to validate/munge users until we actually start to
      # evaluate this property, because they might be added during the catalog
      # apply.
      @should.map! do |val|
        provider.name2uid(val) or raise "Could not find user #{val}"
      end

      return true if @should.include?(current)

      unless Puppet.features.root?
        warnonce "Cannot manage ownership unless running as root"
        return true
      end

      false
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      provider.uid2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue)
      provider.uid2name(newvalue) || newvalue
    end
  end
end

