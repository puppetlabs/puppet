module RGen

module ECore

# Mixin to provide access to the ECore model describing a Ruby class or module
# built using MetamodelBuilder.
# The module should be used to +extend+ a class or module, i.e. to make its
# methods class methods.
# 
module ECoreInterface
  
  # This method will lazily build to ECore model element belonging to the calling
  # class or module using RubyToECore.
  # Alternatively, the ECore model element can be provided up front. This is used
  # when the Ruby metamodel classes and modules are created from ECore.
  # 
  def ecore
    if defined?(@ecore)
      @ecore
    else
      unless defined?(@@transformer)
        require 'rgen/ecore/ruby_to_ecore'
        @@transformer = RubyToECore.new
      end
      @@transformer.trans(self)
    end
  end  

  # This method can be used to clear the ecore cache after the metamodel classes
  # or modules have been changed; the ecore model will be recreated on next access
  # to the +ecore+ method
  # Beware, the ecore cache is global, i.e. for all metamodels.
  #
  def self.clear_ecore_cache
    require 'rgen/ecore/ruby_to_ecore'
    @@transformer = RubyToECore.new
  end

  def _set_ecore_internal(ecore) # :nodoc:
    @ecore = ecore
  end

end

end

end
