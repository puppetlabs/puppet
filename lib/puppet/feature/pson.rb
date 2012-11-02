Puppet.features.add(:pson) do
  Puppet.deprecation_warning "There is no need to check for pson support. It is always available."
  true
end
