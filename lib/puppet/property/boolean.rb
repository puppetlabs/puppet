# frozen_string_literal: true

require_relative '../../puppet/coercion'

class Puppet::Property::Boolean < Puppet::Property
  def unsafe_munge(value)
    Puppet::Coercion.boolean(value)
  end
end
