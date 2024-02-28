# frozen_string_literal: true

module Puppet
  Puppet::Type.type(:file).newproperty(:ctime) do
    desc %q(A read-only state to check the file ctime. On most modern \*nix-like
      systems, this is the time of the most recent change to the owner, group,
      permissions, or content of the file.)

    def retrieve
      current_value = :absent
      stat = @resource.stat
      if stat
        current_value = stat.ctime
      end
      current_value.to_s
    end

    validate do |_val|
      fail "ctime is read-only"
    end
  end
end
