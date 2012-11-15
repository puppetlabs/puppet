require 'puppet/util/feature'

Puppet.features.add(:rubygems) do
  Puppet.deprecation_warning "Puppet.features.rubygems? is deprecated. Require rubygems in your application's entry point if you need it."

  require 'rubygems'
end
