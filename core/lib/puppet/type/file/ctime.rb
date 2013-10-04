module Puppet
  Puppet::Type.type(:file).newproperty(:ctime) do
    desc %q{A read-only state to check the file ctime. On most modern \*nix-like
      systems, this is the time of the most recent change to the owner, group,
      permissions, or content of the file.}

    def retrieve
      current_value = :absent
      if stat = @resource.stat
        current_value = stat.ctime
      end
      current_value
    end

    validate do |val|
      fail "ctime is read-only"
    end
  end
end

