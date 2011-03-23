require 'puppet/interface/indirector'

Puppet::Interface::Indirector.interface(:node) do
  set_default_format :yaml
end
