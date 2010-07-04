require 'puppet/util/feature'

# We want this to load if possible, but it's not automatically
# required.
Puppet.features.rubygems?
Puppet.features.add(:zlib, :libs => %{zlib})
