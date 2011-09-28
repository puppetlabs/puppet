require 'puppet/util/posix'

# Manage file group ownership.
module Puppet
  Puppet::Type.type(:file).newproperty(:group) do
    desc "Which group should own the file.  Argument can be either group
      name or group ID."

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
      provider.gid2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue)
      provider.gid2name(newvalue) || newvalue
    end
  end
end
