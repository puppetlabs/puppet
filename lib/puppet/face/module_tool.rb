require 'puppet/face'
require 'puppet/module_tool'

Puppet::Face.define(:module_tool, '1.0.0') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Creates, installs and searches for modules on the Puppet Forge."
  description <<-EOT
    Creates, installs and searches for modules on the Puppet Forge.
  EOT
end
