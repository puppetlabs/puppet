require 'puppet/interface/indirector'

Puppet::Interface::Indirector.new(:node) do
  set_default_format :yaml
end
