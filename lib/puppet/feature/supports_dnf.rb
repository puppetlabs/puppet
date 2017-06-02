require 'puppet/util/feature'

# Enable dnf feature on platforms that support it
Puppet.features.add(:supports_dnf) do
  File.file?('/usr/bin/dnf')
end
