require 'puppet/util/feature'

if Puppet.features.microsoft_windows?
  Puppet.features.add(:eventlog, :libs => %{win32/eventlog})
end
