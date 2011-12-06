module Puppet
  Puppet::Type.type(:file).newproperty(:ctime) do
    desc "A read-only state to check the file ctime."

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

