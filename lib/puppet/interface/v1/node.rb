require 'puppet/interface/indirector'

Puppet::Interface::Indirector.interface(:node, 1) do
  set_default_format :yaml
end
