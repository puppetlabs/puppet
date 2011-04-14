require 'puppet/face/indirector'

Puppet::Face::Indirector.define(:node, '0.0.1') do
  set_default_format :yaml
end
