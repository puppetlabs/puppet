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
  # This make this class instantiable from Puppet
  include Puppet::Pops::Types::PuppetObject

  def self.register_ptype(loader, ir)
    @ptype = Pcore::create_object_type(loader, ir, self, 'Puppet::Resource::Param', nil,
      {
        Types::KEY_TYPE => Types::PTypeType::DEFAULT,
        Types::KEY_NAME => Types::PStringType::NON_EMPTY,
        'name_var' => {
          Types::KEY_TYPE => Types::PBooleanType::DEFAULT,
          Types::KEY_VALUE => false
        }
      },
      EMPTY_HASH,
      [Types::KEY_NAME]
    )
  end

  attr_reader :name
  attr_reader :type
  attr_reader :name_var

  def initialize(type, name, name_var = false)
    @type = type
    @name = name
    @name_var = name_var
  end

  def to_s
    name
  end

  def self._pcore_type
    @ptype
  end
end
end
end
