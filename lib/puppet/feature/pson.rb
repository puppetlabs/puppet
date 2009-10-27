Puppet.features.add(:pson) do
    require 'puppet/external/pson/common'
    require 'puppet/external/pson/version'
    require 'puppet/external/pson/pure'
    true
end
