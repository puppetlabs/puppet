require 'puppet/faces/indirector'

Puppet::Faces::Indirector.define(:node, '0.0.1') do
  set_default_format :yaml
end
