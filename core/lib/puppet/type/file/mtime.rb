module Puppet
  Puppet::Type.type(:file).newproperty(:mtime) do
    desc %q{A read-only state to check the file mtime. On \*nix-like systems, this
      is the time of the most recent change to the content of the file.}

    def retrieve
      current_value = :absent
      if stat = @resource.stat
        current_value = stat.mtime
      end
      current_value
    end

    validate do |val|
      fail "mtime is read-only"
    end
  end
end
