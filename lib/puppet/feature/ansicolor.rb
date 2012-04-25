require 'puppet/util/feature'

Puppet.features.rubygems?
Puppet.features.add(:ansicolor,
  Puppet.features.microsoft_windows? ? { :libs => 'win32console' } : {} )
