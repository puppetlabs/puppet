# RGen Framework
# (c) Martin Thiede, 2006

require 'rgen/util/name_helper'

module RGen

module MetamodelBuilder

# This module is mixed into MetamodelBuilder::MMBase.
# The methods provided by this module are used by the methods generated
# by the class methods of MetamodelBuilder::BuilderExtensions
module BuilderRuntime
	include Util::NameHelper
	
	def is_a?(c)
    return super unless c.const_defined?(:ClassModule)
    kind_of?(c::ClassModule)
	end
	
	def addGeneric(role, value, index=-1)
		send("add#{firstToUpper(role.to_s)}",value, index)
	end
	
	def removeGeneric(role, value)
		send("remove#{firstToUpper(role.to_s)}",value)
	end
	
	def setGeneric(role, value)
		send("set#{firstToUpper(role.to_s)}",value)
	end

  def hasManyMethods(role)
    respond_to?("add#{firstToUpper(role.to_s)}")
  end

  def setOrAddGeneric(role, value)
    if hasManyMethods(role)
      addGeneric(role, value)
    else
      setGeneric(role, value)
    end
  end

  def setNilOrRemoveGeneric(role, value)
    if hasManyMethods(role)
      removeGeneric(role, value)
    else
      setGeneric(role, nil)
    end
  end

  def setNilOrRemoveAllGeneric(role)
    if hasManyMethods(role)
      setGeneric(role, [])
    else
      setGeneric(role, nil)
    end
  end

	def getGeneric(role)
		send("get#{firstToUpper(role.to_s)}")
	end

  def getGenericAsArray(role)
    result = getGeneric(role)
    result = [result].compact unless result.is_a?(Array)
    result
  end

  def eIsSet(role)
    eval("defined? @#{role}") != nil
  end

  def eUnset(role)
    if respond_to?("add#{firstToUpper(role.to_s)}")
      setGeneric(role, [])
    else
      setGeneric(role, nil)
    end
    remove_instance_variable("@#{role}")
  end

  def eContainer
    @_container
  end

  def eContainingFeature
    @_containing_feature_name
  end

  # returns the contained elements in no particular order
  def eContents
    if @_contained_elements
      @_contained_elements.dup
    else
      []
    end
  end

  # if a block is given, calls the block on every contained element in depth first order. 
  # if the block returns :prune, recursion will stop at this point.
  #
  # if no block is given builds and returns a list of all contained elements.
  #
  def eAllContents(&block)
    if block
      if @_contained_elements
        @_contained_elements.each do |e|
          res = block.call(e)
          e.eAllContents(&block) if res != :prune
        end
      end
      nil
    else
      result = []
      if @_contained_elements
        @_contained_elements.each do |e|
          result << e
          result.concat(e.eAllContents)
        end
      end
      result
    end
  end

  def disconnectContainer
    eContainer.setNilOrRemoveGeneric(eContainingFeature, self) if eContainer
  end

  def _set_container(container, containing_feature_name)
    # if a new container is set, make sure to disconnect from the old one.
    # note that _set_container will never be called for the container and the role
    # which are currently set because the accessor methods in BuilderExtensions
    # block setting/adding a value which is already present.
    # (it may be called for the same container with a different role, a different container
    # with the same role and a different container with a different role, though)
    # this ensures, that disconnecting for the current container doesn't break
    # a new connection which has just been set up in the accessor methods.
    disconnectContainer if container
    @_container._remove_contained_element(self) if @_container
    container._add_contained_element(self) if container
    @_container = container
    @_containing_feature_name = containing_feature_name
  end

  def _add_contained_element(element)
    @_contained_elements ||= []
    @_contained_elements << element
  end

  def _remove_contained_element(element)
    @_contained_elements.delete(element) if @_contained_elements
  end

	def _assignmentTypeError(target, value, expected)
		text = ""
		if target
			targetId = target.class.name
			targetId += "(" + target.name + ")" if target.respond_to?(:name) and target.name
			text += "In #{targetId} : "
		end
		valueId = value.class.name
		valueId += "(" + value.name + ")" if value.respond_to?(:name) and value.name
		valueId += "(:" + value.to_s + ")" if value.is_a?(Symbol)
		text += "Can not use a #{valueId} where a #{expected} is expected"
		StandardError.new(text)
	end

end

end

end
