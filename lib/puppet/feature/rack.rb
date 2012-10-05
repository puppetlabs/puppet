require 'puppet/util/feature'

# See if we have rack available, an HTTP Application Stack
# Explicitly depend on rack library version >= 1.0.0
Puppet.features.add(:rack) do
  require 'rack'

  if ! (defined?(::Rack) and defined?(::Rack.release))
    false
  else
    major_version = ::Rack.release.split('.')[0].to_i
    if major_version >= 1
      true
    else
      false
    end
  end
end

