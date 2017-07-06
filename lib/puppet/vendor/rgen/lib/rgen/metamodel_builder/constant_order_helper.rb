module RGen

module MetamodelBuilder

# The purpose of the ConstantOrderHelper is to capture the definition order of RGen metamodel builder 
# classes, modules and enums. The problem is that Ruby doesn't seem to track the order of
# constants being created in a module. However the order is important because it defines the order
# of eClassifiers and eSubpackages in a EPackage.
#
# It would be helpful here if Ruby provided a +const_added+ callback, but this is not the case up to now.
#
# The idea for capturing is that all events of creating a RGen class, module or enum are reported to the
# ConstantOrderHelper singleton.
# For classes and modules it tries to add their names to the parent's +_constantOrder+ array.
# The parent module is derived from the class's or module's name. However, the new name is only added
# if the respective parent module has a new constant (which is not yet in +_constantOrder+) which
# points to the new class or module.
# For enums it is a bit more complicated, because at the time the enum is created, the parent
# module does not yet contain the constant to which the enum is assigned. Therefor, the enum is remembered
# and it is tried to be stored on the next event (class, module or enum) within the module which was
# created last (which was last extended with ModuleExtension). If it can not be found in that module,
# all parent modules of the last module are searched. This way it should also be correctly entered in
# case it was defined outside of the last created module. 
# Note that an enum is not stored to the constant order array unless another event occurs. That's why
# it is possible that one enum is missing at the enum. This needs to be taken care of by the ECore transformer.
#
# This way of capturing should be sufficient for the regular use cases of the RGen metamodel builder language.
# However, it is possible to write code which messes this up, see unit tests for details.
# In the worst case, the new classes, modules or enums will just not be found in a parent module and thus be ignored.
#
ConstantOrderHelper = Class.new do

  def initialize
    @currentModule = nil
    @pendingEnum = nil
  end

  def classCreated(c)
    handlePendingEnum
    cont = containerModule(c)
    name = (c.name || "").split("::").last
    return unless cont.respond_to?(:_constantOrder) && !cont._constantOrder.include?(name)
    cont._constantOrder << name
  end

  def moduleCreated(m)
    handlePendingEnum
    cont = containerModule(m)
    name = (m.name || "").split("::").last
    return unless cont.respond_to?(:_constantOrder) && !cont._constantOrder.include?(name)
    cont._constantOrder << name
    @currentModule = m
  end

  def enumCreated(e)
    handlePendingEnum
    @pendingEnum = e
  end

  private

  def containerModule(m)
    containerName = (m.name || "").split("::")[0..-2].join("::")
    containerName.empty? ? nil : eval(containerName, TOPLEVEL_BINDING)
  end 

  def handlePendingEnum
    return unless @pendingEnum
    m = @currentModule
    while m
      if m.respond_to?(:_constantOrder)
        newConstants = m.constants - m._constantOrder
        const = newConstants.find{|c| m.const_get(c).object_id == @pendingEnum.object_id}
        if const
          m._constantOrder << const.to_s
          break
        end
      end
      m = containerModule(m)
    end
    @pendingEnum = nil
  end
      
end.new

end

end

