require 'rgen/ecore/ecore_interface'
require 'rgen/metamodel_builder/intermediate/annotation'

module RGen

module MetamodelBuilder

# This module is used to extend modules which should be
# part of RGen metamodels
module ModuleExtension
  include RGen::ECore::ECoreInterface
  
  def annotation(hash)
    _annotations << Intermediate::Annotation.new(hash)
  end
  
  def _annotations
    @_annotations ||= []
  end

  def _constantOrder
    @_constantOrder ||= []
  end
  
  def final_method(m)
    @final_methods ||= []
    @final_methods << m
  end
  
  def method_added(m)
    raise "Method #{m} can not be redefined" if @final_methods && @final_methods.include?(m)
  end

  def self.extended(m)
    MetamodelBuilder::ConstantOrderHelper.moduleCreated(m)
  end

end

end

end
