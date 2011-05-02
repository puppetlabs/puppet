require 'puppet/indirector/face'
Puppet::Indirector::Face.define(:node, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "View and manage nodes"

  description <<-EOT
It defaults to using whatever your node terminus is set as.
  EOT
end
