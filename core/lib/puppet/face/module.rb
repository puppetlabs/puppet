require 'puppet/face'
require 'puppet/module_tool'
require 'puppet/util/colors'

Puppet::Face.define(:module, '1.0.0') do
  extend Puppet::Util::Colors

  copyright "Puppet Labs", 2012
  license   "Apache 2 license; see COPYING"

  summary "Creates, installs and searches for modules on the Puppet Forge."
  description <<-EOT
    This subcommand can find, install, and manage modules from the Puppet Forge,
    a repository of user-contributed Puppet code. It can also generate empty
    modules, and prepare locally developed modules for release on the Forge.
  EOT

  display_global_options "environment", "modulepath"
end
