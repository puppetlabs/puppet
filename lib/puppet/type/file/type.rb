module Puppet
  Puppet::Type.type(:file).newproperty(:type) do
    require 'etc'
    desc "A read-only state to check the file type."

    def retrieve
      current_value = :absent
      stat = @resource.stat
      if stat
        current_value = stat.ftype
      end
      current_value
    end

    validate do |val|
      fail "type is read-only"
    end
  end
end

