# frozen_string_literal: true

require_relative '../../puppet/indirector/terminus'

# A none terminus type, meant to always return nil
class Puppet::Indirector::None < Puppet::Indirector::Terminus
  def find(request)
    nil
  end
end
