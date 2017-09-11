module Puppet::Pops
module Validation

# Validator that limits the set of allowed expressions to not include catalog related operations
# @api private
class TasksChecker < Checker4_0
  def check_Application(o)
    illegalTasksExpression(o)
  end

  def check_CapabilityMapping(o)
    illegalTasksExpression(o)
  end

  def check_CollectExpression(o)
    illegalTasksExpression(o)
  end

  def check_HostClassDefinition(o)
    illegalTasksExpression(o)
  end

  def check_NodeDefinition(o)
    illegalTasksExpression(o)
  end

  def check_RelationshipExpression(o)
    illegalTasksExpression(o)
  end

  def check_ResourceDefaultsExpression(o)
    illegalTasksExpression(o)
  end

  def check_ResourceExpression(o)
    illegalTasksExpression(o)
  end

  def check_ResourceOverrideExpression(o)
    illegalTasksExpression(o)
  end

  def check_ResourceTypeDefinition(o)
    illegalTasksExpression(o)
  end

  def check_SiteDefinition(o)
    illegalTasksExpression(o)
  end

  def illegalTasksExpression(o)
    acceptor.accept(Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING, o)
  end

  def resource_without_title?(o)
    false
  end
end
end
end
