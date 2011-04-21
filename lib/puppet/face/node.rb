require 'puppet/face/indirector'
Puppet::Face::Indirector.define(:node, '0.0.1') do
  summary "View and manage nodes"

  @longdocs = "It defaults to using whatever your node
  terminus is set as."
end
