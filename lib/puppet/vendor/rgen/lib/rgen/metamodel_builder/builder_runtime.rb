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

  def _set_container(container, containing_feature_name)
    @_container = container
    @_containing_feature_name = containing_feature_name
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
