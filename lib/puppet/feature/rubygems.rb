require 'puppet/util/feature'

Puppet.features.add(:rubygems) do
  defined? ::Gem
end
