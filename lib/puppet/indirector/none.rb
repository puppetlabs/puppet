require 'puppet/indirector/terminus'

# A none terminus type, meant to always return nil
class Puppet::Indirector::None < Puppet::Indirector::Terminus
  def find(request)
    return nil
  end
end

