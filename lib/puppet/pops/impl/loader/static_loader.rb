require 'puppet/pops/api'
require 'rgen/ecore/ecore'
module Puppet; module Pops; module Impl
module Loader

  # Static Loader contains constants, basic data types and other types required for the system
  # to boot.
  #
  class StaticLoader
  include Puppet::Pops::API::Utils
  Utils = Puppet::Pops::API::Utils
  
  def [](name)
    load_constant(name)
  end
  
  def load(name, executor)
    load_constant(Utils.relativize_name(name))
  end
  
  def find(name, executor)
    nil
  end
  
  def parent
    nil # at top of the hierarchy
  end
  
  private 
  
  def load_constant(name)
    case name
    when 'String'
      RGen::ECore::EString
    when 'Boolean'
      RGen::ECore::EBoolean
    when 'Float'
      RGen::ECore::EFloat
    when 'Integer'
      RGen::ECore::EInt
    else
      nil
    end  
  end
end
end; end; end; end