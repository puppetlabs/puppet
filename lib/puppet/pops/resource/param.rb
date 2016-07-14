# An implementation of the interface Puppet::Resource
# that adapts the 3.x compiler and catalog expectations on
# a resource instance. This instance is backed by a
# pcore representation of the resource type an instance of this
# ruby class.
#
# This class must inherit from Puppet::Resource because of the
# class expectations in existing logic.
#
# This implementation does not support
# * setting 'strict' - strictness (must refer to an existing type) is always true
# * does not support the indirector
# 
#
module Puppet::Pops
module Resource
class Param
  # This make this class instantiateable from Puppet
  include Puppet::Pops::Types::PuppetObject

  attr_reader :name
  attr_reader :type
  attr_reader :name_var

  def initialize(type, name, name_var = false)
    @type = type
    @name = name
    @name_var = name_var
  end

  def self._ptype
    # TODO
  end
end
end
end
